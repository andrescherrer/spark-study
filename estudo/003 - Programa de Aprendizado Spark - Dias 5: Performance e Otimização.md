# Performance & Otimização em Engenharia de Dados

Com base em 20 anos na área, posso confirmar que esses 4 pilares são **absolutamente críticos** para reduzir custos em cloud (AWS/GCP/Azure) e melhorar latência. Vou detalhar cada um.

---

## 1. **PARTICIONAMENTO E BUCKETING** (2h)

### Conceito
**Particionamento** divide dados em diretórios separados (geralmente por data, região ou categoria). **Bucketing** distribui dados dentro dessas partições usando hash de uma coluna.

```
Estrutura com Particionamento:
/data/eventos/ano=2024/mes=10/dia=20/part-0001.parquet
/data/eventos/ano=2024/mes=10/dia=21/part-0002.parquet

Com Bucketing adicional:
/data/eventos/ano=2024/mes=10/dia=20/bucket_0/part-0001.parquet
/data/eventos/ano=2024/mes=10/dia=20/bucket_1/part-0002.parquet
```

### Impacto Real
- **Particionamento**: Reduz dados lidos em 90%+ (partition pruning)
- **Bucketing**: Acelera JOINs em 3-5x e melhora agregações

### Documentação
- **Apache Spark**: https://spark.apache.org/docs/latest/sql-data-sources-parquet.html
- **Apache Hive**: https://cwiki.apache.org/confluence/display/Hive/LanguageManual+DDL#LanguageManualDDL-BucketedSortedTables
- **AWS Glue/Athena**: https://docs.aws.amazon.com/athena/latest/ug/partitioning-data.html

---

## 2. **CACHING VS PERSISTENCE** (2h)

### Diferenças Críticas

| Aspecto | Caching | Persistence |
|---------|---------|-------------|
| **Duração** | Sessão Spark | Entre jobs |
| **Armazenamento** | RAM/Disk local | Storage distribuído (HDFS/S3) |
| **Caso de uso** | Reutilizar no mesmo script | Compartilhar entre aplicações |

### Exemplo Prático - Impacto Mensurável

```python
# ❌ SEM CACHE - Recomputa tudo 2x
df_vendas = spark.read.parquet("s3://sales/2024/")
df_top_produtos = df_vendas.groupBy("produto").sum("valor").sort(desc("sum(valor)"))
print(df_top_produtos.show())  # 45 segundos

df_categoria_total = df_vendas.groupBy("categoria").sum("valor")
print(df_categoria_total.show())  # 45 segundos NOVAMENTE

# ✅ COM CACHE - Dados em RAM
df_vendas = spark.read.parquet("s3://sales/2024/")
df_vendas.cache()  # Trigger com uma ação
df_top_produtos = df_vendas.groupBy("produto").sum("valor").sort(desc("sum(valor)"))
print(df_top_produtos.show())  # 45 segundos (primeira vez)

df_categoria_total = df_vendas.groupBy("categoria").sum("valor")
print(df_categoria_total.show())  # 2 segundos (da RAM)
```

### Documentação
- **Spark Caching**: https://spark.apache.org/docs/latest/rdd-programming-guide.html#caching
- **RDD Persistence**: https://spark.apache.org/docs/latest/rdd-programming-guide.html#rdd-persistence

---

## 3. **BROADCAST VS SHUFFLE** (2h)

Este é um **game-changer** em JOINs. É onde você mais economiza em cluster.

### Comparação Visual

```
❌ SHUFFLE (padrão - CUSTOSO)
Partition 1 ──┐
Partition 2 ──┼─→ Redistribui TODOS dados pela rede ──→ Merge
Partition 3 ──┘

✅ BROADCAST (quando possível - RÁPIDO)
Tabela Pequena (< 2GB) → Copia para TODOS workers
Tabela Grande (local) → JOIN local em cada partition
```

### Exemplo com Números Reais

