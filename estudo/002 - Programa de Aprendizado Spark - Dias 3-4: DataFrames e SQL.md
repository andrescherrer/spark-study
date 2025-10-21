# Masterclass: DataFrames, SQL e Spark — Uma Abordagem Prática

Ótimo! Vou estruturar isso como faço há 20 anos: começando pelos fundamentos, construindo mental models sólidos, e depois levando você aos desafios reais que enfrentamos em produção.

---

## 📚 DIA 3-4: MÓDULO COMPLETO

### 1. DATAFRAME OPERATIONS (SELECT, FILTER, GROUPBY, AGG)

#### O que é um DataFrame realmente?

Um DataFrame é uma tabela distribuída — pense nele como um Excel que vive em múltiplas máquinas simultaneamente. Diferente de um Pandas DataFrame que cabe em memória, o Spark DataFrame é *lazy* (preguiçoso): ele não executa nada até você pedir resultado.

#### SELECT: Escolher colunas é trivial, mas entender *quando* é eficiente é crítico.

```sql
-- Spark SQL (sintaxe recomendada para produção)
SELECT user_id, total_amount, order_date 
FROM orders
WHERE order_date >= '2024-01-01'
LIMIT 1000000;
```

```python
# PySpark DataFrame API
orders.select("user_id", "total_amount", "order_date")\
    .filter(col("order_date") >= "2024-01-01")\
    .limit(1000000)
```

#### FILTER: Aqui começa o desempenho

Em dados reais com bilhões de linhas, filtros bem posicionados economizam minutos de processamento.

```python
# BOM: Filtro push-down (aplicado antes da agregação)
df.filter((col("status") == "completed") & (col("amount") > 100))\
    .groupBy("user_id")\
    .agg(sum("amount").alias("total"))

# RUIM: Agregação antes do filtro (processa tudo)
df.groupBy("user_id")\
    .agg(sum("amount").alias("total"))\
    .filter(col("total") > 1000)
```

#### GROUPBY + AGG: A operação mais poderosa e perigosa

```python
# Agregações múltiplas (cenário real)
sales_summary = df.groupBy("product_id", "category")\
    .agg(
        count("*").alias("transaction_count"),
        sum("amount").alias("total_revenue"),
        avg("amount").alias("avg_transaction"),
        min("order_date").alias("first_order"),
        max("order_date").alias("last_order"),
        approx_percentile("amount", 0.95).alias("p95_amount")
    )
```

#### Documentação oficial:

