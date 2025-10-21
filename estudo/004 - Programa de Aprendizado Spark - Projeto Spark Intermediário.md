# ETL Intermediário com Apache Spark - Guia Especialista

Olá! Com 20 anos em Engenharia de Dados, vou decompor esse programa robusto de aprendizado prático. Você está no caminho certo — essa é a estrutura que usamos em produção.

## 📚 EXPLICAÇÃO DETALHADA DO PROGRAMA

### 1. EXTRACTION (8h) - Fundações Sólidas

Você vai aprender a **ler dados heterogêneos** sem quebrar o pipeline:

#### Conceitos-chave:

- **CSV/Parquet/JSON**: Cada formato tem idiossincrasia. CSV pode ter encoding quebrado, Parquet é comprimido (eficiente), JSON é semi-estruturado
- **Data Validation**: Validar schemas evita que dados ruins contaminem transformações
- **Tratamento de Corrupção**: Dados do mundo real são sujos. UTF-8 com BOM, delimitadores inconsistentes, linhas incompletas

#### Documentações essenciais:

```
📖 Apache Spark Documentation:
https://spark.apache.org/docs/latest/sql-data-sources.html

📖 PySpark SQL Data Sources (CSV, Parquet, JSON):
https://spark.apache.org/docs/latest/sql-data-sources-csv.html
https://spark.apache.org/docs/latest/sql-data-sources-parquet.html
https://spark.apache.org/docs/latest/sql-data-sources-json.html

📖 Schema Validation & StructType:
https://spark.apache.org/docs/latest/sql-data-types.html
```

#### Exemplo prático que você fará:

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

spark = SparkSession.builder.appName("ETL_NYC_Taxi").getOrCreate()

# Leitura com schema definido (evita inferência lenta)
schema = StructType([
    StructField("trip_id", StringType(), True),
    StructField("pickup_datetime", StringType(), True),
    StructField("dropoff_datetime", StringType(), True),
    StructField("trip_distance", IntegerType(), True),
])

df_raw = spark.read \
    .schema(schema) \
    .option("header", "true") \
    .option("badRecordsPath", "/tmp/bad_records") \
    .option("mode", "PERMISSIVE") \
    .csv("s3://datasets/nyc_taxi/2023/")

# Validação de schema
df_raw.printSchema()
print(f"Total records: {df_raw.count()}")
```

---

### 2. TRANSFORMATION (24h) - O Coração do ETL

Aqui você entende **como os dados fluem e se transformam**:

#### Data Cleaning (6h):

- Detectar e tratar NULLs estrategicamente
- Remover duplicatas (cuidado: qual coluna define duplicação?)
- Normalizar tipos de dados

#### Feature Engineering (6h):

- Derivar novas colunas que agreguem valor
- Exemplo: de `pickup_datetime` criar `hora_pico`, `dia_semana`, `é_madrugada`

#### Agregações Complexas (6h):

- GROUP BY com múltiplas dimensões
- Window functions (RANK, ROW_NUMBER, LAG/LEAD)
- Percentis e distribuições

#### Joins (4h):

- Inner, Left, Right, Full Outer
- Broadcast joins vs Sort-merge joins (performance!)

#### Documentações:

```
📖 PySpark SQL & DataFrame API:
https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/index.html

📖 Window Functions (crítico!):
https://spark.apache.org/docs/latest/sql-ref-window-functions.html

📖 Query Optimization:
https://spark.apache.org/docs/latest/sql-performance-tuning.html

📖 Delta Lake (para transformações incrementais):
https://docs.delta.io/latest/index.html
```

#### Exemplo prático de Feature Engineering + Agregação:

```python
from pyspark.sql.functions import col, from_unixtime, hour, dayofweek, \
    avg, max, min, row_number, dense_rank, lag
from pyspark.sql.window import Window

# Conversão de timestamp
df_clean = df_raw \
    .withColumn("pickup_ts", from_unixtime(col("pickup_timestamp"))) \
    .withColumn("hora_pickup", hour(col("pickup_ts"))) \
    .withColumn("dia_semana", dayofweek(col("pickup_ts")))

