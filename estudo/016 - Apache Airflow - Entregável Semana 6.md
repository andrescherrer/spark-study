# Apache Airflow: Guia Completo para Engenharia de Dados

## 1. O QUE É APACHE AIRFLOW

Apache Airflow é uma plataforma de orquestração de workflows declarativa, escalável e flexível. Diferente de schedulers simples (cron, por exemplo), Airflow permite definir dependências complexas entre tarefas, monitoramento em tempo real e retry inteligente.

**Por que não apenas cron ou scripts?**
- Cron é linear e difícil de debugar
- Airflow oferece DAGs (Directed Acyclic Graphs) que representam visualmente dependências
- Recuperação automática de falhas
- Auditoria completa (quem rodou o quê, quando)
- Interface web intuitiva

---

## 2. CONCEITOS FUNDAMENTAIS

### 2.1 DAG (Directed Acyclic Graph)

```python
from airflow import DAG
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-team',
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'start_date': datetime(2025, 1, 1)
}

dag = DAG(
    dag_id='meu_pipeline_dados',
    default_args=default_args,
    schedule_interval='0 2 * * *',  # 2AM todo dia
    catchup=False
)
```

**Documentação:** https://airflow.apache.org/docs/apache-airflow/stable/concepts/dags.html

### 2.2 Task

Unidade individual de trabalho (executar SQL, fazer request HTTP, processar arquivo, etc)

```python
from airflow.operators.python import PythonOperator

def extract_data():
    print("Extraindo dados...")
    return {'records': 1000}

task1 = PythonOperator(
    task_id='extract',
    python_callable=extract_data,
    dag=dag
)
```

### 2.3 Dependências

```python
task1 >> task2 >> task3  # task2 começa depois de task1
[task1, task2] >> task3   # task3 começa depois de task1 E task2
```

---

## 3. ENTREGÁVEL DETALHADO (SEMANA 5-6)

### ✅ 3.1 DAG Funcionando 100% (1 Execução Completa)

Uma DAG em produção deve ter:

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.models import Variable
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

default_args = {
    'owner': 'data-engineering',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 15),
    'email': ['alertas@empresa.com'],
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'execution_timeout': timedelta(hours=1),
}

dag = DAG(
    dag_id='pipeline_vendas_producao',
    default_args=default_args,
    description='Pipeline de vendas - Extração, Transformação, Carga',
    schedule_interval='0 3 * * *',  # Roda 3AM todos os dias
    catchup=False,
    tags=['producao', 'vendas', 'crítico']
)

def extract_from_api():
    """Extrai dados da API de vendas"""
    import requests
    logger.info("Iniciando extração...")
    
    api_key = Variable.get("api_key")
    response = requests.get(
        'https://api.vendas.com/v1/sales',
        headers={'Authorization': f'Bearer {api_key}'}
    )
    
    if response.status_code == 200:
        logger.info(f"✓ Extraídos {len(response.json())} registros")
        return len(response.json())
    else:
        raise Exception(f"Erro na API: {response.status_code}")

def validate_data(**context):
    """Valida dados extraídos"""
    ti = context['task_instance']
    extracted_count = ti.xcom_pull(task_ids='extract')
    
    if extracted_count < 100:
        raise ValueError("Extração abaixo do esperado!")
    
    logger.info("✓ Validação passou")
    return True

def transform_and_load():
    """Transforma e carrega para Data Warehouse"""
    logger.info("Iniciando transformação...")
    # Simulando processamento
    return {'loaded_records': 950}

# TASKS
task_extract = PythonOperator(
    task_id='extract',
    python_callable=extract_from_api,
    dag=dag
)

task_validate = PythonOperator(
    task_id='validate',
    python_callable=validate_data,
    provide_context=True,
    dag=dag
)

task_transform = PythonOperator(
    task_id='transform_load',
    python_callable=transform_and_load,
    dag=dag
)

task_notify = BashOperator(
    task_id='notify_success',
    bash_command='echo "Pipeline completado com sucesso em {{ execution_date }}"',
    dag=dag
)

