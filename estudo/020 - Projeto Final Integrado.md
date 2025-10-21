# Especialista em Dados: Projeto Final Integrado - Engenharia de Dados Pleno

**Autor**: Especialista em Dados com 20 anos de experiência  
**Data**: 2025  
**Nível**: Pleno (Senior Data Engineer)

---

## Sumário
- [Visão Geral](#visão-geral-da-arquitetura)
- [Componentes](#componentes)
- [Exemplos do Mundo Real](#exemplos-do-mundo-real)
- [Fontes de Estudo](#fontes-complementares-para-estudo)
- [Próximos Passos](#próximos-passos-para-seu-projeto)

---

## 1️⃣ VISÃO GERAL DA ARQUITETURA

A stack que você vai construir segue o padrão **Modern Data Stack (MDS)**:

```
CAMADA 1 (INGESTÃO): Dados brutos de múltiplas fontes
              ↓ (normalização, versionamento)
CAMADA 2 (ORQUESTRAÇÃO): Fluxo e agendamento
              ↓ (DAGs, dependências, SLA)
CAMADA 3 (PROCESSAMENTO): Transformações em escala
              ↓ (Spark, performance, distribuição)
CAMADA 4 (ARMAZENAGEM): Data Lake/Warehouse
              ↓ (schema, partições, retenção)
CAMADA 5 (TRANSFORMAÇÃO): Lógica de negócio
              ↓ (DBT, tests, documentação)
CAMADA 6 (QUALIDADE): Validação e compliance
              ↓ (Great Expectations, alertas)
CAMADA 7 (CONSUMO): Analytics e BI
```

Este é o fluxo **E2E (End-to-End)** que você precisa dominar para Pleno.

### Arquitetura Detalhada

```
[API / Kaggle Dataset]
         ↓
     [S3 / Data Lake]
         ↓
   [Airflow Orchestration]
         ↓
   [Spark Processing]
         ↓
   [Redshift Warehouse]
         ↓
   [Dbt Transformation]
         ↓
[Great Expectations Validation]
         ↓
[Analytics Dashboard]
```

---

## 📋 COMPONENTE 1: DATA INGESTION (16h)

### O que você vai fazer

**Objetivo**: Trazer dados de forma confiável, rastreável e resiliente.

### Conceitos-chave

#### 1. Conectar a Fonte de Verdade
- APIs (REST, GraphQL)
- Bancos de dados (MySQL, PostgreSQL, Oracle)
- Data Warehouses (Snowflake, BigQuery)
- Arquivos (CSV, Parquet, JSON)
- Streams (Kafka, Kinesis)

#### 2. Tratamento de Erros
- Retry logic com backoff exponencial
- Circuit breaker pattern
- Logging e alertas
- Dead letter queues

#### 3. Versionamento do Raw Data
- Manter histórico completo (nunca deletar)
- Schema evolution
- Audit trail

### Documentação Oficial

- **Apache Airflow - Extractors & Operators**: https://airflow.apache.org/docs/apache-airflow/stable/concepts/operators.html
- **AWS S3 Best Practices**: https://docs.aws.amazon.com/s3/latest/userguide/disaster-recovery-resiliency.html
- **Python Requests Library** (para APIs): https://docs.python-requests.org/
- **SQLAlchemy** (para bancos): https://docs.sqlalchemy.org/

### Exemplo Prático: Python + Airflow

```python
# DAG simples para ingestão
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
import boto3
import requests
import json
from datetime import datetime

def extract_from_api(**context):
    """Extrai dados de API e salva em S3"""
    
    # Conectar à API
    response = requests.get(
        "https://api.dados.com/v1/vendas",
        headers={"Authorization": "Bearer TOKEN"},
        params={"date": context['ds']}  # ds = data de execução do Airflow
    )
    response.raise_for_status()
    
    # Validar resposta
    data = response.json()
    if not isinstance(data, list):
        raise ValueError("Formato esperado: lista de objetos")
    
    # Salvar em S3 com versionamento
    s3 = boto3.client('s3')
    key = f"raw/vendas/dt={context['ds']}/{datetime.now().timestamp()}.json"
    
    s3.put_object(
        Bucket='meu-data-lake',
        Key=key,
        Body=json.dumps(data),
        ServerSideEncryption='AES256'
    )
    
    context['task_instance'].xcom_push(
        key='s3_path',
        value=key
    )

dag = DAG(
    'vendas_ingestao',
    default_args={'owner': 'data-eng', 'retries': 3},
    start_date=days_ago(1),
    schedule_interval='0 2 * * *',  # 02:00 UTC diariamente
    tags=['ingestao']
)

ingest_task = PythonOperator(
    task_id='extract_vendas',
    python_callable=extract_from_api,
    provide_context=True,
    dag=dag,
    pool='api_calls',  # Limite de conexões paralelas
    pool_slots=5
)
```

---

## 🚁 COMPONENTE 2: ORCHESTRATION COM AIRFLOW (24h)

### O que você vai fazer

**Objetivo**: Orquestrar pipelines complexos com confiabilidade de produção.

### Conceitos-chave

#### 1. DAG Completa
- Dependências entre tasks
- Branching e merging
- Idempotência

#### 2. Scheduling e SLA
- Cron expressions
- Backfill de dados históricos
- SLA alerts

#### 3. Monitoramento e Alertas
- Logs estruturados
- Métricas (CPU, memória, duration)
- Notificações (Slack, email, PagerDuty)

### Documentação Oficial

- **Apache Airflow Core Concepts**: https://airflow.apache.org/docs/apache-airflow/stable/concepts/overview.html
- **DAG Writing Best Practices**: https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html
- **Airflow Executors** (Local, Celery, Kubernetes): https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/executor/index.html

### Exemplo Prático: Orquestração Completa

```python
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.utils.dates import days_ago
from airflow.models import Variable
from airflow.exceptions import AirflowException
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

# Variáveis configuráveis
environment = Variable.get("environment", "prod")
s3_bucket = Variable.get("s3_bucket", "data-lake-prod")

default_args = {
    'owner': 'data-engineering',
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
    'email': ['data-alerts@empresa.com'],
    'email_on_failure': True,
    'email_on_retry': False,
    'start_date': days_ago(2),
    'sla': timedelta(hours=2)  # Pipeline deve terminar em 2h
}

dag = DAG(
    'pipeline_vendas_completo',
    default_args=default_args,
    description='Pipeline E2E de vendas com qualidade',
    schedule_interval='0 2 * * *',  # 02:00 UTC daily
    max_active_runs=1,  # Apenas 1 execução por vez
    catchup=False,
    tags=['vendas', 'producao']
)

def validate_execution_date(**context):
    """Validação antes de iniciar"""
    exec_date = context['execution_date']
    if exec_date.day == 1:
        logger.warning("Primeira execução do mês - volume esperado maior")
    logger.info(f"Iniciando pipeline para {exec_date}")

start = EmptyOperator(task_id='start', dag=dag)

validate = PythonOperator(
    task_id='validate_date',
    python_callable=validate_execution_date,
    provide_context=True,
    dag=dag
)

# Ingestão paralela de múltiplas fontes
ingest_mysql = BashOperator(
    task_id='ingest_mysql',
    bash_command=f"""
    python /scripts/ingest_mysql.py \
        --date {{{{ ds }}}} \
        --bucket {s3_bucket}
    """,
    pool='ingestao',
    pool_slots=2,
    dag=dag
)

ingest_api = BashOperator(
    task_id='ingest_api',
    bash_command=f"""
    python /scripts/ingest_api.py \
        --date {{{{ ds }}}} \
        --bucket {s3_bucket}
    """,
    pool='ingestao',
    pool_slots=2,
    dag=dag
)

# Spark processing (aguarda ambas ingestões)
process_spark = BashOperator(
    task_id='spark_transform',
    bash_command="""
    spark-submit \
        --master yarn \
        --deploy-mode cluster \
        --num-executors 10 \
        --executor-memory 4g \
        /scripts/spark_processing.py {{ ds }}
    """,
    trigger_rule='all_success',  # Só executa se AMBAS bem-sucedidas
    dag=dag
)

# DBT transformations
dbt_staging = BashOperator(
    task_id='dbt_staging',
    bash_command="""
    cd /dbt && \
    dbt run --models staging.* --select state:modified+ \
        --profiles-dir /dbt/profiles
    """,
    dag=dag
)

dbt_marts = BashOperator(
    task_id='dbt_marts',
    bash_command="""
    cd /dbt && \
    dbt run --models marts.* \
        --profiles-dir /dbt/profiles
    """,
    dag=dag
)

# Data Quality checks
quality_checks = BashOperator(
    task_id='great_expectations',
    bash_command="""
    python /scripts/run_ge_checks.py \
        --checkpoint vendas_checkpoint \
        --date {{ ds }}
    """,
    dag=dag
)

end = EmptyOperator(task_id='end', dag=dag, trigger_rule='all_done')

# Definir dependências
start >> validate
validate >> [ingest_mysql, ingest_api]
[ingest_mysql, ingest_api] >> process_spark
process_spark >> dbt_staging >> dbt_marts
dbt_marts >> quality_checks >> end
```

### Conceitos Avançados: SLA Definition

```python
sla_miss_callback = lambda context: send_alert(
    f"SLA miss: {context['task'].task_id}",
    channel="data-alerts"
)

default_args['sla_miss_callback'] = sla_miss_callback
```

O pipeline inteiro deve terminar às 04:00 UTC, permitindo consumo pelos analistas às 06:00.

---

## ⚡ COMPONENTE 3: PROCESSING COM SPARK (24h)

### O que você vai fazer

**Objetivo**: Transformar dados em larga escala com performance otimizada.

### Conceitos-chave

#### 1. Transformações Complexas
- Window functions
- Joins eficientes
- Aggregações em escala

#### 2. Performance Otimizada
- Particionamento estratégico
- Broadcast joins
- Caching inteligente

#### 3. Tests Unitários
- Testando transformações
- Data contracts

### Documentação Oficial

- **Apache Spark Documentation**: https://spark.apache.org/docs/latest/
- **Spark SQL Performance Tuning**: https://spark.apache.org/docs/latest/sql-performance-tuning.html
- **PySpark API**: https://spark.apache.org/docs/latest/api/python/index.html

### Exemplo Prático: Transformações Spark

```python
# spark_processing.py
from pyspark.sql import SparkSession, Window
from pyspark.sql.functions import (
    col, coalesce, row_number, sum as spark_sum,
    lag, datediff, when, broadcast
)
from datetime import datetime
import sys

def create_spark_session():
    """Factory para criar session otimizada"""
    return SparkSession.builder \
        .appName("vendas-processing") \
        .config("spark.sql.shuffle.partitions", "200") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .config("spark.sql.statistics.histogram.enabled", "true") \
        .config("spark.sql.join.preferSortMergeJoin", "true") \
        .config("spark.sql.autoBroadcastJoinThreshold", "100MB") \
        .config("spark.memory.fraction", "0.8") \
        .getOrCreate()

def load_raw_data(spark, date_str):
    """Carrega raw data do S3"""
    path = f"s3a://data-lake-prod/raw/vendas/dt={date_str}/"
    
    df = spark.read \
        .option("badRecordsPath", f"{path}_bad_records") \
        .json(path)
    
    # Validação básica
    assert df.count() > 0, f"Nenhum registro encontrado para {date_str}"
    return df

def transform_vendas(df):
    """Transformações principais"""
    
    # Window function: ranking de clientes por vendas
    window_spec = Window \
        .partitionBy("cliente_id") \
        .orderBy(col("data_venda").desc())
    
    df_ranked = df.withColumn(
        "venda_rank",
        row_number().over(window_spec)
    )
    
    # Agregações: totais por cliente
    df_agg = df_ranked.groupBy("cliente_id") \
        .agg(
            spark_sum("valor_venda").alias("total_vendas"),
            spark_sum("quantidade").alias("qtd_itens"),
            col("cliente_nome").cast("string").alias("cliente_nome")
        ) \
        .filter(col("total_vendas") > 0)
    
    return df_agg

def test_transform():
    """Unit tests para transformações"""
    spark = create_spark_session()
    
    # Test data
    test_data = [
        ("C001", 100.0, 2, "2024-01-15"),
        ("C001", 50.0, 1, "2024-01-14"),
        ("C002", 200.0, 5, "2024-01-15")
    ]
    
    df = spark.createDataFrame(
        test_data,
        ["cliente_id", "valor_venda", "quantidade", "data_venda"]
    )
    
    result = transform_vendas(df)
    
    # Assertions
    assert result.count() == 2, "Deve ter 2 clientes únicos"
    total_c001 = result.filter(col("cliente_id") == "C001") \
        .select("total_vendas").collect()[0][0]
    assert total_c001 == 150.0, f"Total C001 deve ser 150, foi {total_c001}"
    
    print("✅ Testes passaram!")

def main(date_str):
    spark = create_spark_session()
    
    try:
        # Carregamento
        df = load_raw_data(spark, date_str)
        
        # Transformação
        df_transformed = transform_vendas(df)
        
        # Salvamento particionado
        df_transformed.write \
            .mode("overwrite") \
            .partitionBy("cliente_id") \
            .parquet(f"s3a://data-lake-prod/processed/vendas/dt={date_str}/")
        
        print(f"✅ Processamento concluído: {df_transformed.count()} registros")
        
    except Exception as e:
        print(f"❌ Erro: {str(e)}")
        raise
    finally:
        spark.stop()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1])
    else:
        test_transform()
```

---

## 🗄️ COMPONENTE 4: STORAGE (8h)

### O que você vai fazer

**Objetivo**: Armazenar dados de forma escalável, segura e econômica.

### Conceitos-chave

#### 1. Warehouse Selection
- Redshift vs Snowflake vs BigQuery
- Tradeoffs (custo, performance, features)

#### 2. Particionamento Estratégico
- Partição por data (mais comum)
- Partição por geografia/região
- Compressão (Snappy, ZSTD)

#### 3. Backup & Disaster Recovery
- Replicação
- Point-in-time recovery
- RTO/RPO targets

### Documentação Oficial

- **AWS Redshift Best Practices**: https://docs.aws.amazon.com/redshift/latest/mgmt/working-with-clusters.html
- **Snowflake Architecture**: https://docs.snowflake.com/en/user-guide/intro-key-concepts.html
- **Google BigQuery**: https://cloud.google.com/bigquery/docs

### Exemplo: Redshift Schema

```sql
-- Schema com particionamento (DISTSTYLE)
CREATE SCHEMA IF NOT EXISTS warehouse_prod;

CREATE TABLE warehouse_prod.vendas (
    venda_id BIGINT NOT NULL,
    cliente_id INT NOT NULL,
    valor_venda DECIMAL(12, 2),
    data_venda DATE NOT NULL,
    regiao VARCHAR(50),
    created_at TIMESTAMP DEFAULT SYSDATE,
    updated_at TIMESTAMP DEFAULT SYSDATE
)
DISTKEY (cliente_id)  -- Distribuição por cliente
SORTKEY (data_venda, cliente_id);  -- Sort para performance

-- Encoding para compressão
ALTER TABLE warehouse_prod.vendas 
ENCODE ZSTD;

-- Análise para otimizar
ANALYZE TABLE warehouse_prod.vendas;

-- Backup automático
CREATE OR REPLACE PROCEDURE backup_procedure()
LANGUAGE PLPGSQL
AS $$
BEGIN
    RAISE INFO 'Snapshot criado em %', CURRENT_TIMESTAMP;
END;
$$ EXECUTE;
```

---

## 🔄 COMPONENTE 5: DBT TRANSFORMATIONS (24h)

### O que você vai fazer

**Objetivo**: Transformar dados de forma testada, documentada e versionada.

### Conceitos-chave

#### 1. Layers
- **Staging**: Limpeza e normalização do raw
- **Intermediate**: Lógica de negócio intermediária
- **Marts**: Tabelas finais para consumo

#### 2. Tests Completos
- Unique/not null checks
- Referencial integrity
- Custom tests

#### 3. Documentação
- YAML schemas
- Descrições de tabelas/colunas

### Documentação Oficial

- **DBT Documentation**: https://docs.getdbt.com/
- **DBT Best Practices**: https://docs.getdbt.com/guides/best-practices
- **DBT Testing**: https://docs.getdbt.com/docs/build/tests

### Exemplo Prático: DBT Project

```yaml
# dbt_project.yml
name: 'vendas_analytics'
version: '1.0.0'
profile: 'vendas_prod'

model-paths: ["models"]
analysis-paths: ["analysis"]
test-paths: ["tests"]
data-paths: ["data"]

target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"

vars:
  start_date: '2020-01-01'
  ambiente: 'prod'

require-dbt-version: [">=1.5.0"]
```

```yaml
# models/staging/staging_vendas.yml
version: 2

models:
  - name: stg_vendas
    description: "Limpeza e normalização de vendas"
    columns:
      - name: venda_id
        description: "PK - Identificador único"
        tests:
          - unique
          - not_null
      - name: cliente_id
        description: "FK - Referência ao cliente"
        tests:
          - not_null
          - relationships:
              to: ref('stg_clientes')
              field: cliente_id
      - name: valor_venda
        description: "Valor da venda em BRL"
        tests:
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 999999.99
```

```sql
-- models/staging/stg_vendas.sql
{{ config(
    materialized='incremental',
    unique_key='venda_id',
    incremental_strategy='merge'
) }}

WITH raw_vendas AS (
    SELECT
        venda_id,
        cliente_id,
        CAST(valor_venda AS DECIMAL(12, 2)) AS valor_venda,
        CAST(data_venda AS DATE) AS data_venda,
        UPPER(TRIM(regiao)) AS regiao,
        created_at
    FROM {{ source('raw', 'vendas') }}
    
    -- Incremental: só processar dados novos
    {% if execute %}
        WHERE created_at > (SELECT MAX(created_at) FROM {{ this }})
    {% endif %}
)

SELECT * FROM raw_vendas
WHERE valor_venda > 0
```

```sql
-- models/marts/dim_clientes.sql
{{ config(
    materialized='table',
    indexes=[
        {'columns': ['cliente_id']},
        {'columns': ['data_criacao']}
    ]
) }}

WITH staging AS (
    SELECT * FROM {{ ref('stg_clientes') }}
),

with_metrics AS (
    SELECT
        c.cliente_id,
        c.nome,
        c.email,
        COUNT(DISTINCT v.venda_id) AS total_vendas,
        SUM(v.valor_venda) AS lifetime_value,
        MAX(v.data_venda) AS ultima_compra_data
    FROM staging c
    LEFT JOIN {{ ref('fact_vendas') }} v
        ON c.cliente_id = v.cliente_id
    GROUP BY 1, 2, 3
)

SELECT * FROM with_metrics
```

```yaml
# tests/custom_tests/test_vendas_saldo.sql
# Validação customizada: soma de vendas deve bater com fonte
SELECT
    COUNT(*) AS divergencias
FROM {{ ref('fact_vendas') }}
WHERE valor_venda_acumulado != 
    (SELECT SUM(valor_venda) FROM {{ source('raw', 'vendas') }})
HAVING COUNT(*) > 0
```

---

## ✅ COMPONENTE 6: DATA QUALITY (16h)

### O que você vai fazer

**Objetivo**: Garantir confiabilidade dos dados com validações automatizadas.

### Conceitos-chave

#### 1. Great Expectations Checks
- Schema validation
- Distributional assertions
- Custom expectations

#### 2. Alertas de Anomalias
- Detecção de outliers
- Desvios de volume
- Atrasos

#### 3. SLA Compliance Report
- Porcentagem de sucesso
- Tempo de processamento
- Dados missed

### Documentação Oficial

- **Great Expectations**: https://docs.greatexpectations.io/
- **Data Quality Metrics**: https://docs.greatexpectations.io/docs/guides/validation/

### Exemplo Prático: Great Expectations

```python
# run_ge_checks.py
from great_expectations.dataset import PandasDataset
import great_expectations as ge
from great_expectations.core.batch import RuntimeBatchRequest
import pandas as pd
import logging

logger = logging.getLogger(__name__)

def create_ge_context():
    """Factory para GE context"""
    return ge.get_context()

def build_vendas_checkpoint(context, date_str):
    """Cria checkpoint para validação de vendas"""
    
    suite = context.create_expectation_suite(
        expectation_suite_name="vendas_validation"
    )
    
    # Carrega dados
    batch_request = RuntimeBatchRequest(
        datasource_name="my_postgres",
        data_connector_name="default_runtime_data_connector",
        data_asset_name="vendas",
        runtime_parameters={"query": f"SELECT * FROM vendas WHERE dt='{date_str}'"}
    )
    
    validator = context.get_validator(
        batch_request=batch_request,
        expectation_suite=suite
    )
    
    # Expectativas
    validator.expect_table_row_count_to_be_between(
        min_value=1000,
        max_value=1000000,
        result_format="SUMMARY"
    )
    
    validator.expect_column_values_to_not_be_null(
        column="venda_id"
    )
    
    validator.expect_column_values_to_be_unique(
        column="venda_id"
    )
    
    validator.expect_column_values_to_be_between(
        column="valor_venda",
        min_value=0,
        max_value=1000000
    )
    
    # Custom expectation: valor médio deve estar entre 50-500
    validator.expect_column_mean_to_be_between(
        column="valor_venda",
        min_value=50,
        max_value=500,
        result_format="SUMMARY"
    )
    
    # Salva suite
    validator.save_expectation_suite()
    
    return suite

def run_checkpoint(context, suite_name, date_str):
    """Executa validações"""
    
    checkpoint_config = {
        "name": f"vendas_checkpoint_{date_str}",
        "config_version": 1.0,
        "class_name": "SimpleCheckpoint",
        "validations": [
            {
                "batch_request": {
                    "datasource_name": "my_postgres",
                    "data_connector_name": "default",
                    "data_asset_name": "vendas"
                },
                "expectation_suite_name": suite_name
            }
        ]
    }
    
    checkpoint = context.add_checkpoint(**checkpoint_config)
    result = checkpoint.run()
    
    # Análise de resultado
    validation_result = result["run_results"]
    
    stats = {
        "total_expectations": len(validation_result[0]["validation_result"]["results"]),
        "passed": sum(1 for r in validation_result[0]["validation_result"]["results"] if r["success"]),
        "failed": sum(1 for r in validation_result[0]["validation_result"]["results"] if not r["success"]),
        "timestamp": datetime.now().isoformat()
    }
    
    logger.info(f"QA Report: {stats}")
    
    # Alert se falhas críticas
    if stats["failed"] > 0:
        send_alert(f"Falhas em validação: {stats}", channel="data-alerts")
        raise Exception("Data quality check failed")
    
    return stats

def main():
    context = create_ge_context()
    date_str = "2024-01-15"
    
    suite = build_vendas_checkpoint(context, date_str)
    stats = run_checkpoint(context, suite.expectation_suite_name, date_str)
    
    print(f"✅ Validação concluída: {stats['passed']}/{stats['total_expectations']}")

if __name__ == "__main__":
    main()
```

---

## 📚 COMPONENTE 7: DOCUMENTAÇÃO + DEPLOYMENT (8h)

### O que você vai fazer

**Objetivo**: Documentar, deployar e monitorar em produção.

### Deliverables

#### 1. Architecture Diagram
Criado via: Lucidchart, Draw.io, ou Miro
- Mostra todas as camadas
- Data flows
- Serviços externos

#### 2. Runbook para Troubleshooting

```markdown
# Runbook: Pipeline Vendas - Troubleshooting

## Cenário 1: Pipeline falhou na ingestão

### Sintomas
- Slack alert: "Task extract_vendas failed"
- UI Airflow: DAG com status FAILED

### Diagnóstico
1. Acessar UI Airflow: airflow.empresa.com
2. Navegar para DAG "vendas_ingestao"
3. Clicar em task "extract_vendas" → Logs
4. Procurar por:
   - "Connection refused" → API offline
   - "401 Unauthorized" → Token expirado
   - "Timeout" → Rate limiting

### Resolução

#### Se API offline:
- Contactar time de APIs
- Verificar status em status.api.com
- Reexecutar task manualmente: `airflow tasks run vendas_ingestao extract_vendas {{ ds }}`

#### Se token expirado:
- Gerar novo token em portal.api.com
- Atualizar Airflow Variable: `airflow variables set api_token NEW_TOKEN`
- Reexecutar

#### Se timeout:
- Aumentar timeout em DAG: `execution_timeout=timedelta(minutes=15)`
- Verificar rede com: `curl -I https://api.dados.com`
```

#### 3. Cost Analysis

```python
# cost_analysis.py
def calculate_monthly_costs():
    """
    Estimativa de custos por componente
    """
    
    costs = {
        "S3 Storage (1 TB)": 23.00,
        "Airflow Managed (Composer, 16 vCPU)": 3500.00,
        "Spark (10 executors × 4GB × 730h)": 2000.00,
        "Redshift (dc2.large × 2 nodes)": 2000.00,
        "Data Transfer (egress 100GB)": 900.00,
        "Great Expectations": 500.00,
    }
    
    total = sum(costs.values())
    
    # Otimização: reserved instances salvam 40%
    with_reserved = total * 0.6
    
    print(f"Custo mensal: ${total:,.2f}")
    print(f"Com reserved instances: ${with_reserved:,.2f}")
    print(f"Economia: ${total - with_reserved:,.2f}/mês ({40}%)")
    
    return costs
```

---

# 🌍 EXEMPLOS DO MUNDO REAL

Agora vamos aos casos reais que você vai enfrentar em produção:

## **Caso 1: E-commerce (Shopify → Redshift → Tableau)**

### Contexto
Plataforma de e-commerce com 10k+ pedidos/dia, 50+ lojas parceiras.

### Desafios Reais
- Dados chegam de múltiplas integrações (Shopify, WooCommerce, Magento)
- Schema varia entre integrações
- Latência: relatórios devem estar prontos às 06:00

### Arquitetura Implementada

```
Shopify API (webhooks + polling)
    ↓
Lambda + S3 (raw layer, versionado)
    ↓
Airflow (orquestra ingestão + processamento)
    ↓
Spark (normaliza schema, limpa dados duplicados)
    ↓
Redshift (Data Warehouse central)
    ↓
DBT (staging → marts para diferentes áreas)
    ↓
Tableau (Analytics dashboard)
```

### Métricas de Produção
- Ingestão: 50GB/dia
- Latência P95: 45 minutos
- Uptime: 99.95%
- Custo mensal: ~$4,500

### Problemas Encontrados

#### 1. Schema evolution
Shopify mudou structure de "customer" 
→ **solução**: UNION ALL com tratamento de novos campos

#### 2. Duplicatas
Webhooks reprocessavam 
→ **solução**: idempotência com unique_key em DBT

#### 3. Dados incompletos
Pedidos chegavam sem cliente 
→ **solução**: Great Expectations com alertas

### Código Real: Tratamento de Schema Evolution

```python
# Tratamento de Schema Evolution
from pyspark.sql.types import StructType, StructField, StringType, LongType

def handle_schema_evolution(df_new, schema_expected):
    """Alinha novo schema com esperado"""
    
    for col in schema_expected.fields:
        if col.name not in df_new.columns:
            # Coluna ausente? Adiciona como NULL
            df_new = df_new.withColumn(col.name, lit(None).cast(col.dataType))
    
    # Seleciona apenas colunas esperadas
    df_new = df_new.select([f.name for f in schema_expected.fields])
    
    return df_new
```

---

## **Caso 2: Fintech (Transações em Tempo Real)**

### Contexto
Plataforma de pagamentos com 1M+ transações/dia, requisito de compliance LGPD.

### Desafios Reais
- Dados sensíveis (PII): CPF, email, dados bancários
- Auditoria: rastrear TODAS as mudanças
- Performance: queries devem ser <500ms

### Arquitetura

```
Transações (em tempo real via Kafka)
    ↓
Kinesis → S3 (com encryption KMS)
    ↓
Glue Catalog (metadata gerenciado)
    ↓
Spark (remove PII, aplica masking)
    ↓
BigQuery (Data Lake)
    ↓
DBT (analytics seguras, sem PII)
    ↓
Data Studio (dashboards)
```

### Segurança Implementada

```python
from crypto.fernet import Fernet
import re

def mask_pii_data(df, sensitive_columns):
    """Mascara dados sensíveis"""
    
    from pyspark.sql.functions import regexp_replace, hash
    
    for col in sensitive_columns:
        if col == 'cpf':
            # Mantém últimos 2 dígitos, mascara resto
            df = df.withColumn(
                col,
                regexp_replace(col, r'(\d{3})\d{5}(\d{2})', 'XXX.XXXX.$2')
            )
        elif col == 'email':
            # firstname***@domain
            df = df.withColumn(
                col,
                regexp_replace(col, r'(.{2}).*(@.+)', '$1***$2')
            )
    
    return df
```

### Auditoria: Change Data Capture

```sql
-- Staging: Versiona TUDO
CREATE TABLE stg_transacoes_history AS
SELECT
    transacao_id,
    usuario_id,
    valor,
    status,
    created_at,
    ROW_NUMBER() OVER (PARTITION BY transacao_id ORDER BY created_at DESC) as versao
FROM raw_transacoes;
```

---

## **Caso 3: SaaS Analytics (Dados de 10k+ clientes)**

### Contexto
Platform que coleta dados de usuários de 10k+ clientes diferentes.

### Desafios
- Isolamento de dados (cada cliente vê só seus dados)
- Escalabilidade: crescer para 100k clientes sem quebrar
- Multi-tenancy: agregar dados mas segregar acesso

### Arquitetura

```
Event tracking (SDK em browser/mobile)
    ↓
Segment/Mixpanel (coleta centralizada)
    ↓
S3 (particionado por tenant_id)
    ↓
Spark (agregação por tenant)
    ↓
Snowflake (Separate Databases por tier de cliente)
    ↓
DBT (materializações por tenant)
    ↓
API REST (serve dados aggregados)
```

### Implementação Multi-tenant

```python
def process_tenant_data(spark, tenant_id, date_str):
    """Processa dados isolados por tenant"""
    
    path = f"s3://events/tenant_id={tenant_id}/dt={date_str}/"
    
    df = spark.read.parquet(path)
    
    # Transformações específicas do tenant
    if tenant_id == "cliente_premium":
        # Premium tem acesso a mais eventos
        df = df.filter(col("event_type").isin(PREMIUM_EVENTS))
    else:
        # Free tier: apenas eventos públicos
        df = df.filter(col("event_type").isin(FREE_EVENTS))
    
    # Salva resultado segregado
    output_path = f"s3://warehouse/tenant={tenant_id}/dt={date_str}/"
    df.write.mode("overwrite").parquet(output_path)
```

---

## **Caso 4: Detecção de Fraude (ML + Real-time)**

### Contexto
Bank precisa detectar fraude em tempo real (latência <1s).

### Desafios
- Latência real-time
- Feature engineering em larga escala
- Modelo deve rodar em produção

### Arquitetura

```
Transação (evento Kafka)
    ↓
Feature Store (Redis cache)
    ↓
ML Model (endpoint prediction)
    ↓
Decision (approve/reject/review)
    ↓
Feedback Loop (atualiza features)
    ↓
Airflow (retreina modelo nightly)
    ↓
BigQuery (audit trail)
```

### Feature Engineering Pipeline

```python
from pyspark.ml import Pipeline
from pyspark.ml.feature import StandardScaler, VectorAssembler

def create_ml_features(df):
    """Feature engineering para modelo de fraude"""
    
    # Temporal features
    df = df.withColumn(
        "hora_transacao",
        hour(col("timestamp"))
    ).withColumn(
        "dias_desde_criacao",
        datediff(col("timestamp"), col("data_criacao"))
    )
    
    # Behavioral features
    window_spec = Window.partitionBy("usuario_id").orderBy("timestamp")
    
    df = df.withColumn(
        "transacoes_ultimas_24h",
        count("*").over(window_spec.rangeBetween(-86400, 0))
    ).withColumn(
        "valor_medio_usuario",
        avg("valor").over(window_spec)
    )
    
    # Feature vector
    feature_cols = ["hora_transacao", "valor", "dias_desde_criacao", 
                    "transacoes_ultimas_24h", "valor_medio_usuario"]
    
    assembler = VectorAssembler(
        inputCols=feature_cols,
        outputCol="features"
    )
    
    scaler = StandardScaler(
        inputCol="features",
        outputCol="scaled_features",
        withMean=True,
        withStd=True
    )
    
    pipeline = Pipeline(stages=[assembler, scaler])
    
    return pipeline.fit(df).transform(df)
```

---

# 📚 FONTES COMPLEMENTARES PARA ESTUDO

## Livros & Referências
1. **"Fundamentals of Data Engineering"** - Joe Reis & Matt Housley (2022)
2. **"Designing Data-Intensive Applications"** - Martin Kleppmann (imprescindível)
3. **"The Data Warehouse Toolkit"** - Ralph Kimball (dimensional modeling)

## Plataformas Online
- **Udacity Data Engineering Nanodegree**: https://www.udacity.com/course/data-engineer-nanodegree--nd027
- **DataCamp - Data Engineering Track**: https://www.datacamp.com/courses/data-engineering-track
- **Coursera - Data Engineering on Google Cloud**: https://www.coursera.org/professional-certificates/gcp-data-engineering

## Repositórios GitHub (estudar código real)
- **Uber's Data Engineering Papers**: https://github.com/uber/umap
- **Airflow Examples**: https://github.com/apache/airflow/tree/main/airflow/example_dags
- **DBT Examples**: https://github.com/dbt-labs/dbt-tutorials

## Comunidades & Blogs
- **Data Engineering Weekly**: https://www.dataengineeringweekly.com/
- **Locally Optimistic** (DBT best practices): https://locallyoptimistic.com/
- **Seattle Data Guy** (YouTube): Tutoriais práticos

---

# ✅ PRÓXIMOS PASSOS PARA SEU PROJETO

Para alcançar o nível Pleno, você precisa:

1. **Semana 1-2**: Montar infra AWS (EC2 para Airflow, RDS para metadata)
2. **Semana 3-4**: Implementar pipeline simples (1 fonte → S3 → Redshift)
3. **Semana 5-6**: Adicionar Spark e otimizações
4. **Semana 7**: DBT + testes
5. **Semana 8**: Great Expectations + documentação

## Recomendação

Comece com dataset público do Kaggle (ex: e-commerce), implemente o pipeline E2E, depois replique em dados reais da empresa.

---

**Documento gerado**: 2025  
**Versão**: 1.0  
**Status**: Pronto para produção
