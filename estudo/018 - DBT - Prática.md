# Semana 7: DBT - Guia Completo para Transformação de Dados

## O que é DBT (Data Build Tool)?

DBT é uma ferramenta que transforma dados já carregados no warehouse (seu Airflow alimenta o banco, DBT transforma). Ele trabalha com SQL, versionamento git e testes, implementando boas práticas de engenharia em pipelines de dados.

---

## MÓDULO 1: STAGING MODELS (8h)

### Conceito Fundamental

Staging models são a primeira camada de transformação. Eles limpam, padronizam e preparam dados brutos para o uso business.

**O que fazem:**
- Renomeiam colunas (snake_case padronizado)
- Convertem tipos de dados
- Removem duplicatas
- Aplicam validações básicas

### Documentação Oficial
- **Docs DBT**: https://docs.getdbt.com/docs/introduction
- **Best Practices - Staging Models**: https://docs.getdbt.com/guides/best-practices/how-we-structure/1-guide-overview
- **Ref function**: https://docs.getdbt.com/reference/dbt-jinja-functions/ref

### Exemplo Prático Inicial

```sql
-- models/staging/stg_customers.sql

{{
  config(
    materialized = 'view',
    description = 'Staging layer para dados brutos de clientes'
  )
}}

with source_data as (
  select
    customer_id,
    customer_name as nome_cliente,
    customer_email as email_cliente,
    created_at::date as data_criacao,
    updated_at::date as data_atualizacao
  from {{ source('raw_layer', 'customers') }}
  where deleted_at is null
)

select * from source_data
```

### Testes de Uniqueness (dbt_tests)

```yaml
# models/staging/stg_customers.yml

models:
  - name: stg_customers
    description: "Staging de clientes"
    columns:
      - name: customer_id
        description: "ID único do cliente"
        tests:
          - unique
          - not_null
      - name: email_cliente
        description: "Email do cliente"
        tests:
          - unique
```

**Executar testes:**
```bash
dbt test --models stg_customers
```

---

## MÓDULO 2: MART MODELS (8h)

### Conceito Fundamental

Marts são tabelas de negócio prontas para análise. São agregações, joins e cálculos que business/analytics usam diretamente.

**Características:**
- Denormalizadas (joins já feitos)
- Agregações prontas
- Visão orientada ao negócio
- Geralmente materializadas como tabelas

### Exemplo: Mart de Vendas

```sql
-- models/marts/fct_orders.sql

{{
  config(
    materialized = 'table',
    description = 'Tabela fato de pedidos com todas as dimensões',
    indexes = [
      {'columns': ['order_date'], 'type': 'btree'}
    ]
  )
}}

with orders as (
  select * from {{ ref('stg_orders') }}
),

customers as (
  select * from {{ ref('stg_customers') }}
),

products as (
  select * from {{ ref('stg_products') }}
),

final as (
  select
    o.order_id,
    o.customer_id,
    c.nome_cliente,
    c.email_cliente,
    o.product_id,
    p.nome_produto,
    p.categoria_produto,
    o.quantidade,
    o.preco_unitario,
    (o.quantidade * o.preco_unitario) as valor_total,
    o.data_pedido,
    o.data_entrega,
    case
      when o.data_entrega <= o.data_entrega_esperada then 'No Prazo'
      else 'Atrasado'
    end as status_entrega
  from orders o
  left join customers c on o.customer_id = c.customer_id
  left join products p on o.product_id = p.product_id
)

select * from final
```

### Documentação Oficial
- **Table Materialization**: https://docs.getdbt.com/docs/build/materializations
- **Modeling Techniques**: https://docs.getdbt.com/guides/best-practices/how-we-structure/2-staging

---

## MÓDULO 3: TESTS & DOCUMENTATION (8h)

### Generic Tests (Built-in)

