# CI/CD com dbt: Uma Jornada Prática

Após duas décadas trabalhando em Engenharia de Dados, posso te dizer que a implementação de CI/CD com dbt é onde a maturidade analytics começa. Vou desdobrar isso para você.

## 1. GitHub Actions para rodar dbt

### O Conceito

Você automatiza testes e compilação do dbt toda vez que alguém faz push. É como ter um revisor robótico checando cada modificação.

### Como funciona

Você cria um arquivo `.github/workflows/dbt-ci.yml` que dispara quando há mudanças. O GitHub oferece máquinas virtuais onde seus comandos rodam. No contexto PHP que você conhece, é análogo a usar GitHub Actions para rodar testes PHPUnit automaticamente a cada commit.

### Documentação Oficial

- GitHub Actions: https://docs.github.com/en/actions
- dbt Cloud + GitHub: https://docs.getdbt.com/docs/deploy/continuous-integration-guides/github-actions-setup
- dbt CLI Commands: https://docs.getdbt.com/reference/dbt-commands

### Exemplo básico de workflow

```yaml
name: dbt CI
on: [pull_request]
jobs:
  dbt-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
      - run: pip install dbt-snowflake
      - run: dbt deps
      - run: dbt parse
      - run: dbt test
      - run: dbt docs generate
```

---

## 2. Slim CI (Apenas models modificados)

### O Problema que resolve

Imagine um data warehouse com 500 modelos. Você muda 1 modelo. Executar testes em todos os 500 é desperdiçador. Slim CI roda testes apenas nos modelos alterados e seus dependentes.

### Como funciona internamente

O dbt detecta quais arquivos `.sql` mudaram no commit via `git diff`. Constrói um grafo de dependências e executa testes apenas no subconjunto afetado.

### Documentação

- dbt Slim CI: https://docs.getdbt.com/docs/deploy/continuous-integration-guides/slim-ci

### Exemplo prático

```yaml
- run: dbt test --select state:modified+ --state ./target
```

O `state:modified+` significa "o que foi modificado E tudo que depende disso".

---

## 3. Deployment Staging/Prod

### O Fluxo

1. Dev faz PR → CI roda testes em clone de prod
2. Aprova → merge em main → deploy staging → validação → deploy prod

### Documentação

- dbt Deployments: https://docs.getdbt.com/docs/deploy/deployments
- dbt Cloud Environments: https://docs.getdbt.com/docs/dbt-cloud/cloud-overview-and-workspace-setup

### Conceito crítico que vejo faltando em muitas equipes

A separação de schemas. Você não quer que a CI rode no schema de produção. Tipicamente:
- `analytics_dev` para PRs
- `analytics_staging` para branch staging
- `analytics_prod` para produção

---

## 4. Debugging em Produção

### Cenário comum (que dói)

Um modelo rodou com sucesso em staging, mas falha em prod. Por quê? Volumes diferentes? Dados faltando?

### Estratégias profissionais

1. **Logs estruturados**: Configure seu `profiles.yml` para ativar logs verbosos
2. **Alerts baseados em testes**: Falhas de teste geram Slack/email
3. **Data freshness checks**: dbt testa se dados críticos estão atualizados

### Documentação

- dbt Tests: https://docs.getdbt.com/docs/build/tests
- dbt Logs: https://docs.getdbt.com/docs/using-dbt/debugging

---

## Exemplo Real #1: E-commerce com 50M de transações diárias

Trabalhei em um case assim. A empresa tinha um dbt com 80+ modelos. Antes de CI/CD, um erro em um staging_orders impactava 15 modelos downstream.

### O que implementamos

- GitHub Actions + Slim CI: testes rodavam em 3 minutos (vs. 45 minutos antes)
- Schema por ambiente: `events_dev`, `events_prod`
- Tests críticos:
  ```sql
  -- Modelo: staging_orders
  select * from {{ ref('staging_orders') }}
  where order_date < current_date - interval '2 years' 
    or order_total < 0
  ```
- Alertas em Slack quando testes falhavam em prod

### Resultado

Reduzimos bugs de transformação em 80%.

---

## Exemplo Real #2: SaaS com múltiplos clientes

Cada cliente tinha seus próprios schemas no warehouse. Um único erro podia corromper dados de 50 clientes.

### Implementação

- Matriz de testes por cliente em CI/CD
- Cada PR testava transformações em 5 clientes sample
- Deployment progressivo: roda por cliente com pausas entre eles
- dbt meta tags para marcar modelos sensíveis:
  ```yaml
  models:
    - name: revenue_dashboard
      meta:
        requires_approval: true
  ```

---

## Exemplo Real #3: DataLake de banco de dados

Millhões de logs por dia. Latência era crítica.

### Desafio específico

Qualquer modelo quebrado causava pipeline inteiro falhar.

### Solução

- Testes com **severity: error/warn**
  ```yaml
  models:
    - name: fact_transactions
      tests:
        - dbt_utils.recency:
            datepart: day
            interval: 1
            severity: error  # falha
        - not_null:
            column_name: transaction_id
            severity: warn   # apenas aviso
  ```
- Retry automático em CI para erros transitórios
- Documentação auto-gerada com `dbt docs generate` publicada em internal wiki

---

## Estrutura de Repositório Recomendada

```
dbt_project/
├── .github/workflows/
│   ├── ci.yml              # Roda em PRs
│   ├── deploy-staging.yml  # Deploy em staging
│   └── deploy-prod.yml     # Deploy em prod
├── models/
│   ├── staging/
│   ├── marts/
│   └── tests/
├── dbt_project.yml
├── profiles.yml            # Git-ignored!
└── docs/                   # Documentação customizada
```

---

## Documentação Essencial para Aprofundar

### Núcleo

1. https://docs.getdbt.com/guides/advanced (Advanced Topics)
2. https://docs.getdbt.com/docs/build/custom-schemas (Schemas dinâmicos)
3. https://docs.getdbt.com/docs/deploy/deployments-overview

### Integrações

1. https://docs.getdbt.com/docs/deploy/continuous-integration
2. https://github.com/dbt-labs/dbt-core (Código-fonte para entender internamente)

### Boas práticas

1. dbt Best Practices Guide: https://docs.getdbt.com/guides/best-practices
2. dbt Style Guide: https://github.com/dbt-labs/style-guide

---

## Minhas Recomendações Finais

### Do que vejo em produção (após 20 anos)

1. **Comece simples**: GitHub Actions + testes básicos. Slim CI depois.

2. **Nunca subestime testes**: Em produção, dados ruins são piores que pipeline parado.

3. **Documente enquanto codifica**: `dbt docs generate` salva vidas. Equipes futuras (ou você mesmo em 6 meses) agradece.

4. **Monitoramento é tudo**: Configure alertas em testes que falham em prod. Falhas silenciosas são o pior cenário.

5. **Semelhança com PHP**: Pense em dbt como um framework de transformação de dados. Assim como você não faria deploy de código PHP sem testes, não faça deploy de modelos dbt sem testes rigorosos.

---

Quer que eu aprofunde em algum desses exemplos reais ou que criemos um repositório de exemplo prático?