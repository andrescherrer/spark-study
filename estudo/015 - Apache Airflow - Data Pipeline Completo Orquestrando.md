# Apache Airflow: Orquestração de Pipelines de Dados (Semana 5-6)

Vou te guiar através dessa jornada com a experiência de 20 anos em engenharia de dados. Esse é um conhecimento crítico na indústria.

## 1. ENTENDENDO APACHE AIRFLOW

### O que é Airflow?

Apache Airflow é uma plataforma de orquestração de fluxos de trabalho que permite definir, agendar e monitorar pipelines de dados complexos como código Python (Infrastructure as Code). Diferente de ferramentas legadas como Talend ou Informatica, Airflow oferece máxima flexibilidade.

**Conceitos Fundamentais:**

**DAG (Directed Acyclic Graph)**: Seu pipeline é um grafo direcionado acíclico. Cada nó é uma tarefa (Task) e as arestas representam dependências. O Airflow garante que as tarefas sejam executadas apenas quando suas dependências forem satisfeitas.

**Operadores**: Blocos de construção que definem O QUÊ fazer. Operador de Python, SQL, Spark, etc.

**Sensors**: Tipos especiais de operadores que esperam por uma condição (arquivo existe? Tabela foi atualizada?)

**Hooks**: Conexões reutilizáveis com sistemas externos (banco de dados, APIs, data warehouse)

**XComs (Cross-Communication)**: Mecanismo para passar dados entre tarefas

### Documentação Oficial (CRÍTICA para estudo)

```
https://airflow.apache.org/docs/apache-airflow/stable/
https://airflow.apache.org/docs/apache-airflow/stable/concepts/dags.html
https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/operators.html
https://airflow.apache.org/docs/apache-airflow/stable/concepts/tasks.html
```

---

## 2. ARQUITETURA DETALHADA DO PROJETO E-COMMERCE ETL

Vou desmontar cada fase:

### **FASE 1: Coleta de Dados de API Pública (2h)**

```python
# dags/ecommerce_etl.py
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.providers.http.sensors.http import HttpSensor
from datetime import datetime, timedelta
import requests
import json

# Definir argumentos padrão
default_args = {
    'owner': 'data_team',
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'email_on_failure': True,
    'email': ['data_team@empresa.com']
}

# Criar DAG
dag = DAG(
    'ecommerce_etl_pipeline',
    default_args=default_args,
    description='Pipeline ETL E-commerce completo',
    schedule_interval='0 2 * * *',  # Executa diariamente às 2 AM
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['ecommerce', 'etl']
)

# Função Python para coletar dados da API
def fetch_sales_data(**context):
    """Coleta dados de vendas de API pública"""
    api_url = "https://api.example-ecommerce.com/sales"
    params = {
        'date': context['ds'],  # Data de execução do DAG
        'limit': 10000
    }
    
    try:
        response = requests.get(api_url, params=params, timeout=30)
        response.raise_for_status()
        
        sales_data = response.json()
        
        # Salvar em arquivo intermediário (XCom)
        context['task_instance'].xcom_push(
            key='sales_data',
            value=sales_data
        )
        
        print(f"✓ Coletados {len(sales_data)} registros de vendas")
        return len(sales_data)
        
    except requests.exceptions.RequestException as e:
        print(f"✗ Erro ao coletar dados: {str(e)}")
        raise

# Task 1: Sensor HTTP - Aguarda API ficar disponível
check_api_availability = HttpSensor(
    task_id='check_api_availability',
    http_conn_id='ecommerce_api',
    endpoint='health',
    request_params={},
    response_check=lambda response: response.status_code == 200,
    timeout=300,
    poke_interval=30,
    dag=dag
)

# Task 2: Fetch dados da API
fetch_sales = PythonOperator(
    task_id='fetch_sales_data',
    python_callable=fetch_sales_data,
    provide_context=True,
    dag=dag
)

check_api_availability >> fetch_sales
```

**Por que esse padrão?**
- `HttpSensor`: Evita que task falhe imediatamente se API está temporariamente indisponível
- `XCom`: Passa dados JSON entre tasks de forma eficiente
- `default_args`: Configuração centralizada de retry e alertas

---

### **FASE 2: Validação de Dados (4h)**

