# azure-iot-location-monitoring\iot-simulator\device_simulator.py

# Simulate a GPS-enabled IoT device.
# Sends randomized location data to Azure IoT Hub at regular intervals.
# Uses the Azure IoT SDK for Python.

import time, json, random, logging
from azure.iot.device import IoTHubDeviceClient, Message

# Configure logging
logging.basicConfig(level=logging.INFO)

import os

conn_str = os.getenv("IOTHUB_DEVICE_CONNECTION_STRING")
device_id = os.getenv("IOT_SIMULATOR_DEVICE_NAME", "sim-default-device")

client = IoTHubDeviceClient.create_from_connection_string(conn_str)

try:
    while True:
        data = {
            "deviceId": device_id,
            "latitude": round(30.2672 + random.uniform(-0.01, 0.01), 6),
            "longitude": round(-97.7431 + random.uniform(-0.01, 0.01), 6),
            "timestamp": time.time()
        }
        msg = Message(json.dumps(data))
        client.send_message(msg)
        logging.info(f"Sent message: {data}")
        time.sleep(5)

except KeyboardInterrupt:
    logging.info("Simulation interrupted by user. Closing connection.")
finally:
    client.shutdown()