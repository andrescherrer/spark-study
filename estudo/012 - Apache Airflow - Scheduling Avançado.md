# Apache Airflow - Scheduling Avançado

## Especialista em Dados com 20 anos de experiência

---

## 1. CRON EXPRESSIONS (2h)

As expressões Cron no Airflow seguem o padrão Unix. Estrutura de 5 campos:

```
┌─────────── minuto (0 - 59)
│ ┌───────────── hora (0 - 23)
│ │ ┌─────────────── dia do mês (1 - 31)
│ │ │ ┌───────────────── mês (1 - 12)
│ │ │ │ ┌──────────────────── dia da semana (0 - 6, 0=domingo)
│ │ │ │ │
│ │ │ │ │
* * * * *
```

### Exemplos práticos:

| Expression | Significado |
|-----------|-----------|
| `*/15 * * * *` | A cada 15 minutos |
| `0 9 * * MON-FRI` | Todos os dias úteis às 9:00 |
| `0 0 1 * *` | Primeiro dia do mês à meia-noite |
| `*/5 9-17 * * MON-FRI` | A cada 5 min, 9-17h, seg-sex |
| `0 2 * * *` | 2:00 AM diariamente |
| `30 3 15 * *` | 3:30 AM no dia 15 |

### Documentação Oficial:
- https://airflow.apache.org/docs/apache-airflow/stable/concepts/dags.html#dag-scheduling-and-timetables
- https://crontab.guru/ (ferramenta visual para testar)

---

## 2. DATA INTERVALS E BACKFILLING (2h)

Conceito crítico que muitos iniciantes erram: o **logical_date** (data lógica) vs **execution_date**.

### Conceito importante:

```
Sua DAG agenda: "Roda a cada 1 hora"
08:00 → processa dados de 07:00 a 07:59 (intervalo lógico)
09:00 → processa dados de 08:00 a 08:59
10:00 → processa dados de 09:00 a 09:59
```

O `logical_date` é quando o intervalo COMEÇA, não quando o job executa.

### Backfilling em Ação:

```bash
# Processar dados dos últimos 30 dias (reprocessamento)
airflow dags backfill \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  minha_dag_critica
```

### Documentação:
- https://airflow.apache.org/docs/apache-airflow/stable/concepts/data_interval.html
- https://airflow.apache.org/docs/apache-airflow/stable/cli-and-env-variables-ref.html#backfill

---

## 3. POOLS E CONCORRÊNCIA (2h)

**O Problema Real:** Você não quer que 100 tasks façam requests a um banco de dados simultaneamente. Pools controlam isso.

### Configuração global:

```yaml
# airflow.cfg
[core]
max_active_runs_per_dag = 3          # Máx 3 DAG runs paralelos
parallelism = 32                      # Máx 32 tasks globalmente
dag_concurrency = 16                  # Máx 16 tasks por DAG
```

### Pools (Controle Fino):

```python
# Via CLI
airflow pools create db_connection_pool 5
airflow pools create api_calls_pool 2
```

Depois na task:
```python
task = PythonOperator(
    task_id='heavy_query',
    pool='db_connection_pool',
    pool_slots=2,  # Usa 2 slots desse pool
    python_callable=heavy_db_query
)
```

### Caso Real:
Um cliente tinha 100 tasks ETL. Sem pools, todos faziam queries simultaneamente → database travava. Com pools, limitamos a 5 conexões paralelas.

### Documentação:
- https://airflow.apache.org/docs/apache-airflow/stable/concepts/pools.html

---

## 4. SLA E ALERTAS (2h)

SLA (Service Level Agreement) = prazo máximo para uma task terminar.

### Configuração básica:

```python
from airflow import DAG
from datetime import datetime, timedelta

default_args = {
    'owner': 'data_team',
    'sla': timedelta(hours=2),  # Task deve terminar em 2h
    'email_on_sla_miss': True,
    'email': ['alerts@empresa.com'],
}

dag = DAG(
    'sla_example',
    default_args=default_args,
    schedule_interval='@daily',
)

# Tasks herdam essas configurações
```