# DEPENDÊNCIAS
task_extract >> task_validate >> task_transform >> task_notify
```

**Documentação:**
- DAGs: https://airflow.apache.org/docs/apache-airflow/stable/concepts/dags.html
- Operators: https://airflow.apache.org/docs/apache-airflow/stable/operators-and-hooks-ref.html
- XCom (passar dados entre tasks): https://airflow.apache.org/docs/apache-airflow/stable/concepts/xcoms.html

---

### ✅ 3.2 Tests para Cada Task (pytest)

```python
# tests/test_pipeline_vendas.py
import pytest
from airflow.models import DAG
from airflow.utils import timezone
from datetime import datetime
from dags.pipeline_vendas import (
    extract_from_api,
    validate_data,
    transform_and_load
)
from unittest.mock import patch, MagicMock

@pytest.fixture
def dag():
    return DAG(
        dag_id='test_dag',
        start_date=timezone.utcnow()
    )

class TestExtractTask:
    @patch('requests.get')
    def test_extract_success(self, mock_get):
        """Testa extração bem-sucedida"""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = [
            {'id': 1, 'amount': 100},
            {'id': 2, 'amount': 200}
        ]
        mock_get.return_value = mock_response
        
        result = extract_from_api()
        assert result == 2
        mock_get.assert_called_once()

    @patch('requests.get')
    def test_extract_api_error(self, mock_get):
        """Testa falha na API"""
        mock_response = MagicMock()
        mock_response.status_code = 503
        mock_get.return_value = mock_response
        
        with pytest.raises(Exception):
            extract_from_api()

class TestValidateTask:
    def test_validate_success(self):
        """Testa validação com dados suficientes"""
        context = {
            'task_instance': MagicMock(
                xcom_pull=MagicMock(return_value=500)
            )
        }
        result = validate_data(**context)
        assert result is True

    def test_validate_insufficient_data(self):
        """Testa validação com dados insuficientes"""
        context = {
            'task_instance': MagicMock(
                xcom_pull=MagicMock(return_value=50)
            )
        }
        with pytest.raises(ValueError):
            validate_data(**context)

class TestTransformTask:
    def test_transform_returns_dict(self):
        """Testa se transformação retorna estrutura esperada"""
        result = transform_and_load()
        assert 'loaded_records' in result
        assert isinstance(result['loaded_records'], int)

# Executar: pytest tests/test_pipeline_vendas.py -v
```

**Documentação:**
- Testing Airflow: https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html#testing
- pytest: https://docs.pytest.org/

---

### ✅ 3.3 Logs Limpos no Airflow UI

Logs bem estruturados são críticos para debugar em produção:

```python
import logging
from airflow.utils.log.logging_config import LOGGING_CONFIG

# Configure logger customizado
logger = logging.getLogger(__name__)

def minha_task_com_logs():
    logger.info("="*50)
    logger.info("INICIANDO EXTRAÇÃO DE VENDAS")
    logger.info("="*50)
    
    try:
        logger.info("Conectando ao banco de dados...")
        # seu código aqui
        logger.info("✓ Conexão estabelecida")
        
    except Exception as e:
        logger.error(f"✗ ERRO: {str(e)}", exc_info=True)
        raise
    
    logger.info("="*50)
    logger.info("EXTRAÇÃO COMPLETADA COM SUCESSO")
    logger.info("="*50)
```

**Boas Práticas:**
- Use níveis corretos: `INFO`, `WARNING`, `ERROR`, `CRITICAL`
- Adicione timestamps automáticos
- Não logue dados sensíveis (senhas, tokens)
- Use separadores visuais para legibilidade

**Documentação:** https://airflow.apache.org/docs/apache-airflow/stable/logging-monitoring/logging-setup.html

---

### ✅ 3.4 README Documentando Tudo

```markdown
# Pipeline de Vendas - Airflow

## Visão Geral
Pipeline de orquestração de dados que extrai vendas da API, valida qualidade 
e carrega em Data Warehouse.

## Arquitetura
```
[API Vendas] → [Extract] → [Validate] → [Transform/Load] → [Notify]
```

## Requisitos
- Python 3.9+
- Apache Airflow 2.6+
- PostgreSQL (para metadata DB)

## Instalação

```bash
# 1. Criar ambiente
python -m venv venv
source venv/bin/activate

# 2. Instalar dependências
pip install -r requirements.txt

# 3. Inicializar banco de dados
airflow db init

# 4. Criar usuário admin
airflow users create \
    --username admin \
    --password admin123 \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com

# 5. Iniciar scheduler e webserver
airflow scheduler &
airflow webserver --port 8080
```

## Variáveis de Ambiente

