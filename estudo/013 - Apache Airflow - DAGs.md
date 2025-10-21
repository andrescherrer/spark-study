# Apache Airflow: Dynamic DAGs - Guia Completo

**Especialista em Dados com 20 anos de experiência**

---

## 1. CONCEITOS FUNDAMENTAIS

### Por que Dynamic DAGs?

Em pipelines tradicionais (estáticos), você precisa codificar cada task manualmente. Em cenários reais, você não sabe quantas tasks precisará executar:

- **Múltiplos clientes**: 1000 clientes, 1000 tasks idênticas
- **Múltiplas tabelas**: Ingerir 50 tabelas de um banco de dados dinamicamente
- **Processamento paralelo**: Processar partições que variam diariamente

Dynamic DAGs permitem gerar tasks em **tempo de parsing** (quando o DAG é lido).

---

## 2. OS TRÊS PADRÕES

### A. GENERATING TASKS DINAMICAMENTE (Loop com Loop)

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime

# ❌ ERRADO - Criar tasks em um loop simples
# Isso criaria a mesma task múltiplas vezes
# for i in range(10):
#     task = PythonOperator(task_id=f'task_{i}', ...)

# ✅ CORRETO - Usar lista de IDs e loop
with DAG(
    'dynamic_tasks_example',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily'
) as dag:
    
    # Definir lista de entidades (clientes, tabelas, etc)
    entidades = ['cliente_A', 'cliente_B', 'cliente_C', 
                 'cliente_D', 'cliente_E', 'cliente_F',
                 'cliente_G', 'cliente_H', 'cliente_I', 'cliente_J']
    
    def processar_entidade(entidade_nome):
        print(f"Processando {entidade_nome}")
        # Sua lógica aqui: ingerir dados, validar, transformar
    
    # PADRÃO 1: Loop simples (PRÉ-AIRFLOW 2.3)
    tasks = []
    for entidade in entidades:
        task = PythonOperator(
            task_id=f'processar_{entidade}',
            python_callable=processar_entidade,
            op_kwargs={'entidade_nome': entidade}
        )
        tasks.append(task)
    
    # Configurar dependências
    start_task >> tasks >> end_task
```

**IMPORTANTE**: O loop executa durante o **parsing do DAG** (quando Airflow lê o arquivo), não em runtime!

---

### B. SUBDAGS (Padrão DESCONTINUADO ⚠️)

```python
from airflow.operators.subdag import SubDagOperator

def subdag_para_cliente(parent_dag_id, child_dag_id, cliente_id):
    """Subdag: mini-DAG dentro de outro DAG"""
    with DAG(
        dag_id=f'{parent_dag_id}.{child_dag_id}',
        start_date=datetime(2024, 1, 1),
    ) as subdag:
        
        task1 = PythonOperator(
            task_id='extrair_dados',
            python_callable=extrair_dados,
            op_kwargs={'cliente': cliente_id}
        )
        
        task2 = PythonOperator(
            task_id='validar_dados',
            python_callable=validar_dados
        )
        
        task1 >> task2
        return subdag

with DAG('main_dag_com_subdags') as dag:
    clientes = ['cliente_A', 'cliente_B', 'cliente_C']
    
    for cliente in clientes:
        subdag_task = SubDagOperator(
            task_id=f'processo_{cliente}',
            subdag=subdag_para_cliente('main_dag_com_subdags', 'processo', cliente)
        )
```

**⚠️ POR QUE EVITAR**: Subdags têm problemas de visibilidade, logging e performance. Apache descontinuou em favor de TaskGroups.

---

### C. TASKGROUPS (RECOMENDADO ✅ - Airflow 2.0+)

```python
from airflow.models import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup
from datetime import datetime

