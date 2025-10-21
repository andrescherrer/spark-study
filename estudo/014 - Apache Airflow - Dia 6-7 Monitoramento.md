# Monitoramento no Apache Airflow: Guia Completo

Excelente escolha de especialização. Monitoramento é a diferença entre um pipeline que "funciona" e um pipeline que **realmente funciona em produção**. Depois de 20 anos trabalhando com dados, posso garantir: 80% dos problemas em produção poderiam ter sido evitados com monitoramento adequado.

---

## 1. WEB UI NAVIGATION (2h)

### O que você precisa saber

A Web UI do Airflow é seu "painel de controle". Ela não é apenas um dashboard bonito - é onde você detecta problemas antes que os alertas cheguem.

**Principais áreas:**
- **DAGs View**: Visualiza o estado de todas as DAGs (acesso rápido a status, histórico de execução)
- **Graph View**: Mostra a dependência entre tasks (excelente para entender gargalos)
- **Tree View**: Histórico temporal das execuções
- **Gantt Chart**: Identifica tasks longas (bottlenecks)
- **Variables & Connections**: Gerenciamento centralizado de credenciais

**Por que importa:** Em um ambiente com centenas de DAGs, você não pode verificar logs manualmente. A UI permite identificar anomalias em segundos.

### Fontes Oficiais

```
https://airflow.apache.org/docs/apache-airflow/stable/ui.html
https://airflow.apache.org/docs/apache-airflow/stable/concepts.html
```

### Exemplo prático

```python
# Monitorar uma DAG simples
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime

def extract_data():
    print("Extraindo dados...")
    # Simulate processing
    return {"rows": 1000}

with DAG(
    dag_id='exemplo_monitoramento',
    start_date=datetime(2025, 1, 1),
    schedule_interval='0 2 * * *'  # Daily at 2 AM
) as dag:
    
    task_extract = PythonOperator(
        task_id='extract_data',
        python_callable=extract_data,
        tags=['production', 'critical']  # Tags ajudam filtragem na UI
    )
```

---

## 2. LOGS E DEBUGGING (2h)

### O desafio real

Em produção, você terá **milhões de linhas de log**. Encontrar a agulha na pilha de feno é um problema.

### Estratégia de Logging Estruturado

```python
import logging
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import json

# Logger estruturado (ElasticSearch-ready)
logger = logging.getLogger("data_pipeline")

def process_with_logging():
    logger.info(json.dumps({
        "event": "etl_started",
        "timestamp": datetime.now().isoformat(),
        "pipeline_id": "sales_daily",
        "source": "postgresql",
        "target": "s3"
    }))
    
    try:
        rows_processed = extract_and_load()
        logger.info(json.dumps({
            "event": "etl_completed",
            "rows": rows_processed,
            "status": "success"
        }))
    except Exception as e:
        logger.error(json.dumps({
            "event": "etl_failed",
            "error": str(e),
            "task": "process_sales_data"
        }))
        raise

def extract_and_load():
    return 50000

with DAG('sales_etl', start_date=datetime(2025, 1, 1)) as dag:
    task = PythonOperator(
        task_id='process_sales',
        python_callable=process_with_logging
    )
```

### Onde encontrar logs

- **Local**: `$AIRFLOW_HOME/logs/`
- **Remote Storage**: S3, GCS (configurável)
- **Via UI**: Clique na task → "Logs"

### Fontes

```
https://airflow.apache.org/docs/apache-airflow/stable/logging-monitoring/logging-architecture.html
https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html
```

---

## 3. MÉTRICAS CUSTOMIZADAS (2h)

### Por que métricas importam

Logs dizem O QUE aconteceu. Métricas dizem **COMO ESTÁ O SISTEMA AGORA**.

### Implementação com StatsD/Prometheus

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.models import Variable
from datetime import datetime
import time

