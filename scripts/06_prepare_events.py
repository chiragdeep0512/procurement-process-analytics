"""Prepare BPI Challenge 2019 events for a MySQL staging table.

Run this file from your project's scripts folder in PyCharm.
The default input follows the folder structure confirmed in the tutorial.
Optional command-line arguments allow the same script to run elsewhere.

All source event rows and source field values are retained. Date flags are
review candidates based on the observed dominant years, not confirmed errors.
The source monetary measure is anonymised; no monetary totals are calculated.

Dataset: van Dongen, B. (2019), BPI Challenge 2019, 4TU.ResearchData.
DOI: 10.4121/uuid:d06aff4b-79f0-45e6-8ec8-e19730c248f1
"""

import argparse
import json
from collections import Counter
from pathlib import Path

import pandas as pd


PROJECT_FOLDER = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = (
    PROJECT_FOLDER
    / "Data"
    / "Procurement_Project"
    / "data"
    / "raw"
    / "BPI_Challenge_2019.csv"
)

# Source column names after trimming their outer whitespace.
RENAME_COLUMNS = {
    "eventID": "event_id",
    "case Spend area text": "spend_area",
    "case Company": "company_id",
    "case Document Type": "document_type",
    "case Sub spend area text": "sub_spend_area",
    "case Purchasing Document": "purchase_document_id",
    "case Purch. Doc. Category name": "purchase_document_category",
    "case Vendor": "vendor_id",
    "case Item Type": "item_type",
    "case Item Category": "item_category",
    "case Spend classification text": "spend_classification",
    "case Source": "source_system_id",
    "case Name": "vendor_name",
    "case GR-Based Inv. Verif.": "gr_based_invoice_verification",
    "case Item": "item_id",
    "case concept:name": "case_id",
    "case Goods Receipt": "goods_receipt_required",
    "event User": "event_user",
    "event org:resource": "event_resource",
    "event concept:name": "activity",
    "event Cumulative net worth (EUR)": "source_cumulative_net_worth_eur",
    "event time:timestamp": "event_timestamp_raw",
}

DOMINANT_YEAR_START = 2018
DOMINANT_YEAR_END = 2019


