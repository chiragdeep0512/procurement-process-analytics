from pathlib import Path
import pandas as pd

# Script ke folder se CSV ka path banayenge
project_folder = Path(__file__).resolve().parent.parent

file_path = Path(
    r"D:\AAAAAAAAAAAAAAAAAAAA . New Project\1st one\Data\Procurement_Project\data\raw\BPI_Challenge_2019.csv"
)

print("CSV path:", file_path)

if not file_path.is_file():
    raise FileNotFoundError(
        "CSV nahi mili. File location aur folder structure check karo."
    )

# Abhi sirf pehli 10 rows read karenge
df_preview = pd.read_csv(
    file_path,
    encoding="cp1252",
    dtype=str,
    keep_default_na=False,
    nrows=10
)

print("\nPreview shape:", df_preview.shape)

print("\nColumn names:")
for number, column in enumerate(df_preview.columns, start=1):
    print(f"{number}. {column!r}")

# Console mein kuch important columns dekhenge
preview_columns = [
    "case concept:name",
    "case Purchasing Document",
    "case Item",
    "event concept:name",
    "event time:timestamp"
]

print("\nFirst 10 activity records:")
print(df_preview[preview_columns].to_string(index=False))


# Full dataset ke basic counts
total_events = 0
case_ids = set()
purchase_documents = set()
activity_names = set()

required_columns = [
    "case concept:name",
    "case Purchasing Document",
    "event concept:name"
]

for chunk in pd.read_csv(
    file_path,
    encoding="cp1252",
    dtype=str,
    keep_default_na=False,
    usecols=required_columns,
    chunksize=100_000
):
    total_events += len(chunk)

    case_ids.update(chunk["case concept:name"])

    purchase_documents.update(
        chunk["case Purchasing Document"]
    )

    activity_names.update(chunk["event concept:name"])

print("\nFULL DATASET COUNTS")
print(f"Total events: {total_events:,}")
print(f"Unique cases: {len(case_ids):,}")
print(f"Purchase documents: {len(purchase_documents):,}")
print(f"Activity types: {len(activity_names):,}")