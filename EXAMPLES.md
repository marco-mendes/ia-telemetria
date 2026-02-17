# Exemplos de Queries e Visualizações

Este documento contém queries úteis e exemplos de visualizações para explorar os dados da POC.

## 📊 Queries OpenSearch

### Anomalias

#### Buscar Todas as Anomalias Recentes (última hora)

```json
GET .opendistro-anomaly-results*/_search
{
  "size": 20,
  "query": {
    "bool": {
      "filter": [
        {
          "range": {
            "anomaly_grade": {
              "gte": 0.5
            }
          }
        },
        {
          "range": {
            "execution_end_time": {
              "gte": "now-1h"
            }
          }
        }
      ]
    }
  },
  "sort": [
    {
      "anomaly_grade": {
        "order": "desc"
      }
    }
  ]
}
```

#### Anomalias de CPU com Alto Grau

```json
GET .opendistro-anomaly-results*/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "match": {
            "detector_id": "cpu-usage-detector"
          }
        }
      ],
      "filter": [
        {
          "range": {
            "anomaly_grade": {
              "gte": 0.7
            }
          }
        }
      ]
    }
  },
  "sort": [
    {
      "execution_end_time": {
        "order": "desc"
      }
    }
  ]
}
```

#### Agregação de Anomalias por Detector

```json
GET .opendistro-anomaly-results*/_search
{
  "size": 0,
  "query": {
    "range": {
      "execution_end_time": {
        "gte": "now-24h"
      }
    }
  },
  "aggs": {
    "by_detector": {
      "terms": {
        "field": "detector_id.keyword",
        "size": 10
      },
      "aggs": {
        "avg_grade": {
          "avg": {
            "field": "anomaly_grade"
          }
        },
        "max_grade": {
          "max": {
            "field": "anomaly_grade"
          }
        },
        "anomaly_count": {
          "filter": {
            "range": {
              "anomaly_grade": {
                "gte": 0.7
              }
            }
          }
        }
      }
    }
  }
}
```

### Métricas

#### CPU Usage Timeline

```json
GET otel-metrics-*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        {
          "term": {
            "name": "system_cpu_usage"
          }
        },
        {
          "range": {
            "@timestamp": {
              "gte": "now-1h"
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "cpu_over_time": {
      "date_histogram": {
        "field": "@timestamp",
        "fixed_interval": "1m"
      },
      "aggs": {
        "avg_cpu": {
          "avg": {
            "field": "value"
          }
        },
        "max_cpu": {
          "max": {
            "field": "value"
          }
        }
      }
    }
  }
}
```

#### Memory Usage com Estatísticas

```json
GET otel-metrics-*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        {
          "term": {
            "name": "system_memory_usage"
          }
        },
        {
          "range": {
            "@timestamp": {
              "gte": "now-1h"
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "memory_stats": {
      "stats": {
        "field": "value"
      }
    },
    "memory_percentiles": {
      "percentiles": {
        "field": "value",
        "percents": [50, 75, 90, 95, 99]
      }
    }
  }
}
```

#### Request Latency Distribution

```json
GET otel-metrics-*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        {
          "term": {
            "name": "http_request_duration_seconds"
          }
        },
        {
          "range": {
            "@timestamp": {
              "gte": "now-1h"
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "by_endpoint": {
      "terms": {
        "field": "attributes.endpoint.keyword",
        "size": 10
      },
      "aggs": {
        "latency_percentiles": {
          "percentiles": {
            "field": "value",
            "percents": [50, 90, 95, 99]
          }
        },
        "avg_latency": {
          "avg": {
            "field": "value"
          }
        }
      }
    }
  }
}
```

#### Todas as Métricas Disponíveis

```json
GET otel-metrics-*/_search
{
  "size": 0,
  "aggs": {
    "metric_names": {
      "terms": {
        "field": "name.keyword",
        "size": 50
      }
    }
  }
}
```

### Traces

#### Traces com Erros

```json
GET otel-v1-apm-span-*/_search
{
  "query": {
    "bool": {
      "filter": [
        {
          "term": {
            "attributes.error": true
          }
        },
        {
          "range": {
            "startTime": {
              "gte": "now-1h"
            }
          }
        }
      ]
    }
  },
  "sort": [
    {
      "startTime": {
        "order": "desc"
      }
    }
  ]
}
```

#### Traces Lentos (> 1 segundo)

