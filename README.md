# Monthly encounter exercise

Use Ruby **4.0.2** with the `csv` and `minitest` libraries available.

Run with an input CSV path and a four-digit reporting year:

```sh
ruby monthly_encounters.rb /tmp/synthea-encounter-practice.vB55Dy/extracted/csv/encounters.csv 2019
```

The script prints CSV to standard output with columns `month,encounter_count`.
It always includes January through December in chronological order, using
`YYYY-MM` month labels and zero for months with no encounters.

Rules:

- Input must have case-sensitive `Id` and `START` headers; extra columns are ignored.
- Every row needs a nonblank ID and a valid ISO 8601 timestamp with seconds and
  an explicit timezone (`Z` or an offset such as `-05:00`).
- Convert timestamps to UTC before selecting the reporting year and month.
- Count each ID once. Repeated IDs with the same UTC start instant are duplicates
  and count once, including timestamps written with equivalent timezone offsets.
- Reject repeated IDs with different UTC start instants, even within one day.
- Validate all rows, including those outside the requested year. Errors go to
  standard error with a nonzero exit status; no partial report is printed.

Run the tests:

```sh
ruby test_monthly_encounters.rb
```

The tests use tiny fictional records and manually specified expected monthly
counts. Temporary input files are removed automatically. Keep downloaded datasets
and any saved reports outside this repository; neither belongs in Git.
