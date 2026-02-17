#!/bin/bash

# Script to create Forecast configurations in OpenSearch
# Forecasting in OpenSearch is built on top of the same RCF engine
# but configured to predict future points.

OPENSEARCH_URL="http://localhost:9200"

echo "Creating Forecast for Memory Usage Prediction (Memory Leak Detection)..."

# Note: Using .keyword for filters and 'time' as the field to match our OTel data
curl -X POST "$OPENSEARCH_URL/_plugins/_anomaly_detection/detectors" \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "memory-leak-forecast",
  "description": "Predict future memory usage to detect leaks before they happen",
  "time_field": "time",
  "indices": [
    "otel-metrics-*"
  ],
  "feature_attributes": [
    {
      "feature_name": "memory_prediction",
      "feature_enabled": true,
      "aggregation_query": {
        "memory_prediction": {
          "avg": {
            "field": "value"
          }
        }
      }
    }
  ],
  "filter_query": {
    "bool": {
      "filter": [
        {
          "term": {
            "name.keyword": "system_memory_usage"
          }
        }
      ]
    }
  },
  "detection_interval": {
    "period": {
      "interval": 1,
      "unit": "Minutes"
    }
  },
  "window_delay": {
    "period": {
      "interval": 2,
      "unit": "Minutes"
    }
  },
  "shingle_size": 8
}'

echo -e "\n\nDone! Forecast detector created."
echo "To see forecasting results:"
echo "1. Go to OpenSearch Dashboards -> Anomaly Detection"
echo "2. Open the 'memory-leak-forecast' detector"
echo "3. Use the 'Forecasting' tab to see future predictions based on current trends"
