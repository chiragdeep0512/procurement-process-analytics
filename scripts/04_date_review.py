from pathlib import Path
import pandas as pd

file_path = Path(
    r"D:\AAAAAAAAAAAAAAAAAAAA . New Project\1st one\Data\Procurement_Project\data\raw\BPI_Challenge_2019.csv"
)

output_folder = (
    Path(__file__).resolve().parent.parent / "outputs"
)
output_folder.mkdir(parents=True, exist_ok=True)

output_file = output_folder / "date_review_candidates.csv"

review_parts = []
original_columns = []

for chunk in pd.read_csv(
    file_path,
    encoding="cp1252",
    dtype=str,
    keep_default_na=False,
    chunksize=100_000
):
    original_columns = chunk.columns.tolist()

    parsed = pd.to_datetime(
        chunk["event time:timestamp"],
        format="%d-%m-%Y %H:%M:%S.%f",
        errors="coerce"
    )

    event_years = parsed.dt.year

    # Temporary review rule based on dominant years
    review_mask = (
        parsed.isna()
        | ~event_years.between(2018, 2019)
    )

    if review_mask.any():
        review_rows = chunk.loc[review_mask].copy()

        review_rows["event_year"] = (
            event_years.loc[review_mask].astype("Int64")
        )

        review_rows["review_reason"] = (
            "outside_dominant_years"
        )

        invalid_dates = parsed.loc[review_mask].isna()

        review_rows.loc[
            invalid_dates, "review_reason"
        ] = "missing_or_unparseable_timestamp"

        review_parts.append(review_rows)

if review_parts:
    report = pd.concat(review_parts, ignore_index=True)
else:
    report = pd.DataFrame(
        columns=original_columns
        + ["event_year", "review_reason"]
    )

report.to_csv(
    output_file,
    index=False,
    encoding="utf-8-sig"
)

print("Review events:", len(report))

print(
    "Affected cases:",
    report["case concept:name"].nunique()
)

print("\nActivities requiring date review:")
print(report["event concept:name"].value_counts().to_string())

print("\nReport saved at:", output_file)