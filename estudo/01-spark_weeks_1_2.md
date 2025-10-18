# Detalhamento Semanas 1-2: Apache Spark (80 horas)
## Especialista em Dados | 20 anos experiência

---

## VISÃO GERAL ESTRATÉGICA

Nestas 2 semanas você vai dominar PySpark para processamento distribuído de dados em escala. O objetivo é sair capaz de **otimizar jobs que processam GB/TB**, identificar gargalos e aplicar as técnicas corretas.

**Divisão de tempo:**
- Dias 1-4 (Semana 1): Fundamentos sólidos
- Dias 5-10 (Semana 1-2): Projeto prático intensivo

---

## SEMANA 1: FUNDAMENTOS

### DIAS 1-2: FUNDAMENTOS SPARK (16h total)

#### Dia 1 - Manhã (4h): Arquitetura Spark
**O que você PRECISA entender (não é teórico, é prático):**

**Componente 1: Driver (0.5h)**
- É o maestro da orquestra
- Roda seu código Python
- Comunica com Executors via Spark Context
- Em cluster: roda no master node

**Prática imediata:**
```python
from pyspark.sql import SparkSession

# Criando a sessão = criando o Driver
spark = SparkSession.builder \
    .appName("MeuApp") \
    .master("local[4]") \  # [4] = 4 threads locais
    .getOrCreate()

# Validar: Spark UI em localhost:4040
# Você vai VER o Driver funcionando
```

**Componente 2: Executors (0.5h)**
- Workers que processam os dados de verdade
- Cada executor tem cores (threads)
- Rodam tasks em paralelo

**Prática:**
```python
# Vendo executors em ação
spark.conf.get("spark.executor.cores")      # cores por executor
spark.conf.get("spark.executor.memory")     # memória por executor

# Em local[4]: você tem 4 "executors" virtuais
# Em cluster: você provisiona N executors
```

**Componente 3: Partições (1h)**
```python
# CONCEITO CRÍTICO: Partições = unidade de paralelismo
# 1 tarefa processa 1 partição em 1 executor

df = spark.read.csv("dados.csv")
print(f"Partições: {df.rdd.getNumPartitions()}")  # Quantas tem?

# Reparticionando (caro, use com cuidado)
df_reparticionado = df.repartition(8)

# Distribuição de dados entre partições:
df.show()  # Os dados físicos estão espalhados
# Partição 0: linhas 1-1000
# Partição 1: linhas 1001-2000
# ... etc
```

**Componente 4: Tasks (1h)**
```python
# 1 tarefa = 1 partição processada em 1 executor
# Quando você faz uma transformação, Spark cria DAG de tasks

df.count()  # Quantas tasks foram criadas?
# Resposta: 1 task por partição + 1 para aggregar resultado

# Visualizar no Spark UI:
# http://localhost:4040 > Jobs > Stages > Tasks
# Você verá exatamente 8 tasks (se 8 partições)
```

---

#### Dia 1 - Tarde (4h): RDDs vs DataFrames vs Datasets

**Contexto histórico (importante para entrevistas):**

**RDDs (Resilient Distributed Datasets):**
- Abstração baixo nível (2011)
- Você controla tudo, mas é verboso
- Pouca otimização automática

```python
# RDD - você faz transformação por transformação
rdd = spark.sparkContext.textFile("dados.txt")
rdd_numeros = rdd.map(lambda x: int(x))
rdd_pares = rdd_numeros.filter(lambda x: x % 2 == 0)
resultado = rdd_pares.collect()
```

**DataFrames (2015) - VOCÊ VAI USAR ISSO 95% DO TEMPO:**
- Estruturado (tem schema/tipos)
- Otimizador Catalyst faz milagres
- Tipo SQL + programação

```python
# DataFrame - melhor legibilidade e performance automática
df = spark.read.csv("dados.csv", header=True, inferSchema=True)
df_pares = df.filter((col("numero") % 2) == 0)
df_pares.show()
```

**Datasets (tipo híbrido):**
- Segurança de tipo + performance
- Principalmente para Scala/Java
- Em Python: use DataFrames

**Qual usar:**
- **RDDs**: Raramente. Dados não-estruturados ou lógica complexa.
- **DataFrames**: 95% dos casos. Balanceado.
- **Datasets**: Scala/Java projects.

