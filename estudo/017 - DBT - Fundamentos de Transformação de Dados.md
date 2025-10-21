# DBT - Semana 7: Fundamentos da Transformação de Dados

Excelente! Vou guiá-lo através desses conceitos fundamentais de DBT com minha perspectiva de 20 anos na área. Vou estruturar isto de forma prática e conectada ao dia a dia da engenharia de dados.

---

## 1. DBT vs Spark (2h)

### Conceito Fundamental

DBT (Data Build Tool) e Spark são ferramentas complementares, não concorrentes. Essa é a primeira coisa que precisa entender.

**DBT** é um framework de **transformação de dados** que funciona como um gerenciador de transformações SQL. Ele executa suas queries SQL contra um banco de dados já existente (Snowflake, BigQuery, PostgreSQL, etc). É especialmente poderoso para organizar, testar, documentar e reutilizar lógica de transformação.

**Spark** é um **motor de processamento distribuído** que processa dados em larga escala, ideal para dados não estruturados, processamento paralelo complexo e operações que exigem computação intensiva além do que um data warehouse pode fazer nativamente.

### Quando usar cada um:

**Use DBT quando:**
- Seus dados já estão em um data warehouse (Snowflake, BigQuery, Redshift)
- Você precisa fazer transformações SQL complexas e repetíveis
- Quer versionamento, testes e documentação automática de transformações
- A equipe é mais SQL-native e precisa de abstração de orquestração
- Você quer DAGs automáticos de dependências entre transformações

**Use Spark quando:**
- Precisa processar dados não estruturados (imagens, vídeos, logs sem schema)
- Necessita de transformações que exigem operações de Machine Learning
- Quer escalar horizontalmente em clusters
- Precisa de flexibilidade com linguagens como Python ou Scala
- Está fazendo feature engineering complexo

**Use AMBOS quando:** (Este é o cenário mais comum hoje)
- Spark extrai e processa dados brutos em sua Data Lake
- DBT transforma esses dados no Data Warehouse para BI e analytics
- Exemplo: Spark processa 10TB de logs diários → DBT organiza em tabelas consumíveis

### Documentação Oficial:
- **DBT Docs**: https://docs.getdbt.com/docs/introduction
- **Spark Docs**: https://spark.apache.org/docs/latest/

---

## 2. Models, Tests, Documentação (2h)

### O que é um Model no DBT?

Um **model** é basicamente um arquivo SQL que representa uma transformação. Ele é salvo em `.sql` e DBT converte em uma tabela ou view no seu banco de dados. Pense em models como "componentes reutilizáveis" da sua lógica de transformação.

Cada model tem um arquivo YAML associado que define testes e documentação.

```sql
-- models/stg_customers.sql
SELECT 
    customer_id,
    customer_name,
    email,
    created_at
FROM {{ source('raw', 'customers') }}
WHERE deleted_at IS NULL
```

### Tests (Testes Automatizados)

DBT oferece 4 tipos de testes principais:

**Testes genéricos (built-in):** não_null, unique, accepted_values, relationships. São declarativos e aplicáveis a qualquer coluna. Por exemplo, você garante que `customer_id` nunca é nulo e sempre é único.

**Testes customizados:** você escreve SQL para validações específicas do seu negócio. Por exemplo, validar que a taxa de cancelamento nunca ultrapassa 5% em um dia, ou que receita não pode ser negativa.

```yaml
# models/schema.yml
models:
  - name: stg_customers
    columns:
      - name: customer_id
        tests:
          - not_null
          - unique
      - name: email
        tests:
          - not_null
          - unique
      - name: status
        tests:
          - accepted_values:
              values: ['active', 'inactive', 'suspended']
```

### Documentação

DBT gera documentação automática dos seus modelos, colunas, testes e linhagem de dados. A documentação fica viva - sempre sincronizada com seu código.

```yaml
models:
  - name: dim_customers
    description: "Tabela de dimensão com clientes únicos"
    columns:
      - name: customer_id
        description: "Identificador único do cliente"
        tests:
          - not_null
          - unique
      - name: lifetime_value
        description: "Valor total gasto pelo cliente em toda sua história"
```

### Documentação Oficial:
- **DBT Models**: https://docs.getdbt.com/docs/build/models
- **DBT Tests**: https://docs.getdbt.com/docs/build/tests
- **DBT Documentation**: https://docs.getdbt.com/docs/build/documentation

