# parquet-to-postgres

Restores an AWS RDS Export to S3 (Parquet format) into a PostgreSQL database using PyArrow and psycopg2.

Reads the Parquet schema to generate `CREATE TABLE` statements automatically and inserts data in configurable batches.

## Requirements

- Python 3
- pipenv
- Docker (for local testing)

## Setup

```bash
pipenv install
```

## Local testing

Start a local PostgreSQL container:

```bash
docker compose up -d
```

Run the restore:

```bash
DB_HOST=localhost DB_NAME=mydb DB_USER=myuser DB_PASSWORD=mypassword pipenv run python restore.py
```

## Restore to RDS

```bash
DB_HOST=<rds-host> DB_NAME=<db-name> DB_USER=<user> DB_PASSWORD=<password> pipenv run python restore.py
```

## Environment variables

| Variable      | Default     | Required | Description                        |
|---------------|-------------|----------|------------------------------------|
| `DB_HOST`     | `localhost` | No       | PostgreSQL host                    |
| `DB_PORT`     | `5432`      | No       | PostgreSQL port                    |
| `DB_NAME`     |             | Yes      | Database name                      |
| `DB_USER`     |             | Yes      | Database user                      |
| `DB_PASSWORD` |             | Yes      | Database password                  |
| `BACKUP_DIR`  | `./backup`  | No       | Path to the exported Parquet files |
| `BATCH_SIZE`  | `1000`      | No       | Rows per INSERT batch              |

## Backup structure expected

The directory layout matches the output of `aws rds start-export-task`:

```
<BACKUP_DIR>/
  <schema>.<table_name>/
    1/
      part-00000-*.gz.parquet
      part-00001-*.gz.parquet
      ...
      _SUCCESS
```

## Notes

- Tables are dropped and recreated on each run to ensure the schema is always up to date.
- Uses PyArrow's `to_pylist()` for type-safe null handling — avoids pandas float conversion issues with nullable integers.
- `uint64` maps to `NUMERIC` since its max value exceeds PostgreSQL `BIGINT` range.