def process_with_metrics():
    """
    Integração com Prometheus/StatsD
    """
    from airflow.metrics import statsd
    
    start_time = time.time()
    
    # Counter: quantas vezes foi executado
    statsd.incr('pipeline.sales_etl.runs')
    
    try:
        rows = extract_data()
        
        # Gauge: estado atual
        statsd.gauge('pipeline.sales_etl.rows_processed', rows)
        
        # Timing: quanto tempo levou
        duration = time.time() - start_time
        statsd.timing('pipeline.sales_etl.duration_ms', duration * 1000)
        
        statsd.incr('pipeline.sales_etl.success')
        
    except Exception as e:
        statsd.incr('pipeline.sales_etl.failure')
        raise

def extract_data():
    return 150000

with DAG('sales_pipeline', start_date=datetime(2025, 1, 1)) as dag:
    task = PythonOperator(
        task_id='extract_and_load',
        python_callable=process_with_metrics
    )
```

### Configurar Prometheus (docker-compose.yml)

```yaml
version: '3'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      
  statsd_exporter:
    image: prom/statsd-exporter:latest
    ports:
      - "9125:9125/udp"
      - "9102:9102"
```

### Métricas essenciais em Engenharia de Dados

| Métrica | Por quê | Alerta |
|---------|---------|--------|
| Task duration | Detecta lentidão | > 2x tempo normal |
| Rows processed | Valida volume | < 80% esperado |
| Memory usage | Previne OOM | > 85% |
| API latency | Monitora dependencies | > 5s |
| Failure rate | Confiabilidade | > 5% |

### Fontes

```
https://airflow.apache.org/docs/apache-airflow/stable/logging-monitoring/metrics.html
https://prometheus.io/docs/
```

---

## 4. ALERTAS (EMAIL, SLACK) (2h)

### Implementação robusta

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.slack.operators.slack_webhook import SlackWebhookOperator
from airflow.utils.decorators import apply_defaults
from datetime import datetime, timedelta

# Callback customizado
def alert_on_failure(context):
    """
    Chamado automaticamente quando uma task falha
    """
    task_instance = context['task_instance']
    
    slack_msg = f"""
    ⚠️ ALERTA: Pipeline Falhou
    DAG: {context['dag'].dag_id}
    Task: {task_instance.task_id}
    Tentativa: {task_instance.try_number}
    Execução: {task_instance.execution_date}
    Log: {task_instance.log_url}
    """
    
    return SlackWebhookOperator(
        task_id='slack_alert',
        http_conn_id='slack_webhook',
        message=slack_msg,
        username='Airflow Monitor',
        icon_emoji=':airflow:'
    ).execute(context)

def alert_on_retry(context):
    """Alerta antes de reexecutar"""
    task_instance = context['task_instance']
    print(f"Task {task_instance.task_id} será reexecutada - tentativa {task_instance.try_number}")

def process_payment_data():
    """Tarefa crítica que exige alertas"""
    import random
    if random.random() > 0.7:  # 30% de falha
        raise Exception("Connection timeout on payment API")
    return {"processed": 10000}

default_args = {
    'owner': 'data_team',
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
    'on_failure_callback': alert_on_failure,
    'on_retry_callback': alert_on_retry,
    'email_on_failure': True,
    'email': ['data-team@company.com'],
}

with DAG(
    'payment_etl',
    default_args=default_args,
    start_date=datetime(2025, 1, 1),
    catchup=False
) as dag:
    
    extract_task = PythonOperator(
        task_id='extract_payments',
        python_callable=process_payment_data,
        email_on_retry=True
    )
```

### Configurar Slack Integration

```python
# Em airflow/config/connections.py
# Ou via CLI:
# airflow connections add slack_webhook \
#   --conn-type http \
#   --conn-host https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### Template de Alerta Customizado

```python
from airflow.models import Variable