```python
def validate_sales_data(**context):
    """Valida dados coletados contra regras de negócio"""
    
    # Recuperar dados coletados
    ti = context['task_instance']
    sales_data = ti.xcom_pull(
        task_ids='fetch_sales_data',
        key='sales_data'
    )
    
    validation_errors = []
    validated_records = []
    
    # Regras de validação
    RULES = {
        'order_id': lambda x: x and str(x).strip() != '',
        'customer_id': lambda x: x and x > 0,
        'amount': lambda x: x and x >= 0,
        'timestamp': lambda x: x and isinstance(x, str),
        'status': lambda x: x in ['pending', 'completed', 'failed', 'shipped']
    }
    
    for idx, record in enumerate(sales_data):
        is_valid = True
        errors = []
        
        for field, validator in RULES.items():
            if field not in record or not validator(record.get(field)):
                is_valid = False
                errors.append(f"Campo '{field}' inválido: {record.get(field)}")
        
        if is_valid:
            validated_records.append(record)
        else:
            validation_errors.append({
                'record_index': idx,
                'errors': errors,
                'record': record
            })
    
    # Salvar resultados
    ti.xcom_push(key='validated_records', value=validated_records)
    ti.xcom_push(key='validation_errors', value=validation_errors)
    
    validation_rate = (len(validated_records) / len(sales_data)) * 100
    print(f"✓ Taxa de validação: {validation_rate:.2f}%")
    
    if validation_rate < 95:  # Alerta se muito dado inválido
        raise ValueError(
            f"Apenas {validation_rate:.2f}% dos dados passaram validação. "
            f"Verificar qualidade da fonte."
        )
    
    return {
        'total_records': len(sales_data),
        'valid_records': len(validated_records),
        'invalid_records': len(validation_errors),
        'validation_rate': validation_rate
    }

validate_data = PythonOperator(
    task_id='validate_sales_data',
    python_callable=validate_sales_data,
    provide_context=True,
    dag=dag
)

fetch_sales >> validate_data
```

**Pontos-chave:**
- Validações contra regras de negócio explícitas
- Rastreamento de erros para auditoria
- Falha rápida se qualidade está baixa (fail-fast pattern)

---

### **FASE 3: Transformação com Apache Spark (8h)**

```python
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator

# spark_jobs/transform_sales.py (arquivo separado)
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from datetime import datetime
import sys

def transform_sales_data(input_path, output_path):
    """Transformação complexa com Spark"""
    
    spark = SparkSession.builder \
        .appName("EcommerceSalesTransform") \
        .config("spark.executor.memory", "4g") \
        .config("spark.driver.memory", "2g") \
        .getOrCreate()
    
    # 1. LEITURA
    df = spark.read.json(input_path)
    
    # 2. LIMPEZA
    df_clean = df \
        .dropDuplicates(['order_id']) \
        .filter(col('amount') > 0) \
        .filter(col('timestamp').isNotNull())
    
    # 3. TRANSFORMAÇÕES COMPLEXAS
    df_transformed = df_clean \
        .withColumn('order_date', to_date(col('timestamp'))) \
        .withColumn('order_month', date_format(col('timestamp'), 'yyyy-MM')) \
        .withColumn('amount_usd', 
                   when(col('currency') == 'BRL', col('amount') / 5.0)
                   .otherwise(col('amount'))) \
        .withColumn('processed_at', current_timestamp())
    
    # 4. AGREGAÇÕES
    df_summary = df_transformed.groupBy('order_month', 'status') \
        .agg(
            count('order_id').alias('total_orders'),
            sum('amount_usd').alias('revenue_usd'),
            avg('amount_usd').alias('avg_order_value'),
            max('amount_usd').alias('max_order_value')
        )
    
    # 5. ESCRITA
    df_transformed.write.mode('overwrite') \
        .parquet(f"{output_path}/transformed_sales")
    
    df_summary.write.mode('overwrite') \
        .parquet(f"{output_path}/sales_summary")
    
    print(f"✓ Transformados {df_transformed.count()} registros")

if __name__ == "__main__":
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    transform_sales_data(input_path, output_path)
```

**No DAG:**

