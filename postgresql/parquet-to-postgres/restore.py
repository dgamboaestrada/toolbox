import os
import glob
import pyarrow.parquet as pq
import psycopg2
from psycopg2.extras import execute_values

# --- Connection config (override with env vars) ---
DB_HOST     = os.getenv("DB_HOST",     "localhost")
DB_PORT     = int(os.getenv("DB_PORT", "5432"))
DB_NAME     = os.getenv("DB_NAME",     "")
DB_USER     = os.getenv("DB_USER",     "")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

BACKUP_DIR  = os.getenv("BACKUP_DIR",  "./backup")
BATCH_SIZE  = int(os.getenv("BATCH_SIZE", "1000"))

# --- Arrow -> PostgreSQL type mapping ---
ARROW_TO_PG = {
    "int8":          "SMALLINT",
    "int16":         "SMALLINT",
    "int32":         "INTEGER",
    "int64":         "BIGINT",
    "uint8":         "SMALLINT",
    "uint16":        "INTEGER",
    "uint32":        "BIGINT",
    "uint64":        "NUMERIC",
    "float":         "REAL",
    "double":        "DOUBLE PRECISION",
    "bool":          "BOOLEAN",
    "string":        "TEXT",
    "large_string":  "TEXT",
    "utf8":          "TEXT",
    "large_utf8":    "TEXT",
    "binary":        "BYTEA",
    "large_binary":  "BYTEA",
    "date32[day]":   "DATE",
    "date64[ms]":    "DATE",
}

def pg_type(arrow_type):
    t = str(arrow_type)
    if t in ARROW_TO_PG:
        return ARROW_TO_PG[t]
    if t.startswith("timestamp"):
        return "TIMESTAMP"
    if t.startswith("decimal"):
        return "NUMERIC"
    return "TEXT"

def create_table(cur, schema, table, arrow_schema):
    cur.execute(f'DROP TABLE IF EXISTS "{schema}"."{table}";')
    cols = ", ".join(
        f'"{f.name}" {pg_type(f.type)}'
        for f in arrow_schema
    )
    cur.execute(f'CREATE TABLE "{schema}"."{table}" ({cols});')

def restore_table(conn, schema, table, parquet_files):
    cur = conn.cursor()
    print(f"\n[{schema}.{table}] {len(parquet_files)} file(s)")

    first = pq.read_table(parquet_files[0])
    print("  Schema:")
    for f in first.schema:
        print(f"    {f.name}: {f.type} -> {pg_type(f.type)}")
    create_table(cur, schema, table, first.schema)
    conn.commit()

    col_names = [f'"{f.name}"' for f in first.schema]
    insert_sql = f'INSERT INTO "{schema}"."{table}" ({", ".join(col_names)}) VALUES %s'

    col_order = [f.name for f in first.schema]
    total_rows = 0
    for fpath in parquet_files:
        tbl = pq.read_table(fpath)
        rows = [tuple(row[c] for c in col_order) for row in tbl.to_pylist()]
        for i in range(0, len(rows), BATCH_SIZE):
            execute_values(cur, insert_sql, rows[i:i + BATCH_SIZE])
        conn.commit()
        total_rows += len(rows)
        print(f"  {os.path.basename(fpath)} — {len(rows)} rows  (total: {total_rows})")

    cur.close()
    print(f"  Done: {total_rows} rows imported into {schema}.{table}")

def main():
    for var in ("DB_NAME", "DB_USER", "DB_PASSWORD"):
        if not os.getenv(var):
            raise SystemExit(f"ERROR: {var} environment variable is required")

    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=DB_USER, password=DB_PASSWORD
    )
    print(f"Connected to {DB_HOST}/{DB_NAME}")

    table_dirs = sorted([
        d for d in os.listdir(BACKUP_DIR)
        if os.path.isdir(os.path.join(BACKUP_DIR, d)) and "." in d
    ])

    for entry in table_dirs:
        schema, table = entry.split(".", 1)
        parquet_files = sorted(glob.glob(f"{BACKUP_DIR}/{entry}/1/*.parquet"))
        if not parquet_files:
            print(f"  Skipping {entry} — no parquet files found")
            continue
        restore_table(conn, schema, table, parquet_files)

    conn.close()
    print("\nRestore complete.")

if __name__ == "__main__":
    main()