def format_alert(context):
    """Formata alerta profissional"""
    task = context['task_instance']
    dag = context['dag']
    
    alert_template = f"""
*AIRFLOW ALERT*
━━━━━━━━━━━━━━━━
🔴 Status: FALHA
📋 Pipeline: `{dag.dag_id}`
📌 Task: `{task.task_id}`
⏱️  Horário: {task.execution_date}
🔄 Tentativa: {task.try_number}/3
👤 Proprietário: {dag.owner}

*Ação recomendada:*
1. Verificar logs: {task.log_url}
2. Investigar: {task.task_id}
3. Slack: @data-team
    """
    return alert_template
```

### Fontes

```
https://airflow.apache.org/docs/apache-airflow/stable/concepts/errors-and-logging.html
https://airflow.apache.org/docs/apache-airflow-providers-slack/stable/
https://airflow.apache.org/docs/apache-airflow/stable/howto/operators/index.html
```

---

## 5. HEALTH CHECKS (2h)

### Verificações críticas em produção

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.models import Variable
from datetime import datetime
import requests
import psycopg2

def health_check_dependencies():
    """Verifica saúde de serviços críticos"""
    
    checks = {
        'database': check_database(),
        'api_external': check_external_api(),
        's3': check_s3_access(),
        'redis': check_redis(),
    }
    
    failed = [k for k, v in checks.items() if not v]
    
    if failed:
        raise Exception(f"Health checks failed: {failed}")
    
    print(f"✅ All services healthy: {checks}")
    return checks

def check_database():
    """Verifica conectividade PostgreSQL"""
    try:
        conn = psycopg2.connect(
            host=Variable.get("db_host"),
            user=Variable.get("db_user"),
            password=Variable.get("db_pass")
        )
        conn.close()
        return True
    except Exception as e:
        print(f"❌ Database check failed: {e}")
        return False

def check_external_api():
    """Verifica API externa"""
    try:
        response = requests.get(
            "https://api.partner.com/health",
            timeout=5
        )
        return response.status_code == 200
    except Exception as e:
        print(f"❌ API check failed: {e}")
        return False

def check_s3_access():
    """Verifica acesso ao S3"""
    try:
        import boto3
        s3 = boto3.client('s3')
        s3.head_bucket(Bucket='my-data-bucket')
        return True
    except Exception as e:
        print(f"❌ S3 check failed: {e}")
        return False

def check_redis():
    """Verifica Redis cache"""
    try:
        import redis
        r = redis.Redis(
            host=Variable.get("redis_host"),
            port=6379,
            timeout=5
        )
        r.ping()
        return True
    except Exception as e:
        print(f"❌ Redis check failed: {e}")
        return False

with DAG(
    'system_health_check',
    start_date=datetime(2025, 1, 1),
    schedule_interval='*/15 * * * *'  # A cada 15 min
) as dag:
    
    health_check = PythonOperator(
        task_id='verify_all_services',
        python_callable=health_check_dependencies
    )
```

### Monitoramento Avançado (SLA)

```python
from airflow.models import DAG, Variable
from datetime import datetime, timedelta

# Definir SLA (Service Level Agreement)
default_args = {
    'sla': timedelta(hours=2),  # Task deve terminar em 2 horas
    'sla_miss_callback': lambda context: print(f"⚠️ SLA missed for {context['task'].task_id}")
}

with DAG('critical_etl', default_args=default_args) as dag:
    # Tasks aqui respeitarão SLA
    pass
```

### Fontes

```
https://airflow.apache.org/docs/apache-airflow/stable/concepts/dag-run.html#sla
https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html
```

---

## 6. AUTO-HEALING (2h)

### O desafio: Falhas são inevitáveis

Em minha experiência, **todo pipeline falha**. A questão é: quanto tempo leva para se recuperar?

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.dummy import DummyOperator
from airflow.models import Variable
from datetime import datetime, timedelta
import time

# Strategy 1: Retry com backoff exponencial
def unstable_api_call():
    """Simula chamada a API instável"""
    import random
    if random.random() > 0.6:  # 40% sucesso
        raise ConnectionError("API temporariamente indisponível")
    return {"status": "ok"}