```python
# Tabela de dimensão (3MB) × Tabela de fatos (500GB)

# ❌ Sem Broadcast - 12 minutos (rede saturada)
df_fatos = spark.read.parquet("s3://facts/")
df_dim_usuario = spark.read.parquet("s3://dimensions/user/")
resultado = df_fatos.join(df_dim_usuario, "user_id")

# ✅ Com Broadcast - 1.5 minutos
from pyspark.sql.functions import broadcast
resultado = df_fatos.join(broadcast(df_dim_usuario), "user_id")

# Ganho: 87% de redução de tempo
```

### Requisitos para Broadcast
- Tabela < 2GB (configurável com `spark.sql.broadcastTimeout`)
- Dados devem caber na RAM de cada executor

### Documentação
- **Spark Broadcast**: https://spark.apache.org/docs/latest/sql-performance-tuning.html#broadcast-hint
- **Join Strategies**: https://spark.apache.org/docs/latest/sql-ref-syntax-qry-select-join.html

---

## 4. **PREDICATE PUSHDOWN** (2h)

### O que é?
Filtros aplicados **antes** de ler os dados (no filesystem/database), não depois.

### Comparação

```
❌ SEM PREDICATE PUSHDOWN
Lê 500GB → Filtra apenas janeiro (5GB) → Processa 5GB ❌

✅ COM PREDICATE PUSHDOWN
Filesystem lê APENAS janeiro (5GB) → Processa 5GB ✅
```

### Exemplo com Parquet (formato otimizado)

```python
# ❌ Pushdown NÃO funciona
df = spark.read.parquet("s3://eventos/")
df_filtered = df.filter("data > '2024-10-01' AND usuario_id IN (SELECT id FROM usuarios WHERE tier='premium')")
# Lê dados completos, DEPOIS filtra

# ✅ Pushdown FUNCIONA
df = spark.read.parquet("s3://eventos/ano=2024/mes=10/")
df_filtered = df.filter(col("data") > "2024-10-01")
# Filesystem já lê apenas outubro, depois filtra por data
# Ganha: Leitura reduzida em 90%+
```

### Formatos que suportam Pushdown
- ✅ Parquet (excelente)
- ✅ ORC (excelente)
- ⚠️ CSV (limitado)
- ❌ JSON (sem suporte)

### Documentação
- **Parquet Pushdown**: https://parquet.apache.org/docs/file-format/metadata/
- **Spark SQL Optimization**: https://spark.apache.org/docs/latest/sql-performance-tuning.html#pushdown-filters-to-source

---

# EXEMPLOS DO MUNDO REAL (Engenharia de Dados)

## Caso 1: E-commerce - Análise de Vendas (Milhões de registros/dia)

```python
# Setup
spark.sql("SET spark.sql.adaptive.enabled=true")
spark.sql("SET spark.sql.adaptive.coalescePartitions.enabled=true")

# Query ORIGINAL (Semana anterior - SEM otimização)
vendas = spark.read.parquet("s3://ecommerce/vendas/")
produtos = spark.read.parquet("s3://ecommerce/produtos/")
usuarios = spark.read.parquet("s3://ecommerce/usuarios/")

resultado = (vendas
    .join(produtos, "produto_id")
    .join(usuarios, "usuario_id")
    .filter(year("data_venda") == 2024)
    .groupBy("categoria", "regiao")
    .agg(sum("valor").alias("total"), count("*").alias("quantidade"))
)

# ⏱️ Medição ANTES
resultado.explain(extended=True)  # Mostra plano de execução

# Problema: SEM PARTICIONAMENTO, SEM BROADCAST, SEM PREDICADO PUSHDOWN
start = time.time()
resultado.write.mode("overwrite").parquet("s3://output/resultado_sem_otimizacao/")
print(f"⏱️ Tempo: {time.time() - start:.2f}s")  # ~180s


# ✅ Query OTIMIZADA
from pyspark.sql.functions import broadcast

# 1. Lê com PARTIÇÃO PUSHDOWN (ano está em diretório)
vendas = spark.read.parquet("s3://ecommerce/vendas/ano=2024/")

# 2. Dados pequenos recebem BROADCAST
produtos = spark.read.parquet("s3://ecommerce/produtos/")  # 50MB
usuarios = spark.read.parquet("s3://ecommerce/usuarios/")  # 100MB

resultado_otimizado = (vendas
    .join(broadcast(produtos), "produto_id")
    .join(broadcast(usuarios), "usuario_id")
    .groupBy("categoria", "regiao")
    .agg(sum("valor").alias("total"), count("*").alias("quantidade"))
)

# ⏱️ Medição DEPOIS
resultado_otimizado.explain(extended=True)

start = time.time()
resultado_otimizado.write.mode("overwrite").parquet("s3://output/resultado_otimizado/")
print(f"⏱️ Tempo: {time.time() - start:.2f}s")  # ~18s

# 🎯 GANHO: 90% de redução (180s → 18s)
```

