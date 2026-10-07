from google.cloud import bigquery, storage
from datetime import datetime, timezone, timedelta

creds = r"C:\Users\alysi\.gcp\icef-437920.json"

# GCS generations / soft-delete
storage_client = storage.Client.from_service_account_json(creds, project="icef-437920")
bucket = storage_client.bucket("dbt_historicalbucket-icefschools-1")
print("=== GCS versions/generations for waiting_list_2027.csv ===")
blobs = list(
    storage_client.list_blobs(
        "dbt_historicalbucket-icefschools-1",
        prefix="waiting_list_2027.csv",
        versions=True,
    )
)
print("versioned objects found:", len(blobs))
for b in blobs:
    print(
        {
            "name": b.name,
            "generation": b.generation,
            "size": b.size,
            "updated": b.updated,
            "time_deleted": getattr(b, "time_deleted", None),
            "metageneration": b.metageneration,
        }
    )

# Also soft-deleted?
print("\nbucket versioning_enabled:", bucket.versioning_enabled)

# BQ table time travel
bq = bigquery.Client.from_service_account_json(creds, project="icef-437920", location="us-west1")
print("\n=== BQ waiting_list_2027 current ===")
t = bq.get_table("icef-437920.dbt_historical.waiting_list_2027")
print("rows", t.num_rows, "modified", t.modified, "created", t.created)

for hours in [1, 2, 6, 12, 24, 48, 72, 168]:
    ts = (datetime.now(timezone.utc) - timedelta(hours=hours)).strftime("%Y-%m-%d %H:%M:%S")
    try:
        n = list(
            bq.query(
                f"""
                SELECT COUNT(*) AS n
                FROM `icef-437920.dbt_historical.waiting_list_2027`
                FOR SYSTEM_TIME AS OF TIMESTAMP('{ts}')
                """
            ).result()
        )[0]["n"]
        print(f"{hours}h ago ({ts}): {n} rows")
    except Exception as e:
        print(f"{hours}h ago FAIL:", str(e)[:180])