---

#### Dia 2 - Manhã (4h): Lazy Evaluation e DAG

**Conceito revolucionário (2011):**

```python
# NOTHING HAPPENS YET - Spark apenas PLANEJA
df = spark.read.csv("dados.csv")
df_filtrado = df.filter(col("idade") > 18)
df_grupo = df_filtrado.groupBy("cidade").count()

# Neste ponto: zero bytes foram processados
# Spark construiu um PLANO chamado DAG (Directed Acyclic Graph)

# AGORA SIM - executa!
resultado = df_grupo.collect()  # Ação!
# ou
df_grupo.show()  # Ação!
```

**Por que isso é genial:**
1. Spark otimiza TODO o plano antes de executar
2. Remove operações desnecessárias (predicate pushdown)
3. Reordena operações para eficiência
4. Você escreve código simples, Spark otimiza

**Transformações (Lazy - não fazem nada sozinhas):**
```python
.filter()
.select()
.map()
.flatMap()
.groupBy()
.join()
# etc
```

**Ações (disparam execução - forçam Spark a trabalhar):**
```python
.collect()    # Traz para driver (CUIDADO: em produção!)
.show()       # Print
.count()
.take(10)
.write()      # Salva em disco
.foreach()    # Aplica função
```

**Visualizando o DAG:**
```python
df_grupo.explain()  # Mostra plano de execução

# Saída:
# == Physical Plan ==
# *(2) HashAggregate(keys=[city#10], functions=[count(1)])
# +- Exchange hashpartitioning(city#10, 200)
#    +- *(1) HashAggregate(keys=[city#10], functions=[count(1)])
#       +- *(1) Project [city#10]
#          +- *(1) Filter (age#11 > 18)
#             +- *(1) FileScan csv [id#9,age#11,city#10]
```

Lê de baixo para cima: **Filter → Project → HashAggregate → Exchange → HashAggregate**

---

#### Dia 2 - Tarde (4h): Criando DataFrames e Leitura de Dados

**Prática prática prática:**

```python
# Método 1: Arquivo CSV
df_csv = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv("dados.csv")

# Método 2: JSON
df_json = spark.read.json("dados.json")

# Método 3: Parquet (formato binário comprimido - MELHOR)
df_parquet = spark.read.parquet("dados.parquet")

# Método 4: Banco de dados
df_db = spark.read \
    .format("jdbc") \
    .option("url", "jdbc:postgresql://localhost/banco") \
    .option("dbtable", "vendas") \
    .option("user", "user") \
    .option("password", "senha") \
    .load()

# Método 5: Criar do zero (útil para testes)
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

schema = StructType([
    StructField("id", IntegerType()),
    StructField("nome", StringType()),
    StructField("idade", IntegerType())
])

dados = [
    (1, "João", 25),
    (2, "Maria", 30),
    (3, "Pedro", 28)
]

df = spark.createDataFrame(dados, schema=schema)
```

**Inspecionando DataFrames:**
```python
df.show()                    # Primeiras 20 linhas
df.show(5)                   # Primeiras 5
df.show(truncate=False)      # Sem cortar texto longo

df.printSchema()             # Schema
df.describe().show()         # Estatísticas
df.count()                   # Total de linhas
df.columns                   # Nomes de colunas
df.dtypes                    # Tipos de dados

df.sample(0.1).show()        # Amostra 10% dos dados
```

---

#### Tarefas Dia 1-2:
1. Criar um DataFrame simples a partir de CSV
2. Explorar o schema e estatísticas
3. Vizualizar o DAG com `.explain()`
4. Tentar diferentes formatos de leitura

**Entregável esperado:**
- 1 notebook com 10 exemplos de leitura + transformações básicas
- Print do DAG explicado

---

### DIAS 3-4: DATAFRAMES E SQL (16h total)

#### Dia 3 - Manhã (4h): DataFrame Operations - O Básico

