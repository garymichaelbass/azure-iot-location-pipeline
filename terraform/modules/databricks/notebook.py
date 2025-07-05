# azure-iot-location-monitoring\terraform\modules\databricks\notebook.py

# --- START dbutils Mock for Local Pylance/IDE Linting Only ---
# This block ensures 'dbutils' is defined for the local linter,
# but will not actually run or interfere in the Databricks runtime.
try:
    # This line will fail locally if dbutils is not defined, triggering the 'except' block.
    # In Databricks, dbutils is globally available, so this line succeeds and the 'except' is skipped.
    dbutils.widgets.get
except NameError:
    from types import SimpleNamespace

    class MockWidgets:
        def get(self, name):
            # Provide a dummy value for local testing/linting. This is what Pylance will see.
            # In a real Databricks job run, this code path is not taken.
            print(f"Pylance/Local Linting: Using mock value for widget '{name}'.")
            return f"__MOCKED_VALUE_FOR_{name.upper()}__"

    class MockDbutils:
        @property
        def widgets(self):
            return MockWidgets()

    dbutils = MockDbutils()
# --- END dbutils Mock ---


# Databricks notebook to read from Event Hub and write to Cosmos DB

# Import necessary types for defining the schema of the incoming data
from pyspark.sql.types import StructType, StringType, DoubleType, LongType
# Import functions for data transformation, specifically for parsing JSON
from pyspark.sql.functions import from_json, col, concat_ws

import logging # Import logging module

from pyspark.sql import SparkSession # Provides entry point for Spark

from pyspark.sql.streaming import StreamingQueryListener # Provides event handles for stream

print("🔍 Initializing IoT telemetry pipeline...")

# Configure logging for the notebook
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logging.info("Notebook started: Initializing environment and configurations.")

# Define the schema for the incoming JSON data from Event Hub.
schema = StructType() \
    .add("deviceId", StringType()) \
    .add("latitude", DoubleType()) \
    .add("longitude", DoubleType()) \
    .add("timestamp", LongType())

# Retrieve parameters
eventhub_connection_string = dbutils.widgets.get("eventhub_connection_string")
eventhub_connection_string_plus_entity = dbutils.widgets.get("eventhub_connection_string_plus_entity")

cosmos_db_endpoint         = dbutils.widgets.get("cosmos_db_endpoint")
cosmos_db_key              = dbutils.widgets.get("cosmos_db_key")
cosmos_db_database         = dbutils.widgets.get("cosmos_db_database")
cosmos_db_container        = dbutils.widgets.get("cosmos_db_container")

print("🔒 eventhub_connection_string_plus_entity (pre-encryption): ", eventhub_connection_string_plus_entity)

# Encrypt using Spark's JVM bridge
from pyspark.sql import SparkSession
spark = SparkSession.builder.getOrCreate()
sc = spark.sparkContext
encrypted_connection_string = sc._jvm.org.apache.spark.eventhubs.EventHubsUtils.encrypt(eventhub_connection_string_plus_entity)
print("🔒 encrypted_connection_string into ehConf: ", encrypted_connection_string)

ehConf = {
    "eventhubs.connectionString": encrypted_connection_string
}

print("📡 Event Hub configuration loaded:")
print(ehConf)

# Read streaming data from Azure Event Hubs.
try:
    spark
except NameError:
    from pyspark.sql import SparkSession
    spark = SparkSession.builder.getOrCreate()

    print("🚀 Spark session ready. Reading from Event Hub...")

raw_df = spark.readStream \
    .format("eventhubs") \
    .options(**ehConf) \
    .load()

print("✅ Successfully connected to Event Hub.")

# Optional: Stream raw Event Hub messages to console for debugging
print("✅ Stream raw Event Hub message to console for debugging:")
raw_df.selectExpr("cast(body as string) as raw_json").writeStream \
    .format("console") \
    .outputMode("append") \
    .option("truncate", False) \
    .start()

# Parse the raw Event Hub message body, which is a binary string, into a structured JSON format. 
# NOTE: Also add the required 'id' field
# json_df = raw_df.select(from_json(col("body").cast("string"), schema).alias("data")).select("data.*")
# json_df = json_df.withColumn("id", concat_ws("-", col("deviceId"), col("timestamp")))

# LATEST ADD FROM 20250704  8:47pm
from pyspark.sql.functions import when, lit

# Parse JSON and handle missing timestamps
json_df = raw_df.select(from_json(col("body").cast("string"), schema).alias("data")).select("data.*")

# # Replace null timestamps with current time (or a default)
# json_df = json_df.withColumn(
#     "timestamp",
#     when(col("timestamp").isNull(), lit(0)).otherwise(col("timestamp"))
# )

# # Add a unique ID field
# json_df = json_df.withColumn("id", concat_ws("-", col("deviceId"), col("timestamp")))

