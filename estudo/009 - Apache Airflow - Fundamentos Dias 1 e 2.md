# Apache Airflow - Fundamentos Completos

Com 20 anos na área, posso dizer que Airflow revolucionou como orquestramos pipelines de dados. Vou desdobrar isso para você de forma prática.

## 1️⃣ DAG, TASK, OPERATOR - O Tripé Fundamental

### DAG (Directed Acyclic Graph)

É o "projeto" de execução. Imagine como um blueprint de um prédio - define quais tarefas existem e como se relacionam. É acíclico porque não pode ter loops (A → B → A é proibido).

```
Meu_Pipeline_Diário (DAG)
    ├── Extrair_Dados (Task)
    ├── Validar_Dados (Task)
    └── Carregar_Dados (Task)
```

### Task

É a unidade de trabalho. Cada retângulo no diagrama acima é uma Task.

### Operator

É a implementação da Task. Ele define *como* executar. Exemplos:
- `PythonOperator`: executa código Python
- `BashOperator`: executa comando bash
- `PostgresOperator`: executa SQL
- `HttpOperator`: faz requisições HTTP

### 📚 Fontes Oficiais

- https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html
- https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/tasks.html
- https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/operators.html

---

## 2️⃣ SCHEDULING E TRIGGERS

### Scheduling

Determina *quando* sua DAG roda. Usa cron-like expressions:

```python
from airflow import DAG
from datetime import datetime, timedelta

dag = DAG(
    'meu_pipeline',
    default_args={
        'owner': 'data_team',
        'retries': 2,
        'retry_delay': timedelta(minutes=5)
    },
    schedule_interval='0 2 * * *',  # 2 AM todo dia
    start_date=datetime(2025, 1, 1),
    catchup=False
)
```

- `0 2 * * *` = Todo dia às 2 da manhã
- `0 */6 * * *` = A cada 6 horas
- `@daily` = Atalho para diariamente
- `None` = Manual apenas

### Triggers

São condições que ativam Tasks:
- **Time-based**: Agenda fixa
- **Sensor**: Espera algo acontecer (arquivo chegar, DB atualizar)
- **External**: Webhook, API
- **Conditional**: Resultado de outra task

### 📚 Fontes Oficiais

- https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html#scheduling
- https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/sensors.html

---

## 3️⃣ XCOM E TASK DEPENDENCIES

### XCom (Cross Communication)

Permite que Tasks compartilhem dados pequenos (strings, números, dicionários - não arquivos grandes!).

```python
from airflow.operators.python import PythonOperator

def extrair_dados():
    resultado = {"total": 1000, "status": "sucesso"}
    return resultado  # Isso vira XCom automaticamente

def processar_dados(ti):  # ti = Task Instance
    valor = ti.xcom_pull(task_ids='extrair')
    print(f"Recebi: {valor}")

extract_task = PythonOperator(task_id='extrair', python_callable=extrair_dados, dag=dag)
process_task = PythonOperator(task_id='processar', python_callable=processar_dados, dag=dag)

extract_task >> process_task  # Dependência
```

### Task Dependencies

Define ordem de execução:
- `>>` : A antes de B
- `<<` : B antes de A
- `<<, >>` : Cadeia

```python
# Opção 1: Operador
task_a >> task_b >> task_c

# Opção 2: Lista
task_a >> [task_b, task_c]  # B e C em paralelo depois de A

# Opção 3: Set
[task_a, task_b] >> task_c  # C após ambas terminarem
```

### 📚 Fontes Oficiais

- https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/xcoms.html
- https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/tasks.html#dependencies

---

## 4️⃣ SENSOR vs OPERATOR

| Aspecto | Sensor | Operator |
|--------|--------|----------|
| **Propósito** | Espera algo acontecer | Executa ação |
| **Tempo de espera** | Pode ficar horas/dias | Executa e termina |
| **Exemplo** | "Arquivo já foi criado?" | "Copiar arquivo" |
| **Modo padrão** | `poke` (testa periodicamente) ou `reschedule` | Execute uma vez |

### Exemplo Prático

```python
from airflow.sensors.filesystem import FileSensor
from airflow.operators.bash import BashOperator

# Sensor: Espera arquivo existir
aguardar_arquivo = FileSensor(
    task_id='aguardar_csv',
    filepath='/data/entrada/vendas.csv',
    poke_interval=30,  # Verifica a cada 30s
    timeout=3600,       # Timeout de 1h
    dag=dag
)

# Operator: Processa o arquivo
processar = BashOperator(
    task_id='processar_csv',
    bash_command='python /scripts/processar.py',
    dag=dag
)

aguardar_arquivo >> processar
```

### 📚 Fontes Oficiais

- https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/sensors.html

---

