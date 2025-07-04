# azure-iot-location-monitoring/terraform/modules/databricks/notebook.py

# --- START dbutils Mock for Local Pylance/IDE Linting Only ---
try:
    dbutils.widgets.get
except NameError:
    from types import SimpleNamespace

    class MockWidgets:
        def get(self, name):
            print(f"Pylance/Local Linting: Using mock value for widget '{name}'.")
            return f"__MOCKED_VALUE_FOR_{name.upper()}__"

    class MockDbutils:
        @property
        def widgets(self):
            return MockWidgets()

    dbutils = MockDbutils()
# --- END dbutils Mock ---

from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StringType, DoubleType, LongType
from pyspark.sql.functions import from_json, col, concat_ws
from pyspark.sql.streaming import StreamingQueryListener
import logging

print("🔍 Initializing IoT telemetry pipeline...")

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logging.info("Notebook started: Initializing environment and configurations.")

# Define schema
schema = StructType() \
    .add("deviceId", StringType()) \
    .add("latitude", DoubleType()) \
    .add("longitude", DoubleType()) \
    .add("timestamp", LongType())

# Retrieve parameters
eventhub_connection_string = dbutils.widgets.get("eventhub_connection_string")
cosmos_db_endpoint         = dbutils.widgets.get("cosmos_db_endpoint")
cosmos_db_key              = dbutils.widgets.get("cosmos_db_key")
cosmos_db_database         = dbutils.widgets.get("cosmos_db_database")
cosmos_db_container        = dbutils.widgets.get("cosmos_db_container")

print("🔒 eventhub_connection_string (pre-encryption):", eventhub_connection_string)

# Encrypt Event Hub connection string
spark = SparkSession.builder.getOrCreate()
sc = spark.sparkContext
encrypted_connection_string = sc._jvm.org.apache.spark.eventhubs.EventHubsUtils.encrypt(eventhub_connection_string)

ehConf = {
    "eventhubs.connectionString": encrypted_connection_string
}

print("📡 Event Hub configuration loaded:")
print(ehConf)

# Read from Event Hub
raw_df = spark.readStream \
    .format("eventhubs") \
    .options(**ehConf) \
    .load()

print("✅ Successfully connected to Event Hub.")

# Parse JSON and add required 'id' field
json_df = raw_df.select(from_json(col("body").cast("string"), schema).alias("data")).select("data.*")
json_df = json_df.withColumn("id", concat_ws("-", col("deviceId"), col("timestamp")))

print("🧬 Schema after parsing and adding 'id':")
json_df.printSchema()

# Cosmos DB config
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

# Checkpoint path
checkpoint_path = "dbfs:/tmp/iot_streaming_checkpoints/cosmos_db"
dbutils.fs.mkdirs(checkpoint_path)
print(f"✅ Checkpoint location {checkpoint_path} created.")

# Write to Cosmos DB with batch logging
def log_batch(df, epoch_id):
    count = df.count()
    print(f"📦 Writing batch {epoch_id} with {count} records")
    if count > 0:
        df.write \
            .format("cosmos.oltp") \
            .options(**cosmos_config) \
            .mode("append") \
            .save()

json_df.writeStream \
    .foreachBatch(log_batch) \
    .option("checkpointLocation", checkpoint_path) \
    .start()

print(f"✅ Streaming pipeline initialized with checkpoint: {checkpoint_path}. Data is flowing!")

# Add listener for streaming events
class DebugListener(StreamingQueryListener):
    def onQueryStarted(self, event):
        print(f"🔄 Query started: {event.name}")
    def onQueryProgress(self, event):
        print(f"📈 Progress update: {event.progress.numInputRows} rows received")
    def onQueryTerminated(self, event):
        print(f"💥 Query terminated: {event.id}")

spark.streams.addListener(DebugListener())