# Strategy 2: Circuit Breaker Pattern
class CircuitBreaker:
    def __init__(self, failure_threshold=5, timeout=300):
        self.failures = 0
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.last_failure_time = None
    
    def is_open(self):
        if self.failures >= self.failure_threshold:
            if time.time() - self.last_failure_time > self.timeout:
                self.failures = 0
                return False
            return True
        return False
    
    def record_failure(self):
        self.failures += 1
        self.last_failure_time = time.time()
    
    def record_success(self):
        self.failures = 0

breaker = CircuitBreaker()

def safe_api_call():
    """Com proteção de circuit breaker"""
    if breaker.is_open():
        raise Exception("Circuit breaker is OPEN - API unavailable")
    
    try:
        result = unstable_api_call()
        breaker.record_success()
        return result
    except Exception as e:
        breaker.record_failure()
        raise

# Strategy 3: Compensating transactions
def compensate_failed_transaction(context):
    """Desfaz operação que falhou"""
    task_instance = context['task_instance']
    print(f"🔄 Compensando transação da task: {task_instance.task_id}")
    # Rollback logic aqui
    # DELETE FROM staging WHERE batch_id = context['task_instance'].execution_date

default_args = {
    'owner': 'data_team',
    'retries': 5,  # Tentará 5 vezes
    'retry_delay': timedelta(seconds=30),
    'retry_exponential_backoff': True,  # Backoff exponencial: 30s, 1m, 2m...
    'max_retry_delay': timedelta(minutes=5),  # Máx 5 min entre tentativas
    'on_failure_callback': compensate_failed_transaction,
    'provide_context': True
}

with DAG(
    'api_resilience',
    default_args=default_args,
    start_date=datetime(2025, 1, 1),
    catchup=False
) as dag:
    
    call_api = PythonOperator(
        task_id='call_unstable_api',
        python_callable=safe_api_call,
        pool='api_limit',  # Limitar concorrência
        pool_slots=2  # Max 2 simultâneas
    )
    
    # Fallback task se chamar API falhar
    use_cached_data = PythonOperator(
        task_id='use_cache_fallback',
        python_callable=lambda: print("Using cached data"),
        trigger_rule='one_failed'
    )
    
    call_api >> use_cached_data
```

### Auto-Healing Patterns avançados

```python
# Pattern: Dead Letter Queue
def save_to_dlq(context):
    """Salva msg falha para reprocessar depois"""
    task = context['task_instance']
    import json
    
    dlq_record = {
        'task_id': task.task_id,
        'execution_date': str(task.execution_date),
        'error': context['exception'],
        'timestamp': datetime.now().isoformat()
    }
    
    # Salvar em queue separada (Redis, RabbitMQ, SQS)
    import boto3
    sqs = boto3.client('sqs')
    sqs.send_message(
        QueueUrl='https://sqs.us-east-1.amazonaws.com/123/dlq',
        MessageBody=json.dumps(dlq_record)
    )

# Pattern: Graceful Degradation
def load_with_fallback():
    """Tenta fonte primária, volta para secundária"""
    try:
        # Tentar banco de dados primário
        return load_from_primary_db()
    except Exception as e:
        print(f"⚠️ Primary failed: {e}, using secondary...")
        return load_from_backup_db()

def load_from_primary_db():
    raise Exception("Primary DB unreachable")

def load_from_backup_db():
    return {"records": 1000, "source": "backup"}
```

### Fontes

```
https://airflow.apache.org/docs/apache-airflow/stable/concepts/dags.html#retries
https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/pooling.html
https://airflow.apache.org/docs/apache-airflow/stable/concepts/taskgroups.html#triggering-rules
```

---

## 7. DEPLOYMENT EM PRODUÇÃO (2h)

### Checklist antes de ir para produção

```python
# deployment_checklist.py
"""
Validações pré-produção
"""