# 🏭 EXEMPLOS DO MUNDO REAL - Engenharia de Dados

## Cenário 1: Pipeline ETL de E-commerce

Imagine uma empresa que precisa atualizar seu data warehouse com vendas do dia anterior:

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.sensors.external_task import ExternalTaskSensor
from datetime import datetime, timedelta
import pandas as pd
import requests

default_args = {
    'owner': 'data_eng',
    'retries': 3,
    'retry_delay': timedelta(minutes=10)
}

dag = DAG(
    'ecommerce_etl_diario',
    default_args=default_args,
    schedule_interval='0 3 * * *',  # 3 AM todo dia
    start_date=datetime(2025, 1, 1)
)

# EXTRACT
def extrair_vendas_api(**context):
    """Busca vendas da API do último dia"""
    data = context['ds']  # Data de execução (YYYY-MM-DD)
    
    response = requests.get(
        f'https://api.ecommerce.com/vendas?data={data}'
    )
    vendas = response.json()
    
    # Salvar localmente temporariamente
    df = pd.DataFrame(vendas)
    df.to_csv(f'/tmp/vendas_{data}.csv', index=False)
    
    # Comunicar quantidade de registros
    return {
        'total_registros': len(vendas),
        'data_arquivo': f'/tmp/vendas_{data}.csv'
    }

extract = PythonOperator(
    task_id='extrair_vendas',
    python_callable=extrair_vendas_api,
    dag=dag
)

# TRANSFORM
def validar_e_transformar(**context):
    """Valida, limpa e enriquece dados"""
    # Pega dados da task anterior
    ti = context['task_instance']
    arquivo = ti.xcom_pull(task_ids='extrair_vendas')['data_arquivo']
    
    df = pd.read_csv(arquivo)
    
    # Validações
    assert df['valor'].dtype in ['float64', 'int64'], "Valor deve ser numérico"
    assert len(df) > 0, "Nenhuma venda encontrada"
    
    # Transformações
    df['data_venda'] = pd.to_datetime(df['data_venda'])
    df['margem'] = (df['preco_final'] - df['custo']) / df['preco_final']
    df['categoria_margem'] = pd.cut(
        df['margem'], 
        bins=[0, 0.2, 0.5, 1], 
        labels=['Baixa', 'Média', 'Alta']
    )
    
    # Salvar transformado
    transformado = f'/tmp/vendas_transformadas_{context["ds"]}.parquet'
    df.to_parquet(transformado)
    
    return {
        'registros_validos': len(df),
        'arquivo_final': transformado
    }

transform = PythonOperator(
    task_id='validar_transformar',
    python_callable=validar_e_transformar,
    dag=dag
)

# LOAD
def carregar_warehouse(**context):
    """Insere dados no PostgreSQL"""
    ti = context['task_instance']
    arquivo = ti.xcom_pull(task_ids='validar_transformar')['arquivo_final']
    
    df = pd.read_parquet(arquivo)
    
    # Conexão com o warehouse
    from sqlalchemy import create_engine
    engine = create_engine('postgresql://user:pass@warehouse:5432/analytics')
    
    df.to_sql(
        'vendas_staging',
        engine,
        if_exists='append',
        index=False
    )
    
    return f"Carregados {len(df)} registros"

load = PythonOperator(
    task_id='carregar_warehouse',
    python_callable=carregar_warehouse,
    dag=dag
)

# Data quality check
check_quality = PostgresOperator(
    task_id='validar_qualidade_dados',
    sql="""
        SELECT COUNT(*) as total FROM vendas_staging 
        WHERE data_venda = {{ ds }}
        AND margem IS NOT NULL;
    """,
    postgres_conn_id='warehouse',
    dag=dag
)

# Orquestração
extract >> transform >> load >> check_quality
```

### O que acontece:

1. 3 AM: Airflow dispara a DAG
2. Task 1: API retorna 50.000 vendas
3. Task 2: Remove 200 inválidas, deixa 49.800
4. Task 3: Insere no PostgreSQL
5. Task 4: Valida se inseriu corretamente

---

## Cenário 2: Multi-Source com Sensores (Padrão real!)

Muitas empresas têm dados de múltiplas fontes. Este padrão espera tudo chegar:

```python
from airflow import DAG
from airflow.sensors.filesystem import FileSensor
from airflow.sensors.external_task import ExternalTaskSensor
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

dag = DAG(
    'multi_source_consolidado',
    schedule_interval='0 6 * * *',  # 6 AM
    start_date=datetime(2025, 1, 1)
)

# SENSORES: Espera dados chegarem
sensor_vendas = FileSensor(
    task_id='aguardar_vendas_s3',
    filepath='s3://data-lake/vendas/{{ ds }}/vendas.parquet',
    poke_interval=60,
    timeout=7200,  # 2 horas para chegar
    dag=dag
)