```python
from pyspark.sql.functions import col, lit, count, avg, max

# Dados de exemplo
df = spark.read.csv("vendas.csv", header=True, inferSchema=True)

# SELECT - equivalente: SELECT coluna1, coluna2 FROM tabela
df.select("produto", "valor").show()
df.select(col("produto"), col("valor")).show()  # Mesmo resultado

# SELECT múltiplas colunas dinamicamente
colunas = ["produto", "valor", "data"]
df.select(colunas).show()

# SELECT com renomear
df.select(
    col("produto").alias("item"),
    col("valor").alias("preco")
).show()

# SELECT com expressões
df.select(
    col("produto"),
    (col("valor") * 1.1).alias("valor_com_desconto")
).show()
```

**FILTER - Essencial:**
```python
# WHERE simples
df.filter(col("valor") > 100).show()

# WHERE com múltiplas condições (AND)
df.filter(
    (col("valor") > 100) & 
    (col("produto") == "notebook")
).show()

# WHERE com OR
df.filter(
    (col("produto") == "mouse") | 
    (col("produto") == "teclado")
).show()

# WHERE com NOT
df.filter(~col("produto").isin(["mouse", "teclado"])).show()

# BETWEEN
df.filter(col("valor").between(100, 500)).show()

# CONTAINS (texto)
df.filter(col("produto").contains("book")).show()
```

**GROUPBY - A mágica acontece aqui:**
```python
# Quantas vendas por produto?
df.groupBy("produto").count().show()
# Spark vai:
# 1. Particionar dados por produto
# 2. Contar em cada partição
# 3. Agregar resultados
# = PARALELISMO AUTOMÁTICO

# Múltiplas agregações
df.groupBy("produto").agg(
    count("id").alias("quantidade"),
    avg("valor").alias("preco_medio"),
    max("valor").alias("preco_maximo")
).show()

# GROUP BY múltiplas colunas
df.groupBy("produto", "regiao").agg(
    count("id").alias("vendas")
).show()

# ORDER BY resultado
df.groupBy("produto").count() \
    .orderBy(col("count").desc()) \
    .show()
```

---

#### Dia 3 - Tarde (4h): JOINs - Operação Crítica de Performance

**Contexto:** JOINs são onde 80% dos problemas de performance acontecem em pipelines reais.

```python
# Dados para exemplo
df_vendas = spark.read.csv("vendas.csv", header=True, inferSchema=True)
df_clientes = spark.read.csv("clientes.csv", header=True, inferSchema=True)

# INNER JOIN (padrão - valores que existem em ambas)
df_merged = df_vendas.join(
    df_clientes,
    on="cliente_id",  # Coluna em comum
    how="inner"
)
df_merged.show()

# LEFT JOIN (todas de vendas + matching de clientes)
df_merged = df_vendas.join(
    df_clientes,
    on="cliente_id",
    how="left"
)

# RIGHT JOIN
df_merged = df_vendas.join(
    df_clientes,
    on="cliente_id",
    how="right"
)

# FULL OUTER JOIN (todas as linhas de ambas)
df_merged = df_vendas.join(
    df_clientes,
    on="cliente_id",
    how="outer"
)

# JOIN em múltiplas colunas
df_merged = df_vendas.join(
    df_clientes,
    on=["cliente_id", "regiao"],
    how="inner"
)

# JOIN com condição customizada
df_merged = df_vendas.join(
    df_clientes,
    df_vendas.cliente_id == df_clientes.id,
    how="inner"
)
```

**BROADCAST JOIN - Otimização crítica (economia de shuffle):**
```python
from pyspark.sql.functions import broadcast

# Se df_clientes é pequeno (< 100MB), broadcast!
df_merged = df_vendas.join(
    broadcast(df_clientes),  # Copia tabela pequena para todos executors
    on="cliente_id"
)

# Performance: 100x mais rápido que shuffle join!
# Spark tira proveito quando detecta tabela pequena

# Verificar se foi broadcast:
df_merged.explain()  # Procure por "BroadcastHashJoin"
```

---

#### Dia 4 - Manhã (4h): Window Functions - SQL Analítico