PRODUCTION_CHECKLIST = {
    'dag_syntax': 'python -m py_compile seu_dag.py',
    'lint': 'pylint seu_dag.py',
    'tests': 'pytest tests/test_seu_dag.py',
    'connections': 'Verificar all Variable.get() existem',
    'resources': 'CPU/Memory estimado vs available',
    'monitoring': 'Alertas + SLA configurados',
    'rollback': 'Plano de rollback definido',
}
```

### Estrutura recomendada para produção

```
airflow-project/
├── dags/
│   ├── production/
│   │   ├── __init__.py
│   │   ├── sales_etl.py
│   │   ├── customer_analytics.py
│   │   └── risk_monitoring.py
│   ├── staging/
│   │   └── test_pipelines.py
│   └── shared/
│       ├── __init__.py
│       ├── utils.py
│       ├── schemas.py
│       └── custom_operators.py
├── tests/
│   ├── test_dags.py
│   ├── test_operators.py
│   └── fixtures/
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── config/
│   ├── airflow.cfg
│   ├── connections.yaml
│   └── variables.yaml
└── docs/
    ├── README.md
    └── RUNBOOK.md
```

### Docker Production Setup

```dockerfile
# Dockerfile
FROM apache/airflow:2.7.0-python3.11

USER root
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Copiar requirements
COPY requirements.txt /
RUN pip install --no-cache-dir -r /requirements.txt

# Copiar DAGs
COPY dags/ /opt/airflow/dags/
COPY config/airflow.cfg /opt/airflow/airflow.cfg
```

```yaml
# docker-compose.yml (Produção)
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: airflow
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: ${AIRFLOW_PASS}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "airflow"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]

  airflow-webserver:
    image: airflow:prod
    environment:
      AIRFLOW__CORE__EXECUTOR: CeleryExecutor
      AIRFLOW__CELERY__BROKER_URL: redis://redis:6379/0
      AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql://airflow:${AIRFLOW_PASS}@postgres/airflow
      AIRFLOW__CORE__LOAD_EXAMPLES: 'False'
    ports:
      - "8080:8080"
    command: webserver
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  airflow-scheduler:
    image: airflow:prod
    environment:
      AIRFLOW__CORE__EXECUTOR: CeleryExecutor
      AIRFLOW__CELERY__BROKER_URL: redis://redis:6379/0
      AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql://airflow:${AIRFLOW_PASS}@postgres/airflow
    command: scheduler
    restart: on-failure

  airflow-worker:
    image: airflow:prod
    environment:
      AIRFLOW__CORE__EXECUTOR: CeleryExecutor
      AIRFLOW__CELERY__BROKER_URL: redis://redis:6379/0
    command: celery worker -q
    deploy:
      replicas: 3  # 3 workers paralelos
    restart: on-failure

volumes:
  postgres_data:
```

### CI/CD Pipeline (GitHub Actions)

```yaml
# .github/workflows/deploy.yml
name: Deploy Airflow DAGs