No Airflow UI, configure:
- `api_key`: Chave da API de vendas
- `db_host`: Host do PostgreSQL
- `db_user`: Usuário do banco

## DAGs

### pipeline_vendas_producao
- **Schedule**: 3AM todos os dias
- **Owner**: data-engineering
- **Timeout**: 1 hora
- **Retries**: 2

## Monitoramento

- UI: http://localhost:8080
- Logs: `$AIRFLOW_HOME/logs/`
- Alertas: alertas@empresa.com

## Troubleshooting

**Problema**: Task falha com timeout
**Solução**: Aumentar `execution_timeout` ou otimizar SQL

**Problema**: DAG não aparece na UI
**Solução**: Verificar AIRFLOW_HOME e permissions

## Contato
data-engineering@empresa.com
```

---

### ✅ 3.5 GitHub com Histórico Limpo

Estrutura ideal:

```
projeto-airflow/
├── dags/
│   ├── __init__.py
│   ├── pipeline_vendas.py
│   ├── pipeline_clientes.py
│   └── utils/
│       ├── validators.py
│       ├── extractors.py
│       └── loaders.py
├── tests/
│   ├── conftest.py
│   ├── test_pipeline_vendas.py
│   └── test_validators.py
├── config/
│   ├── airflow.cfg
│   └── logging_config.yaml
├── .gitignore
├── requirements.txt
├── README.md
└── Makefile
```

**.gitignore** (importante!):
```
# Python
__pycache__/
*.py[cod]
*.egg-info/
.pytest_cache/

# Airflow
logs/
airflow.db
airflow_settings.yaml

# IDE
.vscode/
.idea/
*.swp

# Environment
.env
venv/
```

**Commits limpos**:
```bash
git add dags/
git commit -m "feat: add extract task for sales API"

git add tests/
git commit -m "test: add unit tests for validators"

git add README.md
git commit -m "docs: update deployment instructions"
```

---

## 4. EXEMPLOS DO MUNDO REAL (Engenharia de Dados)

### 📊 Exemplo 1: Pipeline ETL com Databricks + Delta Lake

Cenário: Empresa de e-commerce processando 10M de transações/dia

```python
from airflow import DAG
from airflow.providers.databricks.operators.databricks_sql import DatabricksSqlOperator
from airflow.providers.databricks.operators.databricks_notebook import DatabricksNotebookOperator
from datetime import datetime, timedelta

dag = DAG(
    dag_id='ecommerce_etl_databricks',
    start_date=datetime(2025, 1, 1),
    schedule_interval='0 4 * * *',  # 4AM UTC
    max_active_runs=1,  # Previne execuções paralelas
)

# EXTRACT: Carregar dados do S3
extract_task = DatabricksNotebookOperator(
    task_id='extract_from_s3',
    notebook_path='/Users/data-team/notebooks/01_extract',
    job_cluster_config={
        'spark_version': '13.3.x-scala2.12',
        'node_type_id': 'i3.xlarge',
        'num_workers': 4
    },
    dag=dag
)

# TRANSFORM: Executar SQL no Databricks
transform_task = DatabricksSqlOperator(
    task_id='transform_transactions',
    sql="""
    CREATE OR REPLACE TABLE gold_layer.transactions_daily AS
    SELECT 
        DATE(timestamp) as transaction_date,
        customer_id,
        COUNT(*) as num_transactions,
        SUM(amount) as total_amount,
        AVG(amount) as avg_amount
    FROM silver_layer.transactions
    WHERE DATE(timestamp) = CAST('{{ ds }}' AS DATE)
    GROUP BY 1, 2
    """,
    dag=dag
)

# DATA QUALITY: Validar dados transformados
dq_task = DatabricksSqlOperator(
    task_id='quality_checks',
    sql="""
    SELECT 
        CASE 
            WHEN COUNT(*) = 0 THEN RAISE_ERROR('Sem dados!')
            WHEN COUNT(*) < 1000000 THEN RAISE_ERROR('Abaixo do threshold!')
            ELSE 'OK'
        END
    FROM gold_layer.transactions_daily
    WHERE transaction_date = CAST('{{ ds }}' AS DATE)
    """,
    dag=dag
)

