import os
import glob
from pyspark.sql import SparkSession

# --- Connection config (override with env vars) ---
DB_HOST     = os.getenv("DB_HOST",     "localhost")
DB_PORT     = os.getenv("DB_PORT",     "5432")
DB_NAME     = os.getenv("DB_NAME",     "")
DB_USER     = os.getenv("DB_USER",     "")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
JDBC_JAR    = os.getenv("JDBC_JAR",    "./postgresql.jar")

BACKUP_DIR  = os.getenv("BACKUP_DIR",  "./backup")
WRITE_MODE  = os.getenv("WRITE_MODE",  "overwrite")  # overwrite | append

JDBC_URL = f"jdbc:postgresql://{DB_HOST}:{DB_PORT}/{DB_NAME}"

def main():
    for var in ("DB_NAME", "DB_USER", "DB_PASSWORD"):
        if not os.getenv(var):
            raise SystemExit(f"ERROR: {var} environment variable is required")

    spark = SparkSession.builder \
        .appName("parquet-to-postgres-spark") \
        .config("spark.jars", JDBC_JAR) \
        .config("spark.driver.memory", "2g") \
        .config("spark.driver.extraJavaOptions",
                "-Dlog4j.logger.org.apache.hadoop.util.NativeCodeLoader=ERROR") \
        .getOrCreate()

    spark.sparkContext.setLogLevel("WARN")

    jdbc_props = {
        "user":     DB_USER,
        "password": DB_PASSWORD,
        "driver":   "org.postgresql.Driver",
    }

    if not os.path.isdir(BACKUP_DIR):
        raise SystemExit(f"ERROR: BACKUP_DIR '{BACKUP_DIR}' does not exist")

    def find_table_dirs(base):
        """Return list of (schema.table, abs_path) by searching up to 2 levels deep."""
        results = []
        for name in os.listdir(base):
            path = os.path.join(base, name)
            if not os.path.isdir(path):
                continue
            if "." in name:
                results.append((name, path))
            else:
                for sub in os.listdir(path):
                    subpath = os.path.join(path, sub)
                    if os.path.isdir(subpath) and "." in sub:
                        results.append((sub, subpath))
        return sorted(results)

    table_dirs = find_table_dirs(BACKUP_DIR)

    if not table_dirs:
        raise SystemExit(f"ERROR: No schema.table directories found in '{BACKUP_DIR}'")

    for entry, entry_path in table_dirs:
        schema, table = entry.split(".", 1)
        parquet_path = os.path.join(entry_path, "1") + "/"
        files = glob.glob(f"{parquet_path}*.parquet")
        if not files:
            print(f"  Skipping {entry} — no parquet files found")
            continue

        print(f"\n[{schema}.{table}]")
        df = spark.read.parquet(parquet_path)
        print(f"  Rows: {df.count()}")
        df.printSchema()

        df.write.jdbc(
            url=JDBC_URL,
            table=f'"{schema}"."{table}"',
            mode=WRITE_MODE,
            properties=jdbc_props,
        )
        print(f"  Done: {schema}.{table}")

    spark.stop()
    print("\nRestore complete.")

if __name__ == "__main__":
    main()