---

## 3. Sources e Refs (2h)

### Sources (Fontes de Dados)

**Sources** definem as tabelas brutas que alimentam seus models. Elas são a "origem da verdade" do seu pipeline.

Ao usar `source()`, DBT:
1. Rastreia qual tabela bruta alimenta quais transformações
2. Permite validar a integridade dos dados brutos com testes
3. Cria documentação da linhagem de dados
4. Facilita refatoração (se a origem mudar de banco, muda apenas uma referência)

```yaml
# models/sources.yml
sources:
  - name: raw_database
    description: "Dados brutos do sistema de produção"
    database: analytics_raw
    schema: public
    tables:
      - name: customers
        description: "Tabela bruta de clientes"
        columns:
          - name: id
            tests:
              - not_null
              - unique
      - name: orders
        description: "Tabela bruta de pedidos"
```

Seu model então referencia a source:

```sql
-- models/stg_customers.sql
SELECT * FROM {{ source('raw_database', 'customers') }}
```

### Refs (Referências Entre Models)

**Refs** conectam models entre si, criando dependências explícitas.

```sql
-- models/stg_orders.sql (primeiro stage)
SELECT order_id, customer_id, order_date FROM {{ source('raw', 'orders') }}

-- models/fct_orders.sql (modelo de fatos)
SELECT 
    o.order_id,
    c.customer_name,  -- referenciando customer
    o.order_date
FROM {{ ref('stg_orders') }} o
JOIN {{ ref('stg_customers') }} c ON o.customer_id = c.customer_id
```

DBT usa `ref()` para:
1. Gerar o DAG (Directed Acyclic Graph) automaticamente
2. Garantir que models são executados na ordem correta
3. Detectar referências circulares
4. Permitir seleção granular de execução (`dbt run -s +fct_orders` roda apenas fct_orders e suas dependências)

### Por que isso importa?

Você consegue rastrear: dados brutos → staging → marts → dashboards. Se um valor estiver errado no Dashboard, você segue o ref para ver exatamente onde entrou errado.

### Documentação Oficial:
- **DBT Sources**: https://docs.getdbt.com/docs/build/sources
- **DBT Refs**: https://docs.getdbt.com/docs/build/ref
- **Linhagem de Dados**: https://docs.getdbt.com/docs/collaborate/documentation#data-lineage

---

## 4. Materializations (2h)

### O que é Materialização?

**Materialização** define COMO DBT materializa seu model. É o OUTPUT final: vai ser uma tabela? Uma view? Um snapshot?

### Tipos Principais:

**TABLE (Tabela Física)**
- DBT executa a query e armazena resultado em uma tabela no banco
- Faster queries (dados já computados)
- Mais espaço em disco
- Ideal para modelos que são consultados frequentemente
- Melhor para dados que mudam raramente

```sql
{{ config(materialized='table') }}
SELECT ... FROM ...
```

**VIEW (View Materializada)**
- DBT armazena apenas a query, não o resultado
- Executa a query toda vez que consultada
- Sem overhead de espaço
- Ideal para transformações simples e dados que mudam constantemente
- Use para intermediate staging tables

```sql
{{ config(materialized='view') }}
SELECT ... FROM ...
```

**INCREMENTAL (Tabela Incremental)**
- Primeira execução: cria a tabela (como TABLE)
- Execuções posteriores: adiciona apenas NOVOS dados (não recomputa tudo)
- Crítico para pipelines grandes rodando diariamente
- Reduz tempo de execução drasticamente

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    on_schema_change='fail'
) }}

SELECT * FROM {{ source('raw', 'orders') }}