```yaml
# models/marts/mart_vendas.yml

models:
  - name: fct_orders
    description: "Fato de pedidos consolidada"
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: customer_id
        tests:
          - not_null
          - relationships:
              to: ref('stg_customers')
              field: customer_id
      - name: valor_total
        tests:
          - dbt_expectations.expect_column_values_to_be_of_type:
              column_type: numeric
          - dbt_utils.expression_is_true:
              expression: ">= 0"
```

### Custom Tests (Python/SQL)

```sql
-- tests/custom/test_valor_total_coerente.sql

-- Testa se valor_total = quantidade * preco_unitario

select * from {{ ref('fct_orders') }}
where (quantidade * preco_unitario) != valor_total
```

### Documentação Interativa

```yaml
# dbt_project.yml configuração mínima

name: 'projeto_vendas'
version: '1.0.0'
profile: 'projeto_vendas'

model-paths: ["models"]
analysis-paths: ["analysis"]
test-paths: ["tests"]
docs-paths: ["docs"]

target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"

require-dbt-version: [">=1.5.0", "<2.0.0"]
```

**Gerar documentação:**
```bash
dbt docs generate
dbt docs serve  # Visualiza em http://localhost:8000
```

### Documentação Oficial
- **Testing**: https://docs.getdbt.com/docs/build/tests
- **Custom Tests**: https://docs.getdbt.com/docs/build/tests#custom-generic-tests
- **Documentation**: https://docs.getdbt.com/docs/build/documentation

---

# EXEMPLOS DO MUNDO REAL - Engenharia de Dados

## Caso 1: E-commerce com Múltiplas Moedas

Empresa brasileira que vende para 15 países. Precisa de unified reporting.

```sql
-- models/staging/stg_orders_multilingual.sql

with raw_orders as (
  select * from {{ source('raw', 'orders') }}
),

with_exchange_rates as (
  select
    o.*,
    er.exchange_rate,
    o.order_amount * er.exchange_rate as ordem_em_brl
  from raw_orders o
  left join {{ ref('stg_exchange_rates') }} er
    on o.currency = er.currency
    and o.order_date = er.data_cotacao
)

select * from with_exchange_rates
```

**Complexidade real:** Tratamento de timezones, cotações históricas, auditoria de mudanças.

---

## Caso 2: SaaS com Eventos de Usuário (Tracking)

Aplicação coleta 50M+ eventos/dia. Precisa de sessões consolidadas.

```sql
-- models/marts/fct_user_sessions.sql

with events_raw as (
  select
    user_id,
    event_timestamp,
    event_type,
    page_url,
    lag(event_timestamp) over (
      partition by user_id 
      order by event_timestamp
    ) as previous_event_time
  from {{ ref('stg_events') }}
),

sessions as (
  select
    user_id,
    event_timestamp,
    case
      when extract(epoch from (event_timestamp - previous_event_time)) > 1800
        or previous_event_time is null
      then row_number() over (partition by user_id order by event_timestamp)
      else 0
    end as session_id
  from events_raw
),

session_aggregation as (
  select
    user_id,
    min(event_timestamp) as session_start,
    max(event_timestamp) as session_end,
    count(*) as total_events,
    count(distinct page_url) as pages_visited,
    max(case when event_type = 'purchase' then 1 else 0 end) as fez_compra
  from sessions
  group by user_id, session_id
)

select * from session_aggregation
```

**Desafios reais:** Deduplicação de eventos, tratamento de dados fora de ordem, janelas de tempo variáveis.

---

## Caso 3: Marketplace - Matriz RFM para Segmentação

Plataforma que precisa segmentar sellers e buyers.

