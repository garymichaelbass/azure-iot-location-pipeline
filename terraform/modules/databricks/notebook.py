# azure-iot-location-monitoring\terraform\modules\databricks\notebook.py

# The following addresses the error of "dbutils is not defined (Pylance)"
# eventhub_connection_string = dbutils.widgets.get("eventhub_connection_string")
try:
    dbutils.widgets.get
except NameError:
    from types import SimpleNamespace
    dbutils = SimpleNamespace(widgets=SimpleNamespace(get=lambda x: "<placeholder>"))

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
# This schema dictates the structure and data types of the telemetry messages
# that are expected from the IoT devices.
schema = StructType() \
    .add("deviceId", StringType()) \
    .add("latitude", DoubleType()) \
    .add("longitude", DoubleType()) \
    .add("timestamp", LongType())

# Configure the connection details for Azure Event Hubs.
# The 'eventhubs.connectionString' parameter is crucial and must be replaced
# with the actual Event Hub-compatible connection string, which grants access
# to read messages from the Event Hub.
eventhub_connection_string = dbutils.widgets.get("eventhub_connection_string")

ehConf = {
    'eventhubs.connectionString': eventhub_connection_string
}

print("📡 Event Hub configuration loaded:")
print(ehConf)

# Read streaming data from Azure Event Hubs.
# 'spark.readStream' initiates a streaming DataFrame, and '.format("eventhubs")'
# specifies the source. The options are passed from the `ehConf` dictionary.
# This DataFrame (`raw_df`) will initially contain raw Event Hub messages,
# where the actual data payload is typically in the 'body' column.
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
# The 'body' column is first cast to a string, then 'from_json' is used to parse it
# according to the predefined `schema`. The parsed data is aliased as "data",
# and then '.select("data.*")' flattens the nested structure to bring all fields
# directly into the `json_df` DataFrame.
json_df = raw_df.select(from_json(col("body").cast("string"), schema).alias("data")).select("data.*")
print("🧬 Schema after parsing:")
json_df.printSchema()

# Configure the connection and write details for Azure Cosmos DB.
# This dictionary specifies where and how the processed data will be written.
# - "Endpoint": The URI of your Azure Cosmos DB account.
# - "Masterkey": The primary key for your Cosmos DB account (securely managed, not hardcoded in production).
# - "Database": The name of the Cosmos DB database to write to.
# - "Collection": The name of the Cosmos DB container (collection) within the specified database.
# - "Upsert": "true" means that if a document with the same ID already exists, it will be updated;
#             otherwise, a new document will be inserted.
cosmos_config = {
    "Endpoint": var.cosmos_db_endpoint,
    "Masterkey": var.cosmos_db_key,
    "Database": "LocationDB",
    "Collection": "DeviceLocations",
    "Upsert": "true"
}

print("💾 Preparing to write to Cosmos DB...")
print("Cosmos config keys:", list(cosmos_config.keys()))

logging.info(f"Cosmos DB configuration loaded for database: {cosmos_config['Database']}, collection: {cosmos_config['Collection']}")

# Write the processed streaming data from `json_df` to Azure Cosmos DB.
# '.writeStream' indicates a continuous write operation.
# '.format("cosmos.oltp")' specifies the Cosmos DB connector for OLTP (transactional) workloads.
# '.options(**cosmos_config)' applies the defined Cosmos DB connection and write settings.
# '.outputMode("append")' specifies that new records are continuously appended to Cosmos DB.
# '.start()' initiates the streaming job. This job will run continuously, reading from Event Hub,
# parsing messages, and writing them to the specified Cosmos DB collection.
json_df.writeStream \
    .format("cosmos.oltp") \
    .options(**cosmos_config) \
    .outputMode("append") \
    .start()

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