```python
from pyspark.sql.functions import row_number, rank, dense_rank, lag, lead, sum as spark_sum
from pyspark.sql.window import Window

# Dados: vendas por produto por mês
df = spark.read.csv("vendas.csv", header=True, inferSchema=True)

# ROW_NUMBER: Número sequencial (primeira venda = 1, segunda = 2)
window_spec = Window.partitionBy("produto").orderBy("data")

df.withColumn(
    "numero_venda",
    row_number().over(window_spec)
).select("produto", "data", "numero_venda").show()

# RANK: Ranking com gaps se houver empate
df.withColumn(
    "rank_valor",
    rank().over(
        Window.partitionBy("produto").orderBy(col("valor").desc())
    )
).show()

# DENSE_RANK: Ranking sem gaps
df.withColumn(
    "dense_rank_valor",
    dense_rank().over(
        Window.partitionBy("produto").orderBy(col("valor").desc())
    )
).show()

# LAG: Valor anterior (para calcular variação)
df.withColumn(
    "valor_anterior",
    lag("valor").over(window_spec)
).select("produto", "data", "valor", "valor_anterior").show()

# SUM cumulativo (running sum)
df.withColumn(
    "vendas_acumuladas",
    spark_sum("valor").over(window_spec)
).select("produto", "data", "valor", "vendas_acumuladas").show()

# TOP 3 produtos por valor em cada região
df.withColumn(
    "rank",
    rank().over(
        Window.partitionBy("regiao").orderBy(col("valor").desc())
    )
).filter(col("rank") <= 3).show()
```

---

#### Dia 4 - Tarde (4h): Spark SQL Queries

**Converter DataFrame em tabela SQL e usar SQL puro:**

```python
# Registrar DataFrame como tabela temporária
df_vendas.createOrReplaceTempView("vendas")
df_clientes.createOrReplaceTempView("clientes")

# SQL puro!
resultado = spark.sql("""
    SELECT 
        p.produto,
        COUNT(*) as quantidade,
        AVG(p.valor) as preco_medio,
        MAX(p.valor) as preco_maximo
    FROM vendas p
    WHERE p.valor > 100
    GROUP BY p.produto
    HAVING COUNT(*) > 5
    ORDER BY quantidade DESC
""")

resultado.show()

# JOIN em SQL
spark.sql("""
    SELECT 
        v.id,
        v.produto,
        c.nome,
        v.valor
    FROM vendas v
    INNER JOIN clientes c ON v.cliente_id = c.id
""").show()

# Window functions em SQL
spark.sql("""
    SELECT 
        produto,
        valor,
        RANK() OVER (PARTITION BY categoria ORDER BY valor DESC) as rank_produto
    FROM vendas
""").show()

# Criar tabela permanente (salva em disco)
spark.sql("""
    CREATE TABLE vendas_processadas AS
    SELECT 
        produto,
        COUNT(*) as quantidade
    FROM vendas
    GROUP BY produto
""")
```

**Quando usar SQL vs DataFrame API:**
- SQL: Queries exploratórias, equipe com SQL, lógica complexa
- DataFrame API: Código de produção, reutilização, type safety

---

#### Tarefas Dias 3-4:

**Tarefa 1 (4h):** Arquivo CSV com vendas (mínimo 10k linhas)
```
id, cliente_id, produto, valor, data, regiao
1, 101, notebook, 2500, 2024-01-01, sul
2, 102, mouse, 50, 2024-01-01, norte
...
```

**Sua missão:**
```python
# 1. Ler o CSV
# 2. Calcular: Quantas vendas por produto?
# 3. Calcular: Ticket médio por região?
# 4. Window: Qual é o produto mais vendido de cada região?
# 5. JOIN: Adicionar informações do cliente (nome, email)
# 6. Fazer a mesma query em SQL
```

**Tarefa 2 (4h):** Queries com Window Functions
```python
# Trazer para cada venda: o valor anterior no mesmo produto
# Rank: Top 5 produtos por valor total vendido
# Cumulative: Vendas acumuladas por mês
```

**Entregável:**
- 1 notebook com 15 transformações diferentes
- Cada query com print do resultado
- `.explain()` em 3 queries diferentes

---

### DIA 5 (Semana 1): PERFORMANCE & OTIMIZAÇÃO (8h)

**Agora você já domina Spark. Hora de deixar rápido.**

#### Manhã (4h): Particionamento e Bucketing