---

## Caso 2: FinTech - Detecção de Fraude (Dados em Tempo Real)

```python
# Estrutura com PARTICIONAMENTO + BUCKETING
spark.sql("""
CREATE TABLE IF NOT EXISTS transacoes
USING PARQUET
PARTITIONED BY (data_transacao, hora)
CLUSTERED BY (usuario_id) INTO 256 BUCKETS
AS SELECT * FROM transacoes_staging
""")

# Query: Encontrar padrões suspeitos (últimas 24h)
from datetime import datetime, timedelta

data_filtro = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")

# ❌ SEM OTIMIZAÇÃO
resultado_slow = spark.sql(f"""
    SELECT usuario_id, COUNT(*) as num_transacoes
    FROM transacoes
    WHERE data_transacao >= '{data_filtro}'
    GROUP BY usuario_id
    HAVING COUNT(*) > 20
""")

# ✅ OTIMIZADO (predicate pushdown + bucket)
resultado_fast = spark.sql(f"""
    SELECT usuario_id, COUNT(*) as num_transacoes
    FROM transacoes
    WHERE data_transacao = '{data_filtro}'  -- Partition pruning
    GROUP BY usuario_id
    HAVING COUNT(*) > 20
""")

# Ganho: Lê apenas 1 dia (1GB) vs 365 dias (365GB)
# Redução: 99.7%
```

---

## Caso 3: Data Lake - Análise de Logs (Terabytes)

```python
# Estrutura otimizada
logs_path = "s3://data-lake/logs/"
# logs/ano=2024/mes=10/dia=20/hour=14/bucket=0/part-0001.parquet

# Problema comum: ler TUDO sem particionamento
# df = spark.read.parquet("s3://data-lake/logs/")  # ❌ 5TB em memória!

# ✅ Solução: múltiplos níveis de partição + cache
from pyspark.sql.functions import col

df_logs = (spark.read
    .parquet(f"s3://data-lake/logs/ano=2024/mes=10/dia=20/")  # Partition pruning
    .filter(
        (col("hora") >= 14) & 
        (col("hora") < 18) &
        (col("status_code") >= 500)  # Predicate pushdown
    )
    .cache()  # Cache resultado (ex: 50GB em memória)
)

# Primeira agregação (do cache)
error_by_service = df_logs.groupBy("servico").count()

# Segunda agregação (do cache)
error_by_endpoint = df_logs.groupBy("endpoint").count()

# Sem cache: 200 minutos
# Com cache: 40 minutos + 2 minutos = 42 minutos
# Ganho: 79%
```

---

## Documentação Complementar para Aprofundamento

| Tópico | Link |
|--------|------|
| Spark SQL Performance Tuning | https://spark.apache.org/docs/latest/sql-performance-tuning.html |
| Parquet File Format | https://parquet.apache.org/docs/ |
| Apache Arrow (Serialização) | https://arrow.apache.org/docs/ |
| Delta Lake (Otimizações) | https://docs.delta.io/latest/optimizations.html |
| Databricks Best Practices | https://www.databricks.com/blog/2023/08/14/best-practices-for-apache-spark.html |
| AWS Athena Partitioning | https://docs.aws.amazon.com/athena/latest/ug/partitioning-data.html |

---

## 🎯 RESUMO: O que Medir com `explain()`

```python
df.explain(extended=True)  # Analise SEMPRE esses pontos:

# 1. Catalyst Optimizer: As regras foram aplicadas?
# 2. Predicate Pushdown: Filtros estão em baixo no plano?
# 3. Join Strategy: Está usando BroadcastHashJoin?
# 4. Partitions: Quantas partições estão sendo lidas?
```