# Feature: "é pico?" (7-10h, 17-20h)
df_clean = df_clean.withColumn(
    "eh_pico",
    ((col("hora_pickup") >= 7) & (col("hora_pickup") <= 10)) |
    ((col("hora_pickup") >= 17) & (col("hora_pickup") <= 20))
)

# Agregação com Window Function
window_spec = Window.partitionBy("vendor_id").orderBy("pickup_ts")

df_agg = df_clean.withColumn(
    "trip_lag_distance",
    lag(col("trip_distance")).over(window_spec)
).withColumn(
    "vendor_rank",
    dense_rank().over(Window.partitionBy("vendor_id").orderBy(col("total_amount").desc()))
)

# Agregação final
resumo = df_agg.groupBy("hora_pickup", "eh_pico") \
    .agg(
        avg(col("total_amount")).alias("ticket_medio"),
        max(col("trip_distance")).alias("max_distancia"),
        min(col("trip_distance")).alias("min_distancia")
    ) \
    .orderBy(col("hora_pickup"))

resumo.show()
```

---

### 3. LOADING (8h) - Armazenamento Eficiente

#### Parquet (Compressão + Performance):

- Formato columnar → melhor compressão
- Particionamento reduz leitura

#### Delta Lake (ACID + Versionamento):

- Transações ACID em data lakes
- Time travel (voltar a versão anterior)
- Schema enforcement

#### Documentação:

```
📖 Spark - Writing DataFrames:
https://spark.apache.org/docs/latest/sql-data-sources-load-save-functions.html

📖 Partitioning Best Practices:
https://spark.apache.org/docs/latest/sql-data-sources-parquet.html#partition-discovery

📖 Delta Lake - Overview:
https://docs.delta.io/latest/index.html

📖 Delta Lake - Write & Read:
https://docs.delta.io/latest/quick-start.html
```

#### Exemplo prático:

```python
# Escrever em Parquet particionado
df_agg.write \
    .mode("overwrite") \
    .partitionBy("eh_pico", "hora_pickup") \
    .parquet("s3://data-lake/nyc_taxi/processed/")

# Escrever em Delta Lake (com versionamento)
df_agg.write \
    .mode("overwrite") \
    .format("delta") \
    .option("mergeSchema", "true") \
    .save("s3://data-lake/nyc_taxi/delta/")

# Leitura com time travel
df_v1 = spark.read.format("delta").option("versionAsOf", 0).load("...")
```

---

### 4. DOCUMENTAÇÃO (8h)

Código limpo sem documentação é como um carro de luxo sem manual:

```python
"""
ETL Pipeline: NYC Taxi Data Processing
======================================
Objetivo: Processar dados brutos de táxis em NYC e gerar 
agregações para análise de padrões de viagem.

Transformações principais:
1. Validação de schema (rejeita registros malformados)
2. Feature engineering: hora_pico, dia_semana
3. Agregações: ticket médio por hora
4. Carregamento em Delta Lake com particionamento

Autor: [seu_nome]
Data: 2025-10-20
Versão: 1.0
"""
```

---

## 🌍 EXEMPLOS DO MUNDO REAL (Engenharia de Dados Sênior)

Aqui estão os **padrões que você verá em produção**:

### Caso 1: E-commerce - Recomendação de Produtos

```
EXTRACTION:
├─ PostgreSQL (dados de clientes, pedidos)
├─ S3 (logs de cliques em tempo real)
├─ API (dados de concorrentes)

TRANSFORMATION:
├─ Limpeza: remover bots, sessões com 0 segundos
├─ Feature engineering:
│  ├─ "cliente_premium" = gasto_anual > 5k
│  ├─ "categoria_preferida" = moda do histórico
│  └─ "recency" = dias desde última compra
├─ Joins: usuario × produto × categoria × vendedor
├─ Janela temporal: últimos 30/90/365 dias

LOADING:
└─ Delta Lake particionado por data + categoria
   (serve para retrain de modelos ML diários)

IMPACTO: Aumenta cross-sell em 23% (metáfora, mas realista)
```

### Caso 2: FinTech - Detecção de Fraude

```
EXTRACTION (near real-time):
├─ Kafka stream: transações em vivo
├─ Cassandra: histórico de comportamento
└─ Redis: últimas transações (cache quente)

