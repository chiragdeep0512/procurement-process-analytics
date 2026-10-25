from pathlib import Path
import json
import pandas as pd

file_path = Path(
    r"D:\AAAAAAAAAAAAAAAAAAAA . New Project\1st one\Data\Procurement_Project\data\raw\BPI_Challenge_2019.csv"
)

output_folder = (
    Path(__file__).resolve().parent.parent / "outputs"
)
output_folder.mkdir(parents=True, exist_ok=True)

required_columns = [
    "eventID",
    "case concept:name",
    "case Purchasing Document",
    "case Item",
    "event concept:name",
    "event time:timestamp"
]

missing_tokens = {"", "NONE", "NULL", "N/A", "NA", "NAN"}

missing_counts = {
    column: 0 for column in required_columns
}

total_events = 0
seen_event_ids = set()
repeated_event_ids = 0
case_key_mismatches = 0
header_changes = []

for chunk_number, chunk in enumerate(
    pd.read_csv(
        file_path,
        encoding="cp1252",
        dtype=str,
        keep_default_na=False,
        chunksize=100_000
    )
):
    original_headers = chunk.columns.tolist()
    trimmed_headers = [
        column.strip() for column in original_headers
    ]

    if len(trimmed_headers) != len(set(trimmed_headers)):
        raise ValueError(
            "Header trimming se duplicate column names ban rahe hain."
        )

    if chunk_number == 0:
        header_changes = [
            {"original": old, "trimmed": new}
            for old, new in zip(
                original_headers, trimmed_headers
            )
            if old != new
        ]

    chunk.columns = trimmed_headers

    missing_columns = [
        column for column in required_columns
        if column not in chunk.columns
    ]

    if missing_columns:
        raise ValueError(
            f"Required columns nahi mile: {missing_columns}"
        )

    total_events += len(chunk)

    # Required fields mein missing values check karo
    for column in required_columns:
        values = chunk[column].str.strip().str.upper()

        missing_counts[column] += int(
            values.isin(missing_tokens).sum()
        )

    # Event IDs ki uniqueness poori file mein check karo
    for event_id in chunk["eventID"]:
        if event_id.strip().upper() in missing_tokens:
            continue

        if event_id in seen_event_ids:
            repeated_event_ids += 1
        else:
            seen_event_ids.add(event_id)

    # Case ID ka purchase document/item se match
    expected_case_ids = (
        chunk["case Purchasing Document"]
        + "_"
        + chunk["case Item"]
    )

    case_key_mismatches += int(
        chunk["case concept:name"]
        .ne(expected_case_ids)
        .sum()
    )

report = {
    "total_events": total_events,
    "header_changes": header_changes,
    "missing_required_values": missing_counts,
    "unique_nonmissing_event_ids": len(seen_event_ids),
    "repeated_event_id_occurrences": repeated_event_ids,
    "case_key_mismatches": case_key_mismatches
}

output_file = output_folder / "structure_audit.json"

output_file.write_text(
    json.dumps(report, indent=2),
    encoding="utf-8"
)

print(json.dumps(report, indent=2))
print("\nReport saved at:", output_file)