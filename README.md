# Procurement Process Analytics
## Purchase-to-Pay Bottleneck Investigation

An independent data analytics project using **Python, MySQL and Power BI** to investigate procurement process intervals in the **BPI Challenge 2019** event log.

[Download Power BI Report](https://github.com/chiragdeep0512/procurement-process-analytics/releases)

## Business Problem

Which procurement stages have longer observed elapsed times, and which vendor groups should be prioritized for further investigation?

The analysis compares process stages, identifies above-benchmark receipts-to-clearing intervals, and examines monthly patterns.

## Dataset

| Metric | Count |
|---|---:|
| Events | 1,595,923 |
| Purchase-order-item cases | 251,734 |
| Purchase documents | 76,349 |
| Activity types | 42 |
| Stage baseline cases | 168,051 |
| Date-review events | 320 |
| Cases affected by date flags | 266 |

**Case definition:** one purchase document plus item. A case is not an individual invoice.

Source: van Dongen, B. (2019), BPI Challenge 2019,
4TU.ResearchData, CC BY 4.0.

[Original Dataset](https://doi.org/10.4121/uuid:d06aff4b-79f0-45e6-8ec8-e19730c248f1)

This project uses a public CSV conversion of the event log.
Aggregate counts were checked; byte-level equivalence with
the original XES was not established.

## Tools and Workflow

- **Python / pandas:** chunked inspection, timestamp parsing,
  identifier validation and event preparation.
- **MySQL:** staging tables, case summaries, baseline selection,
  window functions, median and nearest-rank P90 analysis.
- **Power BI:** Power Query transformations, data modeling,
  DAX measures and interactive reporting.

Workflow:
Source CSV → Python audits → Prepared events → MySQL analysis
→ Reporting CSVs → Power BI

## Key Findings

### 1. Stage durations differ by process category

Median elapsed calendar days in the selected baseline:

| Stage | Invoice before GR | Invoice after GR |
|---|---:|---:|
| PO creation to first receipt | 8.26 | 9.03 |
| First receipt to second receipt | 8.29 | 23.22 |
| Both receipts recorded to clearing | 42.90 | 27.25 |

GR means goods receipt. Process categories are source labels;
actual event order can vary within a category.

### 2. Long intervals are concentrated among three vendors

Within the **160,825-case invoice-before-GR baseline**:

- Fixed receipts-to-clear P90 benchmark: **97.8770833 days**.
- **16,081 cases** strictly exceed the exact benchmark.
- Three vendors account for **12,955**, approximately
  **80.6%**, of these above-benchmark cases.
- Those vendors represent approximately **15.0%** of baseline cases.

| Vendor | Baseline Cases | Long Interval Cases | Rate |
|---|---:|---:|---:|
| vendorID_0136 | 10,178 | 7,400 | 72.71% |
| vendorID_0120 | 10,217 | 3,420 | 33.47% |
| vendorID_0103 | 3,669 | 2,135 | 58.19% |

**Recommended investigation:** review payment terms,
processing practices and case composition before attributing
the observed differences to a cause.

## Baseline Definition

The stage baseline contains cases from the two three-way-match
categories with:

- Consistent case attributes.
- Exactly one goods receipt, invoice receipt and clearing event.
- No cancellation activities.
- Required milestone dates present, correctly ordered and
  within 2018–2019.

Excluded cases are not automatically invalid. Multiple receipts
and invoices can be legitimate procurement behavior.

## Power BI Data Model

| Table | Grain | Rows |
|---|---|---:|
| Cases | One row per purchase-order-item case | 251,734 |
| StageIntervals | One row per baseline case and stage | 504,153 |

Relationship: **Cases[case_id] (1) → StageIntervals[case_id] (*)**

The relationship is active and filters in a single direction
from Cases to StageIntervals.

## Report Pages

1. **Process Overview:** case counts and stage duration comparison.
2. **Vendor Investigation:** vendor medians, long interval
   counts and rates.
3. **Monthly Comparison:** monthly cohorts based on the second
   receipt date.
4. **Methodology:** baseline rules, date review and limitations.

Download the PBIX from the repository's Releases section.
A PDF export is included among the project files.

## How to Reproduce

1. Obtain the source CSV conversion and inspect its headers.
2. Install pandas and configure the Python input/output paths.
3. Run Python scripts **01–06** in numbered order.
4. Run SQL scripts **01–12** in numbered order using MySQL.
5. Adjust the LOAD DATA path to your server's permitted directory.
   Import once into an empty staging table; check counts before retrying.
6. Export the final reporting views with headers and no row limit:
   - `case_report.csv`: 251,734 rows, 28 columns.
   - `stage_report.csv`: 504,153 rows, 5 columns.
7. Open the PBIX in Power BI Desktop, update the CSV paths in
   Power Query and refresh.

Early inspection scripts contain local Windows paths and
need adjustment on another computer. Raw and processed datasets
are not bundled in this repository.

## Validation

- No missing required source fields detected.
- Event identifiers are unique.
- Case identifiers match purchase-document and item keys.
- All source timestamps parsed successfully.
- Dates outside the dominant years were retained and flagged.
- Power BI stage medians and selected vendor results were
  reconciled against SQL outputs.

## Interpretation Limits

- Calendar duration is not working time or an SLA breach.
- Long intervals do not establish overdue payment.
- Observed clearing does not prove full case completion.
- Vendor associations do not establish causality.
- Late-period cohorts have follow-up and selection limitations;
  shorter intervals do not establish improvement.
- Event-level cumulative monetary values are not summed as spend.
- Separate stage medians cannot be added to obtain a median
  end-to-end duration.

## Author

**Naman Deep Singh**

Independent portfolio project demonstrating data auditing,
SQL analysis, Power BI modeling and business interpretation.