{% if execute %}
    WHERE created_at > (SELECT MAX(created_at) FROM {{ this }})
{% endif %}
```

**EPHEMERAL (Temporária)**
- Não materializa em banco, fica apenas em memória durante execução
- Útil para CTEs reutilizáveis em múltiplos models
- Zero footprint no banco

### Critérios de Decisão (Baseado em 20 anos):

**TABLE quando:**
- Model é consultado 100+ vezes por dia
- Join é complexo ou dados são grandes
- Tempo de query crítico para negócio (dashboards executivos)
- Exemplo: `dim_customers`, `fct_sales`

**VIEW quando:**
- Model é staging intermediário
- Dados mudam constantemente
- Poucas consultas diretas
- Exemplo: `stg_raw_orders`, transformações intermediárias

**INCREMENTAL quando:**
- Dados crescem continuamente (append-only)
- Recomputar histórico é impraticável
- Exemplo: `fct_daily_transactions`, `stg_events_log`

### Documentação Oficial:
- **DBT Materializations**: https://docs.getdbt.com/docs/build/materializations
- **Incremental Models**: https://docs.getdbt.com/docs/build/incremental-models

---

## Exemplos do Mundo Real - Engenharia de Dados

### Caso 1: E-commerce com Crescimento Exponencial

**Contexto:** Uma plataforma de e-commerce processava 1M de pedidos/dia. Começaram com tudo em VIEW e enfrentaram timeout em dashboards.

**Pipeline original:**
```
raw.orders (10B linhas) 
    → stg_orders (VIEW) 
        → fct_orders (VIEW) 
            → Dashboard (⏱️ 5 minutos por query)
```

**Problema:** Cada query refazia computações de 10 anos de histórico.

**Solução implementada (DBT):**
```
raw.orders (append-only)
    ↓
stg_orders (INCREMENTAL - processa apenas últimos 7 dias)
    ↓
fct_orders (TABLE - materializado diariamente)
    ↓
fct_orders_snapshot (SNAPSHOT - track mudanças de status)
    ↓
Dashboard (⏱️ 3 segundos agora)
```

**Resultado:** 
- Queries 100x mais rápidas
- Pipeline inteiro executava em 15 minutos (vs 3 horas antes)
- Testes automáticos detectavam duplicatas de pedidos em staging

**Código DBT Real:**
```sql
-- models/fct_orders.sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    on_schema_change='fail',
    tags=['daily']
) }}

SELECT 
    o.order_id,
    c.customer_id,
    o.order_date,
    SUM(li.price * li.quantity) as order_total,
    COUNT(DISTINCT li.line_item_id) as line_items_count
FROM {{ ref('stg_orders') }} o
JOIN {{ ref('dim_customers') }} c ON o.customer_id = c.customer_id
JOIN {{ ref('stg_line_items') }} li ON o.order_id = li.order_id
WHERE 1=1
    {% if execute %}
        AND o.order_date >= (SELECT MAX(order_date) FROM {{ this }})
    {% endif %}
GROUP BY 1, 2, 3
```

---

### Caso 2: Fintech com Conformidade Regulatória

**Contexto:** Banco digital precisava rastrear exatamente como cada transação foi calculada (compliance KYC/AML).

**Desafio:** Auditores pediam: "Por que este cliente foi sinalizado em 15/10?"

**Solução DBT + Snapshots:**
```sql
-- models/snapshots/snapshot_customer_risk.sql
{% snapshot customer_risk_snapshot %}
  SELECT 
    customer_id,
    risk_score,
    risk_level,
    transactions_last_24h,
    countries_accessed,
    dbt_valid_from,
    dbt_valid_to
  FROM {{ ref('fct_customer_risk') }}
{% endsnapshot %}
```

**Com SNAPSHOT, conseguiam:**
1. Ver exatamente qual era o `risk_score` em qualquer data
2. Auditar quando transições ocorreram (low → high risk)
3. Documentar por que uma decisão foi tomada

**Testes críticos implementados:**
```yaml
models:
  - name: fct_customer_risk
    columns:
      - name: risk_score
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 100
      - name: customer_id
        tests:
          - relationships:
              to: ref('dim_customers')
              field: customer_id
```

Isso garantia que: nenhum `risk_score` fosse nulo, nenhum score saísse do range 0-100, e nenhum cliente fantasma fosse criado.

---

### Caso 3: Data Lake com Governança

**Contexto:** Empresa com 50+ fontes de dados diferentes, 200+ analistas, sem governança.

**Problema:** 
- "Qual tabela de `customers` é a correta?"
- "Quem último usou isso?"
- "Isso ainda é válido?"

**Solução DBT com Sources + Documentação:**
```yaml
# models/sources.yml
sources:
  - name: salesforce_crm
    description: "Sistema Salesforce de CRM (único source autorizado)"
    database: raw_landing
    schema: salesforce
    meta:
      owner: "time_crm@empresa.com"
      freshness:
        warn_after: {count: 6, period: hour}
        error_after: {count: 12, period: hour}
    tables:
      - name: sf_contacts
        description: "Contatos do Salesforce"
        meta:
          owner_team: "CRM Analytics"
        columns:
          - name: contact_id
            tests:
              - not_null
              - unique
              
  - name: legacy_database
    description: "DEPRECATED - Usar salesforce_crm ao invés"
    database: warehouse_old
    schema: public