from pyspark.sql.functions import unix_timestamp, when

# Replace null timestamps with current time
json_df = json_df.withColumn(
    "timestamp",
    when(col("timestamp").isNull(), unix_timestamp()).otherwise(col("timestamp"))
)

# Add a unique ID field using deviceId and timestamp
json_df = json_df.withColumn("id", concat_ws("-", col("deviceId"), col("timestamp")))

print("🧬 Schema after parsing and adding id:")
json_df.printSchema()

# Configure the connection and write details for Azure Cosmos DB.
cosmos_config = {
    "spark.cosmos.accountEndpoint": cosmos_db_endpoint, 
    "spark.cosmos.accountKey": cosmos_db_key,     
    "spark.cosmos.database": cosmos_db_database,    
    "spark.cosmos.container": cosmos_db_container,  
    "spark.cosmos.write.strategy": "ItemOverwrite"
}

print("💾 Preparing to write to Cosmos DB...")
print("Cosmos config keys:", list(cosmos_config.keys()))
logging.info(f"Cosmos DB configuration loaded for database: {cosmos_config['spark.cosmos.database']}, container: {cosmos_config['spark.cosmos.container']}")

# Define the checkpoint location for the streaming query
# This path must be accessible and writable by the Databricks cluster.
# Ensure this path has proper permissions for the Databricks cluster/service principal.
checkpoint_path = "dbfs:/tmp/iot_streaming_checkpoints/cosmos_db" # A common temporary location on DBFS
dbutils.fs.mkdirs(checkpoint_path)
print(f"✅ Checkpoint location {checkpoint_path} created.")

# Write to Cosmos DB with batch logging
   
# Function to "log_batch" to Cosmos, which is call in the json_df.writeStream
def log_batch(df, epoch_id):
    count = df.count()
    print(f"📦 Writing batch {epoch_id} with {count} records; VERIFY next message is 'Batch {epoch_id} written to Cosmos DB.'")
    if count > 0:
        df.show(5, truncate=False)
        df.write \
            .format("cosmos.oltp") \
            .options(**cosmos_config) \
            .mode("append") \
            .save()
        print(f"✅ Batch {epoch_id} written to Cosmos DB.")

json_df.writeStream \
    .format("console") \
    .outputMode("append") \
    .option("truncate", False) \
    .start()


json_df.writeStream \
    .foreachBatch(log_batch) \
    .option("checkpointLocation", checkpoint_path) \
    .start()

# GMB Using the above section and NOT this section to write to Cosmos
# # # Write the processed streaming data from `json_df` to Azure Cosmos DB.
# json_df.writeStream \
#     .format("cosmos.oltp") \
#     .options(**cosmos_config) \
#     .outputMode("append") \
#     .option("checkpointLocation", checkpoint_path) \
#     .start()

print(f"✅ Streaming pipeline initialized with checkpoint: {checkpoint_path}. Data is flowing!")

print("✅ Streaming pipeline initialized. Data is flowing!")

# Surface stats like record volume, throughput, and termination alerts directly into job logs.
from pyspark.sql.streaming import StreamingQueryListener

# class DebugListener(StreamingQueryListener):
#     def onQueryStarted(self, event):
#         print(f"🔄 Query started: {event.name}")
#     def onQueryProgress(self, event):
#         print(f"📈 Progress update: {event.progress.numInputRows} rows received")
#     def onQueryTerminated(self, event):
#         print(f"💥 Query terminated: {event.id}")
        
class DebugListener(StreamingQueryListener):
    def onQueryStarted(self, event):
        print(f"🔄 Query started: {event.name} (ID: {event.id})")

    def onQueryProgress(self, event):
        progress = event.progress
        print(f"📈 Progress update for batch {progress['batchId']}:")
        print(f"   ⏱ Trigger duration: {progress['durationMs'].get('triggerExecution', 'N/A')} ms")
        print(f"   📥 Input rows: {progress['numInputRows']}")
        print(f"   📤 Output rows: {progress['sink'].get('numOutputRows', 'N/A')}")
        print(f"   ⚡ Input rate: {progress.get('inputRowsPerSecond', 'N/A')} rows/sec")
        print(f"   ⚡ Processing rate: {progress.get('processedRowsPerSecond', 'N/A')} rows/sec")
        print("—" * 60)

    def onQueryTerminated(self, event):
        print(f"💥 Query terminated: {event.id}")

spark.streams.addListener(DebugListener())

print("🛰️ Active streaming queries:")
for query in spark.streams.active:
    print(f"- Name: {query.name}")
    print(f"  ID: {query.id}")
    print(f"  Is Active: {query.isActive}")
    print(f"  Status: {query.status}")
    print(f"  Description: {query}")
    print("—" * 60)
