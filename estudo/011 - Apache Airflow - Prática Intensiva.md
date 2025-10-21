# Apache Airflow: Guia Completo - Semanas 5-6

Especialista em Dados com 20 anos de experiência

---

## 📚 FUNDAMENTOS: O QUE É AIRFLOW

Apache Airflow é um **orquestrador de workflows** que permite definir, agendar e monitorar pipelines de dados de forma programática. A diferença crítica: você define seus workflows **como código** (DAGs), não em UI.

### Comparação com o que você conhece (PHP)
Se em PHP você faz requisições HTTP síncronas, Airflow gerencia **múltiplas tasks assíncronas**, com retry automático, logging centralizado e tratamento de dependências complexas.

---

## 🏗️ 1. DAGS (DIRECTED ACYCLIC GRAPHS)

### O que é:
Uma **DAG** é um grafo dirigido acíclico que representa seu pipeline. Cada nó é uma **task**, cada seta é uma **dependência**.

```python
from airflow import DAG
from datetime import datetime, timedelta

default_args = {
    'owner': 'data_team',
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
    'start_date': datetime(2025, 1, 1)
}

dag = DAG(
    'meu_primeiro_pipeline',
    default_args=default_args,
    schedule_interval='0 2 * * *',  # 2h da manhã, todo dia
    catchup=False
)
```

**Conceitos críticos:**
- **schedule_interval**: Cron expression (como agendadores de tarefas em Linux)
- **retries**: Quantas vezes tentar novamente em caso de falha
- **start_date**: Quando o DAG começa a ser válido
- **catchup**: Se deve executar períodos passados perdidos

**Documentação Oficial:**
- [Airflow DAGs Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags/)

---

## ⚙️ 2. OPERADORES COMUNS (EXPLICAÇÃO DETALHADA)

### 2.1 BashOperator
Executa **comandos shell/bash**. Essencial para scripts legados.

```python
from airflow.operators.bash import BashOperator

task_bash = BashOperator(
    task_id='executar_comando',
    bash_command='echo "Iniciando processo" && python /opt/scripts/process.py',
    dag=dag
)
```

**Quando usar:** Scripts shell, comandos do SO, integração com ferramentas legadas.

