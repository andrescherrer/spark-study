# Guia Completo: Fundamentos Apache Spark - Perspectiva de 20 Anos

Vou estruturar isso de forma que você realmente compreenda o **por quê** de cada conceito, não apenas o **como**.

---

## PARTE 1: OS FUNDAMENTOS EXPLICADOS

### 1. Arquitetura Spark: Driver, Executors e Tasks

Imagine o Spark como um **maestro orquestrando músicos**:

**Driver** = Maestro
- Roda seu código
- Cria o plano de execução (DAG)
- Coordena tudo
- Gerencia o estado da aplicação

**Executors** = Músicos
- Máquinas escravas que processam dados
- Cada uma tem CPUs e memória dedicada
- Executam as tarefas em paralelo

**Tasks** = Notas musicais
- Unidade mínima de trabalho
- Uma tarefa = um pedaço de dados + uma operação
- Executadas em paralelo nos executors

```
┌─────────────────────────────────────────┐
│           DRIVER NODE                    │
│   (Seu Script Python/Scala/Java)         │
│   - Planeja execução                     │
│   - Coordena executors                   │
└──────────────────┬──────────────────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
    ┌───▼──┐  ┌───▼──┐  ┌───▼──┐
    │Exec 1│  │Exec 2│  │Exec 3│
    │Tasks │  │Tasks │  │Tasks │
    └──────┘  └──────┘  └──────┘
```

**Documentação oficial:**
- https://spark.apache.org/docs/latest/cluster-overview.html

---

### 2. RDDs vs DataFrames vs Datasets

Saindo de 20 anos de experiência: **use DataFrames quando possível**. Eis por quê:

| Aspecto | RDD | DataFrame | Dataset |
|--------|-----|-----------|---------|
| **Abstração** | Low-level (como arrays) | High-level (como SQL) | Type-safe DataFrame |
| **Performance** | Mais lenta | ~100x mais rápida* | Tão rápida quanto DataFrame |
| **Linguagem** | PySpark, Scala, Java | Todas | Scala, Java |
| **Otimização** | Manual | Automática (Catalyst) | Automática + Type-safe |
| **Uso** | Dados não-estruturados | 80% dos casos | Scala em produção |

*Por quê a diferença de performance? O **Catalyst Optimizer** (engine do Spark) consegue otimizar queries estruturadas, mas não consegue otimizar lógica arbitrária em RDDs.

**Documentação oficial:**
- https://spark.apache.org/docs/latest/rdd-programming-guide.html
- https://spark.apache.org/docs/latest/sql-programming-guide.html

---

### 3. Lazy Evaluation e DAG (Directed Acyclic Graph)

Este é o **segredo do Spark**. Diferente do Pandas que executa imediatamente:

```python
# Lazy evaluation em ação
df = spark.read.csv("dados.csv")  # ← Nada executa aqui
df = df.filter(df.idade > 25)     # ← Ainda nada
df = df.select("nome", "salario") # ← Ainda nada
resultado = df.collect()          # ← AGORA executa tudo!
```

O Spark **constrói um plano** e depois executa de uma vez. Por quê?

1. **Otimização global**: Spark vê toda a cadeia e otimiza tudo junto
2. **Menos shuffles**: Agrupa operações para reduzir movimento de dados
3. **Menos memória**: Não precisa manter dados intermediários

O DAG é esse plano visual. Exemplo:

```
        Read CSV
           │
        Filter (idade > 25)
           │
        Select (nome, salario)
           │
        GroupBy (departamento)
           │
        Aggregate (AVG salary)
```

**Documentação:**
- https://spark.apache.org/docs/latest/rdd-programming-guide.html#transformations-and-actions

---

### 4. Criando DataFrames (4 maneiras práticas)

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

spark = SparkSession.builder.appName("dados").getOrCreate()

# Método 1: De um arquivo CSV
df = spark.read.option("header", "true").csv("vendas.csv")

# Método 2: De um arquivo Parquet (mais eficiente!)
df = spark.read.parquet("dados.parquet")

# Método 3: De dados em memória (Python list)
dados = [("João", 28), ("Maria", 32), ("Pedro", 25)]
schema = StructType([
    StructField("nome", StringType(), True),
    StructField("idade", IntegerType(), True)
])
df = spark.createDataFrame(dados, schema)

# Método 4: De SQL
df = spark.sql("SELECT * FROM tabela_externa")
```

**Documentação:**
- https://spark.apache.org/docs/latest/sql-data-sources.html

---

### 5. Transformações Básicas (Map, Filter, FlatMap)

```python
from pyspark.sql.functions import col, upper, explode

df = spark.read.csv("vendas.csv", header=True)