TRANSFORMATION (complexo!):
├─ Validações: 
│  ├─ Velocidade: mesma conta em cidades diferentes?
│  └─ Padrão: compra de R$ 0.01 + 99.99 (teste de cartão)?
├─ Feature engineering:
│  ├─ Desvio padrão do valor da transação
│  ├─ Anomalia em hora/localização
│  └─ Velocidade de transações (≤5min entre elas?)
├─ Joins: transacao × usuario × dispositivo × localização

LOADING:
└─ Parquet em tempo real + Delta para histórico
   (feedback loop: depois confirmar se foi fraude)

LATÊNCIA: < 500ms (criticamente importante!)
```

### Caso 3: Saúde - Análise de Pacientes

```
EXTRACTION:
├─ HL7 (formato médico de dados)
├─ DICOM (imagens médicas)
├─ EHR (Electronic Health Records - Prontuários)
└─ Validação HIPAA (conformidade)

TRANSFORMATION:
├─ Anonimização: remover PII (Personally Identifiable Info)
├─ Feature engineering:
│  ├─ Índice de Comorbidade de Charlson
│  ├─ Progressão de diagnóstico
│  └─ Aderência ao tratamento
├─ Temporal: sequência de eventos médicos
└─ Joins complexos: paciente × consultas × exames × prescrições

LOADING:
└─ Data warehouse (RedShift, BigQuery)
   com acesso restrito a roles específicas

DESAFIO: Dados altamente sensíveis + conformidade regulatória
```

---

## 🛠️ COMO APLICAR ISSO NA PRÁTICA

### Semana 1 - Quinta a Sexta:

```bash
# 1. Setup do ambiente
git clone seu-repo
pip install pyspark delta-spark pandas pytest

# 2. Exploração do NYC Taxi Dataset
spark-shell  # ou jupyter notebook

# 3. Primeira leitura + validação
# Comece com 100MB apenas (desenvolvimento rápido)
```

### Semana 2 - Segunda a Quarta:

```bash
# Commit structure (histórico limpo):
git log --oneline
✓ feat: extraction com validação de schema
✓ feat: feature engineering - temporal features
✓ refactor: otimização de joins com broadcast
✓ test: 3 queries validadas com pytest
```

---

## 📊 RECURSOS ADICIONAIS PARA APROFUNDAMENTO

### Livros (clássicos):

- *"Fundamentals of Data Engineering"* - Joe Reis & Matt Housley
- *"Designing Data-Intensive Applications"* - Martin Kleppmann

### Cursos/Certificações:

- Databricks Academy: https://academy.databricks.com/
- Spark Fundamentals (gratuito): https://training.databricks.com/

### Comunidades:

- Apache Spark Slack: https://s.apache.org/slack-invite
- Stack Overflow tag `apache-spark`
- GitHub: spark trending repositories

### Ferramentas Relacionadas:

```
ETL Orchestration:    Apache Airflow, Prefect, dbt
Data Quality:         Great Expectations, Soda
Monitoring:           Datadog, New Relic
Lakehouse:            Delta Lake, Iceberg, Hudi
```

---

## ✅ CHECKLIST PARA SEU PROJETO

```
[ ] Extraction
    [ ] Ler 3 formatos diferentes
    [ ] Validar 100% dos schemas
    [ ] Rastrear bad records
    
[ ] Transformation
    [ ] Remover 5+ tipos de anomalias
    [ ] Criar 8+ features derivadas
    [ ] Executar 5+ joins
    [ ] Query time < 2 min
    
[ ] Loading
    [ ] Parquet com 4+ partições
    [ ] Delta Lake com versionamento
    [ ] Testes de integridade (count antes/depois)
    
[ ] GitHub
    [ ] README com instruções claras
    [ ] Commits atômicos
    [ ] .gitignore correto (dados não versionados)
    [ ] 3 queries de teste com resultados esperados
```

---

Você quer que eu elabore mais em algum tópico específico? Recomendo começar pela **Transformation (24h)** — é onde os melhores engenheiros de dados passam o tempo! 🚀