with DAG(
    'dynamic_taskgroups_best_practice',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily',
    catchup=False
) as dag:
    
    clientes = ['cliente_A', 'cliente_B', 'cliente_C', 
                'cliente_D', 'cliente_E', 'cliente_F',
                'cliente_G', 'cliente_H', 'cliente_I', 'cliente_J']
    
    def extrair_dados(cliente_id, **context):
        print(f"Extraindo dados de {cliente_id}")
        # Lógica: conectar API/BD, extrair dados
        return f"dados_{cliente_id}"
    
    def validar_dados(cliente_id, **context):
        print(f"Validando dados de {cliente_id}")
    
    def carregar_dados(cliente_id, **context):
        print(f"Carregando dados de {cliente_id}")
    
    # TASKGROUP PARA CADA CLIENTE
    for cliente in clientes:
        with TaskGroup(group_id=f'processar_{cliente}') as tg:
            
            extract = PythonOperator(
                task_id='extract',
                python_callable=extrair_dados,
                op_kwargs={'cliente_id': cliente}
            )
            
            validate = PythonOperator(
                task_id='validate',
                python_callable=validar_dados,
                op_kwargs={'cliente_id': cliente}
            )
            
            load = PythonOperator(
                task_id='load',
                python_callable=carregar_dados,
                op_kwargs={'cliente_id': cliente}
            )
            
            # Ordem dentro do TaskGroup
            extract >> validate >> load
    
    # Todas as TaskGroups rodam em paralelo
```

**VANTAGENS do TaskGroup**:
- ✅ Melhor visibilidade na UI
- ✅ Organização hierárquica clara
- ✅ Melhor suporte a XComs
- ✅ Performance superior

---

## 3. COMPARAÇÃO VISUAL

```
LOOP SIMPLES:
├── task_cliente_A
├── task_cliente_B
├── task_cliente_C
...

SUBDAG (Descontinuado):
├── subdag_cliente_A
│   ├── extract
│   ├── validate
│   └── load
├── subdag_cliente_B
...

