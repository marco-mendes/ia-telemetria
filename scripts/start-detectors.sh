#!/bin/bash

# Script to start detectors and enable real-time anomaly detection

OPENSEARCH_URL="http://localhost:9200"
USERNAME="admin"
PASSWORD="admin"

echo "Fetching all detectors..."

DETECTORS=$(curl -s -X GET "$OPENSEARCH_URL/_plugins/_anomaly_detection/detectors/_search" \
  -u "$USERNAME:$PASSWORD" \
  -H 'Content-Type: application/json' \
  -d '{
  "query": {
    "match_all": {}
  }
}' | jq -r '.hits.hits[]._id')

echo "Found detectors:"
echo "$DETECTORS"

for DETECTOR_ID in $DETECTORS; do
  echo -e "\nStarting detector: $DETECTOR_ID"
  
  curl -X POST "$OPENSEARCH_URL/_plugins/_anomaly_detection/detectors/$DETECTOR_ID/_start" \
    -u "$USERNAME:$PASSWORD" \
    -H 'Content-Type: application/json'
  
  echo ""
done

echo -e "\nAll detectors started!"
echo "Anomaly detection is now running in real-time."