```python
transform_spark = SparkSubmitOperator(
    task_id='transform_with_spark',
    application='/opt/spark_jobs/transform_sales.py',
    conf={'spark.executor.instances': 4},
    total_executor_cores=8,
    executor_memory='4g',
    driver_memory='2g',
    application_args=[
        '/data/raw/sales_data.json',
        '/data/processed/'
    ],
    dag=dag
)

validate_data >> transform_spark
```

**Por que Spark?**
- Processa dados em paralelo (scale-out)
- Muito mais rápido que Python puro para grandes volumes
- Integração nativa com HDFS, S3, Redshift

---

### **FASE 4: Carregamento em Data Warehouse (4h)**

```python
from airflow.providers.amazon.aws.operators.redshift_data import RedshiftDataOperator
from airflow.providers.amazon.aws.transfers.s3_to_redshift import S3ToRedshiftOperator

# Método 1: Via S3 (melhor prática para grandes volumes)
load_to_redshift = S3ToRedshiftOperator(
    task_id='load_sales_to_redshift',
    s3_bucket='data-pipeline-bucket',
    s3_key='processed/transformed_sales/',
    schema='public',
    table='sales_fact',
    copy_options=['IGNOREHEADER 1', 'DELIMITER \',\''],
    redshift_conn_id='redshift_warehouse',
    method='REPLACE',  # ou 'UPSERT' se tiver PK
    dag=dag
)

# Método 2: Execução de SQL customizado
run_incremental_load = RedshiftDataOperator(
    task_id='incremental_upsert_sales',
    redshift_cluster_identifier='my-warehouse',
    database='analytics_db',
    sql="""
    BEGIN TRANSACTION;
    
    -- Staged table para dados novos
    CREATE TEMP TABLE sales_staging AS
    SELECT * FROM s3 's3://data-pipeline-bucket/processed/transformed_sales/'
    IAM_ROLE 'arn:aws:iam::ACCOUNT:role/RedshiftRole'
    FORMAT AS PARQUET;
    
    -- UPSERT logic
    DELETE FROM sales_fact
    WHERE order_id IN (SELECT order_id FROM sales_staging);
    
    INSERT INTO sales_fact
    SELECT * FROM sales_staging;
    
    COMMIT;
    
    -- Refresh materialized view
    REFRESH MATERIALIZED VIEW sales_summary_mv;
    """,
    dag=dag
)

transform_spark >> load_to_redshift >> run_incremental_load
```

**Documentação essencial:**
```
https://airflow.apache.org/docs/apache-airflow-providers-amazon/stable/operators/transfer/s3_to_redshift.html
https://airflow.apache.org/docs/apache-airflow-providers-amazon/stable/operators/redshift_data.html
```

---

### **FASE 5: Notificação de Stakeholders (2h)**

```python
from airflow.providers.slack.operators.slack_webhook import SlackWebhookOperator
from airflow.providers.smtp.operators.smtp import EmailOperator
from airflow.operators.python import BranchPythonOperator

def generate_summary(**context):
    """Gera sumário de execução"""
    ti = context['task_instance']
    
    validation_result = ti.xcom_pull(
        task_ids='validate_sales_data'
    )
    
    summary = f"""
    📊 PIPELINE ECOMMERCE ETL - RESUMO DIÁRIO
    =====================================
    Data: {context['ds']}
    
    ✓ Registros válidos: {validation_result['valid_records']:,}
    ✗ Registros inválidos: {validation_result['invalid_records']:,}
    📈 Taxa de validação: {validation_result['validation_rate']:.2f}%
    
    Status: ✅ SUCESSO
    """
    
    ti.xcom_push(key='pipeline_summary', value=summary)
    return summary

# Notificar via Slack
notify_slack = SlackWebhookOperator(
    task_id='notify_slack_success',
    http_conn_id='slack_webhook',
    message="""
    🟢 Pipeline E-commerce executado com sucesso!
    {{ task_instance.xcom_pull(task_ids='generate_summary', key='pipeline_summary') }}
    """,
    dag=dag
)

# Enviar email com arquivo CSV
send_report_email = EmailOperator(
    task_id='send_daily_report_email',
    to='stakeholders@empresa.com',
    subject='Relatório Diário E-commerce - {{ ds }}',
    html_content="""
    <html>
        <h2>Relatório de Vendas - {{ ds }}</h2>
        <p>{{ task_instance.xcom_pull(task_ids='generate_summary') }}</p>
    </html>
    """,
    files=['/data/reports/sales_summary_{{ ds }}.csv'],
    dag=dag
)

load_to_redshift >> [notify_slack, send_report_email]
```