```

**Resultado:** 
- Documentação gerada automaticamente mostra owner de cada tabela
- Testes de freshness alertam se Salesforce parou de sincronizar
- DBT docs page servem como "fonte única da verdade" para toda a empresa

---

### Caso 4: Engenharia de Features para ML

**Contexto:** Equipe de ML precisava features atualizadas diariamente para treinar modelo de churn.

**Challenge:** Features vinham de 5 tabelas diferentes, lógica era replicada em 3 idiomas (SQL, Python, Scala).

**Solução DBT + INCREMENTAL:**
```sql
-- models/ml_features/fct_customer_features_daily.sql
{{ config(
    materialized='incremental',
    unique_key=['customer_id', 'feature_date'],
    partition_by={
        'field': 'feature_date',
        'data_type': 'date',
        'granularity': 'day'
    }
) }}

SELECT 
    customer_id,
    CURRENT_DATE as feature_date,
    -- Activity Features
    COALESCE(SUM(CASE WHEN days_since_login <= 7 THEN 1 ELSE 0 END), 0) as logins_last_7_days,
    COALESCE(AVG(session_duration_seconds), 0) as avg_session_duration,
    -- Financial Features
    SUM(total_spent_amount) OVER (
        PARTITION BY customer_id 
        ORDER BY feature_date ROWS BETWEEN 90 PRECEDING AND CURRENT ROW
    ) as revenue_90_days,
    -- Risk Features
    MAX(CASE WHEN fraud_alert = true THEN 1 ELSE 0 END) as has_fraud_flag,
    COUNT(DISTINCT payment_method) as unique_payment_methods
FROM {{ ref('fct_customer_daily_metrics') }}
GROUP BY customer_id, feature_date
```

**Por que isso funciona melhor que Spark aqui:**
- ML team já sabe SQL (não precisa de Python/Scala)
- Data warehouse já tem todos dados agregados
- INCREMENTAL executa em 5 min (vs 45 min em Spark job)
- Testes garantem 0 valores null em features críticas

---

## Estrutura de Projeto DBT (Minha Recomendação)

Após 20 anos vendo isto falhar e funcionar:

```
dbt_project/
├── models/
│   ├── 00_sources/
│   │   └── sources.yml          # Todas as definitions de dados brutos
│   ├── 01_staging/
│   │   ├── stg_customers.sql    # VIEW: limpeza mínima
│   │   └── stg_schema.yml
│   ├── 02_intermediate/
│   │   └── intermediate_*.sql   # VIEW: agregações e joins
│   ├── 03_marts/
│   │   ├── fct_*.sql            # TABLE: fatos (append-only)
│   │   ├── dim_*.sql            # TABLE: dimensões
│   │   └── mart_schema.yml
│   └── 04_snapshots/
│       └── snapshot_*.sql
├── tests/
│   ├── generic/                 # Testes customizados
│   └── data_quality/
├── macros/
│   └── generate_aliases.sql
├── seeds/
│   └── currency_rates.csv
├── dbt_project.yml
└── README.md
```

**Convenção de Nomeclatura:**
- `stg_` = staging (VIEW)
- `fct_` = fatos (TABLE incremental)
- `dim_` = dimensões (TABLE)
- `int_` = intermediários (VIEW)

---

## Recursos Essenciais para Aprofundamento

**Documentação Oficial:**
1. https://docs.getdbt.com/docs/build/models
2. https://docs.getdbt.com/docs/build/tests  
3. https://docs.getdbt.com/docs/build/sources
4. https://docs.getdbt.com/docs/build/incremental-models

**Comunidade (Muito ativa):**
- dbt Slack Community: https://www.getdbt.com/community
- dbt Discourse: https://discourse.getdbt.com/

**Tutoriais Práticos:**
- dbt Learn: https://learn.getdbt.com/ (cursos interativos gratuitos)

---

Quer que eu aprofunde em algum desses tópicos? Posso mostrar mais exemplos de testes customizados, macros avançadas, ou como integrar DBT com orquestradores como Airflow/Dagster.