# azure-iot-location-monitoring\iot-simulator\Dockerfile   

# Use official Python image
FROM python:3.12-alpine

# Dockerfile for device_simulator.py script that sends location data to Azure IoT Hub

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy simulator script
COPY device_simulator.py .

# Run the simulator
CMD ["python", "device_simulator.py"]