---

### **FASE 6: Monitoramento e Alertas (2h)**

```python
from airflow.sensors.sql import SqlSensor
from airflow.providers.slack.operators.slack import SlackAPIPostOperator

# Sensor SQL: Valida dados carregados
check_data_quality = SqlSensor(
    task_id='check_data_quality_redshift',
    conn_id='redshift_warehouse',
    sql="""
    SELECT COUNT(*)
    FROM sales_fact
    WHERE DATE(processed_at) = '{{ ds }}'
    AND amount_usd > 0
    HAVING COUNT(*) > 0  -- Falha se 0 registros
    """,
    poke_interval=60,
    timeout=300,
    dag=dag
)

# Alerta se qualidade ruim
def check_data_freshness(**context):
    """Verifica se dados foram carregados em tempo hábil"""
    # Conectar ao Redshift e verificar last_load_time
    # Se > 2 horas, gerar alerta
    pass

# Task de callback para falha
def on_pipeline_failure(context):
    """Executado quando pipeline falha"""
    error_msg = f"""
    🔴 ALERTA: Pipeline E-commerce FALHOU
    
    DAG: {context['dag'].dag_id}
    Task: {context['task'].task_id}
    Data: {context['ds']}
    Erro: {context['exception']}
    """
    
    # Enviar para Slack, PagerDuty, etc
    print(error_msg)

dag.on_failure_callback = on_pipeline_failure

load_to_redshift >> check_data_quality
```

---

## 3. ESTRUTURA DE DIRETÓRIOS COMPLETA

```
airflow-project/
├── dags/
│   ├── ecommerce_etl.py           # DAG principal
│   ├── staging_etl.py             # DAG para dados staging
│   └── maintenance_dag.py          # Limpeza, backup
│
├── plugins/
│   ├── operators/
│   │   ├── __init__.py
│   │   ├── custom_operators.py    # Operadores customizados
│   │   └── validate_operator.py   # Validação reutilizável
│   │
│   ├── sensors/
│   │   ├── __init__.py
│   │   └── s3_custom_sensor.py    # Sensor S3 customizado
│   │
│   ├── hooks/
│   │   ├── __init__.py
│   │   ├── redshift_hook.py       # Conexão Redshift
│   │   └── api_hook.py            # Conexão API customizada
│   │
│   └── utils/
│       ├── data_quality.py        # Funções de validação
│       └── notifications.py       # Alertas reutilizáveis
│
├── spark_jobs/
│   ├── transform_sales.py         # Job Spark
│   ├── aggregate_metrics.py
│   └── requirements.txt
│
├── tests/
│   ├── test_dags.py               # Testes DAG
│   ├── test_operators.py
│   └── test_data_quality.py
│
├── docker-compose.yml             # Airflow local
├── airflow.cfg                    # Configuração Airflow
├── requirements.txt               # Dependencies Python
└── README.md
```

---

## 4. DOCUMENTAÇÃO OFICIAL PARA ESTUDO

| Tópico | URL |
|--------|-----|
| **Conceitos Principais** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/ |
| **DAGs e Tarefas** | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html |
| **Operadores** | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/operators.html |
| **Sensores** | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/sensors.html |
| **XCom (Pass Data)** | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/xcoms.html |
| **Providers (Integrações)** | https://airflow.apache.org/docs/#providers |
| **Amazon (S3, Redshift)** | https://airflow.apache.org/docs/apache-airflow-providers-amazon/stable/ |
| **Slack Integration** | https://airflow.apache.org/docs/apache-airflow-providers-slack/stable/ |
| **Docker Setup** | https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/ |
| **Best Practices** | https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html |

---

## 5. EXEMPLOS DO MUNDO REAL (Engenharia de Dados Production)

### **CASO 1: Pipeline de Recomendação de E-commerce (Spotify, Netflix Style)**

**Desafio:** Processar 10 milhões de eventos de usuário/dia, gerar recomendações em tempo real.