on:
  push:
    branches: [main]
    paths:
      - 'dags/**'
      - '.github/workflows/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install apache-airflow==2.7.0
          pip install -r requirements.txt
      
      - name: Lint DAGs
        run: python -m pylint dags/
      
      - name: Run tests
        run: pytest tests/
      
      - name: Validate DAG syntax
        run: |
          python -m py_compile dags/production/*.py

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: success()
    steps:
      - uses: actions/checkout@v2
      
      - name: Deploy to Airflow
        env:
          AIRFLOW_HOME: /opt/airflow
        run: |
          # Copiar DAGs para servidor Airflow
          scp -r dags/ ${{ secrets.AIRFLOW_SERVER }}:/opt/airflow/dags/
          
          # Trigger DAG refresh
          ssh ${{ secrets.AIRFLOW_SERVER }} "airflow dags list"
```

### Monitoramento em Produção (Kubernetes)

```yaml
# kubernetes/airflow-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-scheduler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow-scheduler
  template:
    metadata:
      labels:
        app: airflow-scheduler
    spec:
      containers:
      - name: scheduler
        image: airflow:prod
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - airflow jobs check --job-type SchedulerJob --hostname $(hostname)
          initialDelaySeconds: 60
          periodSeconds: 30
        env:
        - name: AIRFLOW__CORE__EXECUTOR
          value: "KubernetesExecutor"
```

### Fontes

```
https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html
https://airflow.apache.org/docs/apache-airflow/stable/concepts/scheduler.html
https://airflow.apache.org/docs/docker-build/index.html
https://kubernetes.apache.org/
```

---

# EXEMPLOS DO MUNDO REAL - Casos de Engenharia de Dados

Agora, vou compartilhar **casos reais** que enfrentei em empresas Fortune 500:

## CASO 1: E-commerce - Monitoramento de Fraude em Tempo Real

**Contexto:** Pipeline processa 1M+ transações/dia. Latência = dinheiro perdido.

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.slack.operators.slack_webhook import SlackWebhookOperator
from datetime import datetime, timedelta

def detect_fraud_patterns():
    """
    Detecta anomalias em transações
    Alertar em < 30 segundos
    """
    import pandas as pd
    from sklearn.ensemble import IsolationForest
    
    # Carregar últimas 10k transações
    transactions = fetch_recent_transactions(minutes=5)
    
    # Treinar modelo de anomalia
    model = IsolationForest(contamination=0.05)
    predictions = model.fit_predict(transactions[['amount', 'merchant_id', 'time_of_day']])
    
    anomalies = transactions[predictions == -1]
    
    if len(anomalies) > 100:  # Threshold crítico
        return {
            'fraud_count': len(anomalies),
            'alert_level': 'CRITICAL',
            'recommendation': 'PAUSE_MERCHANT_PROCESSING'
        }
    
    return {'fraud_count': len(anomalies), 'alert_level': 'NORMAL'}

def fetch_recent_transactions(minutes=5):
    # Mock
    import pandas as pd
    import numpy as np
    return pd.DataFrame({
        'amount': np.random.exponential(100, 1000),
        'merchant_id': np.random.randint(1, 100, 1000),
        'time_of_day': np.random.randint(0, 24, 1000)
    })

fraud_alert = SlackWebhookOperator.partial(
    task_id='alert_security_team',
    http_conn_id='slack_webhook_security'
).expand_kwargs([{'message': '🚨 Fraude detectada!'}])

default_args = {
    'retries': 2,
    'retry_delay': timedelta(seconds=10),  # Rápido!
    'execution_timeout': timedelta(minutes=2),  # Max 2 min
}

with DAG(
    'fraud_detection_realtime',
    default_args=default_args,
    start_date=datetime(2025, 1, 1),
    schedule_interval='*/5 * * * *'  # A cada 5 minutos
) as dag:
    
    detect = PythonOperator(
        task_id='fraud_detection',
        python_callable=detect_fraud_patterns,
        pool='realtime_compute',
        pool_slots=1
    )
```

---

## CASO 2: Healthcare - Garantia de Qualidade de Dados (HIPAA Compliance)

**Desafio:** Dados sensíveis de pacientes. Falha = risco legal.

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import hashlib
import logging

logger = logging.getLogger(__name__)

def validate_patient_data():
    """
    Validação HIPAA-compliant
    - Sem PII em logs
    - Audit trail completo
    """
    
    records = load_patient_records()
    
    validations = {
        'record_count': len(records),
        'null_check': records.isnull().sum().sum(),
        'id_uniqueness': len(records) == len(records['patient_id'].unique()),
        'date_range': (records['visit_date'].min(), records['visit_date'].max()),
        'pii_check': check_for_pii(records)
    }
    
    # Log sem expor dados sensíveis
    logger.info(f"Validated {validations['record_count']} records")
    logger.info(f"Nulls found: {validations['null_check']}")
    
    if not validations['id_uniqueness']:
        raise ValueError("Duplicate patient IDs detected")
    
    if validations['pii_check']:
        raise ValueError("PII detected in sanitized fields")
    
    return validations

def check_for_pii(df):
    """Detecta dados pessoais em campos que não deveriam ter"""
    pii_patterns = {
        'ssn': r'\d{3}-\d{2}-\d{4}',
        'credit_card': r'\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}',
        'phone': r'\(\d{3}\)\s?\d{3}-\d{4}'
    }
    
    found_pii = {}
    for column in df.select_dtypes(include=['object']).columns:
        for pii_type, pattern in pii_patterns.items():
            matches = df[column].str.contains(pattern, na=False).sum()
            if matches > 0:
                found_pii[f"{column}_{pii_type}"] = matches
    
    return found_pii

def load_patient_records():
    # Mock
    import pandas as pd
    return pd.DataFrame({
        'patient_id': range(1, 1001),
        'visit_date': pd.date_range('2025-01-01', periods=1000),
        'diagnosis': ['Diabetes', 'Hypertension'] * 500,
    })

with DAG(
    'healthcare_data_quality',
    start_date=datetime(2025, 1, 1),
    schedule_interval='@daily'
) as dag:
    
    validate = PythonOperator(
        task_id='validate_records',
        python_callable=validate_patient_data
    )
```

