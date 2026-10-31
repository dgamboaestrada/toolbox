# parquet-to-postgres-spark

Restores an AWS RDS Export to S3 (Parquet format) into a PostgreSQL database using PySpark — the local equivalent of AWS Glue.

Spark handles type mapping automatically via its JDBC connector and is significantly faster than row-by-row insertion.

## Requirements

- Python 3.11 (via pyenv)
- pipenv
- Java 11 (required by PySpark 3.5.x)
- Docker (for local testing)
- PostgreSQL JDBC driver JAR

## Setup

Install the correct Python and Java versions:

```bash
pyenv install 3.11
pyenv local 3.11
brew install openjdk@11
export JAVA_HOME=$(brew --prefix openjdk@11)
export PATH="$JAVA_HOME/bin:$PATH"
```

Install dependencies:

```bash
pipenv install
```

Download the PostgreSQL JDBC driver:

```bash
curl -L https://jdbc.postgresql.org/download/postgresql-42.7.3.jar -o postgresql.jar
```

## Local testing

Start a local PostgreSQL container:

```bash
DB_NAME=mydb DB_USER=myuser docker compose up -d
```

Run the restore:

```bash
DB_NAME=mydb DB_USER=myuser DB_PASSWORD=localtest pipenv run python restore.py
```

Verify the data:

```bash
docker exec -it parquet-to-postgres-spark-postgres-1 psql -U myuser -d mydb
```

## Restore to RDS

```bash
DB_HOST=<rds-host> DB_NAME=<db-name> DB_USER=<user> DB_PASSWORD=<password> pipenv run python restore.py
```

## Backup directory structure

The script auto-detects both layouts produced by AWS RDS Export to S3:

**Flat** (database root points directly to tables):
```
BACKUP_DIR/
  public.table_name/
    1/
      part-00000-*.gz.parquet
```

**Nested** (database root contains a database-name subdirectory):
```
BACKUP_DIR/
  my_database/
    public.table_name/
      1/
        part-00000-*.gz.parquet
```

Pass the export root as `BACKUP_DIR` in either case — the script searches up to two levels deep.

## Environment variables

| Variable      | Default            | Required | Description                        |
|---------------|--------------------|----------|------------------------------------|
| `DB_HOST`     | `localhost`        | No       | PostgreSQL host                    |
| `DB_PORT`     | `5432`             | No       | PostgreSQL port                    |
| `DB_NAME`     |                    | Yes      | Database name                      |
| `DB_USER`     |                    | Yes      | Database user                      |
| `DB_PASSWORD` |                    | Yes      | Database password                  |
| `JDBC_JAR`    | `./postgresql.jar` | No       | Path to the PostgreSQL JDBC driver |
| `BACKUP_DIR`  | `./backup`         | No       | Path to the exported Parquet files |
| `WRITE_MODE`  | `overwrite`        | No       | Spark write mode: overwrite/append |

## Compatibility

| Component | Version |
|-----------|---------|
| PySpark   | 3.5.5   |
| Java      | 11      |
| Python    | 3.11    |

## Notes

- Spark handles Parquet → PostgreSQL type mapping automatically via the JDBC connector.
- `WRITE_MODE=overwrite` drops and recreates tables on each run — safe to re-run.
- PySpark 3.5.x requires Java 11. Java 17+ causes Hadoop compatibility issues. Java 26+ is not supported.
- PySpark 4.x requires Java 17+ and is not compatible with this setup.
