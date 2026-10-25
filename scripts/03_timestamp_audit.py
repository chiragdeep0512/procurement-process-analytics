from collections import Counter
from pathlib import Path
import pandas as pd

file_path = Path(
    r"D:\AAAAAAAAAAAAAAAAAAAA . New Project\1st one\Data\Procurement_Project\data\raw\BPI_Challenge_2019.csv"
)

total_events = 0
blank_timestamps = 0
unparseable_timestamps = 0
year_counts = Counter()

for chunk in pd.read_csv(
    file_path,
    encoding="cp1252",
    dtype=str,
    keep_default_na=False,
    usecols=["event time:timestamp"],
    chunksize=100_000
):
    raw_timestamps = chunk["event time:timestamp"]

    blank_mask = raw_timestamps.str.strip().eq("")

    parsed_timestamps = pd.to_datetime(
        raw_timestamps,
        format="%d-%m-%Y %H:%M:%S.%f",
        errors="coerce"
    )

    total_events += len(chunk)
    blank_timestamps += int(blank_mask.sum())

    unparseable_timestamps += int(
        (parsed_timestamps.isna() & ~blank_mask).sum()
    )

    year_counts.update(
        parsed_timestamps.dropna()
        .dt.year
        .value_counts()
        .to_dict()
    )

print("Total events:", f"{total_events:,}")
print("Blank timestamps:", blank_timestamps)

print(
    "Unparseable nonblank timestamps:",
    unparseable_timestamps
)

print("\nEVENTS BY YEAR")
for year, count in sorted(year_counts.items()):
    print(f"{year}: {count:,}")