```python
# dags/recommendation_pipeline.py
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from datetime import datetime, timedelta

dag = DAG(
    'user_recommendation_ml_pipeline',
    schedule_interval='0 3 * * *',  # 3 AM diariamente
    start_date=datetime(2024, 1, 1)
)

# 1. Coleta eventos de cliques
fetch_user_events = PythonOperator(
    task_id='fetch_user_clickstream_events',
    python_callable=lambda: fetch_from_kafka_logs(),
    # Lê últimas 24h de eventos Kafka
    dag=dag
)

# 2. Feature engineering com Spark
compute_user_features = SparkSubmitOperator(
    task_id='compute_ml_features',
    application='/jobs/feature_engineering.py',
    # Calcula: user_lifetime_value, category_preferences,
    # browse_frequency, purchase_propensity, etc
    dag=dag
)

# 3. Treinar modelo ML (PyTorch/TensorFlow)
train_recommendation_model = SparkSubmitOperator(
    task_id='train_collab_filtering_model',
    application='/jobs/train_model.py',
    # Usa collaborative filtering
    # Output: modelo salvo em S3
    dag=dag
)

# 4. Gerar recomendações para todos usuários
generate_batch_recommendations = SparkSubmitOperator(
    task_id='batch_generate_recommendations',
    application='/jobs/generate_recommendations.py',
    # Para cada usuário: top 100 items recomendados
    # Output: Parquet com user_id | recommended_items
    dag=dag
)

# 5. Carregar em cache Redis (para real-time serving)
cache_recommendations_redis = PythonOperator(
    task_id='cache_to_redis',
    python_callable=load_recommendations_to_redis,
    # API consegue buscar recomendação em <50ms
    dag=dag
)

# 6. A/B Testing - Validar qualidade
validate_recommendations_quality = PythonOperator(
    task_id='validate_recommendation_quality',
    python_callable=calculate_metrics,
    # Métricas: CTR, Conversion Rate, Diversity Score
    op_kwargs={
        'metrics': ['ctr', 'conversion_rate', 'diversity', 'novelty']
    },
    dag=dag
)

fetch_user_events >> compute_user_features >> train_recommendation_model >> \
    generate_batch_recommendations >> cache_recommendations_redis >> validate_recommendations_quality
```

**Desafios superados:**
- Processamento de 10M eventos = necessário Spark com 50+ executores
- Modelo ML treina em 2 horas = risco de falha = implementar retry automático
- Redis cache = falha ao cache = recomendações padrão (fallback)
- Monitoramento de drift em recomendações

---

### **CASO 2: Financial Analytics - Processamento de Transações em Tempo Real**

**Desafio:** Processar 50 milhões de transações/dia, detectar fraude, calcular métricas em <5 minutos

```python
# dags/financial_fraud_detection.py

def detect_fraud_patterns(**context):
    """ML-based fraud detection em tempo real"""
    
    # 1. Recuperar últimas 24 horas de transações
    transactions = fetch_from_bigquery("""
    SELECT 
        transaction_id, user_id, amount, merchant_id, 
        timestamp, ip_address, device_id
    FROM transactions
    WHERE DATE(timestamp) = CURRENT_DATE()
    ORDER BY timestamp DESC
    """)
    
    # 2. Feature engineering
    features = compute_features(transactions)
    # Exemplos: user_avg_transaction_size, merchant_risk_score,
    # deviation_from_normal, geographic_anomaly
    
    # 3. Rodar modelo ML (Isolation Forest)
    fraud_scores = ml_model.predict(features)
    
    # 4. Flagging e alertas
    high_risk = transactions[fraud_scores > 0.8]
    
    for transaction in high_risk:
        # Alerta em tempo real para revisão manual
        alert_fraud_team(transaction, fraud_scores)
    
    return {
        'total_transactions': len(transactions),
        'fraud_flagged': len(high_risk),
        'fraud_rate': len(high_risk) / len(transactions)
    }

# DAG
fraud_pipeline = DAG(
    'financial_fraud_detection',
    schedule_interval='*/5 * * * *',  # A CADA 5 MINUTOS!
    max_active_runs=2,
    catchup=False
)

detect_fraud = PythonOperator(
    task_id='detect_fraudulent_transactions',
    python_callable=detect_fraud_patterns,
    execution_timeout=timedelta(minutes=4),  # Deve rodar em <4 min
    pool='fraud_detection_pool',  # Limitar recursos
    dag=fraud_pipeline
)

# Se fraude detectada, escalar
def escalate_to_security(**context):
    result = context['task_instance'].xcom_pull(task_ids='detect_fraudulent_transactions')
    if result['fraud_rate'] > 0.05:  # >5% fraude
        # Alerta crítico
        alert_security_team("CRITICAL: Fraud rate above threshold")
    
escalate = BranchPythonOperator(
    task_id='escalate_if_critical',
    python_callable=escalate_to_security,
    dag=fraud_pipeline
)

detect_fraud >> escalate
```

