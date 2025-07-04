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
            # Provide a dummy value for local testing/linting.
            # This is what Pylance will see.
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
from pyspark.sql.functions import from_json, col

print("🔍 Initializing IoT telemetry pipeline...")

import logging # Import logging module

# Configure logging for the notebook
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logging.info("Notebook started: Initializing environment and configurations.")

# Define the schema for the incoming JSON data from Event Hub.
schema = StructType() \
    .add("deviceId", StringType()) \
    .add("latitude", DoubleType()) \
    .add("longitude", DoubleType()) \
    .add("timestamp", LongType())

# In notebook.py:
eventhub_instance_name = "iothub-events" # Use the IoT Hub's built-in endpoint name
                                         # 20250703_2pm: GMB add
# Retrieve parameters
eventhub_connection_string = dbutils.widgets.get("eventhub_connection_string")
eventhub_connection_string_base64 = dbutils.widgets.get("eventhub_connection_string_base64").strip()
cosmos_db_endpoint         = dbutils.widgets.get("cosmos_db_endpoint")
cosmos_db_key              = dbutils.widgets.get("cosmos_db_key")
cosmos_db_database         = dbutils.widgets.get("cosmos_db_database")
cosmos_db_container        = dbutils.widgets.get("cosmos_db_container")

import base64
eventhub_connection_string_decoded = base64.b64decode(eventhub_connection_string_base64).decode("utf-8")

print(f"GMB_DEBUG: EH Connection String (pre-trimmed): '{eventhub_connection_string}'")
eventhub_connection_string = dbutils.widgets.get("eventhub_connection_string").strip()
# Add a print statement to verify the length and content after stripping
print(f"GMB_DEBUG: EH Connection String (trimmed): '{eventhub_connection_string}' (length: {len(eventhub_connection_string)})")

print(f"GMB_DEBUG: EH Connection String (pre-trimmed): '{eventhub_connection_string_base64}'")
eventhub_connection_string_base64_strip = dbutils.widgets.get("eventhub_connection_string_base64").strip()
# Add a print statement to verify the length and content after stripping
print(f"GMB_DEBUG: EH Connection String (trimmed): '{eventhub_connection_string_base64_strip}' (length: {len(eventhub_connection_string_base64_strip)})")


# Your raw Event Hub connection string
# raw_connection_string = eventhub_connection_string
raw_connection_string = eventhub_connection_string.strip() + ";EntityPath=ioteventhub"

# Encrypt using Spark's JVM bridge
from pyspark.sql import SparkSession
spark = SparkSession.builder.getOrCreate()
sc = spark.sparkContext
encrypted_connection_string = sc._jvm.org.apache.spark.eventhubs.EventHubsUtils.encrypt(raw_connection_string)
print("🔒 Final EH connection string (into ehConf) with EntityPath:", raw_connection_string)

# Use in your Event Hubs configuration
# GMB:Try this on 20250703....
ehConf = {
    "eventhubs.connectionString": encrypted_connection_string
}
    # 'eventhubs.connectionString': eventhub_connection_string_base64,
# ehConf = {
#     "eventhubs.connectionString": eventhub_connection_string_decoded,
#     "shouldEncryptConnectionString": "false"
# }

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

# Parse the raw Event Hub message body, which is a binary string, into a structured JSON format. 
json_df = raw_df.select(from_json(col("body").cast("string"), schema).alias("data")).select("data.*")
print("🧬 Schema after parsing:")
json_df.printSchema()

# Configure the connection and write details for Azure Cosmos DB.
cosmos_config = {
    "spark.cosmos.accountEndpoint": cosmos_db_endpoint, # Corrected key
    "spark.cosmos.accountKey": cosmos_db_key,           # Corrected key
    "spark.cosmos.database": cosmos_db_database,         # Corrected key
    "spark.cosmos.container": cosmos_db_container,       # Corrected key
    "spark.cosmos.write.strategy": "ItemOverwrite"
}

print("💾 Preparing to write to Cosmos DB...")
print("Cosmos config keys:", list(cosmos_config.keys()))

logging.info(f"Cosmos DB configuration loaded for database: {cosmos_config['spark.cosmos.database']}, container: {cosmos_config['spark.cosmos.container']}")

# Define the checkpoint location for the streaming query
# This path must be accessible and writable by the Databricks cluster.
# Ensure this path has proper permissions for the Databricks cluster/service principal.
dbutils.fs.mkdirs("dbfs:/tmp/iot_streaming_checkpoints/cosmos_db")
print("✅ Checkpoint location dbfs:/tmp/iot_streaming_checkpoints/cosmos_db created.")

checkpoint_path = "dbfs:/tmp/iot_streaming_checkpoints/cosmos_db" # A common temporary location on DBFS

# Write the processed streaming data from `json_df` to Azure Cosmos DB.
json_df.writeStream \
    .format("cosmos.oltp") \
    .options(**cosmos_config) \
    .outputMode("append") \
    .option("checkpointLocation", checkpoint_path) \
    .start()

print(f"✅ Streaming pipeline initialized with checkpoint: {checkpoint_path}. Data is flowing!")

print("✅ Streaming pipeline initialized. Data is flowing!")

# Surface stats like record volume, throughput, and termination alerts directly into job logs.
from pyspark.sql.streaming import StreamingQueryListener

class DebugListener(StreamingQueryListener):
    def onQueryStarted(self, event):
        print(f"🔄 Query started: {event.name}")
    def onQueryProgress(self, event):
        print(f"📈 Progress update: {event.progress.numInputRows} rows received")
    def onQueryTerminated(self, event):
        print(f"💥 Query terminated: {event.id}")

spark.streams.addListener(DebugListener())