```python
# PARTICIONAMENTO (divisão lógica de arquivos em disco)

# Scenario: 10GB de dados de vendas por ano
df = spark.read.parquet("vendas/")

# SEM particionamento: Spark lê TODO o arquivo
# COM particionamento: Spark lê apenas partições relevantes

# Salvando COM particionamento
df.write \
    .partitionBy("ano", "mes") \
    .parquet("vendas_particionadas/")

# Estrutura em disco:
# vendas_particionadas/
# ├── ano=2023/
# │   ├── mes=01/
# │   ├── mes=02/
# ├── ano=2024/
# │   ├── mes=01/

# Agora uma query em 2024:
df_2024 = spark.read.parquet("vendas_particionadas/") \
    .filter((col("ano") == 2024) & (col("mes") == 3))

# Spark IGNORA os 2GB de 2023, lê apenas dados de 2024!
# Predicate pushdown automático

# BUCKETING (ordenação em buckets para JOINs)
# Para quando você faz muitos JOINs na mesma coluna

df_vendas.write \
    .bucketBy(10, "cliente_id") \  # 10 buckets, distribuir por cliente_id
    .mode("overwrite") \
    .parquet("vendas_bucketed/")

df_clientes.write \
    .bucketBy(10, "id") \
    .mode("overwrite") \
    .parquet("clientes_bucketed/")

# JOINs depois são MUITO mais rápidos
df_v = spark.read.parquet("vendas_bucketed/")
df_c = spark.read.parquet("clientes_bucketed/")

df_v.join(df_c, df_v.cliente_id == df_c.id).show()
# Spark não faz shuffle aqui! Dados já estão organizados.
```

**Quando particionar:**
- **Sim**: Dados em camadas (tempo), queries sempre filtram por coluna, dados crescem
- **Não**: Dados pequenos (<1GB), sem padrão de filtro

---

#### Tarde (4h): Caching, Broadcast e Predicate Pushdown

```python
# CACHE: Manter DataFrame em memória para reutilização

df = spark.read.csv("grande_arquivo.csv")

# Sem cache: cada ação processa tudo de novo
resultado1 = df.filter(col("valor") > 100).count()
resultado2 = df.filter(col("valor") > 200).count()
# Spark processou arquivo 2x

# Com cache: processa uma vez, reutiliza
df.cache()  # ou df.persist()

resultado1 = df.filter(col("valor") > 100).count()
resultado2 = df.filter(col("valor") > 200).count()
# Spark processou arquivo 1x, cache foi usado na 2ª

# Cache em memória ou disco?
df.cache()                           # Memória (MEMORY_ONLY)
df.persist(StorageLevel.MEMORY_AND_DISK)  # Memória + disco se exceder
df.persist(StorageLevel.DISK_ONLY)  # Disco (para dados gigantes)

# Remover do cache
df.unpersist()

# BROADCAST: Copiar DataFrame pequeno para todos executors

from pyspark.sql.functions import broadcast

df_grande = spark.read.csv("10gb_vendas.csv")
df_pequeno = spark.read.csv("1mb_categorias.csv")

# SEM broadcast: shuffle (caro)
resultado1 = df_grande.join(df_pequeno, "categoria")

# COM broadcast: cópia para cada executor (barato)
resultado2 = df_grande.join(broadcast(df_pequeno), "categoria")

# Verify com explain()
resultado2.explain()  # Procure por "BroadcastHashJoin"

# PREDICATE PUSHDOWN: Deixe Spark otimizar

# ❌ Subótimo: Spark lê arquivo inteiro
df.filter(col("valor") > 100).select("produto").show()

# ✅ Ótimo: Spark filtra enquanto lê (em DB/Parquet)
df.filter(col("valor") > 100).select("produto").show()

# Como ver?
df.filter(col("valor") > 100).explain()
# Procure por "PushDown" - Spark fez a otimização!
```

---

#### Tarefas Dia 5:

**Tarefa 1:** Benchmark de Performance
```python
# 1. Pegar um CSV de 100MB+
# 2. Executar uma query SEM otimizações - medir tempo
# 3. Executar a MESMA query COM cache - medir tempo
# 4. Executar COM particionamento - medir tempo
# 5. Executar COM broadcast join - medir tempo

import time

# Sem otimização
start = time.time()
resultado1 = df.filter(...).groupBy(...).count().collect()
print(f"Tempo: {time.time() - start}s")

# Com cache
df.cache()
start = time.time()
resultado2 = df.filter(...).groupBy(...).count().collect()
print(f"Tempo com cache: {time.time() - start}s")
```