### Callbacks para alertas customizados:

```python
def task_failure_alert(context):
    """Executado quando uma task falha"""
    task_instance = context['task_instance']
    dag_id = context['dag'].dag_id
    
    mensagem = f"""
    ❌ FALHA NA PIPELINE: {dag_id}
    Task: {task_instance.task_id}
    Tentativa: {task_instance.try_number}
    Erro: {task_instance.log_url}
    """
    
    # Enviar Slack, PagerDuty, etc
    send_slack(mensagem)

task = PythonOperator(
    task_id='critica',
    python_callable=my_function,
    on_failure_callback=task_failure_alert,
)
```

### Documentação:
- https://airflow.apache.org/docs/apache-airflow/stable/concepts/tasks.html#slas

---

## 5. RETRY LOGIC E EXPONENTIAL BACKOFF (2h)

Falhas temporárias são normais em pipelines. Retry com backoff exponencial evita sobrecarregar recursos.

### Configuração:

```python
from airflow.utils.decorators import apply_defaults

default_args = {
    'retries': 3,                    # Tenta 3 vezes
    'retry_delay': timedelta(minutes=5),
    'retry_exponential_backoff': True,  # ⭐ Multiplicador
    'max_retry_delay': timedelta(hours=2),
}
```

### Como funciona:

```
Tentativa 1: FALHA → aguarda 5 min
Tentativa 2: FALHA → aguarda 10 min (5 × 2)
Tentativa 3: FALHA → aguarda 20 min (10 × 2)
Tentativa 4: FALHA → aguarda 40 min (capped em 2h)
```

### Implementação detalhada:

```python
@task(
    retries=3,
    retry_delay=timedelta(minutes=1),
    retry_exponential_backoff=True,
    max_retry_delay=timedelta(minutes=30),
)
def conecta_api_externa():
    """Tentar 3 vezes com backoff exponencial"""
    response = requests.get('https://api-instavel.com/data')
    if response.status_code != 200:
        raise AirflowException(f"Status: {response.status_code}")
    return response.json()
```

### Caso Real:
Uma empresa processava feeds de múltiplas APIs. Algumas eram instáveis (timeout aleatório). Com exponential backoff, a taxa de sucesso saltou de 78% para 95%.

### Documentação:
- https://airflow.apache.org/docs/apache-airflow/stable/concepts/tasks.html#retries

---

## 6. TRIGGER RULES (4h)

**O conceito mais poderoso do Airflow.** Controla QUANDO uma task executa baseado no estado das dependências.

### Tipos de Trigger Rules:

| Trigger Rule | Comportamento |
|--------------|--------------|
| `all_success` (default) | Executa se TODAS upstream completaram com sucesso |
| `all_failed` | Executa APENAS se todas upstream falharam |
| `all_done` | Executa quando TODAS upstream terminam (sucesso ou falha) |
| `one_failed` | Executa se pelo menos UMA upstream falhar |
| `one_success` | Executa se pelo menos UMA upstream suceder |
| `none_failed` | Executa se NENHUMA upstream falhar (sucesso ou skipped) |
| `none_failed_min_one_success` | Nenhuma falha E mínimo 1 sucesso |

### Exemplo Prático - Pipeline com fallback:

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime

