#!/bin/bash

# Load generator script to simulate traffic and generate data for ML

DEMO_APP_URL="http://localhost:8080"

echo "Starting load generator for demo application..."
echo "This will generate traffic to create data for anomaly detection and forecasting"
echo "Press Ctrl+C to stop"
echo ""

# Counter for requests
REQUEST_COUNT=0

# Array of endpoints
ENDPOINTS=("/" "/api/data" "/api/process" "/health")

while true; do
  # Random endpoint selection using jot (macOS compatible)
  RANDOM_INDEX=$((RANDOM % 4))
  ENDPOINT="${ENDPOINTS[$RANDOM_INDEX]}"
  
  # Make request
  if [ "$ENDPOINT" = "/api/process" ]; then
    curl -s -X POST "$DEMO_APP_URL$ENDPOINT" \
      -H "Content-Type: application/json" \
      -d '{"data": "test"}' > /dev/null
  else
    curl -s "$DEMO_APP_URL$ENDPOINT" > /dev/null
  fi
  
  REQUEST_COUNT=$((REQUEST_COUNT + 1))
  
  # Trigger anomaly simulation every 100 requests (approx every 2-3 mins)
  # Longer sleep to ensure a very clear latency spike
  if [ $((REQUEST_COUNT % 100)) -eq 0 ]; then
    echo "!!! Triggering strong anomaly spike... (request #$REQUEST_COUNT) !!!"
    for i in {1..3}; do
        curl -s "$DEMO_APP_URL/simulate/anomaly?sleep=10" > /dev/null
        sleep 2
    done
  fi
  
  # Progress indicator
  if [ $((REQUEST_COUNT % 10)) -eq 0 ]; then
    echo "Requests sent: $REQUEST_COUNT"
  fi
  
  # Random delay between requests (0.1 to 2 seconds)
  # Using jot for macOS compatibility
  DELAY=$(jot -r 1 1 20)
  DELAY_SECONDS=$(echo "scale=1; $DELAY / 10" | bc)
  sleep "$DELAY_SECONDS"
done