**Entregável:**
- Comparação antes/depois de 4 otimizações diferentes
- Print do `explain()` mostrando diferenças
- Relatório com tempos de execução

---

## SEMANA 2: PROJETO SPARK INTERMEDIÁRIO (48h)

**Você tem os fundamentos. Hora de construir algo real.**

### Estrutura do Projeto (40h trabalho direto)

#### Fase 1: EXTRACTION (8h)

**Objetivo:** Ler dados de múltiplas fontes com tratamento de erros

```python
# dados_publicos/etl_pipeline.py

from pyspark.sql import SparkSession
from pyspark.sql.types import *
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

spark = SparkSession.builder \
    .appName("ETL_Pipeline") \
    .config("spark.sql.shuffle.partitions", "200") \
    .getOrCreate()

class DataExtractor:
    """Extrai dados de múltiplas fontes"""
    
    def read_csv(self, path, **options):
        """Ler CSV com tratamento de erro"""
        try:
            df = spark.read.csv(
                path,
                header=True,
                inferSchema=True,
                **options
            )
            logger.info(f"✓ CSV lido: {path} ({df.count()} linhas)")
            return df
        except Exception as e:
            logger.error(f"✗ Erro ao ler CSV: {e}")
            raise
    
    def read_json(self, path):
        """Ler JSON"""
        try:
            df = spark.read.json(path)
            logger.info(f"✓ JSON lido: {path}")
            return df
        except Exception as e:
            logger.error(f"✗ Erro ao ler JSON: {e}")
            raise
    
    def read_parquet(self, path):
        """Ler Parquet (mais eficiente)"""
        try:
            df = spark.read.parquet(path)
            logger.info(f"✓ Parquet lido: {path}")
            return df
        except Exception as e:
            logger.error(f"✗ Erro ao ler Parquet: {e}")
            raise

# Uso:
extractor = DataExtractor()
df_vendas = extractor.read_csv("data/raw/vendas.csv", sep=";")
df_clientes = extractor.read_csv("data/raw/clientes.csv")
df_produtos = extractor.read_json("data/raw/produtos.json")
```

**Tarefa Extraction:**
- Ler 3 arquivos em formatos diferentes
- Validar schemas
- Contar linhas
- Print com estatísticas básicas

---

#### Fase 2: TRANSFORMATION (24h)

**Objetivo:** Limpeza, enriquecimento, agregações complexas

```python
# dados_publicos/transformations.py

from pyspark.sql.functions import *
from pyspark.sql.types import *
from pyspark.sql.window import Window

class DataTransformer:
    """Transformações complexas de dados"""
    
    @staticmethod
    def clean_nulls(df):
        """Remove nulos estrategicamente"""
        # Contar nulos
        null_counts = df.select(
            [count(when(col(c).isNull(), c)).alias(c) for c in df.columns]
        )
        print("Nulos por coluna:")
        null_counts.show()
        
        # Remover linhas onde coluna crítica é nula
        df_clean = df.dropna(subset=["client_id", "amount"])
        logger.info(f"Removidas {df.count() - df_clean.count()} linhas com nulos críticos")
        return df_clean
    
    @staticmethod
    def remove_duplicates(df, subset=None):
        """Remove duplicatas"""
        before = df.count()
        df_unique = df.dropDuplicates(subset=subset)
        after = df_unique.count()
        logger.info(f"Removidas {before - after} linhas duplicadas")
        return df_unique
    
    @staticmethod
    def feature_engineering(df):
        """Cria novas features"""
        df = df.withColumn(
            "amount_category",
            case()
                .when(col("amount") < 100, "baixo")
                .when(col("amount") < 500, "medio")
                .otherwise("alto")
                .end()
        )
        
        # Valor por cliente (para análise de padrão de gasto)
        window_spec = Window.partitionBy("client_id")
        df = df.withColumn(
            "client_total_spend",
            sum(col("amount")).over(window_spec)
        )
        
        # Número de compras do cliente
        df = df.withColumn(
            "client_purchase_count",
            count("*").over(window_spec)
        )
        
        # Data em formato legível
        df = df.withColumn(
            "transaction_date",
            to_date(col("timestamp"))
        )
        
        logger.info("✓ Features criadas")
        return df
    
    @staticmethod
    def aggregate_by_product(df):
        """Agregações por produto"""
        agg_df = df.groupBy("product_id") \
            .agg(
                count("*").alias("total_vendas"),
                sum("amount").alias("revenue_total"),
                avg("amount").alias("ticket_medio"),
                max("amount").alias("maior_venda"),
                min("amount").alias("menor_venda"),
                count(distinct("client_id")).alias("clientes_unicos")
            ) \
            .orderBy(col("revenue_total").desc())
        
        return agg_df
    
    @staticmethod
    def rank_top_products(df, top_n=10):
        """Top 10 produtos por revenue"""
        window_spec = Window.orderBy(col("revenue_total").desc())
        
        ranked = df.withColumn(
            "rank",
            rank().over(window_spec)
        ).filter(col("rank") <= top_n)
        
        return ranked

# Uso:
transformer = DataTransformer()

# Sequência de transformações
df = transformer.clean_nulls(df_vendas)
df = transformer.remove_duplicates(df, subset=["transaction_id"])
df = transformer.feature_engineering(df)

# Agregações
df_por_produto = transformer.aggregate_by_product(df)
df_top_produtos = transformer.rank_top_products(df_por_produto, top_n=10)

df_top_produtos.show()
```

