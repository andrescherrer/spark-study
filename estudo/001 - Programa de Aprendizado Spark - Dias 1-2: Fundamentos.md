# Programa de Aprendizado Spark - Dias 1-2: Fundamentos

Com 20 anos em Engenharia de Dados, este guia desmembra conceitos de forma prática e estruturada.

---

## 📚 PARTE 1: EXPLICAÇÃO TÉCNICA DOS CONCEITOS

### 1. Arquitetura Spark: Driver, Executors, Tasks (2h)

#### O Modelo Mental

Spark funciona como um maestro orquestrando múltiplos músicos. Você não toca, você dirige a orquestra.

#### Driver (Maestro)
- Roda no seu computador ou servidor
- Contém o programa principal (`SparkContext`)
- Planeja a execução em DAG (gráfico acíclico direcionado)
- Coordena e monitora executors
- Coleta resultados

#### Executors (Músicos)
- Processos separados em máquinas do cluster
- Executam tarefas em paralelo
- Cada executor tem cache de memória próprio
- Comunicam resultados ao Driver

#### Tasks (Notas Musicais)
- Unidades mínimas de execução
- Uma tarefa por partição de dados
- Rodam paralelamente em threads do executor

#### Fonte Oficial
- [Spark Architecture - Apache Spark Documentation](https://spark.apache.org/docs/latest/cluster-overview.html)
- Seção: "Cluster Mode Overview"

---

### 2. RDDs vs DataFrames vs Datasets (2h)

#### RDD (Resilient Distributed Dataset) - O Veterano

```python
# RDD: abstração baixo nível, imutável
rdd = sc.textFile("dados.txt") \
    .map(lambda x: x.split(","))
```

- Mais controle, menos otimização
- Use quando: dados desestruturados, transformações customizadas complexas
- Mais lento que DataFrames

#### DataFrame - O Padrão Ouro (95% dos casos)

```python
# DataFrame: estruturado, otimizado
df = spark.read.csv("dados.csv", header=True)
df.filter(df.idade > 25).select("nome", "salario")
```

- Schema definido (colunas, tipos)
- Catálogo otimizado (Catalyst Optimizer)
- 100-1000x mais rápido que RDD
- SQL integrado

#### Dataset - O Tipo-Seguro (Scala/Java)

```scala
// Dataset (Scala): type-safe
val dataset: Dataset[Pessoa] = df.as[Pessoa]
```

- Compilação type-check em Scala/Java
- Python não possui Datasets nativos

#### Comparação Real

| Aspecto | RDD | DataFrame | Dataset |
|---------|-----|-----------|---------|
| Otimização | Manual | Automática (Catalyst) | Automática + Type-safe |
| Performance | Lenta | Rápida | Rápida |
| Schema | Sem estrutura | Com esquema | Tipado |
| Quando usar | Casos especiais | Maioria (ETL) | Sistemas críticos (Scala/Java) |

#### Fonte Oficial
- [RDDs vs DataFrames vs Datasets](https://spark.apache.org/docs/latest/sql-getting-started.html)
- [Spark SQL, DataFrames and Datasets Guide](https://spark.apache.org/docs/latest/sql-programming-guide.html)

---

### 3. Lazy Evaluation e DAG (2h)

#### Lazy Evaluation = A Arte de Adiar o Trabalho

```python
# NADA acontece aqui (transformações são "preguiçosas")
df_filtrado = df.filter(df.salario > 5000)
df_select = df_filtrado.select("nome")
df_group = df_select.groupBy("departamento").count()

# AQUI SIM! Ação dispara a execução
resultado = df_group.collect()  # ← AÇÃO
# ou
df_group.write.parquet("/output")  # ← AÇÃO
```

#### Por que isso importa

A avaliação tardia permite que Spark **otimize o plano de execução inteiro** antes de qualquer dado ser processado. É como escrever um script inteiro antes de executá-lo.

#### DAG (Directed Acyclic Graph)

```
Transformações:           
filter → select → groupBy → collect

       [DAG]
       ┌─────────────────────────────┐
       │  Seu Plano de Execução     │
       │  Otimizado Automaticamente │
       └─────────────────────────────┘
              ↓
       [Catalyst Optimizer]
              ↓
       [Execução Distribuída]
```

#### Ações que "disparam" o DAG
- `collect()` - trazer para memória
- `write.parquet()` - salvar arquivo
- `count()` - contar registros
- `show()` - exibir
- `take(n)` - pegar N linhas

#### Fonte Oficial
- [Lazy Evaluation & DAG - Spark Documentation](https://spark.apache.org/docs/latest/rdd-programming-guide.html#lazy-evaluation)
- [Understanding Apache Spark Internals](https://spark.apache.org/docs/latest/cluster-overview.html)

---

### 4. Criando DataFrames e Leitura de Dados (4h prático)

#### Inicializar Spark (primeiro passo SEMPRE)

```python
from pyspark.sql import SparkSession

# Criar sessão Spark
spark = SparkSession.builder \
    .appName("MeuApp") \
    .master("local[*]") \
    .getOrCreate()
```

#### Formas de Criar DataFrames

```python
# 1️⃣ Ler CSV
df = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv("/caminho/dados.csv")

# 2️⃣ Ler Parquet (formato comprimido - preferido em produção)
df = spark.read.parquet("/caminho/dados.parquet")

# 3️⃣ Ler JSON
df = spark.read.json("/caminho/dados.json")

# 4️⃣ Ler do Banco de Dados
df = spark.read \
    .format("jdbc") \
    .option("url", "jdbc:postgresql://localhost:5432/db") \
    .option("dbtable", "tabela") \
    .option("user", "usuario") \
    .option("password", "senha") \
    .load()

# 5️⃣ Criar from scratch (Python list)
dados = [
    ("Alice", 30, 5000),
    ("Bob", 25, 4000),
    ("Carlos", 35, 6000)
]
schema = ["nome", "idade", "salario"]
df = spark.createDataFrame(dados, schema=schema)
```

#### Inspecionar DataFrame

```python
df.show(5)              # Exibir primeiras 5 linhas
df.printSchema()        # Mostrar estrutura
df.describe().show()    # Estatísticas básicas
df.info()               # (pandas-like)
df.count()              # Total de linhas (AÇÃO - cuidado!)
```

#### Fonte Oficial
- [Reading Data - Spark SQL Guide](https://spark.apache.org/docs/latest/sql-data-sources.html)
- [Creating DataFrames](https://spark.apache.org/docs/latest/sql-getting-started.html)

---

### 5. Transformações Básicas (4h prático)

#### map() - Transformar cada elemento

```python
# RDD (baixo nível)
numeros_rdd = sc.parallelize([1, 2, 3, 4, 5])
quadrados = numeros_rdd.map(lambda x: x ** 2)
# Resultado: [1, 4, 9, 16, 25]

# DataFrame (alto nível - melhor)
from pyspark.sql.functions import col, pow

df = spark.createDataFrame([(1,), (2,), (3,)], schema=["numero"])
df_quadrados = df.withColumn("quadrado", pow(col("numero"), 2))
```

#### filter() - Manter apenas linhas que atendem critério

```python
# RDD
numeros = sc.parallelize([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
pares = numeros.filter(lambda x: x % 2 == 0)
# Resultado: [2, 4, 6, 8, 10]

# DataFrame
df = spark.read.csv("vendas.csv", header=True, inferSchema=True)
df_2024 = df.filter(df.ano == 2024)
df_vendas_altas = df.filter((df.valor > 1000) & (df.status == "concluído"))
```

#### flatMap() - Map + "achatar" resultado

```python
# RDD
frases = sc.parallelize(["olá mundo", "apache spark"])
palavras = frases.flatMap(lambda x: x.split(" "))
# Resultado: ["olá", "mundo", "apache", "spark"]

# Use case real: explodir arrays
df = spark.createDataFrame([
    ("Alice", ["python", "java", "scala"]),
    ("Bob", ["go", "rust"])
], schema=["nome", "skills"])

from pyspark.sql.functions import explode

df_explodido = df.select("nome", explode(col("skills")).alias("skill"))
# Resultado:
# Alice  python
# Alice  java
# Alice  scala
# Bob    go
# Bob    rust
```

#### Fonte Oficial
- [Transformations - Spark RDD Programming Guide](https://spark.apache.org/docs/latest/rdd-programming-guide.html#transformations)
- [DataFrame API Reference](https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/api/pyspark.sql.DataFrame.html)

---

## 🎯 TAREFA PRÁTICA - DIAS 1-2

Arquivo CSV de 100MB com: `id, nome, departamento, salario, data_contratacao, ativo`

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, year

spark = SparkSession.builder \
    .appName("TarefaDias1-2") \
    .master("local[*]") \
    .config("spark.driver.memory", "4g") \
    .config("spark.executor.memory", "4g") \
    .getOrCreate()

# 1️⃣ LER CSV
df = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv("dados_100mb.csv")

print("Total de registros:", df.count())
df.printSchema()

# 2️⃣ TRANSFORMAÇÃO 1: FILTER (colaboradores ativos com salário > 5000)
df_filtrado = df.filter((col("ativo") == True) & (col("salario") > 5000))

# 3️⃣ TRANSFORMAÇÃO 2: SELECT (selecionar apenas colunas relevantes)
df_select = df_filtrado.select("nome", "departamento", "salario")

# 4️⃣ TRANSFORMAÇÃO 3: GROUPBY (agregação por departamento)
resultado = df_select \
    .groupBy("departamento") \
    .agg({
        "salario": "avg",
        "nome": "count"
    }) \
    .withColumnRenamed("avg(salario)", "salario_medio") \
    .withColumnRenamed("count(nome)", "total_colaboradores")

# ✅ AÇÃO: Salvar resultado
resultado.write.mode("overwrite").csv("/output/resultado")
resultado.show()
```

**Tempo esperado:** 15-30 segundos em máquina com 4 cores (dependendo do I/O)

---

## 🌍 PARTE 2: EXEMPLOS REAIS DE ENGENHARIA DE DADOS

Casos que você encontrará em produção:

### Caso 1: Pipeline ETL em E-commerce

**Contexto Real:** Empresa processa 500GB de logs diários de vendas

```python
from pyspark.sql.functions import col, when, sum, count, avg, date_format
from datetime import datetime, timedelta

# EXTRACT: Ler dados brutos de múltiplas fontes
vendas = spark.read.parquet("s3://bucket/vendas/2024-10-19/")
clientes = spark.read.jdbc("postgresql://db:5432", "clientes")
produtos = spark.read.json("s3://bucket/produtos/")

# TRANSFORM: Limpeza e enriquecimento
vendas_limpo = vendas \
    .filter(col("valor") > 0) \
    .dropna(subset=["cliente_id", "produto_id"]) \
    .join(clientes, on="cliente_id") \
    .join(produtos, on="produto_id")

# Criar métricas
metricas_diarias = vendas_limpo \
    .groupBy(
        date_format(col("timestamp"), "yyyy-MM-dd").alias("data"),
        col("categoria")
    ) \
    .agg(
        sum("valor").alias("receita_total"),
        count("*").alias("num_transacoes"),
        avg("valor").alias("ticket_medio")
    ) \
    .filter(col("receita_total") > 1000)

# LOAD: Salvar em formato otimizado
metricas_diarias \
    .repartition(10) \
    .write \
    .mode("overwrite") \
    .partitionBy("data") \
    .parquet("s3://bucket/metricas/vendas/")

# Também carregar em Data Warehouse
metricas_diarias.write \
    .format("jdbc") \
    .mode("append") \
    .option("url", "jdbc:postgresql://warehouse:5432/analytics") \
    .option("dbtable", "vendas_diarias") \
    .save()
```

**Por que Spark aqui?**
- 500GB de dados não cabe em memória de 1 servidor
- Spark distribui em cluster, reduz 8 horas para 15 minutos

---

### Caso 2: Data Lake com Histórico (SCD - Slowly Changing Dimensions)

**Contexto:** Rastrear mudanças de clientes ao longo do tempo

```python
from pyspark.sql.functions import col, lit, current_timestamp, max, row_number
from pyspark.sql.window import Window

# Novo dados chegando
novos_clientes = spark.read.csv("clientes_novo.csv", header=True)

# Clientes históricos (já em produção)
clientes_hist = spark.read.parquet("s3://data-lake/clientes/hist/")

# Merge (SCD Type 2: manter histórico com datas)
novos_com_flag = novos_clientes \
    .withColumn("data_inicio", current_timestamp()) \
    .withColumn("data_fim", lit(None)) \
    .withColumn("versao", lit(1))

# Identificar mudanças
clientes_expirados = clientes_hist \
    .join(
        novos_com_flag,
        on=["cliente_id"],
        how="inner"
    ) \
    .filter(col("status") != col("status_novo")) \
    .select(
        col("cliente_id"),
        col("data_inicio"),
        current_timestamp().alias("data_fim")
    )

# Combinar histórico com novo
clientes_consolidado = clientes_hist \
    .filter(~col("cliente_id").isin(clientes_expirados.select("cliente_id"))) \
    .union(novos_com_flag) \
    .union(clientes_expirados)

clientes_consolidado \
    .write \
    .mode("overwrite") \
    .parquet("s3://data-lake/clientes/hist/")
```

**Vantagem:** Auditoria completa - sabe exatamente quando cada mudança ocorreu

---

### Caso 3: Detecção de Fraude em Tempo Real (Streaming)

**Contexto:** Processa transações de cartão de crédito em tempo real

```python
from pyspark.sql.functions import col, window, count, stddev

# Ler stream de Kafka
df_stream = spark \
    .readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("subscribe", "transacoes") \
    .load()

# Parse JSON
from pyspark.sql.types import StructType, StructField, StringType, DoubleType

schema = StructType([
    StructField("usuario_id", StringType()),
    StructField("valor", DoubleType()),
    StructField("timestamp", StringType()),
    StructField("pais", StringType())
])

transacoes = df_stream \
    .select(from_json(col("value").cast("string"), schema).alias("dados")) \
    .select("dados.*")

# Detectar anomalias: 3+ transações em países diferentes em 5 min
anomalias = transacoes \
    .groupBy(
        col("usuario_id"),
        window(col("timestamp"), "5 minutes")
    ) \
    .agg(
        count(col("pais").cast("string")).alias("paises_unicos"),
        count("*").alias("num_transacoes")
    ) \
    .filter(col("paises_unicos") >= 2)  # Fraude provável

# Salvar alertas
query = anomalias \
    .writeStream \
    .format("console") \
    .outputMode("append") \
    .start()

query.awaitTermination()
```

**Por que Spark Streaming?**
- Processa milhões de transações/segundo
- Latência < 5 segundos
- Escalável horizontalmente

---

### Caso 4: Machine Learning - Feature Engineering

**Contexto:** Preparar dados para modelo preditivo de churn

```python
from pyspark.sql.functions import col, avg, max, min, datediff, current_date
from pyspark.ml import Pipeline
from pyspark.ml.feature import StandardScaler, VectorAssembler

# 1️⃣ Ler dados brutos
df = spark.read.parquet("s3://data/usuarios/")

# 2️⃣ Feature Engineering
features = df \
    .groupBy("usuario_id") \
    .agg(
        avg("valor_gasto").alias("gastos_medio"),
        max("valor_gasto").alias("gastos_maximo"),
        datediff(current_date(), max("ultima_compra")).alias("dias_inatividade"),
        count("*").alias("num_transacoes")
    ) \
    .filter(col("num_transacoes") > 5)

# 3️⃣ Normalizar features
vector_assembler = VectorAssembler(
    inputCols=["gastos_medio", "gastos_maximo", "dias_inatividade", "num_transacoes"],
    outputCol="features"
)

scaler = StandardScaler(
    inputCol="features",
    outputCol="features_normalizadas"
)

pipeline = Pipeline(stages=[vector_assembler, scaler])
df_processado = pipeline.fit(features).transform(features)

# 4️⃣ Salvar para modelo
df_processado.write.parquet("s3://data/features_ml/")
```

**Ganho:** De 10 horas manuais em Pandas para 2 minutos em Spark (10 milhões de usuários)

---

## 📊 RESUMO DE FONTES POR TÓPICO

| Tópico | Documentação Oficial | Profundidade |
|--------|----------------------|--------------|
| **Arquitetura** | [cluster-overview.html](https://spark.apache.org/docs/latest/cluster-overview.html) | Fundamental |
| **RDD vs DF** | [sql-programming-guide.html](https://spark.apache.org/docs/latest/sql-programming-guide.html) | Intermediário |
| **DAG & Lazy** | [rdd-programming-guide.html](https://spark.apache.org/docs/latest/rdd-programming-guide.html#lazy-evaluation) | Avançado |
| **Data Sources** | [sql-data-sources.html](https://spark.apache.org/docs/latest/sql-data-sources.html) | Prático |
| **API Python** | [pyspark.sql Reference](https://spark.apache.org/docs/latest/api/python/) | Reference |
| **Performance** | [tuning.html](https://spark.apache.org/docs/latest/tuning.html) | Avançado |

---

## ✅ Próximos Passos Recomendados

1. **Execute a tarefa prática** (CSV 100MB) hoje
2. **Estude DAG Visualization** - use `spark.sql.explain("extended")`
3. **Experimente com dados reais** - use datasets públicos (Kaggle, DataHub)
4. **Configure seu ambiente local** com Docker/conda