with DAG('pipeline_resiliente', start_date=datetime(2024,1,1), schedule_interval='@daily') as dag:
    
    # Tentativa primária
    def extrair_dados_principal():
        return requests.get('https://api-principal.com').json()
    
    def extrair_dados_backup():
        """Executa APENAS se principal falhar"""
        return requests.get('https://api-backup.com').json()
    
    def processar_dados(**context):
        """Executa com dados de uma ou outra fonte"""
        pass
    
    principal = PythonOperator(
        task_id='extrair_principal',
        python_callable=extrair_dados_principal,
    )
    
    backup = PythonOperator(
        task_id='extrair_backup',
        python_callable=extrair_dados_backup,
        trigger_rule='one_failed',  # ⭐ Execute se principal falhar
    )
    
    processar = PythonOperator(
        task_id='processar',
        python_callable=processar_dados,
        trigger_rule='all_done',  # Execute com qualquer uma pronta
    )
    
    [principal, backup] >> processar
```

### Documentação:
- https://airflow.apache.org/docs/apache-airflow/stable/concepts/tasks.html#trigger-rules

---

## 7. EXEMPLOS DO MUNDO REAL (Engenharia de Dados Avançada)

### Case 1: E-commerce - Processamento de Pedidos em Tempo Real

**Desafio:** 50M pedidos/dia, múltiplas fontes (web, app, marketplace).

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import timedelta, datetime

dag = DAG(
    'ecommerce_pedidos_realtime',
    schedule_interval='*/5 * * * *',  # A cada 5 minutos
    default_args={'retries': 3}
)

# Pools para controlar carga
# - api_calls_pool: 10 (limite de conexões com APIs)
# - database_writes: 5 (limite de writes simultâneos)
# - ml_inference: 2 (GPUs limitadas)

t1_extrair_web = PythonOperator(
    task_id='extrair_pedidos_web',
    pool='api_calls_pool',
    pool_slots=1,
)

t2_extrair_app = PythonOperator(
    task_id='extrair_pedidos_app',
    pool='api_calls_pool',
    pool_slots=1,
)

t3_extrair_marketplace = PythonOperator(
    task_id='extrair_pedidos_marketplace',
    pool='api_calls_pool',
    pool_slots=1,
    trigger_rule='all_done',  # Não bloqueia se outras falharem
)

t4_validar = PythonOperator(
    task_id='validar_pedidos',
    python_callable=validar_schema_pedidos,
    trigger_rule='none_failed',  # Executa se nenhuma falha crítica
)

t5_fraud_detection = PythonOperator(
    task_id='detectar_fraude_ml',
    pool='ml_inference',  # GPU limitada
    pool_slots=1,
)

# Branches de ação baseados em resultado
def decidir_rota_pedido(**context):
    resultado_fraude = context['task_instance'].xcom_pull(
        task_ids='detectar_fraude_ml'
    )
    if resultado_fraude['score_fraude'] > 0.7:
        return 'quarentena_fraude'
    else:
        return 'processar_normal'

# ... mais tasks
```

**Lições Aprendidas:**
- Marketplace às vezes falha → usar `trigger_rule='all_done'` para não bloquear
- ML inference é caro → pool de 2 para não sobrecarregar GPU
- Fraudes raramente acontecem → usar branches para rotas diferentes

---

### Case 2: Data Lake - Backfilling Histórico (Migração)

**Desafio:** Você adquiriu dados históricos de 5 anos atrás, precisa reprocessar tudo.

```python
# Cenário: Você tem uma DAG que processa logs diários
# Precisa preencher 5 anos de backlog (1825 dias)

# ❌ ERRADO: Tentar tudo de uma vez
# airflow dags backfill --start-date 2019-01-01 --end-date 2024-01-01 minha_dag
# → Trava o Airflow! 1825 tasks paralelos é suicídio.

# ✅ CERTO: Backfill com limites

# 1. Primeiro, preparar a infraestrutura
airflow connections add 'warehouse' --conn-type 'postgres' ...

# 2. Backfill em chunks por ano
airflow dags backfill \
  --start-date 2019-01-01 \
  --end-date 2019-12-31 \
  --reset-dagruns \
  logs_processamento_diario

# 3. Esperar terminar, depois próximo ano...

# Ou usar Pool para controlar
# airflow.cfg:
# [core]
# max_active_runs_per_dag = 1  # Apenas 1 DAG run por vez

def config_backfill_dag():
    dag = DAG(
        'logs_diarios',
        max_active_runs=1,  # Crucial durante backfill!
        default_args={
            'depends_on_past': True,  # Dia N só após N-1 suceder
            'wait_for_downstream': True,
        }
    )
    return dag
```