sensor_clientes = FileSensor(
    task_id='aguardar_clientes_db',
    filepath='/tmp/clientes_{{ ds }}.csv',  # CRM exporta aqui
    poke_interval=30,
    timeout=3600,
    dag=dag
)

# Espera DAG CRM terminar
sensor_external = ExternalTaskSensor(
    task_id='esperar_crm_finalizar',
    external_dag_id='crm_daily_export',
    external_task_id='exportar_clientes',
    allowed_states=['success'],
    failed_states=['failed'],
    poke_interval=60,
    timeout=3600,
    dag=dag
)

# Só depois que tudo chegou, começa a consolidação
def consolidar_fontes(**context):
    """Junta dados de 3 fontes"""
    import s3fs
    import pandas as pd
    
    data = context['ds']
    
    # Lê Parquet do S3
    fs = s3fs.S3FileSystem()
    with fs.open(f's3://data-lake/vendas/{data}/vendas.parquet', 'rb') as f:
        vendas = pd.read_parquet(f)
    
    # Lê CSV local (CRM)
    clientes = pd.read_csv(f'/tmp/clientes_{data}.csv')
    
    # Join
    consolidado = vendas.merge(clientes, on='cliente_id')
    
    # Salva resultado
    consolidado.to_parquet(f'/data/consolidado_{data}.parquet')

consolidar = PythonOperator(
    task_id='consolidar_dados',
    python_callable=consolidar_fontes,
    dag=dag
)

# Espera TODOS os sensores
[sensor_vendas, sensor_clientes, sensor_external] >> consolidar
```

### Padrão real de empresa:

Quando você tem APIs lentas, SFTPs, databases de diferentes departamentos, precisa coordenar tudo. Sensores mantêm o Airflow *intelligente*.

---

## Cenário 3: DAG com Retry e Error Handling (Production-ready)

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.slack.operators.slack_webhook import SlackWebhookOperator
from airflow.utils.trigger_rule import TriggerRule
from datetime import datetime, timedelta

dag = DAG(
    'robusto_producao',
    default_args={
        'owner': 'data_eng',
        'retries': 3,
        'retry_delay': timedelta(minutes=5),
        'retry_exponential_backoff': True,  # Aumenta delay exponencialmente
        'max_retry_delay': timedelta(minutes=60)
    },
    schedule_interval='0 2 * * 1-5',  # Seg-Sex às 2 AM
    start_date=datetime(2025, 1, 1)
)

def extrair_com_retry(**context):
    """Com tratamento de erro"""
    try:
        # Tenta conexão 3x
        for tentativa in range(3):
            try:
                dados = requisitar_api()  # Função que pode falhar
                return dados
            except ConnectionError:
                if tentativa < 2:
                    time.sleep(2 ** tentativa)  # Backoff
                else:
                    raise
    except Exception as e:
        # Log estruturado
        context['task_instance'].log.error(f"Falha na extração: {str(e)}")
        raise

extract = PythonOperator(
    task_id='extrair',
    python_callable=extrair_com_retry,
    dag=dag
)

# Task que roda mesmo se anterior falhar
notificar_falha = SlackWebhookOperator(
    task_id='notificar_falha',
    http_conn_id='slack_webhook',
    message='Pipeline falhou em {{ task }}',
    trigger_rule=TriggerRule.ONE_FAILED,  # Só roda se houver falha
    dag=dag
)

extract >> notificar_falha
```

---

## 📊 Comparação com Alternativas (Para Contexto)

| Ferramenta | Use Para | Problema |
|-----------|----------|---------|
| **Airflow** | ETL complexo, dependências | Curva aprendizado |
| **Cron + Scripts** | Tasks simples | Sem UI, difícil debugar |
| **Prefect** | Similar ao Airflow, mais novo | Comunidade menor |
| **dbt** | Transformações SQL | Não orquestra Python/APIs |
| **Spark Jobs** | Processamento massivo | Não é orquestrador |

**Minha recomendação:** Para Engenharia de Dados hoje, Airflow é padrão de mercado (Uber, Netflix, Airbnb usam). Dominar bem te abre portas.

---

## 📚 Roadmap Seu Estudo

Após dominar estes 4 pilares (DAG, Task, XCom, Sensors), estude em ordem:

1. **Hooks** - Conexões com sistemas externos (DB, S3, APIs)
2. **Connections & Secrets** - Variáveis de ambiente, credenciais
3. **Backfill** - Reprocessar dados históricos
4. **SLA monitoring** - Alertas se pipeline atrasar
5. **Custom Operators** - Criar seus próprios operators

Quer que eu detalhe algum destes com exemplos práticos?