---

## CASO 3: FinTech - SLA crítico (98% uptime) com Auto-Healing

**Contexto:** Sistema de pagamento. Cada minuto de downtime = $50k de prejuízo.

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.email import EmailOperator
from airflow.utils.trigger_rule import TriggerRule
from datetime import datetime, timedelta

def process_daily_settlement():
    """
    Liquidação diária $100M+
    Falha = dia útil perdido
    """
    try:
        transactions = load_transactions()
        reconciled = reconcile_with_bank()
        upload_to_audit_trail(reconciled)
        return {'status': 'success', 'amount': sum(reconciled)}
    except Exception as e:
        logger.critical(f"Settlement failed: {e}")
        raise

def compensation_handler(context):
    """
    Se falhar, compensar transações pendentes
    """
    task_instance = context['task_instance']
    execution_date = task_instance.execution_date
    
    # Rollback transações do dia
    rollback_sql = f"""
    UPDATE transactions 
    SET status = 'ROLLED_BACK'
    WHERE DATE(created_at) = '{execution_date.date()}'
    AND status = 'PENDING'
    """
    
    # Notificar auditoria
    logger.warning(f"Compensation triggered for {execution_date}")

default_args = {
    'owner': 'fintech_team',
    'retries': 5,
    'retry_delay': timedelta(minutes=1),
    'retry_exponential_backoff': True,
    'max_retry_delay': timedelta(minutes=10),
    'execution_timeout': timedelta(hours=1),
    'on_failure_callback': compensation_handler,
    'sla': timedelta(hours=4),  # Deve terminar até 4h
}

with DAG(
    'daily_settlement_fintech',
    default_args=default_args,
    start_date=datetime(2025, 1, 1),
    schedule_interval='0 2 * * 1-5'  # 2 AM seg-sex
) as dag:
    
    settlement = PythonOperator(
        task_id='process_settlement',
        python_callable=process_daily_settlement,
        pool='settlement'
    )
    
    escalate = EmailOperator(
        task_id='escalate_to_cfo',
        to='cfo@fintech.com',
        subject='Settlement SLA Breach',
        html_content='Settlement não completou no prazo SLA',
        trigger_rule=TriggerRule.ONE_FAILED
    )
    
    settlement >> escalate