extract_task >> transform_task >> dq_task
```

**Padrão importante**: Esse pipeline segue o paradigma **Bronze/Silver/Gold**:
- **Bronze**: Dados crus do S3
- **Silver**: Dados limpos e validados
- **Gold**: Dados prontos para BI/Analytics

**Documentação**: https://docs.databricks.com/en/workflows/jobs/how-to/use-airflow-integration.html

---

### 📊 Exemplo 2: Pipeline de Machine Learning com Monitoramento

Cenário: Retraining de modelo de churn diariamente

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.slack.operators.slack_webhook import SlackWebhookOperator
from datetime import datetime, timedelta
import json

def prepare_training_data(**context):
    """Prepara dados para treino do modelo"""
    import pandas as pd
    from sklearn.preprocessing import StandardScaler
    
    # Carregar dados do último mês
    df = pd.read_sql(
        "SELECT * FROM customers WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'",
        connection_string='postgresql://user:pass@host/db'
    )
    
    # Feature engineering
    df['avg_monthly_spend'] = df.groupby('customer_id')['amount'].transform('mean')
    df['days_since_last_purchase'] = (datetime.now() - df['last_purchase']).dt.days
    
    # Normalizar
    scaler = StandardScaler()
    features = scaler.fit_transform(df[['avg_monthly_spend', 'days_since_last_purchase']])
    
    return {
        'rows_prepared': len(df),
        'features_shape': features.shape
    }

def train_model(**context):
    """Treina modelo de churn"""
    from sklearn.ensemble import RandomForestClassifier
    import joblib
    
    ti = context['task_instance']
    data_info = ti.xcom_pull(task_ids='prepare_data')
    
    print(f"Treinando com {data_info['rows_prepared']} registros...")
    
    # Carregar dados e treinar
    model = RandomForestClassifier(n_estimators=100, max_depth=10)
    # ... código de treinamento ...
    
    # Salvar modelo
    joblib.dump(model, '/models/churn_model_v1.pkl')
    
    return {
        'model_accuracy': 0.89,
        'model_version': 'v1',
        'timestamp': datetime.now().isoformat()
    }

def evaluate_model(**context):
    """Avalia performance do modelo"""
    ti = context['task_instance']
    model_info = ti.xcom_pull(task_ids='train_model')
    
    accuracy = model_info['model_accuracy']
    
    if accuracy < 0.85:
        raise ValueError(f"Modelo com acurácia baixa: {accuracy}")
    
    return model_info

def notify_success(**context):
    """Notifica sucesso no Slack"""
    ti = context['task_instance']
    model_info = ti.xcom_pull(task_ids='evaluate_model')
    
    message = f"""
    ✅ Pipeline ML - Churn Prediction
    
    • Acurácia: {model_info['model_accuracy']*100:.2f}%
    • Versão: {model_info['model_version']}
    • Timestamp: {model_info['timestamp']}
    """
    
    return message

dag = DAG(
    dag_id='ml_churn_retraining',
    start_date=datetime(2025, 1, 1),
    schedule_interval='0 2 * * *',  # 2AM UTC
    catchup=False,
    tags=['ml', 'churn-prediction', 'producao']
)

t1 = PythonOperator(
    task_id='prepare_data',
    python_callable=prepare_training_data,
    dag=dag
)

t2 = PythonOperator(
    task_id='train_model',
    python_callable=train_model,
    provide_context=True,
    dag=dag
)

t3 = PythonOperator(
    task_id='evaluate_model',
    python_callable=evaluate_model,
    provide_context=True,
    dag=dag
)

t4 = PythonOperator(
    task_id='notify',
    python_callable=notify_success,
    provide_context=True,
    dag=dag
)

t1 >> t2 >> t3 >> t4
```

**Conceitos importantes**:
- **Model versioning**: Sempre versionem modelos em produção
- **Drift detection**: Monitore queda de acurácia ao longo do tempo
- **Notificações**: Alerts em tempo real são críticos

---

### 📊 Exemplo 3: Dynamic DAG com Multiple Databases

Cenário: Sincronizar dados de 50 lojas diferentes para data warehouse central

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import json

# Configuração dinâmica
STORES_CONFIG = [
    {'store_id': 'STORE_001', 'region': 'SP', 'db_host': 'db-sp-01.internal'},
    {'store_id': 'STORE_002', 'region': 'RJ', 'db_host': 'db-rj-01.internal'},
    # ... 48 more stores
]

