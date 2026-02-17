#!/bin/bash

# Health check script for OpenSearch POC

OPENSEARCH_URL="http://localhost:9200"

echo "=== 1. Cluster Health ==="
curl -s "$OPENSEARCH_URL/_cluster/health" | jq -r '.status'
echo ""

echo "=== 2. Ingestion Status (Index Counts) ==="
METRICS_COUNT=$(curl -s "$OPENSEARCH_URL/otel-metrics-*/_count" | jq -r '.count // 0')
SPANS_COUNT=$(curl -s "$OPENSEARCH_URL/otel-v1-apm-span-*/_count" | jq -r '.count // 0')
LOGS_COUNT=$(curl -s "$OPENSEARCH_URL/otel-logs-*/_count" | jq -r '.count // 0')

echo "Metrics: $METRICS_COUNT"
echo "Spans:   $SPANS_COUNT"
echo "Logs:    $LOGS_COUNT"
echo ""

echo "=== 3. Anomaly Detectors Status ==="
curl -s "$OPENSEARCH_URL/_plugins/_anomaly_detection/detectors/_search" -H "Content-Type: application/json" -d '{"query":{"match_all":{}}}' | jq -r '.hits.hits[] | ._id' | while read id; do
    NAME=$(curl -s "$OPENSEARCH_URL/_plugins/_anomaly_detection/detectors/$id" | jq -r '.anomaly_detector.name')
    PROFILE=$(curl -s "$OPENSEARCH_URL/_plugins/_anomaly_detection/detectors/$id/_profile")
    STATE=$(echo "$PROFILE" | jq -r '.state')
    ERROR=$(echo "$PROFILE" | jq -r '.error // ""')
    
    echo "Detector: $NAME ($id)"
    echo "  State: $STATE"
    if [ ! -z "$ERROR" ] && [ "$ERROR" != "null" ]; then
        echo "  Error: $ERROR"
    fi
done
echo ""

echo "=== 4. Recent Anomaly Results (Last 10 mins) ==="
RESULTS=$(curl -s "$OPENSEARCH_URL/.opendistro-anomaly-results*/_search" -H "Content-Type: application/json" -d '{
  "size": 5,
  "sort": [{"execution_end_time": {"order": "desc"}}],
  "query": {
    "bool": {
      "filter": [
        {"range": {"anomaly_grade": {"gt": 0}}},
        {"range": {"execution_end_time": {"gte": "now-10m"}}}
      ]
    }
  }
}')

ANOMALY_TOTAL=$(echo "$RESULTS" | jq -r '.hits.total.value // 0')
if [ "$ANOMALY_TOTAL" -eq "0" ]; then
    echo "No anomalies detected in the last 10 minutes."
else
    echo "Found $ANOMALY_TOTAL recent anomalies:"
    echo "$RESULTS" | jq -r '.hits.hits[] | "- Time: \(.source.execution_end_time), Detector: \(.source.detector_id), Grade: \(.source.anomaly_grade)"'
fi
echo ""

echo "=== 5. Active Alerts ==="
curl -s "$OPENSEARCH_URL/_plugins/_alerting/monitors/alerts" | jq -r '.alerts[] | "- Monitor: \(.monitor_name), State: \(.state), Start Time: \(.start_time)"'