**Pontos-chave de Production:**
- Schedule a CADA 5 MINUTOS (não diário)
- Max active runs = 2 (evita sobrecarga)
- Execution timeout rigoroso (4 min para processar 50M transações!)
- Alertas em tempo real, não batch

---

### **CASO 3: Data Lake com Governo de Dados (Catalogo de Dados)**

**Desafio:** 500+ tabelas em múltiplas fontes, rastreabilidade completa, Data Lineage

```python
# dags/data_governance_pipeline.py

def profile_data_quality(**context):
    """Perfil automático de qualidade de dados"""
    
    connections = fetch_all_data_sources()  # 500+ tabelas
    
    for source in connections:
        for table in source.tables:
            profile = {
                'table': table.name,
                'row_count': get_row_count(table),
                'null_percentage': calculate_null_ratio(table),
                'unique_values': get_cardinality(table),
                'last_updated': get_last_modified(table),
                'data_freshness_hours': get_data_age(table),
                'columns': get_column_stats(table)
            }
            
            # Salvar metadata
            save_to_catalog(profile)
            
            # Alertar se dados velhos
            if profile['data_freshness_hours'] > 24:
                alert_data_owner(
                    f"Table {table.name} not updated in 24h"
                )

def generate_data_lineage(**context):
    """Gerar e visualizar data lineage (DAG de dados)"""
    
    # SQL Parser: analisar todas as queries SQL
    lineage = {
        'dependencies': {},  # table A depende de tables B, C
        'transformations': {},  # qual query transforma B+C em A
        'owners': {}  # quem é responsável por cada tabela
    }
    
    for transformation_query in fetch_all_dbt_models():
        upstream = parse_sql_dependencies(transformation_query)
        downstream = parse_sql_outputs(transformation_query)
        
        lineage['dependencies'][downstream] = upstream
    
    # Visualizar com Cytoscape.js
    render_lineage_graph(lineage)  # Gera página web interativa

# Exemplo: se tabela SALES muda, rastrear quem depende dela
# SALES -> SALES_SUMMARY -> REVENUE_DASHBOARD -> EMAIL_REPORT

governance_dag = DAG(
    'data_governance_metadata',
    schedule_interval='0 4 * * *',  # 4 AM
    dag=fraud_pipeline
)

profile_quality = PythonOperator(
    task_id='profile_all_tables_quality',
    python_callable=profile_data_quality,
    pool='io_intensive_pool',
    dag=governance_dag
)

generate_lineage = PythonOperator(
    task_id='generate_data_lineage',
    python_callable=generate_data_lineage,
    dag=governance_dag
)

profile_quality >> generate_lineage
```

**Por que importante:**
- Em companies maduras, GOVERNANCE é tão importante quanto pipelines
- Data Lineage ajuda a debugar qual transformação causou o erro
- Catálogo de dados permite auto-descoberta

---

### **CASO 4: Real-time Analytics - Agregações Contínuas**

**Desafio:** 100k eventos/segundo, agregações atualizadas a cada 1 minuto