def create_dynamic_dag():
    dag = DAG(
        dag_id='multi_store_sync',
        start_date=datetime(2025, 1, 1),
        schedule_interval='0 22 * * *',  # 10PM UTC
        catchup=False,
    )
    
    # Tarefa de sincronização geral (começa tudo)
    start_task = PythonOperator(
        task_id='start_sync',
        python_callable=lambda: print("Iniciando sincronização de todas as lojas"),
        dag=dag
    )
    
    # Cria uma task para cada loja
    extract_tasks = []
    for store_config in STORES_CONFIG:
        task = PythonOperator(
            task_id=f"extract_store_{store_config['store_id']}",
            python_callable=extract_store_data,
            op_kwargs={'store_config': store_config},
            pool='db_connections',  # Limita conexões paralelas
            pool_slots=1,
            dag=dag
        )
        extract_tasks.append(task)
        start_task >> task
    
    # Task final que espera todas as extrações
    consolidate_task = PythonOperator(
        task_id='consolidate_all_stores',
        python_callable=consolidate_data,
        trigger_rule='all_success',  # Só roda se TODAS as tasks anterior sucederam
        dag=dag
    )
    
    extract_tasks >> consolidate_task
    
    return dag

def extract_store_data(store_config):
    """Extrai dados de uma loja específica"""
    import psycopg2
    
    print(f"Extraindo dados de {store_config['store_id']}...")
    
    conn = psycopg2.connect(
        host=store_config['db_host'],
        database='vendas_local',
        user='sync_user',
        password='encrypted_pass'
    )
    
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM transactions WHERE DATE(created_at) = CURRENT_DATE")
    rows = cursor.fetchall()
    
    print(f"✓ {len(rows)} registros extraídos de {store_config['store_id']}")
    conn.close()
    
    return len(rows)

def consolidate_data():
    """Consolida todos os dados no Data Warehouse"""
    print("Consolidando dados de todas as lojas no Data Warehouse...")
    # INSERT INTO data_warehouse SELECT * FROM staging_area ...

# Criar DAG dinamicamente
globals()['multi_store_sync'] = create_dynamic_dag()
```

**Padrões importantes aqui**:
- **Pool**: Controla quantas tasks rodam em paralelo (evita sobrecarregar banco)
- **Trigger Rules**: `all_success`, `all_failed`, `one_success`, etc
- **Dynamic DAGs**: Escalável para N lojas

---

### 📊 Exemplo 4: Pipeline com Sensor (Aguardar Arquivo)

Cenário: Esperar arquivo de parceiro chegar no S3 antes de processar

```python
from airflow import DAG
from airflow.sensors.s3_key_sensor import S3KeySensor
from airflow.operators.python import PythonOperator
from airflow.providers.amazon.aws.transfers.s3_to_redshift import S3ToRedshiftOperator
from datetime import datetime, timedelta

dag = DAG(
    dag_id='partner_data_pipeline',
    start_date=datetime(2025, 1, 1),
    schedule_interval='0 6 * * *',
    catchup=False,
)

# SENSOR: Aguardar arquivo do parceiro
wait_for_file = S3KeySensor(
    task_id='wait_for_partner_file',
    bucket_name='data-lake-prod',
    bucket_key='partners/acme_corp/sales_{{ ds_nodash }}.csv',
    aws_conn_id='aws_default',
    poke_interval=60,  # Verifica a cada 60 segundos
    timeout=3600,  # Timeout após 1 hora
    mode='poke',  # ou 'reschedule' para tarefas longas
    dag=dag
)

# PROCESS: Depois que arquivo chegar
def process_partner_data():
    import pandas as pd
    from s3fs import S3FileSystem
    
    s3 = S3FileSystem()
    df = pd.read_csv(
        's3://data-lake-prod/partners/acme_corp/sales_{{ ds_nodash }}.csv'
    )
    
    # Validações
    required_columns = ['id', 'amount', 'date']
    if not all(col in df.columns for col in required_columns):
        raise ValueError(f"Colunas faltando! Esperadas: {required_columns}")
    
    print(f"✓ {len(df)} registros validados")
    
    # Salvar em staging
    df.to_parquet(
        's3://data-lake-prod/staging/acme_corp_{{ ds_nodash }}.parquet'
    )

process_task = PythonOperator(
    task_id='process_partner_data',
    python_callable=process_partner_data,
    dag=dag
)