# FILTER: Apenas linhas que atendem condição
df_filtrado = df.filter((col("valor") > 100) & (col("regiao") == "SP"))

# SELECT (Map em SQL): Escolher colunas e transformá-las
df_transformado = df.select(
    col("id"),
    upper(col("cliente")).alias("cliente_maiuscula"),  # Transforma
    (col("valor") * 0.9).alias("valor_desconto")        # Calcula
)

# FLATMAP: Explode (expande uma coluna)
# Ex: cliente_ids = [1, 2, 3] vira 3 linhas
df_expandido = df.select(
    col("venda_id"),
    explode(col("cliente_ids")).alias("cliente_id")  # Explode é o flatMap do Spark
)

# RDD style (evite, mais lento):
rdd = df.rdd
rdd_transformado = rdd.map(lambda row: (row.nome, row.salario * 1.1))
```

**Documentação:**
- https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/functions.html

---

## PARTE 2: EXEMPLOS DO MUNDO REAL

### Cenário Real 1: Pipeline de ETL em E-commerce

Você trabalha na **Engenharia de Dados de um e-commerce** e precisa processar eventos de click/compra de 100GB/dia.

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp, window, count, sum as spark_sum
from datetime import datetime

spark = SparkSession.builder \
    .appName("ecommerce_etl") \
    .config("spark.sql.shuffle.partitions", "100") \
    .getOrCreate()

# EXTRAÇÃO: Ler dados brutos de S3
df_eventos = spark.read.parquet("s3://data-lake/eventos/2025-01-15/")

print(f"Eventos lidos: {df_eventos.count()}")  # 15 milhões de registros

# TRANSFORMAÇÃO 1: FILTER - Apenas compras com sucesso
df_compras = df_eventos.filter(
    (col("tipo_evento") == "compra") & 
    (col("status") == "sucesso")
)
print(f"Compras válidas: {df_compras.count()}")  # 3 milhões

# TRANSFORMAÇÃO 2: SELECT - Trazer apenas colunas necessárias + calcular comissão
df_processado = df_compras.select(
    col("id_compra"),
    col("id_cliente"),
    col("timestamp"),
    col("valor_total"),
    (col("valor_total") * 0.15).alias("valor_comissao"),  # Comissão 15%
    col("categoria_produto")
)

# TRANSFORMAÇÃO 3: GROUPBY + Agregações - Receita por categoria por hora
df_resumo = df_processado.groupBy(
    window(col("timestamp"), "1 hour"),  # Agrupa por hora
    col("categoria_produto")
).agg(
    count("id_compra").alias("num_compras"),
    spark_sum("valor_total").alias("receita_bruta"),
    spark_sum("valor_comissao").alias("comissao_total")
)

# AÇÃO: Salvar resultado em Parquet (formato eficiente!)
df_resumo.write.mode("overwrite").parquet("s3://data-warehouse/resumo_compras/")

# Também enviar para dashboard real-time
df_resumo.write.mode("overwrite").saveAsTable("vendas_por_hora")

print("✓ Pipeline concluído com sucesso!")
```

**O que aprendemos aqui:**
- Read dados brutos (parquet é 10x mais rápido que CSV)
- 3 transformações sequenciais (filter → select → groupby)
- Lazy evaluation: nada executou até `count()` ou `write()`
- Parquet é formato padrão em Data Lakes (compressão, schema preservation)

---

### Cenário Real 2: Detecção de Fraude em Tempo Real

Você é Engenheiro de Dados num **banco** e detecta fraudes em transações:

```python
from pyspark.sql.functions import col, lag, when, md5, concat_ws
from pyspark.sql.window import Window

# LEITURA: Transações em tempo real (Kafka → Spark)
df_transacoes = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "broker:9092") \
    .option("subscribe", "transacoes") \
    .load()

# Parse JSON
from pyspark.sql.functions import from_json
df_transacoes = df_transacoes.select(
    from_json(col("value").cast("string"), "timestamp STRING, id_cliente STRING, valor DOUBLE, pais STRING")
    .alias("dados")
).select("dados.*")

# TRANSFORMAÇÃO: Detectar transações suspeitas
# Regra 1: Múltiplas transações no mesmo país em < 5 minutos (viagem impossível)
# Regra 2: Valor anormalmente alto para cliente

# Criar janela para detectar múltiplas transações
window_spec = Window.partitionBy("id_cliente").orderBy("timestamp").rangeBetween(-300, 0)

df_fraude = df_transacoes.select(
    col("*"),
    count("*").over(window_spec).alias("transacoes_5min"),
    # Flag se mudar de país em tempo impossível
    when(
        (col("pais") != lag("pais").over(window_spec)) &
        (col("transacoes_5min") > 1),
        1
    ).otherwise(0).alias("suspeita_viagem"),
    # Flag se valor > 5x a média histórica
    when(
        col("valor") > 5000,
        1
    ).otherwise(0).alias("valor_anormal")
)

# Filtrar apenas transações suspeitas
df_alertas = df_fraude.filter(
    (col("suspeita_viagem") == 1) | (col("valor_anormal") == 1)
)

# AÇÃO: Enviar alertas para tópico Kafka
df_alertas.select(
    to_json(struct("*")).alias("value")
).writeStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "broker:9092") \
    .option("topic", "alertas_fraude") \
    .option("checkpointLocation", "/tmp/checkpoint") \
    .start()
```