TASKGROUP (Recomendado):
├── processar_cliente_A
│   ├── extract
│   ├── validate
│   └── load
├── processar_cliente_B
│   ├── extract
│   ├── validate
│   └── load
```

---

## 4. DOCUMENTAÇÃO OFICIAL

| Tópico | URL | Notas |
|--------|-----|-------|
| **Dynamic DAGs** | https://airflow.apache.org/docs/apache-airflow/stable/howto/dynamic-dag-generation.html | Guia principal |
| **TaskGroups** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/tasks.html#task-groups | Padrão moderno |
| **Subdags (Deprecated)** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/dags.html#subdags | Evitar para novos projetos |
| **XCom (Passar dados entre tasks)** | https://airflow.apache.org/docs/apache-airflow/stable/concepts/xcoms.html | Essencial para dados dinâmicos |
| **Best Practices** | https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html | Leitura obrigatória |

---

## 5. SOLUÇÃO DA TAREFA: DAG COM 10 TASKS DINÂMICAS

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.utils.task_group import TaskGroup
from datetime import datetime, timedelta
import json

# Configurações
default_args = {
    'owner': 'data_team',
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    dag_id='dynamic_10_tasks_dag',
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily',
    catchup=False,
    description='DAG que cria 10 tasks dinamicamente baseado em lista'
) as dag:
    
    # ============== CONFIGURAÇÃO ==============
    # Lista de entidades a processar (10 items)
    entidades = [
        'vendas_norte',
        'vendas_nordeste',
        'vendas_centro_oeste',
        'vendas_sudeste',
        'vendas_sul',
        'marketing_digital',
        'atendimento_cliente',
        'logistica',
        'financeiro',
        'recursos_humanos'
    ]
    
    # ============== FUNÇÕES ==============
    def extrair_dados(entidade_id, **context):
        """Simula extração de dados de uma fonte"""
        print(f"🔄 Extraindo dados para: {entidade_id}")
        
        # Simular dados extraídos
        dados = {
            'entidade': entidade_id,
            'registros': 1500,
            'timestamp': context['execution_date'].isoformat()
        }
        
        # Retornar dados (será armazenado em XCom)
        return json.dumps(dados)
    
    def validar_dados(entidade_id, **context):
        """Valida dados extraídos"""
        print(f"✓ Validando dados para: {entidade_id}")
        
        # Recuperar dados do upstream task
        task_instance = context['task_instance']
        dados_extraidos = task_instance.xcom_pull(
            task_ids=f'processar_{entidade_id}.extract'
        )
        
        print(f"  Dados recebidos: {dados_extraidos}")
        
        # Simular validação
        validacao = {
            'entidade': entidade_id,
            'linhas_validas': 1450,
            'linhas_invalidas': 50,
            'status': 'OK'
        }
        
        return json.dumps(validacao)
    
    def transformar_dados(entidade_id, **context):
        """Transforma dados para formato final"""
        print(f"⚙️ Transformando dados para: {entidade_id}")
        
        transformacao = {
            'entidade': entidade_id,
            'tabelas_criadas': 3,
            'status': 'SUCESSO'
        }
        
        return json.dumps(transformacao)
    
    def carregar_dados(entidade_id, **context):
        """Carrega dados em data warehouse"""
        print(f"💾 Carregando dados para: {entidade_id}")
        
        # Simular inserção em banco de dados
        resultado = {
            'entidade': entidade_id,
            'linhas_inseridas': 1450,
            'tempo_ms': 2500,
            'status': 'CARREGADO'
        }
        
        return json.dumps(resultado)
    
    # ============== TASK DE INÍCIO ==============
    inicio = BashOperator(
        task_id='inicio_pipeline',
        bash_command='echo "Iniciando pipeline de processamento para 10 entidades"'
    )
    
    # ============== CRIAÇÃO DINÂMICA DE TASKS ==============
    # Padrão: Usar TaskGroup para agrupar tasks relacionadas
    task_groups = []
    
    for entidade in entidades:
        with TaskGroup(group_id=f'processar_{entidade}') as tg:
            
            # Task 1: Extração
            extract = PythonOperator(
                task_id='extract',
                python_callable=extrair_dados,
                op_kwargs={'entidade_id': entidade},
            )
            
            # Task 2: Validação
            validate = PythonOperator(
                task_id='validate',
                python_callable=validar_dados,
                op_kwargs={'entidade_id': entidade},
            )
            
            # Task 3: Transformação
            transform = PythonOperator(
                task_id='transform',
                python_callable=transformar_dados,
                op_kwargs={'entidade_id': entidade},
            )
            
            # Task 4: Carregamento
            load = PythonOperator(
                task_id='load',
                python_callable=carregar_dados,
                op_kwargs={'entidade_id': entidade},
            )
            
            # Dependências dentro do TaskGroup
            extract >> validate >> transform >> load
            
            task_groups.append(tg)
    
    # ============== TASK DE FIM ==============
    fim = BashOperator(
        task_id='fim_pipeline',
        bash_command='echo "Pipeline finalizado com sucesso"'
    )
    
    # ============== FLUXO PRINCIPAL ==============
    # inicio >> task_groups >> fim
    # (TaskGroups são executadas em paralelo)
    inicio >> task_groups >> fim
```

---

## 6. CASOS DE USO REAIS EM ENGENHARIA DE DADOS

### 📌 Caso 1: Ingestão Multi-Tabela de Banco de Dados

**Cenário Real**: Você precisa extrair 50+ tabelas de um PostgreSQL para Data Lake diariamente.

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup
from sqlalchemy import create_engine, inspect
import pandas as pd

def obter_tabelas_dinamicamente():
    """Consulta quais tabelas existem no BD em tempo de execução"""
    engine = create_engine('postgresql://user:pass@host/dbname')
    inspector = inspect(engine)
    return inspector.get_table_names()  # Retorna lista dinâmica

with DAG('ingestao_multi_tabela', ...) as dag:
    
    tabelas = obter_tabelas_dinamicamente()  # ← Executado no parsing
    
    for tabela in tabelas:
        with TaskGroup(f'processar_tabela_{tabela}') as tg:
            
            extract = PythonOperator(
                task_id='extract',
                python_callable=lambda t=tabela: pd.read_sql(
                    f'SELECT * FROM {t}',
                    con=engine
                ).to_parquet(f'/data/raw/{t}.parquet')
            )
            
            # ... validate, transform, load