```sql
-- models/marts/dim_customer_rfm.sql

with orders as (
  select * from {{ ref('fct_orders') }}
),

rfm_base as (
  select
    customer_id,
    count(distinct order_id) as frequency,
    sum(valor_total) as monetary,
    max(data_pedido) as last_purchase_date,
    current_date - max(data_pedido) as recency_days
  from orders
  where data_pedido >= current_date - interval '365 days'
  group by customer_id
),

rfm_scores as (
  select
    customer_id,
    frequency,
    monetary,
    recency_days,
    ntile(5) over (order by recency_days desc) as recency_score,
    ntile(5) over (order by frequency asc) as frequency_score,
    ntile(5) over (order by monetary asc) as monetary_score
  from rfm_base
),

rfm_segments as (
  select
    *,
    case
      when recency_score >= 4 and frequency_score >= 4 then 'Campeoes'
      when recency_score >= 3 and frequency_score >= 4 then 'Clientes Leais'
      when recency_score <= 2 and frequency_score >= 4 then 'Em Risco'
      when recency_score <= 2 and frequency_score <= 2 then 'Perdidos'
      else 'Potencial'
    end as segment_rfm
  from rfm_scores
)

select * from rfm_segments
```

---

## Caso 4: FinTech - Compliance e Auditoria

Empresa financeira com rastreabilidade obrigatória.

```sql
-- tests/custom/test_auditoria_consistencia_saldos.sql

-- Garante que saldo inicial + entradas - saídas = saldo final

with transacoes as (
  select
    conta_id,
    data_transacao,
    tipo_transacao,
    valor,
    saldo_final
  from {{ ref('fct_transacoes') }}
),

saldo_calculado as (
  select
    conta_id,
    data_transacao,
    sum(case 
      when tipo_transacao = 'entrada' then valor
      when tipo_transacao = 'saida' then -valor
      else 0
    end) over (
      partition by conta_id 
      order by data_transacao
      rows between unbounded preceding and current row
    ) as saldo_esperado,
    saldo_final
  from transacoes
)

select * from saldo_calculado
where saldo_esperado != saldo_final
```

---

## Caso 5: Analytics de Retenção (Cohort Analysis)

SaaS com análise de churn.

```sql
-- models/marts/fct_user_retention_cohort.sql

with first_purchase as (
  select
    customer_id,
    min(data_pedido) as first_purchase_date,
    extract(year_month from min(data_pedido)) as cohort_month
  from {{ ref('fct_orders') }}
  group by customer_id
),

all_purchases as (
  select
    o.customer_id,
    fp.cohort_month,
    o.data_pedido,
    extract(year_month from o.data_pedido) as purchase_month,
    (extract(year from o.data_pedido) - extract(year from fp.first_purchase_date)) * 12 +
    (extract(month from o.data_pedido) - extract(month from fp.first_purchase_date))
      as months_since_first_purchase
  from {{ ref('fct_orders') }} o
  join first_purchase fp on o.customer_id = fp.customer_id
)

select
  cohort_month,
  months_since_first_purchase,
  count(distinct customer_id) as retained_customers
from all_purchases
group by cohort_month, months_since_first_purchase
```

---

# ESTRUTURA DE PROJETO RECOMENDADA

```
projeto_dados/
├── models/
│   ├── staging/
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   └── stg_products.sql
│   ├── marts/
│   │   ├── fct_orders.sql
│   │   ├── dim_customers.sql
│   │   └── dim_products.sql
│   ├── schema.yml           # Documentação de todas as tabelas
│   └── sources.yml          # Definição dos dados brutos
├── tests/
│   ├── custom/
│   │   └── test_validacao_negocio.sql
│   └── generic/             # Generic tests via YAML
├── docs/
│   └── index.md
├── dbt_project.yml
└── profiles.yml             # Configuração de conexão BD
```

---

# CHECKLIST FINAL (40h)

- ✅ 3+ staging models com documentação
- ✅ 5+ mart models com joins complexos
- ✅ 10+ testes (unique, not_null, relationships, custom)
- ✅ Documentação em YAML completa
- ✅ `dbt run` passando sem erros
- ✅ `dbt test` com 100% de cobertura
- ✅ `dbt docs serve` funcionando
- ✅ Projeto versionado em Git

---

## Próxima etapa

Integrar com Looker/Metabase para visualizações.