**Tarefas Transformation (24h distribuído):**

**8h - Limpeza:**
- Remover nulos estrategicamente
- Eliminar duplicatas
- Validar tipos de dados
- Remover outliers se necessário

**8h - Feature Engineering:**
- Criar coluna categórica (baixo/médio/alto)
- Calcular agregações por cliente
- Window functions para ranking
- Transformações de data

**8h - Agregações Complexas:**
- Total vendido por produto (rank)
- Ticket médio por categoria
- Clientes que mais gastam
- Produtos top 10 por diferentes métricas

---

#### Fase 3: LOADING (8h)

```python
# dados_publicos/load.py

class DataLoader:
    """Escreve dados processados em disco"""
    
    @staticmethod
    def to_parquet_partitioned(df, path, partition_cols=None):
        """Salva em Parquet particionado (MELHOR PERFORMANCE)"""
        if partition_cols:
            df.write \
                .partitionBy(partition_cols) \
                .mode("overwrite") \
                .parquet(path)
        else:
            df.write.mode("overwrite").parquet(path)
        
        logger.info(f"✓ Dados salvos em Parquet: {path}")
    
    @staticmethod
    def to_csv(df, path):
        """Salva em CSV (menos eficiente, mas legível)"""
        df.coalesce(1).write \
            .mode("overwrite") \
            .csv(path, header=True)
        logger.info(f"✓ Dados salvos em CSV: {path}")
    
    @staticmethod
    def validate_integrity(df_original, df_loaded):
        """Valida se dados foram salvos/carregados corretamente"""
        assert df_original.count() == df_loaded.count(), "Contagem diferente!"
        assert set(df_original.columns) == set(df_loaded.columns), "Colunas diferentes!"
        logger.info("✓ Validação de integridade passou")

# Uso:
loader = DataLoader()

# Salvar transformados
loader.to_parquet_partitioned(
    df_transformed,
    "data/processed/vendas",
    partition_cols=["ano", "mes"]
)

# Salvar agregados
loader.to_parquet_partitioned(
    df_top_produtos,
    "data/output/top_produtos"
)

# Salvar em CSV para análise rápida
loader.to_csv(df_top_produtos, "data/output/top_produtos.csv")
```

**Tarefa Loading:**
- Salvar DataFrame transformado em Parquet (particionado)
- Salvar agregados em CSV
- Validar integridade dos dados salvos
- Verificar tamanho dos arquivos

---

#### Fase 4: DOCUMENTAÇÃO (8h)

```python
# README.md

# ETL Pipeline - Dados Públicos

## Arquitetura

```
Raw Data (CSV/JSON)
    ↓
Extraction (leitura, validação)
    ↓
Transformation (limpeza, features)
    ↓
Loading (Parquet particionado)
    ↓
Output (CSV para análise)
```

## Como Rodar

```bash
# Instalar dependências
pip install pyspark pandas

# Rodar pipeline completo
python main.py

