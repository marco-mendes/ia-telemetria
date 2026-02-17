# Random Cut Forest (RCF) no OpenSearch

O OpenSearch utiliza o algoritmo **Random Cut Forest (RCF)** para sua detecção de anomalias. Este é um algoritmo de aprendizado não supervisionado (unsupervised) projetado especificamente para detectar anomalias em fluxos de dados (streaming).

## 1. O que é uma Random Cut Forest?

Imagine uma "floresta" (Forest) composta por várias "árvores" de decisão aleatórias (Random Cut Trees). 

- **Random Cut Tree (RCT)**: É uma estrutura de árvore onde cada nó representa uma partição do espaço de dados.
- **Random Cut**: Para criar a árvore, o algoritmo escolhe aleatoriamente uma dimensão (um atributo, como CPU ou Latência) e um ponto de corte aleatório dentro da variação dos dados.

## 2. Como o RCF detecta anomalias?

O princípio fundamental do RCF é a **complexidade de inserção**. O algoritmo se pergunta: *"O quanto a estrutura da minha árvore mudaria se eu adicionasse este novo ponto de dado?"*

### O conceito de Deslocamento (Displacement)
- **Pontos Normais**: Seguem o padrão dos dados anteriores. Eles "caem" em ramos existentes da árvore sem exigir grandes mudanças estruturais.
- **Pontos Anômalos**: São outliers. Eles forçam a árvore a criar novos ramos significativos ou a reestruturar partes importantes para acomodá-los.

O "Anomaly Grade" (Grau de Anomalia) é proporcional a esse deslocamento. Quanto mais a árvore precisa mudar para aceitar o ponto, maior é a pontuação de anomalia.

## 3. Conceitos Chave na POC

Para que o RCF funcione bem nesta POC, configuramos os seguintes parâmetros:

### Shingle Size (Tamanho da Janela)
Um "shingle" é uma técnica que transforma uma série temporal em um vetor multidimensional agrupando pontos vizinhos. 
- **Exemplo**: Se o `shingle_size` é 8, o algoritmo não olha apenas o valor atual da CPU, mas sim os últimos 8 minutos como um "bloco" único. Isso permite detectar anomalias baseadas em **padrões/formas** (ex: um aumento súbito) em vez de apenas valores absolutos.

### Anomaly Grade vs. Confidence
- **Anomaly Grade (0.0 a 1.0)**: Indica a força da anomalia. 0 significa normalidade total, valores acima de 0.5 geralmente indicam comportamentos suspeitos.
- **Confidence (0.0 a 1.0)**: Indica o quão confiável é o modelo. No início (etapa de `INIT`), a confiança é baixa porque a floresta ainda está "crescendo" e aprendendo o que é normal.

## 4. Vantagens do RCF para Observabilidade

1. **Eficiência em Streaming**: O RCF é projetado para processar dados conforme eles chegam, sem precisar re-escanear todo o histórico.
2. **Adaptação Dinâmica**: O modelo é atualizado continuamente. Se a carga do seu servidor subir permanentemente de 20% para 40% (um novo "normal"), o RCF eventualmente se adaptará a esse novo baseline.
3. **Não Supervisionado**: Não precisamos dizer ao OpenSearch o que é um erro. Ele aprende sozinho o comportamento esperado da sua aplicação.

## 5. Ciclo de Vida do Detector na POC

1. **INIT**: O detector está coletando os primeiros "shingles" para treinar a floresta.
2. **COLD START**: O modelo realiza o treinamento inicial intensivo com os dados acumulados.
3. **RUNNING**: O modelo começa a dar scores em tempo real para cada minuto de dado que entra.