- [Spark SQL Documentation - Select, Filter](https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/api/pyspark.sql.DataFrame.select.html)
- [GroupBy & Agg Functions](https://spark.apache.org/docs/latest/sql-ref-functions-builtin.html)

---

### 2. JOINS: Inner, Left, Right, Outer + Performance

#### Os 4 tipos de JOIN e quando usar cada um

Nos meus 20 anos, **80% dos problemas de performance vêm de joins mal-feitos**. Você precisa entender não só sintaxe, mas *estratégia*.

```python
# INNER JOIN: Apenas registros que existem em ambas as tabelas
orders.join(
    customers,
    orders.customer_id == customers.id,
    "inner"
)

# LEFT JOIN: Todos de 'orders', + matches de 'customers'
orders.join(
    customers,
    orders.customer_id == customers.id,
    "left"
)

# RIGHT JOIN: Todos de 'customers', + matches de 'orders'
orders.join(
    customers,
    orders.customer_id == customers.id,
    "right"
)

# FULL OUTER JOIN: Tudo de ambas as tabelas
orders.join(
    customers,
    orders.customer_id == customers.id,
    "outer"
)
```

#### Performance Real - Broadcast vs Shuffle

Este é o diferencial entre um junior e um sênior.

```python
# ❌ LENTO: Shuffle (move 10GB de dados entre nós)
large_orders.join(large_customers, "inner")
# Resultado: 20+ minutos com 1TB de dados

# ✅ RÁPIDO: Broadcast (copia 50MB para cada executor)
large_orders.join(
    broadcast(small_lookup_table),
    "inner"
)
# Resultado: 30 segundos
```

A regra de ouro: **Broadcasts funcionam quando a tabela menor < 2GB**. Acima disso, Spark faz shuffle.

```python
from pyspark.sql.functions import broadcast

# Forçar broadcast (quando você tem certeza)
orders.join(
    broadcast(products),  # produtos = 500MB
    orders.product_id == products.id
)

# Spark estimará automaticamente se <= 8GB (default)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 10*1024*1024*1024)  # 10GB
```

#### Documentação:

- [Spark Join Operations](https://spark.apache.org/docs/latest/sql-performance-tuning.html#join-hints)
- [Broadcast Join](https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/functions/broadcast.html)

---

### 3. WINDOW FUNCTIONS (RANK, ROW_NUMBER, DENSE_RANK)

#### Window functions salvam vidas em análises complexas

A ideia é simples: calcule algo *dentro de uma janela* de dados sem fazer um groupby.

```python
from pyspark.sql.window import Window
from pyspark.sql.functions import rank, row_number, dense_rank, lag, lead

# Definir janela: particionada por categoria, ordenada por vendas (DESC)
window_spec = Window.partitionBy("category")\
    .orderBy(col("sales").desc())

# RANK: Pula números se houver empate
df_ranked = df.withColumn(
    "rank", 
    rank().over(window_spec)
)
# Resultado: 1, 1, 3 (pula 2)

# ROW_NUMBER: Sequência sem pular
df_ranked = df.withColumn(
    "row_num", 
    row_number().over(window_spec)
)
# Resultado: 1, 2, 3

# DENSE_RANK: Preenche os buracos
df_ranked = df.withColumn(
    "dense_rank", 
    dense_rank().over(window_spec)
)
# Resultado: 1, 1, 2
```

#### Caso real que você usará 100 vezes

```python
# "Pega top 3 produtos por categoria por vendas"
window_top3 = Window.partitionBy("category")\
    .orderBy(col("sales").desc())\
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

products_ranked = products.withColumn(
    "rank_in_category",
    dense_rank().over(window_top3)
)

top_3_per_category = products_ranked.filter(col("rank_in_category") <= 3)
```

#### Funções avançadas que vão bombar seus reports

```python
# LAG/LEAD: Comparar com linha anterior/próxima
window_ordered = Window.partitionBy("customer_id")\
    .orderBy("order_date")

df_with_lag = df.withColumn(
    "previous_order_amount", 
    lag("amount").over(window_ordered)
).withColumn(
    "next_order_date",
    lead("order_date").over(window_ordered)
)

# Calcular crescimento entre pedidos
df_with_lag = df_with_lag.withColumn(
    "growth_vs_last",
    ((col("amount") - col("previous_order_amount")) / col("previous_order_amount") * 100)
)

# CUMULATIVE SUM
window_cumulative = Window.partitionBy("customer_id")\
    .orderBy("order_date")\
    .rangeBetween(Window.unboundedPreceding, Window.currentRow)

df_cumulative = df.withColumn(
    "lifetime_value",
    sum("amount").over(window_cumulative)
)
```

#### Documentação:

- [Window Functions - Official Spark](https://spark.apache.org/docs/latest/sql-ref-syntax-expr-window.html)
- [PySpark Window API](https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/window.html)

---

### 4. SPARK SQL QUERIES - Integrando Tudo

Aqui é onde a magia acontece. Spark SQL é idêntico a SQL tradicional, mas distribuído.

```sql
-- Query completa real: Ranking de produtos + análise de tendência
WITH product_sales AS (
    SELECT 
        p.product_id,
        p.category,
        p.name,
        SUM(oi.quantity) as total_quantity,
        SUM(oi.quantity * oi.price) as total_revenue,
        COUNT(DISTINCT o.order_id) as order_count,
        AVG(oi.quantity * oi.price) as avg_order_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_date >= DATE_SUB(CURRENT_DATE, 90)
    GROUP BY p.product_id, p.category, p.name
),
ranked_products AS (
    SELECT 
        *,
        RANK() OVER (PARTITION BY category ORDER BY total_revenue DESC) as category_rank,
        DENSE_RANK() OVER (ORDER BY total_revenue DESC) as global_rank
    FROM product_sales
)
SELECT 
    category,
    product_id,
    name,
    total_quantity,
    total_revenue,
    order_count,
    avg_order_value,
    category_rank,
    global_rank
FROM ranked_products
WHERE category_rank <= 3
ORDER BY category, category_rank;
```

#### Documentação:

- [Spark SQL Language Manual](https://spark.apache.org/docs/latest/sql-ref.html)
- [Databricks SQL Documentation](https://docs.databricks.com/en/sql/language-manual/sql-ref.html)

---

## 🎯 AS 5 QUERIES COMPLEXAS (Sua Tarefa)

Vou dar os 5 exemplos que você DEVE fazer para dominar este tópico:

### Query 1: Top 3 Produtos por Categoria + Ranking Global

```python
# PySpark - Essa é a mais importante
from pyspark.sql.functions import rank, dense_rank, col, sum, count, avg
from pyspark.sql.window import Window

# Passo 1: Agregar dados por produto
product_sales = orders_items.groupBy("product_id", "product_category")\
    .agg(
        sum("quantity").alias("total_qty"),
        sum(col("quantity") * col("price")).alias("revenue"),
        count("*").alias("transaction_count")
    ).join(products, "product_id")

# Passo 2: Rankear dentro da categoria E globalmente
window_category = Window.partitionBy("product_category")\
    .orderBy(col("revenue").desc())

window_global = Window.orderBy(col("revenue").desc())

ranked = product_sales.withColumn(
    "rank_in_category", rank().over(window_category)
).withColumn(
    "global_rank", rank().over(window_global)
)

# Passo 3: Filtrar top 3
result = ranked.filter(col("rank_in_category") <= 3)
```

### Query 2: Clientes + Last Order Date + Days Since Last Purchase

```python
window_customer = Window.partitionBy("customer_id")\
    .orderBy(col("order_date").desc())

recency = orders.withColumn(
    "row_num", row_number().over(window_customer)
).filter(col("row_num") == 1)\
.select(
    "customer_id",
    col("order_date").alias("last_order_date"),
    datediff(current_date(), col("order_date")).alias("days_since_purchase")
)
```

### Query 3: Análise de Coorte - Quando Cliente Fez Primeira vs Última Compra

```python
window_first = Window.partitionBy("customer_id")\
    .orderBy(col("order_date").asc())

window_last = Window.partitionBy("customer_id")\
    .orderBy(col("order_date").desc())

customer_lifecycle = orders.join(
    orders.withColumn("first_order", row_number().over(window_first))
    .filter(col("first_order") == 1)
    .select("customer_id", col("order_date").alias("first_purchase_date")),
    "customer_id"
).withColumn(
    "customer_age_days",
    datediff(col("order_date"), col("first_purchase_date"))
)
```

### Query 4: Running Total (Cumulative) + % of Total

```python
window_cumulative = Window.partitionBy("customer_id")\
    .orderBy("order_date")\
    .rangeBetween(Window.unboundedPreceding, Window.currentRow)

total_by_customer = orders.groupBy("customer_id").agg(sum("amount").alias("customer_total"))

result = orders.join(total_by_customer, "customer_id")\
.withColumn(
    "running_total", sum("amount").over(window_cumulative)
).withColumn(
    "percent_of_customer_total", 
    (col("running_total") / col("customer_total") * 100)
)
```

### Query 5: Cohort Analysis - Retenção de Clientes por Mês

```python
window_first = Window.partitionBy("customer_id")\
    .orderBy(col("order_date").asc())

first_purchase = orders.withColumn(
    "first_order", row_number().over(window_first)
).filter(col("first_order") == 1)\
.select(
    "customer_id",
    trunc(col("order_date"), "month").alias("cohort_month")
)

orders_with_cohort = orders.join(first_purchase, "customer_id")\
.withColumn(
    "order_month", trunc(col("order_date"), "month")
).withColumn(
    "months_since_cohort",
    months_between(col("order_month"), col("cohort_month"))
)

cohort_matrix = orders_with_cohort.groupBy("cohort_month", "months_since_cohort")\
.agg(countDistinct("customer_id").alias("customers"))
```

---

## 🚀 EXEMPLOS DO MUNDO REAL - Engenharia de Dados

Agora vou trazer os **4 casos que você enfrentará em produção**:

### CASO 1: Fraud Detection em E-commerce Real-Time

#### O Desafio

Amazon processa 50 mil pedidos por minuto. Você precisa identificar fraudes usando padrões históricos sem latência.

```python
from pyspark.sql.functions import *
from pyspark.sql.window import Window

# Dataset: 5 anos de transações, 10TB
orders = spark.table("orders_history")
customers = spark.table("customers")

# Window: últimas 24h para cada cliente
window_24h = Window.partitionBy("customer_id")\
    .orderBy(col("order_timestamp").desc())\
    .rangeBetween(
        Window.unboundedPreceding,
        -1 * 24 * 60 * 60  # 24 horas em segundos
    )

# Detectar anomalias
fraud_indicators = orders.join(
    customers,
    orders.customer_id == customers.customer_id,
    "left"
).withColumn(
    # Quantos pedidos nos últimos 1 dia?
    "orders_24h",
    count("*").over(window_24h)
).withColumn(
    # Valor total em 24h
    "volume_24h",
    sum("amount").over(window_24h)
).withColumn(
    # Esse pedido é > 3x a média histórica?
    "amount_spike",
    when(col("amount") > col("customer_avg_amount") * 3, 1).otherwise(0)
).withColumn(
    # Está em país diferente em < 4 horas?
    "impossible_travel",
    when(
        (col("country") != lag("country").over(
            Window.partitionBy("customer_id").orderBy("order_timestamp")
        )) & 
        (col("time_diff_hours") < 4),
        1
    ).otherwise(0)
)

# Score de risco
fraud_score = fraud_indicators.withColumn(
    "fraud_risk_score",
    (
        col("orders_24h") * 0.2 +
        col("amount_spike") * 0.4 +
        col("impossible_travel") * 0.4
    )
)

# Flag pedidos suspeitos
flagged = fraud_score.filter(col("fraud_risk_score") > 0.7)\
    .select("order_id", "customer_id", "fraud_risk_score")\
    .repartition(10)  # Para escrita rápida

# Salvar em tempo real
flagged.write.mode("append").parquet("s3://ml-ops/fraud-flags/")
```

#### Lições aqui:

- Window com `rangeBetween` para períodos de tempo (não linhas)
- Broadcast join com lookup de média histórica
- Particionamento para escrita em paralelo

---

### CASO 2: Data Warehouse - Star Schema com Fatos Agregados

#### O Desafio

Você é engenheiro de dados em um banco. 500 milhões de transações/dia. Dashboards precisam de resposta em < 2s.

```python
# Dimensão: Clientes
dim_customers = spark.read.table("customers")\
.select(
    "customer_id",
    "name",
    "email",
    "country",
    col("created_at").cast("date").alias("customer_since")
)\
.withColumn("dw_load_date", current_date())

# Dimensão: Produtos
dim_products = spark.read.table("products")\
.select(
    "product_id",
    "product_name",
    "category",
    "subcategory",
    "supplier_id",
    "unit_cost"
)

# Fato: Vendas Diárias Agregadas (PRÉ-COMPUTADA)
# ⚠️ Isso é feito uma vez por dia em batch, não em tempo real
window_product_daily = Window.partitionBy("product_id", "sale_date")\
    .orderBy("sale_date")

fact_sales = spark.read.table("raw_orders")\
.filter(col("order_date") >= date_sub(current_date(), 90))\
.groupBy(
    trunc(col("order_timestamp"), "day").alias("sale_date"),
    "product_id",
    "customer_id"
)\
.agg(
    count("*").alias("qty_transactions"),
    sum("amount").alias("total_sales"),
    min("amount").alias("min_sale"),
    max("amount").alias("max_sale"),
    avg("amount").alias("avg_sale")
)\
.join(dim_products, "product_id")\
.join(dim_customers, "customer_id")\
.select(
    col("sale_date"),
    col("product_id"),
    col("customer_id"),
    col("qty_transactions"),
    col("total_sales"),
    col("category"),
    col("country"),
    current_timestamp().alias("dw_load_timestamp")
)

# Escrever em Parquet particionado por data (para queries rápidas)
fact_sales.write.mode("overwrite")\
    .partitionBy("sale_date")\
    .parquet("s3://data-warehouse/fact_sales/")

# Criar view para Dashboard (Tableau, Looker, etc)
fact_sales.write.mode("overwrite").option("path", "s3://dw/fact_sales")\
    .saveAsTable("fact_sales_daily")
```

#### Lições:

- Pré-computação de agregações é **faster-than-light** comparado a queries ad-hoc
- Particionamento por data = queries 100x mais rápidas
- Star schema é o padrão ouro de data warehousing

---

### CASO 3: Machine Learning Feature Engineering

#### O Desafio

Time de ML precisa treinar modelo de churn prediction. Você tem 100 features para extrair de 10TB de dados históricos.

```python
from pyspark.sql.window import Window
from pyspark.sql.functions import *

# 1. Features Recency
window_recency = Window.partitionBy("customer_id")\
    .orderBy(col("transaction_date").desc())

recency_features = transactions.withColumn(
    "days_since_last_purchase",
    datediff(current_date(), first_value("transaction_date").over(window_recency))
)

# 2. Features Frequency & Monetary (RFM clássico)
rfm = transactions.groupBy("customer_id")\
    .agg(
        max("transaction_date").alias("last_purchase_date"),
        count("*").alias("frequency"),
        sum("amount").alias("monetary"),
        avg("amount").alias("avg_ticket")
    )\
    .withColumn(
        "recency",
        datediff(current_date(), col("last_purchase_date"))
    )

# 3. Features comportamentais (12 meses rolling)
window_12m = Window.partitionBy("customer_id")\
    .orderBy(col("transaction_date").desc())\
    .rangeBetween(
        -1 * 365 * 24 * 60 * 60,
        0
    )

behavioral_features = transactions.withColumn(
    "purchase_frequency_12m",
    count("*").over(window_12m)
).withColumn(
    "avg_days_between_purchases",
    when(
        count("*").over(window_12m) > 1,
        datediff(
            first_value("transaction_date").over(window_12m),
            last_value("transaction_date").over(window_12m)
        ) / (count("*").over(window_12m) - 1)
        ).otherwise(null)
)

# 4. Features de produto preferido
window_product = Window.partitionBy("customer_id")\
    .orderBy(col("transaction_date").desc())

product_features = transactions.withColumn(
    "favorite_category",
    first("product_category").over(window_product)
).withColumn(
    "category_diversity",
    size(collect_set("product_category").over(
        Window.partitionBy("customer_id").orderBy(col("transaction_date").desc()).rangeBetween(-365*24*60*60, 0)
    ))
)

# 5. Juntar tudo para ML
ml_features = rfm.join(behavioral_features, "customer_id")\
    .join(product_features, "customer_id")\
    .select(
        "customer_id",
        "recency",
        "frequency",
        "monetary",
        "avg_ticket",
        "purchase_frequency_12m",
        "avg_days_between_purchases",
        "category_diversity"
    )

# Salvar para treinamento
ml_features.write.mode("overwrite").parquet("s3://ml-features/churn_features/")
```

#### Lições:

- Rolling windows com `rangeBetween` em segundos, não dias
- `collect_set` para agregações de strings/categorias
- Sempre normalizar features (escopo do ML, mas pense nisso)

---

### CASO 4: Real-time Streaming + Histórico (Lambda Architecture)

#### O Desafio

Você trabalha em fintech. Precisa processar transações streaming (Kafka) E histórico (Data Lake) simultaneamente.

```python
from pyspark.sql.streaming import *
from pyspark.sql.functions import *
from datetime import timedelta

# Parte 1: Streaming (em tempo real)
kafka_df = spark.readStream\
    .format("kafka")\
    .option("kafka.bootstrap.servers", "kafka-broker:9092")\
    .option("subscribe", "transactions")\
    .option("startingOffsets", "latest")\
    .load()

parsed_stream = kafka_df.select(
    from_json(
        col("value").cast("string"),
        "transaction_id STRING, customer_id STRING, amount DOUBLE, timestamp LONG"
    ).alias("data")
).select("data.*")\
.withColumn("transaction_timestamp", from_unixtime(col("timestamp")))

# Parte 2: Juntar com histórico (batch)
# ⚠️ Broadcast é crucial aqui
customer_history = spark.read.parquet("s3://data-lake/customer-history/")\
    .select("customer_id", "total_lifetime_value", "transaction_count")\
    .withColumn("load_date", current_date())

# Enriquecer stream com histórico
enriched_stream = parsed_stream.join(
    broadcast(customer_history),
    "customer_id",
    "left"
)

# Detecção de anomalia em tempo real
window_5min = Window.partitionBy("customer_id")\
    .orderBy(col("transaction_timestamp").desc())\
    .rangeBetween(
        Window.unboundedPreceding,
        -5 * 60  # Últimos 5 minutos
    )

anomaly_detection = enriched_stream.withColumn(
    "transaction_count_5min",
    count("*").over(window_5min)
).withColumn(
    "is_anomaly",
    when(
        (col("amount") > col("total_lifetime_value") * 0.5) |
        (col("transaction_count_5min") > 10),
        1
    ).otherwise(0)
)

# Salvar resultado em tempo real
query = anomaly_detection.writeStream\
    .format("parquet")\
    .option("path", "s3://streaming-output/anomalies")\
    .option("checkpointLocation", "s3://checkpoints/anomalies")\
    .partitionBy("transaction_timestamp")\
    .trigger(processingTime="10 seconds")\
    .start()

query.awaitTermination()
```

#### Lições críticas:

- Streaming + Broadcast de dados históricos = padrão ouro
- `trigger(processingTime)` controla latência vs throughput
- Checkpoint é obrigatório para recuperação de falhas

---

## 📖 Recursos para Estudo Completo

| Tema | Link |
|------|------|
| **Spark SQL Docs** | https://spark.apache.org/docs/latest/sql-ref.html |
| **PySpark API** | https://spark.apache.org/docs/latest/api/python/ |
| **Databricks Academy** | https://www.databricks.com/learn |
| **Window Functions Deep Dive** | https://spark.apache.org/docs/latest/sql-ref-syntax-expr-window.html |
| **Performance Tuning** | https://spark.apache.org/docs/latest/sql-performance-tuning.html |
| **RDD vs DataFrame** | https://spark.apache.org/docs/latest/rdd-programming-guide.html |
| **Partitioning & Bucketing** | https://spark.apache.org/docs/latest/sql-data-sources-parquet.html |

---

## 🎓 Próximos Passos

1. **Faça as 5 queries** no Databricks Community (gratuito)
2. **Implemente um dos 4 casos reais** com dados mockados
3. Estude **query plans** com `.explain()`:

```python
df.filter(...).join(...).explain(extended=True)
```

Isso vai mostrar EXATAMENTE o que Spark está fazendo. Entender `WholeStageCodeGen` e `BroadcastHashJoin` vs `SortMergeJoin` é a diferença entre ser mediano e ser sênior.

**Perguntas ou quer que eu aprofunde em algum dos 4 casos?**