**Conceitos importantes aqui:**
- **Window Functions**: Análise temporal (últimas 5 minutos)
- **Streaming**: Spark Structured Streaming processa dados em tempo real
- **FlatMap implícito**: `window()` expande dados para janelas
- DAG em ação: múltiplas transformações otimizadas juntas

---

### Cenário Real 3: Machine Learning Pipeline (Join massivo)

Você prepara dados para **modelo preditivo de churn**:

```python
# Ler 3 datasets gigantes
df_clientes = spark.read.parquet("s3://clientes/")         # 10M registros
df_transacoes = spark.read.parquet("s3://transacoes/")     # 500M registros  
df_interacoes = spark.read.parquet("s3://interacoes/")     # 2B registros

# JOIN 1: Clientes + Transações (N:M relationship)
df_cliente_trans = df_clientes.join(
    df_transacoes,
    on="id_cliente",
    how="left"
).cache()  # ← Cache porque usaremos múltiplas vezes

# AGREGAÇÃO: Resumir comportamento de cada cliente
df_perfil = df_cliente_trans.groupBy("id_cliente").agg(
    count("id_transacao").alias("num_transacoes"),
    avg("valor").alias("ticket_medio"),
    max("data_transacao").alias("ultima_compra")
)

# JOIN 2: Adicionar interações (emails, chats, etc)
df_features = df_perfil.join(
    df_interacoes.groupBy("id_cliente").agg(count("*").alias("num_interacoes")),
    on="id_cliente",
    how="left"
)

# FILTER + SELECT: Apenas clientes para treinar modelo
df_ml = df_features.filter(
    col("num_transacoes") > 5  # Clientes com histórico
).select(
    col("id_cliente"),
    col("num_transacoes"),
    col("ticket_medio"),
    col("num_interacoes"),
    col("churn").alias("label")  # Target variable
).na.fill(0)  # Preencher NULLs com 0

# Salvar para treinar modelo ML
df_ml.write.parquet("s3://ml_datasets/churn_features/")
```

**Por que isso é otimizado:**
- **Broadcast join**: Se um dataset cabe em memória, Spark transmite para todos executors
- **Predicate pushdown**: Filters são aplicados antes de joins (mais cedo = menos dados)
- **Cache**: Reusa dados em memória para múltiplas operações
- DAG otimiza tudo automaticamente!

---

## DOCUMENTAÇÃO ESSENCIAL PARA CONSULTA

| Tópico | Link |
|--------|------|
| **Guia Arquitetura** | https://spark.apache.org/docs/latest/cluster-overview.html |
| **API DataFrames** | https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql.html |
| **Funções SQL** | https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/functions.html |
| **Performance Tuning** | https://spark.apache.org/docs/latest/tuning.html |
| **Streaming** | https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html |

---

## TAREFA PRÁTICA PARA SEU PRIMEIRO DIA

```python
# Arquivo de teste: criar dados de vendas
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, count

spark = SparkSession.builder.appName("primeiro_spark").getOrCreate()

# 1. LER CSV de 100MB
df = spark.read.option("header", "true").option("inferSchema", "true").csv("vendas.csv")

# 2. TRANSFORMAÇÃO 1: FILTER
df = df.filter(col("valor") > 1000)

# 3. TRANSFORMAÇÃO 2: SELECT (com cálculo)
df = df.select(
    col("cliente"),
    col("produto"),
    (col("valor") * 1.1).alias("valor_com_imposto")
)

# 4. TRANSFORMAÇÃO 3: GROUPBY
resultado = df.groupBy("produto").agg(
    count("cliente").alias("num_vendas"),
    spark_sum("valor_com_imposto").alias("receita_total")
)

# 5. Ver resultado
resultado.show(100)

# 6. Salvar em Parquet
resultado.write.mode("overwrite").parquet("resultado.parquet")
```

---

**Você tem dúvidas sobre algum conceito específico? Posso aprofundar em Window Functions, Shuffle optimization, ou algum cenário real específico.**