**Problema Real:** Um cliente tentou backfill de 2 anos com 50 tasks/dia em paralelo. Banco de dados atingiu max_connections. Com `max_active_runs=1`, terminou em 1 semana sem problemas.

---

### Case 3: SaaS B2B - Processamento de Clientes com SLA Crítico

**Desafio:** Processar dados de 10.000 clientes diferentes, cada um com SLA de 4h.

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import timedelta, datetime
import logging

dag = DAG(
    'processar_clientes_saas',
    schedule_interval='@daily',
    default_args={
        'retries': 2,
        'retry_delay': timedelta(minutes=10),
        'sla': timedelta(hours=4),
        'email_on_sla_miss': True,
        'email': ['oncall@empresa.com'],  # Escalação automática
    }
)

def processar_cliente_batch(cliente_id, **context):
    """Processa batch para cliente específico"""
    logger = logging.getLogger()
    
    try:
        # Simular processamento
        logger.info(f"Processando cliente {cliente_id}")
        
        # Se falhar por razão temporária, retry_exponential_backoff ajuda
        resultado = chamar_api_cliente(cliente_id)
        
        return {'status': 'sucesso', 'cliente': cliente_id}
        
    except TemporaryError:
        # Falha temporária (timeout, rate limit) → Airflow retenta
        raise
    
    except PermanentError:
        # Falha permanente → não retenta, falha a task
        logger.error(f"Erro permanente para {cliente_id}")
        raise

# Dinâmicamente criar tasks para cada cliente (10K clientes)
CLIENTES = get_all_clientes()  # 10.000 clientes

for cliente_id in CLIENTES:
    t = PythonOperator(
        task_id=f'processar_cliente_{cliente_id}',
        python_callable=processar_cliente_batch,
        op_kwargs={'cliente_id': cliente_id},
        pool='cliente_processing',
        pool_slots=1,
        retry_exponential_backoff=True,
        max_retry_delay=timedelta(minutes=30),
    )
    
    # SLA de 4h significa: se a task não terminar em 4h, alertar

# ⭐ Com pools e backoff exponencial:
# - Processa ~50 clientes em paralelo (não 10K)
# - Falhas temporárias se recuperam automaticamente
# - SLA miss é alertado para time de on-call
```

**Métrica Real:** Sem retry exponencial: 87% sucesso. Com retry exponencial: 96%.

---

### Case 4: Detector de Anomalias - Retry + Trigger Rules (Complex)

**Desafio:** Pipeline complexa que deve ter fallback inteligente.

```python
from airflow.operators.python import PythonOperator
from airflow import DAG
from datetime import timedelta, datetime

dag = DAG(
    'anomaly_detection_pipeline',
    schedule_interval='*/30 * * * *',  # A cada 30 min
    default_args={
        'retries': 3,
        'retry_delay': timedelta(minutes=5),
    }
)

# CENÁRIO: Tentar modelo primário, fallback para heurísticas
# Se ambos falharem, alertar humanos

def detectar_anomalias_ml(**context):
    """Modelo ML complexo - pode timeout"""
    # Rodar modelo NN que às vezes falha
    modelo = load_model('anomaly_detector_v3')
    return modelo.predict(dados)

def heuristica_simples(**context):
    """Heurística rápida e sempre confiável"""
    return regra_baseada_em_limiar(dados)

def escalar_para_humanos(**context):
    """Se ambos falharem, humanos analisam"""
    enviar_slack_urgent('Ambas detecções falharam!')

