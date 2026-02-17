# Troubleshooting Guide - OpenSearch POC

## Problemas Comuns e Soluções

### 1. Platform Mismatch (Apple Silicon / M1/M2/M3)
**Erro:** `The requested image's platform (linux/amd64) does not match the detected host platform...`
**Solução:** Adicionar `platform: linux/amd64` em todos os serviços no `docker-compose.yml`. O Docker Desktop usa Rosetta 2 para emulação.

### 2. OTLP gRPC - StatusCode.UNAVAILABLE
**Problema:** A aplicação demo não consegue enviar dados e mostra erros de conexão.
**Causas e Soluções:**
1.  **Formato do Endpoint (Crítico)**: Para gRPC em Python, o endpoint **NÃO** deve incluir o protocolo.
    -   ❌ Incorreto: `http://data-prepper:21890`
    -   ✅ Correto: `data-prepper:21890`
2.  **Insecure Mode**: Como o SSL está desabilitado na POC, o SDK deve ser configurado com `insecure=True` (ou similar).
3.  **Portas**: Verifique se as portas batem com o `pipelines.yaml`:
    -   Traces: 21890
    -   Metrics: 21891
    -   Logs: 21892

### 3. OTLP HTTP - 404 Not Found
**Problema:** Erro 404 ao tentar enviar via HTTP.
**Solução:** 
-   A ingestão via gRPC é mais robusta no Data Prepper 2.6. Recomendamos usar os gRPC exporters.
-   Se usar HTTP, ative `unframed_requests: true` na source do Data Prepper.
-   Cuidado com caminhos duplos: o SDK anexa `/v1/traces` automaticamente se o endpoint for apenas o host.

### 4. OpenSearch Security Plugin Error
**Erro:** `java.lang.IllegalStateException: plugins.security.ssl.transport.enabled must be set to 'true'`
**Solução:** Desabilitar o plugin de segurança (`DISABLE_SECURITY_PLUGIN=true` no env e `plugins.security.disabled: true` no `opensearch.yml`).

### 5. Data Prepper - ByteCountInvalidInputException
**Erro:** `Byte counts must have a unit`
**Solução:** Adicionar `mb` ou `gb` aos valores de circuit breaker no `data-prepper-config.yaml` (ex: `usage: 400mb`).

### 6. Anomaly Detectors "Initializing"
**Problema:** O status do detector fica em inicialização por muito tempo.
**Solução:** O algoritmo RCF precisa de dados. Certifique-se de que o `load-generator.sh` está rodando e gerando dados nos índices `otel-*`. Geralmente leva 5-10 minutos de dados contínuos.

---

## Comandos de Diagnóstico

### Verificar Saúde do Cluster
```bash
curl -s http://localhost:9200/_cluster/health | jq
```

### Verificar Índices e Documentos
```bash
curl -s "http://localhost:9200/_cat/indices/otel-*?v"
```

### Verificar Pipelines do Data Prepper
```bash
curl -s http://localhost:4900/list
```

### Ver Logs em Tempo Real
```bash
docker-compose logs -f demo-app
docker-compose logs -f data-prepper
```

---

## Dicas de Performance
-   **Memória**: Aumente a memória do Docker Desktop para 6GB se encontrar lentidão ou crashes.
-   **Cleanup**: Se os dados ficarem inconsistentes, use `docker-compose down -v` para limpar os volumes e recomeçar.