# Tempo de execução esperado: ~2 minutos
# Dados processados: ~500MB
```

## Transformações Implementadas

1. **Limpeza de Dados**
   - Remoção de 2.5% de linhas com nulos críticos
   - Eliminação de 1.2% de duplicatas
   - Validação de schemas

2. **Feature Engineering**
   - Categorização de valores (baixo/médio/alto)
   - Agregações por cliente (total_spend, purchase_count)
   - Transformações de data

3. **Agregações Principais**
   - Ranking de produtos por revenue
   - Ticket médio por categoria
   - Top 10 clientes por gasto

## Resultados

- **Total de transações**: 1.2M
- **Clientes únicos**: 45k
- **Produtos**: 1.2k
- **Valor total processado**: R$ 45M

## Commits GitHub

```
commit 1: setup - estrutura inicial
commit 2: extraction - readers para múltiplos formatos
commit 3: transformation - limpeza e features
commit 4: loading - salvamento em Parquet
commit 5: docs - readme e diagrama
```

## Commits no GitHub (IMPORTANTE)

```bash
git add .
git commit -m "feat: extraction - readers CSV/JSON/Parquet"

git add transformations.py
git commit -m "feat: transformation - limpeza e feature engineering"

git add load.py
git commit -m "feat: loading - salvamento em Parquet particionado"

git add main.py
git commit -m "feat: pipeline - orquestração completa"

git add README.md
git commit -m "docs: documentação do pipeline"
```
```

---

### Estrutura Final do Repositório

```
spark-etl-projeto/
├── README.md                 (documentação)
├── main.py                   (entry point)
├── requirements.txt          (pip dependencies)
├── src/
│   ├── __init__.py
│   ├── extractor.py          (leitura de dados)
│   ├── transformer.py        (transformações)
│   └── loader.py             (salvamento)
├── data/
│   ├── raw/                  (dados originais)
│   ├── processed/            (dados transformados)
│   └── output/               (resultado final)
├── notebooks/
│   └── exploratory.ipynb     (análise exploratória)
├── tests/
│   └── test_transformations.py
└── .gitignore
```

---

### Entregável Semana 2:

✅ Repositório GitHub com:
- Código clean e bem comentado
- 5+ commits significativos
- README explicando cada transformação
- Dados de entrada de verdade (Kaggle recomendado)
- Output final em CSV para validar resultado
- Notebooks com exploração dos dados

✅ Performance:
- Execute `df.explain()` em 3 queries principais
- Documente otimizações aplicadas
- Mostre before/after se tiver aplicado cache/particionamento

✅ Testes:
- Mínimo 5 testes unitários
- Validação de integridade dos dados

---

## RESUMO SEMANA 1-2

| Período | O Que Você Aprendeu | Ferramenta |
|---------|-------------------|-----------|
| Dias 1-2 | RDD/DataFrame/Lazy Evaluation | PySpark Core |
| Dias 3-4 | SQL, Joins, Window Functions | SQL + DataFrame API |
| Dia 5 | Cache, Broadcast, Particionamento | Performance |
| Semana 2 | Pipeline ETL Real | Projeto Completo |

**Saindo dessa semana você será capaz de:**
- Ler dados de múltiplas fontes
- Transformar com joins complexos e window functions
- Otimizar queries automaticamente
- Implementar pipeline production-ready
- Identificar gargalos de performance

---

## DICAS DE OURO (20 anos de experiência)

1. **Sempre use Parquet, não CSV** - Economia de 80% em storage e tempo
2. **Cache agressivamente em desenvolvimento** - Mas remova em produção
3. **Particione por tempo (ano/mês)** - 90% dos casos é assim
4. **Broadcast JOINs com tabelas pequenas** - Ganha 100x em performance
5. **Repartition(N) apenas quando necessário** - Operação cara
6. **DataFrame API > RDD** - Use SQL quando possível
7. **Explain() é seu melhor amigo** - Rode antes de commitar
8. **Commits diários no GitHub** - Portfolio importa em entrevista

---

## Próximas Semanas

Terminada essa fase, você entra nas semanas 3-4 (AWS) com fundamento sólido em Spark. O pipeline que você vai construir aqui será orquestrado com Airflow (semana 5) e transformado com Dbt (semana 7).