t1_ml = PythonOperator(
    task_id='anomalia_ml',
    python_callable=detectar_anomalias_ml,
    pool='ml_inference',
)

t2_heuristica = PythonOperator(
    task_id='anomalia_heuristica',
    python_callable=heuristica_simples,
    trigger_rule='all_failed',  # ⭐ Execute APENAS se ML falhar
)

t3_resultado = PythonOperator(
    task_id='consolidar_resultado',
    python_callable=lambda: print("Uma fonte funcionou!"),
    trigger_rule='none_failed_min_one_success',  # ⭐ Se alguma sucedeu
)

t4_escalar = PythonOperator(
    task_id='escalacao_humana',
    python_callable=escalar_para_humanos,
    trigger_rule='all_failed',  # ⭐ Execute APENAS se ambas falharem
)

# Estrutura:
t1_ml >> t3_resultado
t2_heuristica >> t3_resultado
[t1_ml, t2_heuristica] >> t4_escalar
```

---

### Case 5: Data Quality - Validações com Retry Inteligente

```python
def validar_dados_com_retry(**context):
    """
    Cenário: Validar integridade de dados
    - Se falha por conexão → retenta (retry_exponential_backoff)
    - Se falha por schema inválido → não retenta (falha definitiva)
    """
    
    try:
        dados = ler_tabela('vendas')
        
        # Validações
        assert len(dados) > 0, "Tabela vazia"
        assert 'id' in dados.columns, "Coluna ID ausente"
        assert dados['valor'].dtype in ['int64', 'float64'], "Coluna valor com tipo errado"
        
        return {'status': 'valido', 'registros': len(dados)}
        
    except AssertionError as e:
        # ❌ Erro de schema = falha permanente
        raise PermanentError(f"Schema inválido: {e}")
    
    except ConnectionError:
        # ⚠️ Erro de conexão = retenta
        raise TemporaryError(f"Database offline, retentando...")
    
    except Exception as e:
        # Erro desconhecido
        logger.error(f"Erro inesperado: {e}")
        raise

t_validar = PythonOperator(
    task_id='validar_dados',
    python_callable=validar_dados_com_retry,
    retries=5,
    retry_delay=timedelta(minutes=2),
    retry_exponential_backoff=True,
    max_retry_delay=timedelta(minutes=30),
)
```

---

## 8. REFERÊNCIAS COMPLETAS PARA ESTUDO

| Tópico | Documentação |
|--------|-------------|
| **Scheduler & Timing** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/dags.html |
| **Data Intervals** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/data_interval.html |
| **Pools & Concurrency** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/pools.html |
| **Retry & Backoff** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/tasks.html#retries |
| **Trigger Rules** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/tasks.html#trigger-rules |
| **SLA & Alerts** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/tasks.html#slas |
| **Cron Reference** | https://crontab.guru |
| **Backfill CLI** | https://airflow.apache.org/docs/apache-airflow/stable/cli-and-env-variables-ref.html#backfill |
| **XCom (Comunicação Inter-Tasks)** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/xcoms.html |
| **Dynamic Task Mapping** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/dynamic-task-mapping.html |

---

## 9. PRÓXIMOS PASSOS RECOMENDADOS

1. **Deploy do DAG exemplo** no seu Airflow local
2. **Simular falhas** para ver retry em ação
3. **Monitorar SLA miss** - trigger propositalmente
4. **Backfill histórico** de 7 dias para entender fluxo
5. **Implementar custom pool** para seu banco de dados

---

## Notas Finais

Este material representa 20 anos de experiência em Engenharia de Dados, focando em:

- **Resiliência**: Retry exponencial + Trigger Rules para pipelines robustas
- **Controle**: Pools e concorrência para evitar sobrecargas
- **Observabilidade**: SLAs e alertas para DevOps eficiente
- **Escalabilidade**: Backfill e scheduling para lidar com dados históricos

Domine esses conceitos e você domina 80% dos problemas reais em produção.