# LOAD: Carregar para Redshift
load_task = S3ToRedshiftOperator(
    task_id='load_to_redshift',
    s3_bucket='data-lake-prod',
    s3_key='staging/acme_corp_{{ ds_nodash }}.parquet',
    schema='staging',
    table='partner_sales_raw',
    copy_options=['PARQUET'],
    redshift_conn_id='redshift_prod',
    dag=dag
)

wait_for_file >> process_task >> load_task
```

**Conceitos**:
- **Sensors**: Tarefas que esperam por eventos (arquivo, banco de dados, API response)
- **Mode**: `poke` (polling contínuo) vs `reschedule` (libera worker e volta depois)
- **SLA**: Adicionar `sla=timedelta(hours=2)` para alertar atrasos

---

## 5. ESTRUTURA PROFISSIONAL COMPLETA

```python
# dags/config/settings.py
from enum import Enum

class Environment(Enum):
    DEV = "dev"
    STAGING = "staging"
    PRODUCTION = "production"

class AirflowConfig:
    ENV = Environment.PRODUCTION
    MAX_ACTIVE_RUNS = 1 if ENV == Environment.PRODUCTION else 5
    EMAIL_ON_FAILURE = ['alertas@empresa.com']
    
    # Database connections
    DB_CONFIGS = {
        'staging': 'postgresql://user:pass@db-staging:5432/data_lake',
        'production': 'postgresql://user:pass@db-prod:5432/data_lake',
    }

# dags/utils/email_alert.py
from airflow.utils.email import send_email_smtp

def send_failure_email(context):
    """Notificação customizada de falha"""
    task = context['task']
    exception = context.get('exception')
    
    send_email_smtp(
        to=['alertas@empresa.com'],
        subject=f"❌ Pipeline {context['dag'].dag_id} falhou",
        html_content=f"""
        <h2>Pipeline Failure Alert</h2>
        <p><b>Task:</b> {task.task_id}</p>
        <p><b>Error:</b> {str(exception)}</p>
        <p><b>Log:</b> {context['log_url']}</p>
        """
    )
```

---

## 6. RECURSOS ESSENCIAIS PARA ESTUDO

### Documentação Oficial

| Recurso | Link |
|---------|------|
| Apache Airflow Docs | https://airflow.apache.org/docs/apache-airflow/stable/ |
| Concepts & Architecture | https://airflow.apache.org/docs/apache-airflow/stable/concepts/overview.html |
| Best Practices | https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html |
| Providers | https://airflow.apache.org/docs/apache-airflow-providers/packages-ref.html |
| API Reference | https://airflow.apache.org/docs/apache-airflow/stable/_api/index.html |

### Cursos & Plataformas
- **Udemy**: "The Complete Hands-On Introduction to Apache Airflow"
- **DataCamp**: "Introduction to Data Orchestration"
- **Coursera**: "Data Pipelines with Apache Airflow"

### Livros
- "Fundamentals of Data Engineering" - Joe Reis & Matt Housley (capítulo sobre orchestration)
- "The Data Warehouse Toolkit" - Ralph Kimball (design patterns)

### Comunidade
- GitHub: https://github.com/apache/airflow
- Stack Overflow: tag `airflow`
- Apache Airflow Slack: https://s.apache.org/airflow-slack

---

## 7. CHECKLIST PARA SEMANA 5-6

```
SEMANA 5:
☐ Setup local Airflow (venv + pip)
☐ Entender DAGs, Tasks, Operators
☐ Criar primeira DAG simples
☐ Testar localmente com `airflow dags list`
☐ Explorar Airflow UI (localhost:8080)
☐ Estudar XCom (passar dados entre tasks)

SEMANA 6:
☐ Implementar DAG com tratamento de erro
☐ Adicionar logs estruturados
☐ Escrever testes unitários (pytest)
☐ Configurar alertas (email/Slack)
☐ Commit GitHub com histórico limpo
☐ Documentar README
☐ Fazer deploy em ambiente staging
☐ 1 execução 100% completa do pipeline

ENTREGÁVEL FINAL:
✓ DAG prod-ready
✓ Testes com cobertura > 80%
✓ Logs legíveis
✓ Documentação clara
✓ GitHub organizado
✓ README com instruções
```

---

## Nota Final

Como você programa majoritariamente em PHP, não se preocupe! Python + Airflow é o padrão de facto em data engineering. Mas você pode criar um wrapper em PHP que dispara tasks Airflow via API REST se necessário.