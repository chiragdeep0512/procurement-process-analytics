from pathlib import Path
import pandas as pd

file_path = Path(
    r"D:\AAAAAAAAAAAAAAAAAAAA . New Project\1st one\Data\Procurement_Project\data\raw\BPI_Challenge_2019.csv"
)

# Preview mein dikhne wala ek case
target_case = "4507004931_00020"

required_columns = [
    "case concept:name",
    "case Purchasing Document",
    "case Item",
    "case Item Category",
    "event concept:name",
    "event time:timestamp"
]

case_parts = []

# Poori file mein is case ki saari activities dhoondhenge
for chunk in pd.read_csv(
    file_path,
    encoding="cp1252",
    dtype=str,
    keep_default_na=False,
    usecols=required_columns,
    chunksize=100_000
):
    matched_rows = chunk.loc[
        chunk["case concept:name"].eq(target_case),
        required_columns
    ]

    if not matched_rows.empty:
        case_parts.append(matched_rows.copy())

if not case_parts:
    raise ValueError(f"Case nahi mila: {target_case}")

case_data = pd.concat(case_parts, ignore_index=True)

# Original timestamp ke saath ek parsed column banayenge
case_data["parsed_timestamp"] = pd.to_datetime(
    case_data["event time:timestamp"],
    format="%d-%m-%Y %H:%M:%S.%f",
    errors="coerce"
)

# Date/time ke according arrange karenge
case_data = case_data.sort_values(
    "parsed_timestamp",
    kind="stable",
    na_position="last"
)

print("Case ID:", target_case)

print(
    "Process categories:",
    case_data["case Item Category"].unique().tolist()
)

print("Total events:", len(case_data))

print(
    "Unparseable timestamps:",
    case_data["parsed_timestamp"].isna().sum()
)

print("\nCASE TIMELINE")
print(
    case_data[
        ["event concept:name", "event time:timestamp"]
    ].to_string(index=False)
)