```python
# Usando Kafka + Flink/Spark Streaming

# Ao invés de batch Airflow, usar streaming
# Mas Airflow monitora o job de streaming

monitoring_dag = DAG(
    'streaming_jobs_monitoring',
    schedule_interval='*/1 * * * *',  # A CADA 1 MINUTO
)

def check_streaming_health(**context):
    """Verifica saúde do job Spark Streaming"""
    
    job_status = {
        'flink_job': fetch_flink_status(),  # Running? Backpressure?
        'kafka_lag': fetch_kafka_consumer_lag(),  # Atrasado?
        'events_processed_last_minute': fetch_processed_count(),
        'error_rate': calculate_error_rate()
    }
    
    if job_status['kafka_lag'] > 1_000_000:  # 1M+ mensagens atrasadas
        # Escalar tasks de processamento
        scale_up_spark_executors(from_count=10, to_count=30)
        alert_oncall("Kafka lag above threshold, scaled up Spark")
    
    if job_status['error_rate'] > 0.01:  # >1% erro
        # Pausar processamento, investigar
        pause_streaming_job()
        alert_critical("High error rate in streaming pipeline")

health_check = PythonOperator(
    task_id='monitor_streaming_job_health',
    python_callable=check_streaming_health,
    pool='monitoring_pool',
    dag=monitoring_dag
)
```

---

## 6. PADRÕES AVANÇADOS & ANTI-PATTERNS

### ✅ **BOAS PRÁTICAS**

```python
# 1. Idempotência - Task pode rodar 2x sem problemas
# ❌ RUIM: INSERT INTO table VALUES (...)
# ✅ BOM: INSERT OVERWRITE / UPSERT com chave composta

# 2. Granularidade de Tasks
# ❌ RUIM: Uma task faz tudo (coleta + validação + transforma + carrega)
# ✅ BOM: Cada etapa é uma task separada (easier debugging)

# 3. Usar Pools para limitar recursos
default_view_pool_size = 10  # Max 10 tasks paralelas
pool = create_pool('io_intensive', 5)  # Max 5 I/O tasks

# 4. SLA (Service Level Agreements)
dag_sla = timedelta(hours=2)  # Deve completar em 2 horas
task_sla = timedelta(minutes=30)  # Cada task em 30 min

sla_miss_callback = lambda context: alert("SLA missed!")

# 5. Logging detalhado
import logging
log = logging.getLogger(__name__)
log.info(f"Processados {n_records} em {time_taken}s")
```

### ❌ **ANTI-PATTERNS A EVITAR**

```python
# ❌ Não fazer:
def extract_and_transform_and_load():  # Uma megatareffa
    data = fetch_api()
    validate_and_transform(data)  # Difícil debugar qual etapa falhou
    load_to_warehouse(data)

# ❌ Não fazer:
schedule_interval='*/1 * * * *'  # A cada minuto para ETL batch
# Se processar 10GB, vai ficar atrasado

# ❌ Não fazer:
xcom_push(huge_dataframe)  # XCom é para pequenos dados
# Use S3/Parquet ao invés

# ❌ Não fazer:
dag_id = f"pipeline_{random.randint(1,100)}"  # DAG IDs devem ser estáveis
```

---

## 7. FERRAMENTAS COMPLEMENTARES (Stack típico)

| Ferramenta | Função | Quando usar |
|-----------|--------|-----------|
| **Apache Spark** | Processamento distribuído | >1GB dados |
| **dbt** | Transformações SQL reutilizáveis | Models estruturadas |
| **Great Expectations** | Data quality framework | Validação automática |
| **Terraform** | Infra as Code | Provisionar recursos AWS/GCP |
| **Prometheus + Grafana** | Monitoramento de métricas | Dashboards de performance |
| **ArgoCD** | Deploy de DAGs (GitOps) | CI/CD para Airflow |
| **DBT Cloud** | Orquestração de modelos dbt | Alternativa ao Airflow só para SQL |

---

## 8. ROADMAP DE ESTUDO (20-80 horas)

```
Semana 1-2: Fundamentos (20h)
└─ Conceitos DAG, Operators, Sensors, XCom
└─ Setup Docker local
└─ Criar 3-4 DAGs simples

Semana 3-4: Integrações (20h)
└─ AWS (S3, Redshift, EC2)
└─ Kafka, SQL, APIs
└─ Error handling e retries

Semana 5-6: Projeto Real (32h)
└─ Pipeline ETL production-grade
└─ Monitoramento, alertas
└─ Testes unitários

Semana 7-8: Advanced (8h)
└─ Custom Operators, Hooks
└─ Dynamic DAG generation
└─ Multi-tenant pipelines
```

---

## Recomendação Final

Comece pelo **Caso 1 (Recomendação)** - é mais próximo do mundo real que exemplos triviais de tutoriais. Entender pipeline com ML é diferente de um simples ETL.