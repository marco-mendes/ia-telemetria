#!/bin/bash

# Script to create monitors and alerts based on anomaly detection results

OPENSEARCH_URL="http://localhost:9200"
USERNAME="admin"
PASSWORD="admin"

# Function to get detector ID by name
get_detector_id() {
    local name=$1
    curl -s -X POST "$OPENSEARCH_URL/_plugins/_anomaly_detection/detectors/_search" \
      -H 'Content-Type: application/json' \
      -d "{\"query\":{\"term\":{\"name.keyword\":\"$name\"}}}" | jq -r '.hits.hits[0]._id'
}

CPU_DETECTOR_ID=$(get_detector_id "cpu-usage-detector")
MEM_DETECTOR_ID=$(get_detector_id "memory-usage-detector")
LATENCY_DETECTOR_ID=$(get_detector_id "request-latency-detector")

echo "Found IDs: CPU=$CPU_DETECTOR_ID, MEM=$MEM_DETECTOR_ID, LATENCY=$LATENCY_DETECTOR_ID"

if [ "$CPU_DETECTOR_ID" == "null" ] || [ "$MEM_DETECTOR_ID" == "null" ] || [ "$LATENCY_DETECTOR_ID" == "null" ]; then
    echo "Error: Could not find one or more detector IDs. Make sure they are created."
    exit 1
fi

echo "Creating Monitor for CPU Anomalies..."
curl -X POST "$OPENSEARCH_URL/_plugins/_alerting/monitors" \
  -H 'Content-Type: application/json' \
  -d "{
  \"type\": \"monitor\",
  \"name\": \"CPU Anomaly Alert\",
  \"enabled\": true,
  \"schedule\": { \"period\": { \"interval\": 1, \"unit\": \"MINUTES\" } },
  \"inputs\": [
    {
      \"search\": {
        \"indices\": [\".opendistro-anomaly-results*\"],
        \"query\": {
          \"size\": 1,
          \"query\": {
            \"bool\": {
              \"filter\": [
                { \"range\": { \"anomaly_grade\": { \"gt\": 0.7 } } },
                { \"range\": { \"execution_end_time\": { \"gte\": \"now-5m\" } } },
                { \"term\": { \"detector_id\": \"$CPU_DETECTOR_ID\" } }
              ]
            }
          }
        }
      }
    }
  ],
  \"triggers\": [
    {
      \"name\": \"High CPU Anomaly Detected\",
      \"severity\": \"1\",
      \"condition\": { \"script\": { \"source\": \"ctx.results[0].hits.total.value > 0\", \"lang\": \"painless\" } },
      \"actions\": [
        {
          \"name\": \"Log Alert\",
          \"destination_id\": \"\",
          \"message_template\": {
            \"source\": \"CPU anomaly detected! Anomaly grade: {{ctx.results.0.hits.hits.0._source.anomaly_grade}}\",
            \"lang\": \"mustache\"
          },
          \"throttle_enabled\": false,
          \"subject_template\": { \"source\": \"CPU Anomaly Alert - {{ctx.monitor.name}}\", \"lang\": \"mustache\" }
        }
      ]
    }
  ]
}"

echo -e "\n\nCreating Monitor for Memory Anomalies..."
curl -X POST "$OPENSEARCH_URL/_plugins/_alerting/monitors" \
  -H 'Content-Type: application/json' \
  -d "{
  \"type\": \"monitor\",
  \"name\": \"Memory Anomaly Alert\",
  \"enabled\": true,
  \"schedule\": { \"period\": { \"interval\": 1, \"unit\": \"MINUTES\" } },
  \"inputs\": [
    {
      \"search\": {
        \"indices\": [\".opendistro-anomaly-results*\"],
        \"query\": {
          \"size\": 1,
          \"query\": {
            \"bool\": {
              \"filter\": [
                { \"range\": { \"anomaly_grade\": { \"gt\": 0.7 } } },
                { \"range\": { \"execution_end_time\": { \"gte\": \"now-5m\" } } },
                { \"term\": { \"detector_id\": \"$MEM_DETECTOR_ID\" } }
              ]
            }
          }
        }
      }
    }
  ],
  \"triggers\": [
    {
      \"name\": \"High Memory Anomaly Detected\",
      \"severity\": \"2\",
      \"condition\": { \"script\": { \"source\": \"ctx.results[0].hits.total.value > 0\", \"lang\": \"painless\" } },
      \"actions\": [
        {
          \"name\": \"Log Alert\",
          \"destination_id\": \"\",
          \"message_template\": {
            \"source\": \"Memory anomaly detected! Anomaly grade: {{ctx.results.0.hits.hits.0._source.anomaly_grade}}\",
            \"lang\": \"mustache\"
          },
          \"throttle_enabled\": false,
          \"subject_template\": { \"source\": \"Memory Anomaly Alert - {{ctx.monitor.name}}\", \"lang\": \"mustache\" }
        }
      ]
    }
  ]
}"

echo -e "\n\nCreating Monitor for Request Latency Anomalies..."
curl -X POST "$OPENSEARCH_URL/_plugins/_alerting/monitors" \
  -H 'Content-Type: application/json' \
  -d "{
  \"type\": \"monitor\",
  \"name\": \"Request Latency Anomaly Alert\",
  \"enabled\": true,
  \"schedule\": { \"period\": { \"interval\": 1, \"unit\": \"MINUTES\" } },
  \"inputs\": [
    {
      \"search\": {
        \"indices\": [\".opendistro-anomaly-results*\"],
        \"query\": {
          \"size\": 1,
          \"query\": {
            \"bool\": {
              \"filter\": [
                { \"range\": { \"anomaly_grade\": { \"gt\": 0.6 } } },
                { \"range\": { \"execution_end_time\": { \"gte\": \"now-5m\" } } },
                { \"term\": { \"detector_id\": \"$LATENCY_DETECTOR_ID\" } }
              ]
            }
          }
        }
      }
    }
  ],
  \"triggers\": [
    {
      \"name\": \"High Latency Anomaly Detected\",
      \"severity\": \"3\",
      \"condition\": { \"script\": { \"source\": \"ctx.results[0].hits.total.value > 0\", \"lang\": \"painless\" } },
      \"actions\": [
        {
          \"name\": \"Log Alert\",
          \"destination_id\": \"\",
          \"message_template\": {
            \"source\": \"Request latency anomaly detected! Anomaly grade: {{ctx.results.0.hits.hits.0._source.anomaly_grade}}\",
            \"lang\": \"mustache\"
          },
          \"throttle_enabled\": false,
          \"subject_template\": { \"source\": \"Latency Anomaly Alert - {{ctx.monitor.name}}\", \"lang\": \"mustache\" }
        }
      ]
    }
  ]
}"

echo -e "\n\nDone! Monitors and alerts created."