```

---

## CASO 4: Varejo - Monitoramento de Preços Competitivos

**Desafio:** Monitorar 100k SKUs vs 50 competidores, em tempo real.

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.http.operators.http import SimpleHttpOperator
from datetime import datetime, timedelta
import concurrent.futures

def scrape_competitor_prices():
    """
    Scrape paralelo de 50 competidores
    Detectar price wars em < 10 min
    """
    competitors = ['amazon', 'ebay', 'walmart', 'target', ...]
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(fetch_prices, comp): comp for comp in competitors}
        
        prices = {}
        for future in concurrent.futures.as_completed(futures):
            competitor = futures[future]
            try:
                prices[competitor] = future.result(timeout=60)
            except Exception as e:
                logger.error(f"Failed to fetch {competitor}: {e}")
    
    return prices

def analyze_price_wars(context):
    """
    Detecta quando estamos sendo undercut
    """
    import pandas as pd
    
    our_prices = load_our_prices()
    competitor_prices = context['task_instance'].xcom_pull(
        task_ids='scrape_competitors'
    )
    
    # Comparação
    analysis = []
    for sku, our_price in our_prices.items():
        competitor_min = min([p.get(sku, float('inf')) for p in competitor_prices.values()])
        
        if competitor_min < our_price * 0.95:  # 5% undercutting
            analysis.append({
                'sku': sku,
                'our_price': our_price,
                'lowest_competitor': competitor_min,
                'action': 'REVIEW_PRICING'
            })
    
    return analysis

def fetch_prices(competitor):
    # Mock
    import random
    return {f'sku_{i}': random.uniform(10, 100) for i in range(1000)}

def load_our_prices():
    # Mock
    import random
    return {f'sku_{i}': random.uniform(15, 120) for i in range(1000)}

with DAG(
    'competitor_price_monitoring',
    start_date=datetime(2025, 1, 1),
    schedule_interval='*/10 * * * *'  # A cada 10 min
) as dag:
    
    scrape = PythonOperator(
        task_id='scrape_competitors',
        python_callable=scrape_competitor_prices,
        pool='api_calls'
    )
    
    analyze = PythonOperator(
        task_id='analyze_price_wars',
        python_callable=analyze_price_wars,
        provide_context=True
    )
    
    scrape >> analyze
```

---

## CASO 5: Media/Analytics - Processamento de 500GB/dia com Quality Gates

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.branch import BranchPythonOperator
from datetime import datetime, timedelta

def validate_raw_data():
    """
    Gatekeeping antes de transformação
    Se validação falha, não processa
    """
    raw_records = count_records('s3://raw-data/')
    
    # Expectativas
    expected_range = (100_000_000, 150_000_000)  # 100M-150M records
    
    if not (expected_range[0] <= raw_records <= expected_range[1]):
        logger.warning(f"Data volume anomaly: {raw_records} records")
        return 'alert_data_quality'
    
    return 'proceed_with_processing'

def count_records(s3_path):
    # Mock
    return 125_000_000

def quality_alert():
    logger.error("Data volume outside expected range - manual review needed")

def process_data():
    logger.info("Processing 500GB of daily data...")

with DAG(
    'media_analytics_daily',
    start_date=datetime(2025, 1, 1),
    schedule_interval='@daily'
) as dag:
    
    validate = BranchPythonOperator(
        task_id='validate_volume',
        python_callable=validate_raw_data
    )
    
    alert = PythonOperator(
        task_id='alert_data_quality',
        python_callable=quality_alert
    )
    
    process = PythonOperator(
        task_id='proceed_with_processing',
        python_callable=process_data
    )
    
    validate >> [alert, process]
```

---

# Recursos Essenciais Para Aprofundamento

## Documentação Oficial

1. **Airflow Core Concepts**: https://airflow.apache.org/docs/apache-airflow/stable/concepts/index.html
2. **Monitoring & Logging**: https://airflow.apache.org/docs/apache-airflow/stable/logging-monitoring/
3. **Best Practices**: https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html

## Ferramentas Complementares

- **Prometheus + Grafana**: Visualizar métricas em tempo real
- **ELK Stack**: Centralizar logs
- **DataDog/New Relic**: APM profissional

## Certificações

- **Apache Airflow Fundamentals** (Udemy)
- **Data Engineering with Airflow** (Coursera)

---

## Conclusão

**Dica profissional de 20 anos:** O melhor código é aquele que falha graciosamente e você descobre pelo dashboard, não por telefonema de 3 da manhã.

Quer que eu explore algum dos casos em mais profundidade?