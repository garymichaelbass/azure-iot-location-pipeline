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
import base64 # REQUIRED for Base64 decoding
# IMPORTANT: 're' module is NOT imported here, as we are not manually parsing components.
from pyspark.sql import SparkSession # Ensure SparkSession is imported for sc access

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

# --- Retrieve parameters from widgets ---

# Only retrieve the Base64 encoded Event Hub connection string passed by Terraform job.
# This string is expected to be the full IoT Hub built-in endpoint connection string.
eventhub_connection_string_base64_from_widget = dbutils.widgets.get("eventhub_connection_string_base64").strip()

# DEBUG: Print the Base64 string and its length after stripping from widget
print(f"GMB_DEBUG: EH Connection String B64 (from widget, stripped): '{eventhub_connection_string_base64_from_widget}' (length: {len(eventhub_connection_string_base64_from_widget)})")

# Retrieve other Cosmos DB parameters and strip them for cleanliness
cosmos_db_endpoint         = dbutils.widgets.get("cosmos_db_endpoint").strip()
cosmos_db_key              = dbutils.widgets.get("cosmos_db_key").strip()
cosmos_db_database         = dbutils.widgets.get("cosmos_db_database").strip()
cosmos_db_container        = dbutils.widgets.get("cosmos_db_container").strip()
# --- END RETRIEVE PARAMETERS ---


# --- Decode the Event Hub connection string ---
try:
    # Decode the base64 string to get the original raw connection string.
    # This string will now contain the correct IoT Hub hostname (e.g., iotlocationhub.azure-devices.net)
    # AND the EntityPath=iothub-events.
    eventhub_connection_string_decoded = base64.b64decode(eventhub_connection_string_base64_from_widget).decode('utf-8')
    # Optional: Keep this line commented for security, uncomment for local debug if needed
    # print(f"GMB_DEBUG: EH Connection String (decoded for use): '{eventhub_connection_string_decoded}' (length: {len(eventhub_connection_string_decoded)})")
except Exception as e:
    print(f"ERROR: Failed to Base64 decode Event Hub connection string from widget: {e}")
    raise # Re-raise the error to fail the job if decoding fails


# --- Encrypt the decoded string using EventHubsUtils.encrypt ---
# This method helps prevent specific decryption errors that occurred earlier.
# The 'spark' object is pre-initialized in Databricks notebooks.
sc = SparkSession.builder.getOrCreate().sparkContext # Get SparkContext for JVM access
encrypted_connection_string_for_ehConf = sc._jvm.org.apache.spark.eventhubs.EventHubsUtils.encrypt(eventhub_connection_string_decoded)
print("🔒 Final EH connection string into ehConf (encrypted):", encrypted_connection_string_for_ehConf)


# --- ehConf setup using the encrypted full connection string ---
# This uses the 'eventhubs.connectionString' option directly.
ehConf = {
    'eventhubs.connectionString': encrypted_connection_string_for_ehConf,
    # 'shouldEncryptConnectionString': 'false' is not strictly needed when using EventHubsUtils.encrypt,
    # as encrypt prepares the string in the expected format.
    'eventhubs.maxEventsPerTrigger': '10000', # Optional: Adjust as needed
    'eventhubs.startingPosition': '{"offset":"-1", "enqueuedTime":"-1"}' # Optional: Start from beginning
}

print("📡 Event Hub configuration loaded:")
print(ehConf) # This will print the configuration keys, but the sensitive value is still obfuscated by Spark's internal handling

# Read streaming data from Azure Event Hubs.
raw_df = SparkSession.builder.getOrCreate().readStream \
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
dbutils.fs.mkdirs("dbfs:/tmp/iot_streaming_checkpoints/cosmos_db")
print("✅ Checkpoint location dbfs:/tmp/iot_streaming_checkpoints/cosmos_db created.")

checkpoint_path = "dbfs:/tmp/iot_streaming_checkpoints/cosmos_db"

# Write the processed streaming data from `json_df` to Azure Cosmos DB.
json_df.writeStream \
    .format("cosmos.oltp") \
    .options(**cosmos_config) \
    .outputMode("append") \
    .option("checkpointLocation", checkpoint_path) \
    .start()

print(f"✅ Streaming pipeline initialized with checkpoint: {checkpoint_path}. Data is flowing!")

# Removed duplicate print for clarity
# print("✅ Streaming pipeline initialized. Data is flowing!") 

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