```

**Impacto Real**: Ao invés de codificar 50 tasks, você tem 50 geradas automaticamente!

---

### 📌 Caso 2: Processamento de Múltiplos Clientes (SaaS)

**Cenário Real**: Plataforma SaaS com 1000+ clientes. Cada um precisa de ETL diário.

```python
from airflow import DAG
from airflow.models import Variable
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup

def obter_clientes_ativos():
    """Busca clientes ativos do banco de metadados"""
    # SELECT id, name FROM customers WHERE status='ACTIVE'
    return ['cliente_001', 'cliente_002', ..., 'cliente_1000']

with DAG('multi_cliente_etl', schedule_interval='@daily') as dag:
    
    clientes = obter_clientes_ativos()
    
    for cliente_id in clientes:
        with TaskGroup(f'cliente_{cliente_id}') as tg:
            
            # Cada cliente tem seu próprio pipeline ETL isolado
            # Falha de um não afeta outro
            
            extract = PythonOperator(
                task_id='extract',
                python_callable=extrair_dados_cliente,
                op_kwargs={'customer_id': cliente_id}
            )
            # ... mais tasks
```

**Benefício**: Isolamento de falhas + processamento paralelo = escalabilidade

---

### 📌 Caso 3: Ingestão de APIs com Paginação Dinâmica

**Cenário Real**: API com 100+ endpoints, cada um precisando de sincronização.

```python
import requests
from airflow.utils.task_group import TaskGroup

def descobrir_endpoints():
    """Consulta OpenAPI/Swagger para descobrir endpoints dinamicamente"""
    response = requests.get('https://api.example.com/swagger.json')
    endpoints = [path for path in response.json()['paths'].keys()]
    return endpoints

with DAG('api_dynamic_ingest') as dag:
    
    endpoints = descobrir_endpoints()
    
    for endpoint in endpoints:
        with TaskGroup(f'sync_{endpoint.replace("/", "_")}') as tg:
            
            def ingerir_endpoint(ep_path, page=1, **context):
                """Sincroniza com paginação dinâmica"""
                all_data = []
                
                while True:
                    resp = requests.get(
                        f'https://api.example.com{ep_path}?page={page}'
                    )
                    
                    if not resp.json():
                        break
                    
                    all_data.extend(resp.json())
                    page += 1
                
                # Salvar em data lake
                pd.DataFrame(all_data).to_parquet(
                    f'/data/apis/{ep_path.replace("/", "_")}.parquet'
                )
            
            ingerir = PythonOperator(
                task_id='ingest',
                python_callable=ingerir_endpoint,
                op_kwargs={'ep_path': endpoint}
            )
```

---

### 📌 Caso 4: Processamento de Partições Dinâmicas (Hadoop/S3)

**Cenário Real**: Processar 10000+ arquivos Parquet particionados por data/região.

```python
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup
import boto3
from datetime import datetime, timedelta

def descobrir_particoes_s3(bucket, prefix):
    """Lista partições de data que não foram processadas ainda"""
    s3 = boto3.client('s3')
    
    objetos = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
    particoes = set()
    
    for obj in objetos.get('Contents', []):
        # Extrair data da chave: s3://bucket/data/2024/01/15/...
        partes = obj['Key'].split('/')
        data = f"{partes[2]}/{partes[3]}/{partes[4]}"
        particoes.add(data)
    
    return sorted(list(particoes))

with DAG('processar_particoes_s3') as dag:
    
    particoes = descobrir_particoes_s3('meu-bucket', 'raw/vendas/')
    
    for particao in particoes[-7:]:  # Últimos 7 dias
        with TaskGroup(f'particao_{particao.replace("/", "_")}') as tg:
            
            processar = PythonOperator(
                task_id='process',
                python_callable=lambda p=particao: processar_dados(
                    f's3://meu-bucket/raw/vendas/{p}/'
                )
            )
```

**Realidade**: Com 10 dias de dados × múltiplas regiões = 1000+ tasks geradas automaticamente!

---

### 📌 Caso 5: Pipeline Parametrizado com Branch Dinâmica

**Cenário Real**: Diferentes regras de transformação por tipo de cliente.

```python
from airflow.models import Variable
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup
from airflow.operators.dummy import DummyOperator

