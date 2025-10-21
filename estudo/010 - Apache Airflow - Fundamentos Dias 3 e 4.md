# Apache Airflow: Guia Completo para Engenharia de Dados

Ótimo! Com meus 20 anos na área, posso te dizer que dominar Airflow é fundamental em qualquer pipeline de dados moderno. Vou estruturar isso do básico até casos reais complexos.

## 📚 Conceitos Fundamentais

### O que é Apache Airflow?

Airflow é um **orquestrador de workflows** programável que permite:
- Definir pipelines de dados como código (DAGs)
- Executar tarefas de forma distribuída e escalável
- Monitorar, debugar e rastrear execuções
- Tratar falhas, retries e dependências complexas

**Por que é importante?** Em minha experiência, a maioria dos problemas em data pipelines não vem da análise, mas da orquestração. Airflow resolve isso elegantemente.

---

## 🔧 SETUP LOCAL COM DOCKER (2h)

### Instalação com Docker

**Documentação Oficial:**
- 🔗 [Apache Airflow - Official Documentation](https://airflow.apache.org/docs/apache-airflow/stable/index.html)
- 🔗 [Docker Setup Guide](https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose.html)

**Passo a passo prático:**

```bash
# 1. Criar pasta do projeto
mkdir airflow-learning && cd airflow-learning

# 2. Baixar docker-compose.yaml oficial
curl -LfO 'https://airflow.apache.org/docs/apache-airflow/stable/docker-compose.yaml'

# 3. Criar diretórios necessários
mkdir -p ./dags ./logs ./plugins ./config

# 4. Inicializar banco de dados
docker-compose up airflow-init

# 5. Iniciar Airflow
docker-compose up
```

**Acessar interface:**
- URL: `http://localhost:8080`
- User: `airflow`
- Password: `airflow`

**Verificação:** Se você consegue acessar a interface web, parabéns! Setup pronto.

---

## ✅ PRIMEIRA DAG SIMPLES (2h)

Uma DAG (Directed Acyclic Graph) é um gráfico que define seu pipeline.

**Documentação:**
- 🔗 [DAG Concepts](https://airflow.apache.org/docs/apache-airflow/stable/concepts/dags.html)
- 🔗 [Tasks & Operators](https://airflow.apache.org/docs/apache-airflow/stable/concepts/tasks.html)

### Tarefa: "Hello World" em 3 tasks sequenciais

Crie o arquivo `dags/hello_world_dag.py`:

```python
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

# Definindo argumentos padrão
default_args = {
    'owner': 'data-engineer',
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'start_date': datetime(2025, 1, 1),
}

# Definindo a DAG
dag = DAG(
    'hello_world_dag',
    default_args=default_args,
    description='DAG simples: Hello World com 3 tasks',
    schedule_interval='@daily',  # Executa diariamente
    catchup=False,
)

# Funções para cada task
def print_hello():
    print("Hello from Task 1!")
    return "Task 1 completed"

def print_world():
    print("World from Task 2!")
    return "Task 2 completed"

def print_done():
    print("Done! Task 3 completed!")
    return "Task 3 completed"

# Criando as tasks
task1 = PythonOperator(
    task_id='task_hello',
    python_callable=print_hello,
    dag=dag,
)

task2 = PythonOperator(
    task_id='task_world',
    python_callable=print_world,
    dag=dag,
)

task3 = PythonOperator(
    task_id='task_done',
    python_callable=print_done,
    dag=dag,
)

# Definindo dependências (sequência)
task1 >> task2 >> task3
```

**Como testar:**

```bash
# Ver a DAG registrada
docker-compose exec airflow-webserver airflow dags list

# Testar a DAG sem executar (lint)
docker-compose exec airflow-webserver airflow dags test hello_world_dag 2025-01-01

# Acionar manualmente na interface web
# Menu: DAGs > hello_world_dag > Trigger DAG
```

---

## 🔌 CONECTAR COM BANCO DE DADOS (2h)

**Documentação:**
- 🔗 [Airflow Connections](https://airflow.apache.org/docs/apache-airflow/stable/howto/connection.html)
- 🔗 [Database Operators](https://airflow.apache.org/docs/apache-airflow-providers-mysql/stable/operators.html)

### Setup de Conexão com MySQL (exemplo clássico)

**1. Criar conexão via interface:**
- Admin → Connections → Create
- Conn Id: `mysql_default`
- Conn Type: MySQL
- Host: `mysql` (se usar docker-compose)
- Database: `seu_banco`
- Login: `seu_usuario`
- Password: `sua_senha`

**2. DAG conectando ao banco:**

```python
from airflow import DAG
from airflow.providers.mysql.operators.mysql import MySqlOperator
from airflow.providers.mysql.transfers.mysql_to_hive import MySqlToHiveOperator
from datetime import datetime

dag = DAG(
    'database_connection_dag',
    start_date=datetime(2025, 1, 1),
    schedule_interval='@daily',
    catchup=False,
)

# Task 1: Criar tabela se não existir
create_table = MySqlOperator(
    task_id='create_table',
    sql="""
    CREATE TABLE IF NOT EXISTS logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        message VARCHAR(255),
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    """,
    mysql_conn_id='mysql_default',
    dag=dag,
)

# Task 2: Inserir dados
insert_data = MySqlOperator(
    task_id='insert_data',
    sql="""
    INSERT INTO logs (message) VALUES ('Pipeline executado com sucesso');
    """,
    mysql_conn_id='mysql_default',
    dag=dag,
)

create_table >> insert_data
```

---

## 🐛 EXECUTAR E DEBUGAR (2h)

**Logs & Debugging:**

```bash
# Ver logs de uma task específica
docker-compose logs -f airflow-scheduler

# Acessar logs via interface
# DAGs > hello_world_dag > Task Instance > Log

# Testar uma task isoladamente
docker-compose exec airflow-webserver airflow tasks test hello_world_dag task_hello 2025-01-01

# Validar sintaxe Python da DAG
docker-compose exec airflow-webserver python /home/airflow/dags/hello_world_dag.py
```

**Problemas comuns:**
- **DAG não aparece:** Aguarde 2-3 minutos, Airflow faz scan a cada 300s
- **Task falha:** Verifique `Admin → XCom` para valores compartilhados entre tasks
- **Connection error:** Teste manualmente a conexão em `Admin → Connections → Edit → Test`

---

## 🌍 EXEMPLOS DO MUNDO REAL (Engenharia de Dados)

### Exemplo 1: ETL Completo - Dados de Vendas

Cenário real que implementei em uma fintech:

```python
from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.operators.python import PythonOperator
from airflow.providers.amazon.aws.transfers.s3_to_redshift import S3ToRedshiftOperator
from datetime import datetime, timedelta
import requests
import pandas as pd

default_args = {
    'owner': 'data-team',
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'email_on_failure': ['alerts@empresa.com'],
}

dag = DAG(
    'etl_vendas_realtime',
    default_args=default_args,
    schedule_interval='0 */2 * * *',  # A cada 2 horas
    catchup=False,
)

# Task 1: Extrair dados de API externa
def extract_sales_api():
    """Extrai últimas 2 horas de vendas"""
    response = requests.get(
        'https://api.vendas.com/transactions',
        params={'hours': 2},
        headers={'Authorization': 'Bearer TOKEN'}
    )
    data = response.json()
    
    # Salvar em S3 como staging
    import json
    with open('/tmp/sales_raw.json', 'w') as f:
        json.dump(data, f)
    
    return len(data['transactions'])

extract_task = PythonOperator(
    task_id='extract_sales_api',
    python_callable=extract_sales_api,
    dag=dag,
)

# Task 2: Validar e transformar dados
def transform_sales_data():
    """Limpa, valida e transforma dados"""
    import pandas as pd
    import json
    
    with open('/tmp/sales_raw.json', 'r') as f:
        raw_data = json.load(f)
    
    # Converter para DataFrame
    df = pd.DataFrame(raw_data['transactions'])
    
    # Transformações
    df['data_venda'] = pd.to_datetime(df['timestamp'])
    df['valor'] = df['valor'].astype(float)
    df = df[df['valor'] > 0]  # Remover valores negativos
    df = df.dropna(subset=['cliente_id'])
    
    # Validações
    assert len(df) > 0, "Nenhum dado válido após transformação"
    
    df.to_csv('/tmp/sales_transformed.csv', index=False)
    print(f"✅ {len(df)} registros transformados")

transform_task = PythonOperator(
    task_id='transform_sales_data',
    python_callable=transform_sales_data,
    dag=dag,
)

# Task 3: Carregar para Data Warehouse (Redshift)
load_to_warehouse = S3ToRedshiftOperator(
    task_id='load_to_redshift',
    s3_bucket='data-lake-prod',
    s3_key='sales/transformed/',
    schema='raw_layer',
    table='vendas_staging',
    copy_options=['IGNOREHEADER 1', 'CSV'],
    redshift_conn_id='redshift_connection',
    method='REPLACE',
    dag=dag,
)

# Task 4: Atualizar tabelas analíticas (dimensional)
create_analytics = PostgresOperator(
    task_id='create_analytics_tables',
    sql="""
    INSERT INTO analytics.vendas_por_dia
    SELECT 
        DATE(data_venda) as data,
        COUNT(*) as total_vendas,
        SUM(valor) as receita_total,
        AVG(valor) as ticket_medio
    FROM raw_layer.vendas_staging
    WHERE data_venda >= CURRENT_DATE - INTERVAL '2 hours'
    GROUP BY DATE(data_venda)
    ON CONFLICT (data) DO UPDATE SET
        total_vendas = EXCLUDED.total_vendas,
        receita_total = EXCLUDED.receita_total,
        ticket_medio = EXCLUDED.ticket_medio;
    """,
    postgres_conn_id='analytics_db',
    dag=dag,
)

# Task 5: Notificar time (alerta se problema)
def notify_team():
    """Envia notificação para Slack"""
    from airflow.providers.slack.operators.slack_webhook import SlackWebhookOperator
    
    message = "✅ Pipeline de vendas completado com sucesso!"
    print(message)

notify_task = PythonOperator(
    task_id='notify_slack',
    python_callable=notify_team,
    dag=dag,
)

# Definir sequência
extract_task >> transform_task >> load_to_warehouse >> create_analytics >> notify_task
```

**Por que este exemplo é real:**
- ❌ Sem orquestração: processaria dados de forma inconsistente
- ✅ Com Airflow: garante que cada etapa executa em ordem, com tratamento de falhas

---

### Exemplo 2: Data Quality Checks

Implementação que uso em projetos críticos:

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.great_expectations.operators.great_expectations import GreatExpectationsOperator
from datetime import datetime

dag = DAG(
    'data_quality_pipeline',
    start_date=datetime(2025, 1, 1),
    schedule_interval='@hourly',
)

def validate_data_quality():
    """Validação customizada"""
    import pandas as pd
    
    df = pd.read_csv('/data/incoming/dados.csv')
    
    validations = {
        'rows_count': len(df) > 0,
        'no_nulls_critical': df[['id', 'valor']].isnull().sum().sum() == 0,
        'valor_positivo': (df['valor'] > 0).all(),
        'duplicates': df['id'].is_unique,
    }
    
    failed = [k for k, v in validations.items() if not v]
    
    if failed:
        raise ValueError(f"❌ Validações falharam: {failed}")
    
    print("✅ Todos os checks passaram!")

quality_check = PythonOperator(
    task_id='quality_validation',
    python_callable=validate_data_quality,
    dag=dag,
)
```

---

### Exemplo 3: Backfill e Recuperação de Dados

Cenário comum: você precisa reprocessar dados históricos:

```python
# Executar backfill de 30 dias atrás
# CLI: airflow dags backfill etl_vendas_realtime -s 2024-12-01 -e 2024-12-31

# Ou via código:
from airflow import DAG
from airflow.operators.bash import BashOperator

dag = DAG(
    'backfill_historical_data',
    schedule_interval=None,  # Sem agendamento automático
    catchup=False,
)

backfill_task = BashOperator(
    task_id='run_backfill',
    bash_command="""
    airflow dags backfill etl_vendas_realtime \
        -s {{ ds }} \
        -e {{ ds }}
    """,
    dag=dag,
)
```

---

## 📖 Documentação Oficial (Favoritos para Estudo)

| Tópico | URL |
|--------|-----|
| **Conceitos Principais** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/index.html |
| **Operators** | https://airflow.apache.org/docs/apache-airflow/stable/operators-and-hooks.html |
| **Best Practices** | https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html |
| **Providers (integrações)** | https://airflow.apache.org/docs/#providers-packages-docs |
| **XCom (compartilhar dados)** | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/xcoms.html |

---

## 🎯 Próximos Passos Recomendados

1. **Dominar XCom**: Como passar dados entre tasks (crítico!)
2. **Dynamic DAGs**: Gerar tasks em runtime (muito poderoso)
3. **Sensor Operators**: Esperar por eventos externos
4. **Error Handling**: On-failure callbacks, alertas

Quer que eu aprofunde em algum desses tópicos? Tenho exemplos prontos para produção! 🚀