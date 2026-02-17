"""
Demo Application with OpenTelemetry Instrumentation
Generates metrics, logs, and traces for OpenSearch + Data Prepper POC
Simulates normal behavior and anomalies for ML detection
"""

import os
import time
import random
import logging
from flask import Flask, jsonify, request
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry._logs import set_logger_provider
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

# Configuration
SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "demo-service")
OTLP_TRACES_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "data-prepper:21890")
OTLP_METRICS_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", "data-prepper:21891")
OTLP_LOGS_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT", "data-prepper:21892")

# Resource configuration
resource = Resource.create({
    "service.name": SERVICE_NAME,
    "service.namespace": "poc",
    "deployment.environment": "dev"
})

# Configure Tracing
trace_provider = TracerProvider(resource=resource)
otlp_span_exporter = OTLPSpanExporter(endpoint=OTLP_TRACES_ENDPOINT, insecure=True)
trace_provider.add_span_processor(BatchSpanProcessor(otlp_span_exporter))
trace.set_tracer_provider(trace_provider)
tracer = trace.get_tracer(__name__)

# Configure Metrics
from opentelemetry.sdk.metrics.export import AggregationTemporality
from opentelemetry.sdk.metrics import (
    Counter,
    UpDownCounter,
    Histogram,
    ObservableCounter,
    ObservableUpDownCounter,
    ObservableGauge,
)

temporality_delta = {
    Counter: AggregationTemporality.DELTA,
    UpDownCounter: AggregationTemporality.DELTA,
    Histogram: AggregationTemporality.DELTA,
    ObservableCounter: AggregationTemporality.DELTA,
    ObservableUpDownCounter: AggregationTemporality.DELTA,
    ObservableGauge: AggregationTemporality.DELTA,
}

metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(
        endpoint=OTLP_METRICS_ENDPOINT, 
        insecure=True, 
        preferred_temporality=temporality_delta
    ),
    export_interval_millis=5000
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)
meter = metrics.get_meter(__name__)

# Configure Logging
logger_provider = LoggerProvider(resource=resource)
set_logger_provider(logger_provider)
otlp_log_exporter = OTLPLogExporter(endpoint=OTLP_LOGS_ENDPOINT, insecure=True)
logger_provider.add_log_record_processor(BatchLogRecordProcessor(otlp_log_exporter))
handler = LoggingHandler(level=logging.INFO, logger_provider=logger_provider)

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.addHandler(handler)

# Create Flask app
app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

# Custom Metrics
request_counter = meter.create_counter(
    name="http_requests_total",
    description="Total HTTP requests",
    unit="1"
)

response_time_histogram = meter.create_histogram(
    name="http_request_duration_seconds",
    description="HTTP request duration",
    unit="s"
)

error_counter = meter.create_counter(
    name="http_errors_total",
    description="Total HTTP errors",
    unit="1"
)

# Observable gauge for simulating CPU usage
def get_cpu_usage_callback(options):
    """Simulate CPU usage with occasional anomalies"""
    base_usage = random.uniform(20, 40)
    
    # Simulate anomaly (spike) 1% of the time to allow for a clearer baseline
    if random.random() < 0.01:
        base_usage = random.uniform(90, 100)
        logger.warning(f"HIGH CPU spike detected: {base_usage:.2f}%")
    
    yield metrics.Observation(base_usage, {"host": "demo-host"})

cpu_gauge = meter.create_observable_gauge(
    name="system_cpu_usage",
    callbacks=[get_cpu_usage_callback],
    description="System CPU usage percentage",
    unit="%"
)

# Observable gauge for memory usage
def get_memory_usage_callback(options):
    """Simulate memory usage with gradual increase (potential leak)"""
    base_memory = random.uniform(50, 70)
    
    # Simulate gradual increase over time
    time_factor = (time.time() % 300) / 300  # Increases over 5 minutes
    memory_usage = base_memory + (time_factor * 20)
    
    # Occasional spike
    if random.random() < 0.05:
        memory_usage = random.uniform(85, 95)
        logger.warning(f"Memory spike detected: {memory_usage:.2f}%")
    
    yield metrics.Observation(memory_usage, {"host": "demo-host"})

memory_gauge = meter.create_observable_gauge(
    name="system_memory_usage",
    callbacks=[get_memory_usage_callback],
    description="System memory usage percentage",
    unit="%"
)

