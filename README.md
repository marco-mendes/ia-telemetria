# OpenSearch OpenTelemetry ML POC

Este projeto demonstra uma pipeline completa de observabilidade utilizando **OpenSearch**, **Data Prepper** e **OpenTelemetry**, com foco em recursos de Machine Learning (**Anomaly Detection** e **Forecasting**).

## 🚀 Arquitetura

1.  **Demo App (Python/Flask)**: Aplcação instrumentada com OpenTelemetry SDK para gerar traces, métricas e logs.
2.  **Data Prepper**: Atua como o coletor e processador OTel, transformando e enviando dados para o OpenSearch.
3.  **OpenSearch**: Armazenamento dos dados e motor de ML.
4.  **OpenSearch Dashboards**: Interface para visualização e gerenciamento de detecção de anomalias.

---

## 🛠️ Como Iniciar

### Pré-requisitos
- Docker e Docker Compose instalados.
- Ao menos 4GB de memória dedicados ao Docker.

### Passo 1: Subir o ambiente
```bash
docker-compose up -d --build
```
Isso iniciará o OpenSearch, Dashboards, Data Prepper e a aplicação demo.

### Passo 2: Configurar o ambiente ML
```bash
# 1. Criar os detectores de anomalias (via API)
./scripts/create-anomaly-detectors.sh

# 2. Iniciar a detecção em tempo real
./scripts/start-detectors.sh

# 3. Configurar alertas (opcional)
./scripts/create-alerts.sh
```

---

## 🧪 Testando a POC

### Gerar Tráfego e Anomalias
```bash
./scripts/load-generator.sh
```
Este script gera tráfego contínuo e simula anomalias de CPU e latência periodicamente. **Deixe rodando por pelo menos 10-15 minutos** para que o modelo RCF tenha dados suficientes para treinamento.

---

## 📊 Visualização e ML

### Acessar o Dashboards
- URL: **http://localhost:5601** (Segurança desabilitada para a POC).

### Configurar Index Patterns
Para ver os dados no Discovery/Dashboards, você precisa criar os patterns:
1. Vá em **Stack Management** -> **Index Patterns** -> **Create index pattern**.
2. **Métricas**: Pattern `otel-metrics-*`, Time field `time`.
3. **Logs**: Pattern `otel-logs-*`, Time field `time`.
4. **Traces**: Pattern `otel-v1-apm-span-*`, Time field `startTime`.

### Explorar Recursos de ML

#### 1. Anomaly Detection (Detecção de Anomalias)
1. Vá no menu lateral -> **OpenSearch Plugins** -> **Anomaly Detection**.
2. Você verá os detectores `cpu-usage-detector`, `memory-usage-detector`, etc.
3. Clique em um detector para ver o gráfico de **Anomaly Grade** e **Confidence**.

#### 2. Forecasting (Previsão)
A detecção de anomalias do OpenSearch também permite prever valores futuros.
1. No menu lateral -> **Observability** → **Metrics**.
2. Explore as métricas de `system_cpu_usage` e utilize o recurso de forecasting nos gráficos.

#### 3. Trace Analytics
1. Menu lateral -> **Observability** -> **Trace Analytics**.
2. Visualize o **Service Map** e identifique gargalos de performance.

---

## 🛠️ Troubleshooting & Dicas Técnicas

### 1. Formato do Endpoint OTLP (gRPC)
Se a aplicação demo não conseguir enviar dados (`StatusCode.UNAVAILABLE`), verifique:
- O endpoint deve ser apenas `host:port` (ex: `data-prepper:21890`), **sem** `http://`.
- Como a segurança está desabilitada, use `insecure=True` no exporter do SDK.

### 2. Memória Insuficiente
O OpenSearch e o Data Prepper são intensivos em memória (JVM). Se algum container morrer sozinho, aumente o limite de memória do seu Docker Desktop para pelo menos 4-6GB.

### 3. Falta de Dados nos Detectores
Os detectores RCF precisam de um período de "aquecimento" (geralmente 50-100 data points). Se o status estiver `Initializing`, continue rodando o `load-generator.sh`.

### 4. Portas Importantes
- **5601**: OpenSearch Dashboards
- **9200**: OpenSearch API
- **21890**: OTel Traces (gRPC)
- **21891**: OTel Metrics (gRPC)
- **21892**: OTel Logs (gRPC)
- **4900**: Data Prepper Metrics/Server

---

## 📄 Scripts Úteis

- `scripts/health-check.sh`: Verifica a saúde do cluster e ingestão.
- `scripts/cleanup.sh`: Remove detectores e limpa índices (use com cautela).

---

## 🧹 Limpeza e Saneamento

Se você precisar resetar o ambiente ou liberar espaço em disco, siga os procedimentos abaixo:

### 1. Parar o ambiente
```bash
docker-compose down
```

### 2. Saneamento Completo (Containers, Imagens e Volumes)
Para remover tudo, incluindo os dados persistidos no OpenSearch e as imagens compiladas da aplicação demo:

```bash
# Para os containers e remove volumes (limpa os dados do OpenSearch)
docker-compose down -v

# Remove a imagem da aplicação demo e imagens órfãs
docker rmi ia-telemetria-demo-app
docker image prune -f
```

### 3. Limpeza de Logs e Cache Local
```bash
# Remove arquivos de cache do Python (caso tenha rodado localmente)
find . -type d -name "__pycache__" -exec rm -rf {} +
```

### 4. Resetar apenas os dados (sem parar os containers)
Se você quiser apenas limpar os índices e detectores de ML para começar do zero:
```bash
# Atenção: Isso deleta todos os dados coletados!
curl -X DELETE "http://localhost:9200/otel-*"
curl -X DELETE "http://localhost:9200/_plugins/_anomaly_detection/detectors/*"
```

---

## 🎯 Objetivo da POC
Demonstrar como o OpenSearch pode ser usado não apenas para logs, mas como uma plataforma completa de monitoramento proativo, capaz de identificar comportamentos anômalos em tempo real sem a necessidade de regras estáticas e complexas.

