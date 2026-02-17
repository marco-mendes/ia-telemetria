#!/bin/bash

# Script to create Anomaly Detector in OpenSearch
# This uses the Random Cut Forest (RCF) algorithm

OPENSEARCH_URL="http://localhost:9200"
USERNAME="admin"
PASSWORD="admin"

echo "Creating Anomaly Detector for CPU Usage..."

curl -X POST "$OPENSEARCH_URL/_plugins/_anomaly_detection/detectors" \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "cpu-usage-detector",
  "description": "Detect CPU usage anomalies using RCF",
  "time_field": "time",
  "indices": [
    "otel-metrics-*"
  ],
  "feature_attributes": [
    {
      "feature_name": "cpu_usage",
      "feature_enabled": true,
      "aggregation_query": {
        "cpu_usage": {
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
            "name.keyword": "system_cpu_usage"
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
  "shingle_size": 8,
  "schema_version": 0
}'

echo -e "\n\nCreating Anomaly Detector for Memory Usage..."

curl -X POST "$OPENSEARCH_URL/_plugins/_anomaly_detection/detectors" \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "memory-usage-detector",
  "description": "Detect memory usage anomalies and trends using RCF",
  "time_field": "time",
  "indices": [
    "otel-metrics-*"
  ],
  "feature_attributes": [
    {
      "feature_name": "memory_usage",
      "feature_enabled": true,
      "aggregation_query": {
        "memory_usage": {
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
  "shingle_size": 8,
  "schema_version": 0
}'

echo -e "\n\nCreating Anomaly Detector for Request Latency..."

curl -X POST "$OPENSEARCH_URL/_plugins/_anomaly_detection/detectors" \
  -H 'Content-Type: application/json' \
  -d '{
  "name": "request-latency-detector",
  "description": "Detect request latency anomalies using RCF (from metrics)",
  "time_field": "time",
  "indices": [
    "otel-metrics-*"
  ],
  "feature_attributes": [
    {
      "feature_name": "latency_sum",
      "feature_enabled": true,
      "aggregation_query": {
        "latency_sum": {
          "avg": {
            "field": "sum"
          }
        }
      }
    },
    {
      "feature_name": "throughput",
      "feature_enabled": true,
      "aggregation_query": {
        "throughput": {
          "sum": {
            "field": "count"
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
            "name.keyword": "http.server.duration"
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
  "shingle_size": 8,
  "schema_version": 0
}'

echo -e "\n\nDone! Anomaly detectors created."