```json
GET otel-v1-apm-span-*/_search
{
  "query": {
    "bool": {
      "filter": [
        {
          "script": {
            "script": {
              "source": "doc['endTime'].value - doc['startTime'].value > 1000000",
              "lang": "painless"
            }
          }
        },
        {
          "range": {
            "startTime": {
              "gte": "now-1h"
            }
          }
        }
      ]
    }
  },
  "sort": [
    {
      "startTime": {
        "order": "desc"
      }
    }
  ]
}
```

#### Traces por Endpoint

```json
GET otel-v1-apm-span-*/_search
{
  "size": 0,
  "query": {
    "range": {
      "startTime": {
        "gte": "now-1h"
      }
    }
  },
  "aggs": {
    "by_route": {
      "terms": {
        "field": "attributes.http@route.keyword",
        "size": 10
      },
      "aggs": {
        "avg_duration": {
          "avg": {
            "script": {
              "source": "doc['endTime'].value - doc['startTime'].value",
              "lang": "painless"
            }
          }
        },
        "error_rate": {
          "filter": {
            "term": {
              "attributes.error": true
            }
          }
        }
      }
    }
  }
}
```

### Logs

#### Logs com Nível ERROR

```json
GET otel-logs-*/_search
{
  "query": {
    "bool": {
      "filter": [
        {
          "term": {
            "severityText.keyword": "ERROR"
          }
        },
        {
          "range": {
            "@timestamp": {
              "gte": "now-1h"
            }
          }
        }
      ]
    }
  },
  "sort": [
    {
      "@timestamp": {
        "order": "desc"
      }
    }
  ]
}
```

#### Logs Correlacionados com Trace

```json
GET otel-logs-*/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "exists": {
            "field": "traceId"
          }
        }
      ],
      "filter": [
        {
          "range": {
            "@timestamp": {
              "gte": "now-1h"
            }
          }
        }
      ]
    }
  }
}
```

## 📈 Visualizações Recomendadas

### 1. CPU Usage com Anomalias Overlay

**Tipo**: Line Chart

**Configuração**:
- **X-axis**: `@timestamp` (date histogram, 1m interval)
- **Y-axis**: `avg(value)` where `name=system_cpu_usage`
- **Overlay**: Anomaly markers from `.opendistro-anomaly-results*`

**Código de Visualização**:
```json
{
  "title": "CPU Usage with Anomalies",
  "type": "line",
  "params": {
    "type": "line",
    "grid": {
      "categoryLines": false
    },
    "categoryAxes": [
      {
        "id": "CategoryAxis-1",
        "type": "category",
        "position": "bottom",
        "show": true,
        "title": {
          "text": "Time"
        }
      }
    ],
    "valueAxes": [
      {
        "id": "ValueAxis-1",
        "name": "LeftAxis-1",
        "type": "value",
        "position": "left",
        "show": true,
        "title": {
          "text": "CPU %"
        }
      }
    ],
    "seriesParams": [
      {
        "show": true,
        "type": "line",
        "mode": "normal",
        "data": {
          "label": "CPU Usage",
          "id": "1"
        },
        "valueAxis": "ValueAxis-1"
      }
    ]
  }
}
```

### 2. Memory Forecast Dashboard

**Tipo**: Multi-metric visualization

**Métricas**:
1. Actual memory usage (line)
2. Predicted values (dashed line)
3. Confidence interval (area)

### 3. Request Latency Heatmap

**Tipo**: Heatmap

**Configuração**:
- **X-axis**: Time buckets (5m)
- **Y-axis**: Endpoints
- **Color**: P95 latency

### 4. Anomaly Grade Timeline

**Tipo**: Multi-line chart

**Configuração**:
- **Lines**: One per detector
- **Y-axis**: Anomaly grade (0-1)
- **Threshold line**: 0.7 (alert threshold)

### 5. Service Map

**Tipo**: Network Graph

**Fonte**: `otel-v1-apm-service-map`

**Mostra**:
- Nodes: Services
- Edges: Dependencies
- Metrics: Request count, error rate

### 6. Error Rate Dashboard

**Tipo**: Gauge + Timeline

**Métricas**:
- Current error rate (gauge)
- Error rate over time (line)
- Errors by endpoint (bar)

## 🎨 Criando Visualizações no OpenSearch Dashboards

### Passo a Passo

1. **Acessar Dashboards**
   - Navegue para http://localhost:5601
   - Login: admin/admin