def obter_configuracao_clientes():
    """Busca mapeamento cliente -> tipo -> regras"""
    return {
        'cliente_001': {'tipo': 'premium', 'schema': 'premium_rules'},
        'cliente_002': {'tipo': 'standard', 'schema': 'standard_rules'},
        'cliente_003': {'tipo': 'enterprise', 'schema': 'enterprise_rules'},
    }

with DAG('pipeline_parametrizado') as dag:
    
    config = obter_configuracao_clientes()
    
    for cliente_id, detalhes in config.items():
        
        with TaskGroup(f'cliente_{cliente_id}') as tg:
            
            extract = PythonOperator(
                task_id='extract',
                python_callable=extrair_dados,
                op_kwargs={'cliente': cliente_id}
            )
            
            # Aplicar regras específicas por tipo de cliente
            if detalhes['tipo'] == 'premium':
                transform = PythonOperator(
                    task_id='transform_premium',
                    python_callable=transformar_premium
                )
            elif detalhes['tipo'] == 'standard':
                transform = PythonOperator(
                    task_id='transform_standard',
                    python_callable=transformar_standard
                )
            
            load = PythonOperator(
                task_id='load',
                python_callable=carregar_para_dw,
                op_kwargs={'schema': detalhes['schema']}
            )
            
            extract >> transform >> load
```

---

## 7. PADRÕES AVANÇADOS

### Pattern: Usar Variáveis do Airflow para Configuração

```python
# No arquivo .env ou UI do Airflow:
# CLIENTES_PARA_PROCESSAR = "['cliente_A', 'cliente_B', 'cliente_C']"

from airflow.models import Variable
import json

clientes = json.loads(Variable.get('CLIENTES_PARA_PROCESSAR'))

for cliente in clientes:
    # ... criar tasks
```

### Pattern: XCom para Passar Dados Entre Tasks Dinâmicas

```python
def tarefa_upstream(**context):
    ti = context['task_instance']
    ti.xcom_push(key='dados_processados', value={'resultado': 42})

def tarefa_downstream(**context):
    ti = context['task_instance']
    # Buscar dados de qualquer task do grupo anterior
    dados = ti.xcom_pull(
        task_ids='processar_cliente_A.tarefa_upstream',
        key='dados_processados'
    )
```

---

## 8. ARMADILHAS COMUNS ⚠️

| Problema | Causa | Solução |
|----------|-------|--------|
| **Tasks não aparecem** | Loop em runtime, não parsing | Mover lógica para fora do DAG |
| **Muitas tasks** | Geração sem limite (10k+) | Usar `max_active_tasks` + scheduler limits |
| **Memória explode** | DAG with 100k tasks carregado em memória | Usar SerializedDAG + dynamic task mapping |
| **XCom falha** | Tamanho de dados > limite (24KB padrão) | Usar backend externo ou S3 XCom |

---

## 9. PRÓXIMOS PASSOS PARA APROFUNDAMENTO

1. **Dynamic Task Mapping** (Airflow 2.3+) - mais moderno que TaskGroups
   - https://airflow.apache.org/docs/apache-airflow/stable/howto/dynamic-task-mapping.html

2. **Scheduler Tuning** - quando você tem 10k+ tasks
   - https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html#general-best-practices

3. **Monitoramento & Alertas** - com Prometheus + Grafana
   - https://airflow.apache.org/docs/apache-airflow/stable/logging-monitoring-alerting.html

---

## RESUMO EXECUTIVO

- **Generating Tasks**: Loop simples para gerar N tasks idênticas
- **SubDAGs**: EVITAR - padrão descontinuado
- **TaskGroups**: RECOMENDADO - melhor performance e visibilidade
- **Casos reais**: Multi-tabela, multi-cliente, APIs, partições S3, pipelines parametrizados
- **Armadilha comum**: Confundir tempo de parsing com tempo de execução

**Próxima aula**: Dynamic Task Mapping (Airflow 2.3+) para casos ainda mais escaláveis!