import duckdb
from fsspec import filesystem
from google.cloud import bigquery
from datetime import datetime, timedelta

def initialize_duckdb():
  """
  Initialize DuckDB connection with custom settings.
  """
  conn = duckdb.connect(':memory:')
  conn.register_filesystem(filesystem('gcs'))
  return conn

def extract_data_from_gcs(conn, gcs_path):
  """
  Read parquet files from GCS into DuckDB.
  """
  print('Extracting data...')
  conn.execute(f"CREATE TABLE source AS SELECT * FROM read_parquet('{gcs_path}')")

def transform_data_in_duckdb(conn):
  """
  Transform data using DuckDB.
  """
  query = """
    CREATE TABLE transformed AS
      SELECT
        merchant_id,
        transaction_type,
        transaction_payment_method,
        SUM(transaction_amount) AS transaction_amount,
        COUNT(DISTINCT transaction_id) AS transaction,
        transaction_datetime::DATE AS transaction_date,
        current_timestamp AS load_at
      FROM 
        source 
      WHERE 
        transaction_status = 'completed'
      GROUP BY
        1,2,3,6,7
  """
  print('Transforming data...')
  conn.execute(query)
  conn.execute('DROP TABLE IF EXISTS source')

def load_data_to_gcs(conn, gcs_path):
  """
  Write transformed data as Parquet to GCS.
  """
  print('Load data to GCS...')
  conn.execute(f"COPY (SELECT * FROM transformed) TO '{gcs_path}' (FORMAT 'parquet', CODEC 'zstd')")
  conn.execute('DROP TABLE IF EXISTS transformed')

def load_data_to_bigquery(gcs_path, table_id):
  """
  Load transformed parquet file to BigQuery.
  """
  client = bigquery.Client()

  job_config = bigquery.LoadJobConfig(
    source_format=bigquery.SourceFormat.PARQUET,
    write_disposition=bigquery.WriteDisposition.WRITE_APPEND
    )

  load_job = client.load_table_from_uri(
    gcs_path, table_id, job_config=job_config
    )

  print('Load data to BigQuery...')
  load_job.result()

def yesterday():
  now_utc7 = datetime.now() + timedelta(hours=7)
  return now_utc7.date() - timedelta(days=1)

def main(request):
  """
  Cloud Function to extract data from Parquet files in GCS, transform using DuckDB, and load to BigQuery.
  """
  request_json = request.get_json(silent=True)
  bucket_name = request_json['bucket']
  table_id = request_json['table_id']
  date = yesterday()

  input_gcs_path = f'gs://{bucket_name}/merchant_transactions/raw/{date.year}/{date.month}/transactions_{date}.parquet'
  output_gcs_path = f'gs://{bucket_name}/merchant_transactions/processed/{date.year}/{date.month}/transactions_agg_{date}.parquet'

  try:
    conn = initialize_duckdb()
    extract_data_from_gcs(conn, input_gcs_path)
    transform_data_in_duckdb(conn)
    load_data_to_gcs(conn, output_gcs_path)
    load_data_to_bigquery(output_gcs_path, table_id)
    print('ETL success.')
    return 'Completed.'

  except Exception as e:
    print(f'An error occurred: {str(e)}')
    return 'Failed.'
    
if __name__ == '__main__':
  main(request)