2. **Criar Index Pattern**
   - Stack Management → Index Patterns
   - Create index pattern: `otel-metrics-*`
   - Time field: `@timestamp`
   - Repetir para `otel-logs-*` e `otel-v1-apm-span-*`

3. **Criar Visualização**
   - Visualize → Create visualization
   - Escolher tipo (Line, Bar, Pie, etc.)
   - Selecionar index pattern
   - Configurar métricas e buckets

4. **Adicionar ao Dashboard**
   - Dashboard → Create dashboard
   - Add → Selecionar visualizações
   - Arrange e resize

### Dashboard Sugerido: "Observability Overview"

**Painéis**:

1. **Top Row** (Métricas Gerais)
   - Total Requests (Metric)
   - Error Rate (Gauge)
   - Avg Latency (Metric)
   - Active Anomalies (Metric)

2. **Middle Row** (Timelines)
   - CPU Usage with Anomalies (Line)
   - Memory Usage Trend (Line + Forecast)
   - Request Latency P95 (Line)

3. **Bottom Row** (Detalhes)
   - Errors by Endpoint (Bar)
   - Service Map (Network)
   - Recent Anomalies (Table)

## 🔍 Queries Avançadas

### Correlação entre Anomalias e Erros

```json
GET .opendistro-anomaly-results*/_search
{
  "size": 0,
  "query": {
    "range": {
      "execution_end_time": {
        "gte": "now-24h"
      }
    }
  },
  "aggs": {
    "anomaly_windows": {
      "date_histogram": {
        "field": "execution_end_time",
        "fixed_interval": "5m"
      },
      "aggs": {
        "high_anomalies": {
          "filter": {
            "range": {
              "anomaly_grade": {
                "gte": 0.7
              }
            }
          }
        }
      }
    }
  }
}
```

Depois correlacionar com:

```json
GET otel-logs-*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        {
          "term": {
            "severityText.keyword": "ERROR"
          }
        },
        {
          "range": {
            "@timestamp": {
              "gte": "now-24h"
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "errors_over_time": {
      "date_histogram": {
        "field": "@timestamp",
        "fixed_interval": "5m"
      }
    }
  }
}
```

### Top 10 Traces Mais Lentos

```json
GET otel-v1-apm-span-*/_search
{
  "size": 10,
  "query": {
    "bool": {
      "must_not": [
        {
          "exists": {
            "field": "parentSpanId"
          }
        }
      ],
      "filter": [
        {
          "range": {
            "startTime": {
              "gte": "now-1h"
            }
          }
        }
      ]
    }
  },
  "sort": [
    {
      "_script": {
        "type": "number",
        "script": {
          "source": "doc['endTime'].value - doc['startTime'].value",
          "lang": "painless"
        },
        "order": "desc"
      }
    }
  ]
}
```

### Detecção de Padrões de Memory Leak

```json
GET otel-metrics-*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        {
          "term": {
            "name": "system_memory_usage"
          }
        },
        {
          "range": {
            "@timestamp": {
              "gte": "now-1h"
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "memory_trend": {
      "date_histogram": {
        "field": "@timestamp",
        "fixed_interval": "5m"
      },
      "aggs": {
        "avg_memory": {
          "avg": {
            "field": "value"
          }
        },
        "memory_derivative": {
          "derivative": {
            "buckets_path": "avg_memory"
          }
        }
      }
    }
  }
}
```

## 💡 Dicas de Uso

### Performance

1. **Use filtros de tempo**: Sempre limite queries com range filters
2. **Agregações**: Prefira agregações a retornar muitos documentos
3. **Size 0**: Use `"size": 0` quando só precisa de agregações

### Anomaly Detection

1. **Warm-up period**: Aguarde 10-15 min de dados antes de avaliar
2. **Threshold tuning**: Ajuste thresholds baseado em false positives
3. **Feature engineering**: Teste diferentes agregações (avg, max, sum)

### Visualizações

1. **Time range**: Sincronize time range entre visualizações
2. **Refresh**: Configure auto-refresh para dashboards em tempo real
3. **Drill-down**: Use filtros interativos para exploração

## 📚 Recursos Adicionais

- [OpenSearch Query DSL](https://opensearch.org/docs/latest/query-dsl/)
- [Anomaly Detection API](https://opensearch.org/docs/latest/monitoring-plugins/ad/api/)
- [Visualization Types](https://opensearch.org/docs/latest/dashboards/visualize/viz-index/)