**Docs:** [BashOperator](https://airflow.apache.org/docs/apache-airflow/stable/operators-and-hooks/operators/bash.html)

---

### 2.2 PythonOperator
Executa **funções Python** diretamente. A mais usada em Engenharia de Dados.

```python
from airflow.operators.python import PythonOperator
import pandas as pd

def processar_dados(**context):
    # context contém metadata da execução
    execution_date = context['execution_date']
    print(f"Processando dados de: {execution_date}")
    
    # Seu código de transformação
    df = pd.read_csv('dados.csv')
    df_processado = df[df['valor'] > 100]
    df_processado.to_parquet('output.parquet')
    
    # Passar dados para próxima task
    return df_processado.shape[0]

task_python = PythonOperator(
    task_id='processar',
    python_callable=processar_dados,
    dag=dag
)
```

**Quando usar:** 95% dos seus pipelines. Lógica de negócio, transformações, ML.

**Docs:** [PythonOperator](https://airflow.apache.org/docs/apache-airflow/stable/operators-and-hooks/operators/python.html)

---

### 2.3 SqlOperator
Executa **queries SQL** direto no banco.

```python
from airflow.operators.sql import SQLExecuteQueryOperator

task_sql = SQLExecuteQueryOperator(
    task_id='inserir_dados_warehouse',
    sql="""
    INSERT INTO fact_vendas (id, valor, data)
    SELECT 
        pedido_id,
        total,
        data_pedido
    FROM staging_pedidos
    WHERE data_pedido = '{{ ds }}'
    """,
    conn_id='snowflake_prod',  # Conexão pré-configurada
    dag=dag
)
```

**Quando usar:** Transformações em SQL puro (dbt alternativa), carga de dados em warehouse.

**Importante:** Use `{{ ds }}` para data de execução (Data-Sensitive templates).

**Docs:** [SQLExecuteQueryOperator](https://airflow.apache.org/docs/apache-airflow/stable/operators-and-hooks/operators/sql.html)

---

### 2.4 S3FileTransformOperator
Move/transforma **arquivos no S3 (AWS)**.

```python
from airflow.operators.amazon.s3.s3_file_transform import S3FileTransformOperator

task_s3 = S3FileTransformOperator(
    task_id='transformar_arquivo_s3',
    source_s3_key='s3://meu-bucket/raw/dados_{{ ds }}.csv',
    dest_s3_key='s3://meu-bucket/processed/dados_{{ ds }}.parquet',
    transform_script='/scripts/converter_csv_parquet.py',
    script_args=['--format=parquet', '--compression=snappy'],
    aws_conn_id='aws_default',
    dag=dag
)
```

**Quando usar:** Data lake workflows, transformações de arquivos em escala.

**Docs:** [S3FileTransformOperator](https://airflow.apache.org/docs/apache-airflow-providers-amazon/stable/operators/s3/s3_file_transform.html)

---

### 2.5 EmailOperator
Envia **notificações por email**.

```python
from airflow.operators.email import EmailOperator

task_email = EmailOperator(
    task_id='notificar_conclusao',
    to='analista@empresa.com',
    subject='Pipeline finalizado - {{ ds }}',
    html_content="""
    <h2>Relatório de Execução</h2>
    <p>Data: {{ ds }}</p>
    <p>Status: Sucesso ✓</p>
    <p>Registros processados: {{ task_instance.xcom_pull(task_ids='processar') }}</p>
    """,
    dag=dag
)
```

**Quando usar:** Alertas de sucesso/falha, relatórios automáticos.

**Docs:** [EmailOperator](https://airflow.apache.org/docs/apache-airflow/stable/operators-and-hooks/operators/email.html)

---

### 2.6 HttpOperator
Faz **requisições HTTP** (GET, POST, etc).

```python
from airflow.operators.http import HttpOperator
import json

task_http = HttpOperator(
    task_id='chamar_api_externa',
    http_conn_id='api_vendas',  # Conexão pré-configurada
    endpoint='/api/v1/relatorios/gerar',
    method='POST',
    data=json.dumps({
        'data_inicio': '{{ ds }}',
        'data_fim': '{{ ds }}',
        'formato': 'json'
    }),
    headers={'Content-Type': 'application/json'},
    response_filter=lambda response: response.json()['id'],  # Extrai ID
    dag=dag
)
```

**Quando usar:** Integração com APIs, webhooks, microserviços.

**Docs:** [HttpOperator](https://airflow.apache.org/docs/apache-airflow/stable/operators-and-hooks/operators/http.html)

---

## 🔗 DEPENDÊNCIAS ENTRE TASKS

```python
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

# Define as tasks
task_1 = PythonOperator(task_id='extrair', python_callable=funcao_extracao, dag=dag)
task_2 = PythonOperator(task_id='transformar', python_callable=funcao_transformacao, dag=dag)
task_3 = BashOperator(task_id='carregar', bash_command='echo "Carregando"', dag=dag)

# Define sequência
task_1 >> task_2 >> task_3

# Ou dependências múltiplas:
# task_1 >> [task_2, task_3]  # task_2 e task_3 executam em paralelo após task_1
```

---

## 📋 TAREFA PRÁTICA: DAG COM 5 OPERADORES

Veja o arquivo `dag_5_operadores.py` (fornecido em artifact separado)

---

## 🌍 EXEMPLOS DO MUNDO REAL - ENGENHARIA DE DADOS

### **Caso 1: E-commerce - Pipeline de Recomendações**

```python
dag_ecommerce = DAG('pipeline_recomendacoes', schedule_interval='0 3 * * *')

# Extrair logs de visualização S3
extract_logs = BashOperator(
    task_id='extract_s3_logs',
    bash_command='aws s3 sync s3://logs-prod/vendas/ /tmp/vendas_{{ ds }}/ --exclude "*" --include "*.json"',
    dag=dag_ecommerce
)

# Processar com PySpark (como PythonOperator)
def processar_com_spark(**context):
    from pyspark.sql import SparkSession
    spark = SparkSession.builder.appName("recomendacoes").getOrCreate()
    
    df = spark.read.json(f"/tmp/vendas_{context['ds']}/*.json")
    
    # ML Pipeline: produto viewing → recomendação
    recomendacoes = df.filter(df.usuario_id.isNotNull()).groupBy('usuario_id').count()
    
    recomendacoes.write.mode('overwrite').parquet(f"/data/recomendacoes/{context['ds']}")
    spark.stop()

ml_processing = PythonOperator(
    task_id='ml_recomendacoes',
    python_callable=processar_com_spark,
    dag=dag_ecommerce
)

# Carregar em Elasticsearch (HttpOperator)
def bulk_elasticsearch(**context):
    import requests
    ds = context['ds']
    
    # Ler parquet processado
    df = pd.read_parquet(f"/data/recomendacoes/{ds}")
    
    # Bulk insert no ES
    bulk_data = ""
    for idx, row in df.iterrows():
        bulk_data += f'{{"index": {{"_index": "recomendacoes", "_id": "{row["usuario_id"]}"}}\n'
        bulk_data += f'{{"usuario_id": "{row["usuario_id"]}", "score": {row["count"]}}}\n'
    
    requests.post('http://elasticsearch:9200/_bulk', data=bulk_data)

load_elasticsearch = PythonOperator(
    task_id='load_elasticsearch',
    python_callable=bulk_elasticsearch,
    dag=dag_ecommerce
)

extract_logs >> ml_processing >> load_elasticsearch
```

---

### **Caso 2: Fintech - Fraud Detection em Tempo Real**

```python
dag_fraud = DAG('pipeline_deteccao_fraude', schedule_interval='*/5 * * * *')  # A cada 5 minutos

# Puxar transações do Kafka via API
def extrair_transacoes_kafka(**context):
    from kafka import KafkaConsumer
    import json
    
    consumer = KafkaConsumer('transactions_prod', bootstrap_servers=['kafka:9092'])
    
    eventos = []
    for message in consumer:
        eventos.append(json.loads(message.value))
        if len(eventos) >= 1000:
            break
    
    df = pd.DataFrame(eventos)
    df.to_parquet('/tmp/transacoes.parquet')
    return len(df)

kafka_task = PythonOperator(
    task_id='extract_kafka_transactions',
    python_callable=extrair_transacoes_kafka,
    dag=dag_fraud
)

# ML Inference (modelo treinado em produção)
def predict_fraud(**context):
    import joblib
    
    model = joblib.load('/models/fraud_xgboost.pkl')
    
    df = pd.read_parquet('/tmp/transacoes.parquet')
    
    features = df[['valor', 'velocidade_transacao', 'distancia_loc', 'horario_inusitado']]
    
    df['fraude_prob'] = model.predict_proba(features)[:, 1]
    df['eh_fraude'] = df['fraude_prob'] > 0.7
    
    # Salvar suspeitas
    suspeitas = df[df['eh_fraude'] == True]
    suspeitas.to_sql('transacoes_suspeitas', con='sqlite:////fraud_db.db', if_exists='append')
    
    return suspeitas.shape[0]

ml_fraud = PythonOperator(
    task_id='ml_fraud_detection',
    python_callable=predict_fraud,
    dag=dag_fraud
)

# Enviar alertas via API para time de risco
def alertar_fraude(**context):
    task_instance = context['task_instance']
    num_fraudes = task_instance.xcom_pull(task_ids='ml_fraud_detection')
    
    if num_fraudes > 0:
        requests.post('http://api-interno/risk-alerts', json={
            'num_fraudes': num_fraudes,
            'timestamp': datetime.now().isoformat()
        })

alert_task = PythonOperator(
    task_id='alert_fraud_team',
    python_callable=alertar_fraude,
    dag=dag_fraud
)

kafka_task >> ml_fraud >> alert_task
```

---

### **Caso 3: BigData - Datalake com Delta Lake (Streaming)**

```python
dag_datalake = DAG('pipeline_datalake_delta', schedule_interval='0 1 * * *')

# Bronze Layer: Raw data
def load_bronze_layer(**context):
    from delta import configure_spark_with_delta_pip
    from pyspark.sql import SparkSession
    
    builder = configure_spark_with_delta_pip(
        SparkSession.builder.appName("DeltaLake")
    )
    spark = builder.getOrCreate()
    
    # Ler múltiplas fontes
    df_api = spark.read.json(f"s3://raw/api_logs/{context['ds']}/*")
    df_db = spark.read.jdbc("jdbc:mysql://prod-db:3306/sales", "orders")
    
    # Combinar
    df_union = df_api.union(df_db.select(df_api.columns))
    
    # Escrever em Delta (ACID transactions)
    df_union.write.format("delta").mode("append").save("s3://datalake/bronze/raw_data")

bronze_task = PythonOperator(
    task_id='load_bronze_layer',
    python_callable=load_bronze_layer,
    dag=dag_datalake
)

# Silver Layer: Cleaned & deduplicated
def load_silver_layer(**context):
    from delta import configure_spark_with_delta_pip
    from pyspark.sql import SparkSession
    
    builder = configure_spark_with_delta_pip(SparkSession.builder)
    spark = builder.getOrCreate()
    
    # Ler bronze
    df = spark.read.format("delta").load("s3://datalake/bronze/raw_data")
    
    # Transformações
    df_limpo = (df
        .dropDuplicates(['id'])
        .filter(df.valor > 0)
        .filter(df.data_criacao.isNotNull())
    )
    
    df_limpo.write.format("delta").mode("overwrite").save("s3://datalake/silver/clean_data")

silver_task = PythonOperator(
    task_id='load_silver_layer',
    python_callable=load_silver_layer,
    dag=dag_datalake
)

# Gold Layer: Business-ready aggregations
gold_sql = SQLExecuteQueryOperator(
    task_id='load_gold_layer',
    sql="""
    CREATE TABLE IF NOT EXISTS gold_vendas_por_categoria AS
    SELECT
        categoria,
        DATE(data_criacao) as data,
        COUNT(*) as num_vendas,
        SUM(valor) as valor_total,
        AVG(valor) as valor_medio,
        MAX(valor) as valor_maximo
    FROM silver.clean_data
    WHERE data_criacao >= DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)
    GROUP BY categoria, DATE(data_criacao)
    """,
    conn_id='delta_spark_sql',
    dag=dag_datalake
)

bronze_task >> silver_task >> gold_sql
```

---

## 📚 DOCUMENTAÇÃO E RECURSOS IMPORTANTES

| Tópico | Link Oficial |
|--------|--------------|
| Airflow Docs Principal | https://airflow.apache.org/docs/apache-airflow/stable/ |
| Operadores Disponíveis | https://airflow.apache.org/docs/apache-airflow-providers/packages-ref.html |
| Conceitos de DAGs | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags/ |
| Jinja Templating | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/variables.html |
| XCom (Task Communication) | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/xcoms.html |
| Scheduling & Cron | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dag-run.html |
| AWS Providers | https://airflow.apache.org/docs/apache-airflow-providers-amazon/stable/ |
| Hooks & Connections | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/connections.html |

---

## 🎯 CONCEITOS CRÍTICOS PARA DOMINAR

1. **Templates Jinja**: `{{ ds }}`, `{{ yesterday_ds }}`, `{{ task_instance.xcom_pull() }}`
2. **Operadores Dinâmicos**: TaskGroup para evitar repetição de código
3. **Backfilling**: Executar DAGs para datas passadas
4. **Sensor**: Operadores que esperam por condições (ex: arquivo chegar)
5. **Branching**: Decisões condicionais no pipeline

---

## 📝 NOTAS FINAIS

Este guia cobre os fundamentos de Apache Airflow com foco em casos de uso reais de Engenharia de Dados. Os exemplos fornecidos são totalmente funcionais e podem ser adaptados para seus pipelines específicos.

**Próximos passos:**
- Aprofundar em dbt integration com Airflow
- Estudar Sensors e Triggers
- Explorar TaskGroups para reutilização de código
- Implementar custom Operators para sua stack específica