# Request latency simulation
def simulate_latency():
    """Simulate request latency with occasional anomalies"""
    base_latency = random.uniform(0.01, 0.1)
    
    # Simulate slow requests 15% of the time
    if random.random() < 0.15:
        base_latency = random.uniform(0.5, 2.0)
    
    return base_latency

@app.route("/")
def index():
    """Main endpoint"""
    start_time = time.time()
    
    with tracer.start_as_current_span("index_request") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/")
        
        # Simulate processing
        latency = simulate_latency()
        time.sleep(latency)
        
        request_counter.add(1, {"method": "GET", "endpoint": "/"})
        response_time_histogram.record(time.time() - start_time, {"method": "GET", "endpoint": "/"})
        logger.info(f"Request to / completed in {latency:.3f}s")
        
        return jsonify({
            "status": "ok",
            "service": SERVICE_NAME,
            "timestamp": time.time()
        })

@app.route("/api/data")
def get_data():
    """Data endpoint with potential errors"""
    start_time = time.time()
    
    with tracer.start_as_current_span("get_data") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/api/data")
        
        # Simulate errors 5% of the time
        if random.random() < 0.05:
            error_counter.add(1, {"method": "GET", "endpoint": "/api/data", "error": "500"})
            logger.error("Internal server error occurred")
            span.set_attribute("error", True)
            return jsonify({"error": "Internal server error"}), 500
        
        latency = simulate_latency()
        time.sleep(latency)
        
        data = {
            "items": [
                {"id": i, "value": random.randint(1, 100)}
                for i in range(random.randint(5, 20))
            ]
        }
        
        request_counter.add(1, {"method": "GET", "endpoint": "/api/data"})
        response_time_histogram.record(time.time() - start_time, {"method": "GET", "endpoint": "/api/data"})
        
        logger.info(f"Data request completed with {len(data['items'])} items")
        
        return jsonify(data)

@app.route("/api/process", methods=["POST"])
def process_data():
    """Processing endpoint with nested spans"""
    start_time = time.time()
    
    with tracer.start_as_current_span("process_data") as span:
        span.set_attribute("http.method", "POST")
        span.set_attribute("http.route", "/api/process")
        
        data = request.get_json() or {}
        
        # Nested span for validation
        with tracer.start_as_current_span("validate_input") as validation_span:
            validation_time = random.uniform(0.01, 0.05)
            time.sleep(validation_time)
            validation_span.set_attribute("validation.time", validation_time)
        
        # Nested span for processing
        with tracer.start_as_current_span("execute_processing") as processing_span:
            processing_time = simulate_latency()
            time.sleep(processing_time)
            processing_span.set_attribute("processing.time", processing_time)
            processing_span.set_attribute("data.size", len(str(data)))
        
        request_counter.add(1, {"method": "POST", "endpoint": "/api/process"})
        response_time_histogram.record(time.time() - start_time, {"method": "POST", "endpoint": "/api/process"})
        
        logger.info(f"Processing completed in {time.time() - start_time:.3f}s")
        
        return jsonify({
            "status": "processed",
            "timestamp": time.time()
        })

@app.route("/health")
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy"})

@app.route("/simulate/anomaly")
def simulate_anomaly():
    """Manually trigger anomaly simulation"""
    with tracer.start_as_current_span("simulate_anomaly") as span:
        anomaly_type = random.choice(["latency", "error", "cpu"])
        
        if anomaly_type == "latency":
            sleep_time = float(request.args.get("sleep", random.uniform(2, 5)))
            time.sleep(sleep_time)
            logger.warning(f"Simulated latency anomaly: {sleep_time}s")
        elif anomaly_type == "error":
            error_counter.add(1, {"method": "GET", "endpoint": "/simulate/anomaly", "error": "simulated"})
            logger.error("Simulated error anomaly")
        else:
            logger.warning("Simulated CPU anomaly (check metrics)")
        
        span.set_attribute("anomaly.type", anomaly_type)
        
        return jsonify({
            "status": "anomaly_simulated",
            "type": anomaly_type
        })

if __name__ == "__main__":
    logger.info(f"Starting {SERVICE_NAME}")
    logger.info(f"OTLP Traces: {OTLP_TRACES_ENDPOINT}")
    logger.info(f"OTLP Metrics: {OTLP_METRICS_ENDPOINT}")
    logger.info(f"OTLP Logs: {OTLP_LOGS_ENDPOINT}")
    app.run(host="0.0.0.0", port=8080, debug=False)