def prepare_events(
    input_file: Path,
    output_file: Path,
    summary_file: Path,
    chunk_size: int = 100_000,
) -> dict:
    """Stream the input into an annotated CSV and return its preparation report."""
    input_file = input_file.resolve()
    output_file = output_file.resolve()
    summary_file = summary_file.resolve()

    if not input_file.is_file():
        raise FileNotFoundError(
            f"CSV not found: {input_file}\n"
            "Place this Python file in the project's scripts folder, "
            "or provide the CSV location with --input."
        )
    if len({input_file, output_file, summary_file}) != 3:
        raise ValueError("Input, prepared CSV and summary paths must differ.")
    if chunk_size <= 0:
        raise ValueError("Chunk size must be greater than zero.")

    output_file.parent.mkdir(parents=True, exist_ok=True)
    summary_file.parent.mkdir(parents=True, exist_ok=True)
    temporary_file = output_file.with_suffix(output_file.suffix + ".part")
    if temporary_file == input_file:
        raise ValueError("Temporary output path would overwrite the input.")

    total_events = 0
    reason_counts = Counter()
    review_cases = set()
    written_columns = []
    first_chunk = True

    # UTF-8 and explicit LF newlines make the output straightforward to import.
    with temporary_file.open("w", encoding="utf-8", newline="") as output:
        for chunk in pd.read_csv(
            input_file,
            encoding="cp1252",
            dtype=str,
            keep_default_na=False,
            chunksize=chunk_size,
        ):
            source_columns = [column.strip() for column in chunk.columns]
            if len(source_columns) != len(set(source_columns)):
                raise ValueError("Trimming headers creates duplicate column names.")
            chunk.columns = source_columns

            missing = set(RENAME_COLUMNS) - set(source_columns)
            unexpected = set(source_columns) - set(RENAME_COLUMNS)
            if missing or unexpected:
                raise ValueError(
                    f"Source schema differs. Missing: {sorted(missing)}; "
                    f"unexpected: {sorted(unexpected)}"
                )

            prepared = chunk.rename(columns=RENAME_COLUMNS)
            prepared = prepared[list(RENAME_COLUMNS.values())].copy()

            raw_timestamps = prepared["event_timestamp_raw"]
            blank_mask = raw_timestamps.str.strip().eq("")
            parsed = pd.to_datetime(
                raw_timestamps,
                format="%d-%m-%Y %H:%M:%S.%f",
                errors="coerce",
            )

            # No timezone is inferred. The raw source timestamp is retained.
            prepared["event_timestamp"] = (
                parsed.dt.strftime("%Y-%m-%d %H:%M:%S.%f").fillna("")
            )
            prepared["event_year"] = parsed.dt.year.astype("Int64")

            outside_years = parsed.notna() & ~parsed.dt.year.between(
                DOMINANT_YEAR_START, DOMINANT_YEAR_END
            )
            prepared["date_review_reason"] = "within_dominant_years"
            prepared.loc[outside_years, "date_review_reason"] = (
                "outside_dominant_years"
            )
            prepared.loc[parsed.isna() & ~blank_mask, "date_review_reason"] = (
                "unparseable_timestamp"
            )
            prepared.loc[blank_mask, "date_review_reason"] = "blank_timestamp"
            prepared["date_review_required"] = (
                prepared["date_review_reason"]
                .ne("within_dominant_years")
                .astype("int8")
            )

            reason_counts.update(
                prepared["date_review_reason"].value_counts().to_dict()
            )
            review_cases.update(
                prepared.loc[
                    prepared["date_review_required"].eq(1), "case_id"
                ]
            )

            prepared.to_csv(
                output,
                index=False,
                header=first_chunk,
                lineterminator="\n",
            )
            first_chunk = False
            written_columns = prepared.columns.tolist()
            total_events += len(prepared)
            print(f"Prepared {total_events:,} events...", flush=True)

    if total_events == 0:
        raise ValueError("The input contains no event rows.")
    if sum(reason_counts.values()) != total_events:
        raise RuntimeError("Date-review counts do not reconcile to event rows.")

    # Publish the completed CSV only after all chunks finish successfully.
    temporary_file.replace(output_file)
    review_events = sum(
        count
        for reason, count in reason_counts.items()
        if reason != "within_dominant_years"
    )
    report = {
        "input_file_name": input_file.name,
        "input_encoding": "cp1252",
        "output_file_name": output_file.name,
        "output_encoding": "utf-8",
        "pandas_version": pd.__version__,
        "events_written": total_events,
        "output_column_count": len(written_columns),
        "output_columns": written_columns,
        "date_review_events": int(review_events),
        "cases_with_date_review_flags": len(review_cases),
        "date_review_reason_counts": {
            reason: int(count) for reason, count in sorted(reason_counts.items())
        },
        "date_review_rule": {
            "dominant_year_start": DOMINANT_YEAR_START,
            "dominant_year_end": DOMINANT_YEAR_END,
            "interpretation": (
                "Temporary review heuristic based on dominant years. A zero flag "
                "means the date parsed and its year is in this range; further "
                "case chronology and business-rule checks remain necessary."
            ),
        },
        "source_rows_filtered_out": 0,
        "source_field_values_corrected_or_imputed": False,
        "timezone_inferred": False,
        "notes": [
            "The source CSV is a documented third-party conversion of BPI 2019.",
            "Source IDs, leading zeros and original timestamp text are retained.",
            "Source monetary values are anonymised; the measure is not summed.",
        ],
    }
    summary_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print("\nPREPARATION COMPLETE")
    print(f"Events written: {total_events:,}")
    print(f"Output columns: {len(written_columns)}")
    print(f"Date review events: {review_events:,}")
    print(f"Cases with date review flags: {len(review_cases):,}")
    print(f"Prepared CSV: {output_file}")
    print(f"Summary report: {summary_file}")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--summary",
        type=Path,
        default=PROJECT_FOLDER / "outputs" / "preparation_summary.json",
    )
    parser.add_argument("--chunk-size", type=int, default=100_000)
    args = parser.parse_args()

    output_file = args.output or (
        args.input.parent.parent / "processed" / "events_prepared.csv"
    )
    prepare_events(args.input, output_file, args.summary, args.chunk_size)


if __name__ == "__main__":
    main()
