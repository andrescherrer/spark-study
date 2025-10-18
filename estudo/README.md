# Plano de Estudos - Engenheiro de Dados Pleno
## 2 Meses | 8 horas/dia | 480 horas totais

---

## ESTRUTURA GERAL

**Distribuição de Tempo:**
- Spark: 80h (Semanas 1-2)
- AWS: 72h (Semanas 3-4)
- Airflow: 80h (Semanas 5-6)
- Dbt: 40h (Semana 7)
- Qualidade de Dados + Projeto: 128h (Semana 8 + integração)

**Metodologia:**
- 60% prática (código rodando)
- 40% conceitos (leitura, vídeos)
- Cada semana: Meta clara e entregável

---

## SEMANA 1-2: APACHE SPARK (80 horas)

### Objetivo
Dominar PySpark para processamento distribuído. Você DEVE ser capaz de otimizar um job que processa GB/TB de dados.

### Segunda - Quarta (Semana 1)
**Dia 1-2: Fundamentos Spark (16h)**
- Arquitetura: Driver, Executors, Tasks (2h)
- RDDs vs DataFrames vs Datasets (2h)
- Lazy evaluation e DAG (2h)
- Criando DataFrames e leitura de dados (4h - prático)
- Transformações básicas (map, filter, flatMap) (4h - prático)

**Recursos:**
- Video: "PySpark Tutorial for Beginners" (DataCamp ou Udemy - 8h)
- Documentação oficial: spark.apache.org/docs

**Tarefa do Dia:**
- Ler arquivo CSV de 100MB, fazer 3 transformações (filter, select, groupBy)

---

**Dia 3-4: DataFrames e SQL (16h)**
- DataFrame Operations (select, filter, groupBy, agg) (4h)
- Joins (inner, left, right, outer) e performance (4h)
- Window functions (rank, row_number, dense_rank) (4h)
- Spark SQL queries (4h)

**Recursos:**
- Documentação: DataFrames API
- Notebook prático no Databricks Community

**Tarefa do Dia:**
- Fazer 5 queries complexas com joins e window functions
- Exemplo: "Rank produtos por vendas por categoria, pegando top 3 de cada"

---

**Dia 5 (Semana 1): Performance & Otimização (8h)**
- Particionamento e bucketing (2h)
- Caching vs Persistence (2h)
- Broadcast vs Shuffle (2h)
- Predicate pushdown (2h)

**Tarefa:**
- Refazer 2 queries da semana anterior otimizadas
- Medir tempo antes/depois com explain()

---

### Quinta - Sexta (Semana 1) + Segunda - Quarta (Semana 2)
**Prática Intensiva (48h)**

**Projeto Spark Intermediário:**
Você vai fazer um ETL completo de dados públicos (ex: Kaggle dataset):

1. **Extraction (8h)**
   - Ler múltiplos formatos (CSV, Parquet, JSON)
   - Tratar dados corrompidos
   - Validar schemas

2. **Transformation (24h)**
   - Data cleaning (valores null, duplicatas)
   - Feature engineering (novas colunas derivadas)
   - Agregações complexas
   - Joins com múltiplas tabelas
   - Otimização de queries

3. **Loading (8h)**
   - Escrever em Parquet (particionado)
   - Escrever em Delta Lake
   - Testes de integridade

4. **Documentação (8h)**
   - Explicar cada transformação
   - Commit no GitHub com histórico limpo

**Dataset Recomendado:**
- NYC Taxi (Kaggle) - ~2GB, bem documentado
- Ou: E-commerce Dataset com múltiplas tabelas

**Entregável Semana 2:**
- Repositório GitHub com código clean
- README explicando pipeline
- 3 queries de teste funcionando

---

## SEMANA 3-4: AWS (72 horas)

### Objetivo
Ser confortável com infraestrutura AWS para dados. Você não precisa ser DevOps, mas precisa provisionar recursos e entender custo/performance.

### Conceitos Essenciais (16h)

**Dia 1-2:**
- Regiões, AZs, VPC (2h)
- IAM e permissões (2h)
- S3 profundo: buckets, prefixes, storage classes (4h)
- EC2 básico para dados (2h)
- RDS e banco relacional gerenciado (2h)
- Custos e Cost Explorer (2h)

**Recursos:**
- AWS Skill Builder (grátis para 30 dias)
- Documentação AWS oficial
- Video: "AWS for Data Engineering" (CloudAcademy)

---

### Prática Semanal (56h)

**Semana 3: S3 + RDS + Redshift**

**Dia 1-2: S3 Deep Dive (16h)**
- Criar buckets com diferentes configurações
- Upload/download com AWS CLI
- Versionamento e lifecycle policies
- S3 Select e data format optimization
- Praticar com dados de 10GB

**Tarefa:**
- Upload dados CSV para S3
- Criar lifecycle policy (90 dias → Glacier)
- Fazer queries direto do S3 com S3 Select

---

**Dia 3-4: Redshift (16h)**
- Criar cluster (dev tier é barato)
- Conectar e executar queries
- Distribuição de dados (DISTKEY, SORTKEY)
- COPY e UNLOAD commands
- Performance tuning básico

**Tarefa:**
- Fazer load de dados do S3 para Redshift
- Executar 5 queries analíticas
- Medir query execution plan

---

**Dia 5: RDS + Data Pipeline S3→RDS (8h)**
- Criar banco PostgreSQL em RDS
- Conectar via Python
- Fazer ETL: S3 → Python → RDS

**Tarefa:**
- Pipeline funcional end-to-end

---

**Semana 4: AWS Lambda + Glue + CloudWatch**

**Dia 1-2: AWS Glue (16h)**
- Glue Data Catalog (2h)
- Glue ETL jobs (Python) (4h)
- Spark on Glue (4h)
- Crawlers e schema detection (2h)
- Troubleshooting e logs (2h)

**Tarefa:**
- Criar 1 Glue job que processa dados do S3
- Usar Crawler para detectar schema automaticamente

---

**Dia 3-4: Lambda + EventBridge (8h)**
- Função Lambda básica (2h)
- Trigger com S3 (2h)
- Integração com Glue jobs (2h)
- CloudWatch logs (2h)

**Tarefa:**
- Lambda que dispara quando arquivo chega em S3
- Glue job é acionado automaticamente

---

**Dia 5: CloudWatch + Troubleshooting (8h)**
- Logs, métricas e alarmes (2h)
- Dashboard customizado (2h)
- Entender custos (2h)
- Troubleshooting prático (2h)

---

**Entregável Semana 4:**
- Repositório com IaC (Terraform simples)
- Diagrama da arquitetura AWS
- Estimativa de custos monthly

---

## SEMANA 5-6: APACHE AIRFLOW (80 horas)

### Objetivo
Orquestrar pipelines de dados com Airflow. Você deve ser capaz de criar DAGs complexas, com retry logic, monitoring e alertas.

### Fundamentos (16h)

**Dia 1-2: Conceitos Airflow (8h)**
- DAG, Task, Operator (2h)
- Scheduling e triggers (2h)
- XCom e task dependencies (2h)
- Sensor vs Operator (2h)

**Recursos:**
- Documentação oficial Airflow
- Video: "Apache Airflow Essentials" (Udemy)

---

**Dia 3-4: Setup Local (8h)**
- Instalar Airflow localmente com Docker (2h)
- Primeira DAG simples (2h)
- Conectar com banco de dados (2h)
- Executar e debugar (2h)

**Tarefa:**
- DAG que imprime "Hello World" em 3 tasks sequenciais

---

### Prática Intensiva (64h)

**Semana 5: DAGs, Operadores, Scheduling**

**Dia 1-2: Operadores Comuns (16h)**
- BashOperator (2h)
- PythonOperator (4h)
- SqlOperator (2h)
- S3FileTransformOperator (2h)
- EmailOperator (2h)
- HttpOperator (2h)

**Tarefa:**
- Criar DAG com 5 operadores diferentes

---

**Dia 3-4: Scheduling Avançado (16h)**
- Cron expressions (2h)
- Data intervals e backfilling (2h)
- Pools e concorrência (2h)
- SLA e alertas (2h)
- Retry logic e exponential backoff (2h)
- Trigger rules (all_success, all_failed, etc) (4h)

**Tarefa:**
- DAG que roda a cada 15min com retry policy
- Se falha 3x, envia email com erro

---

**Dia 5: Dynamic DAGs (8h)**
- Gerar tasks dinamicamente (4h)
- Subdags (2h)
- TaskGroups (2h)

**Tarefa:**
- DAG que cria 10 tasks dinamicamente baseado em lista

---

**Dia 6-7: Monitoramento (16h)**
- Web UI navigation (2h)
- Logs e debugging (2h)
- Métricas customizadas (2h)
- Alertas (email, Slack) (2h)
- Health checks (2h)
- Auto-healing (2h)
- Deployment em produção (2h)

---

**Semana 6: Projeto Real com Airflow**

**Projeto: Data Pipeline Completo Orquestrado (32h)**

Você vai criar um pipeline REAL que:
1. Coleta dados de uma API pública (2h)
2. Valida dados (4h)
3. Transforma com Spark (8h)
4. Carrega em warehouse (4h)
5. Notifica stakeholders (2h)
6. Monitora e alertas (2h)

**Pipeline de Exemplo: E-commerce ETL**
- Coleta vendas de API
- Limpa e deduplicata (Spark)
- Carrega em Redshift
- Gera relatório CSV
- Envia por email

**Estrutura do Código:**
```
airflow-project/
├── dags/
│   └── ecommerce_etl.py
├── plugins/
│   ├── operators/
│   ├── sensors/
│   └── hooks/
├── tests/
├── docker-compose.yml
└── README.md
```

**Entregável Semana 6:**
- DAG funcionando 100% (1 execução completa)
- Tests para cada task (pytest)
- Logs limpos no Airflow UI
- README documentando tudo
- GitHub com histórico limpo

---

## SEMANA 7: DBT (40 horas)

### Objetivo
Transformação de dados declarativa. Dbt é o novo padrão para transformações em warehouse.

### Conceitos (8h)

**Dia 1-2:**
- Quando usar Dbt vs Spark (2h)
- Models, tests, documentação (2h)
- Sources e refs (2h)
- Materializations (table, view, incremental) (2h)

---

### Prática (32h)

**Dia 3-5: Projeto Dbt (24h)**

Você vai transformar os dados que carregou do Airflow com Dbt:

1. **Staging Models (8h)**
   - Criar 3 staging models
   - Renomear colunas, tipagem
   - Testes de uniqueness

2. **Mart Models (8h)**
   - Criar models de negócio
   - Joins entre tables
   - Aggregations

3. **Tests & Documentation (8h)**
   - Generic tests (not null, unique)
   - Custom tests (Python)
   - Escrever documentação
   - Gerar dbt docs

**Tarefa Final:**
- dbt run, dbt test, dbt docs tudo passando
- 8+ modelos bem documentados

---

**Dia 6-7: Ci/Cd com Dbt (8h)**
- GitHub Actions para rodar dbt (2h)
- Slim CI (apenas models modificados) (2h)
- Deployment staging/prod (2h)
- Debugging em produção (2h)

---

**Entregável Semana 7:**
- Repositório Dbt no GitHub
- Modelos bem testados
- Documentação automática gerada
- CI/CD funcional

---

## SEMANA 8: QUALIDADE DE DADOS + PROJETO FINAL (128 horas)

### Objetivo
Garantir confiabilidade dos dados. Este é o diferencial de um Pleno.

### Conceitos (16h)

**Dia 1-2:**
- Data Quality Framework (4h)
- Great Expectations intro (2h)
- Data observability (2h)
- SLAs para dados (2h)
- Anomaly detection basics (2h)
- Data governance (2h)

---

### Projeto Final Integrado (112h)

**Você vai entregar um PROJETO COMPLETO que mostra expertise Pleno:**

```
Arquitetura do Projeto:
[API / Kaggle Dataset]
         ↓
     [S3 / Data Lake]
         ↓
   [Airflow Orchestration]
         ↓
   [Spark Processing]
         ↓
   [Redshift Warehouse]
         ↓
   [Dbt Transformation]
         ↓
[Great Expectations Validation]
         ↓
[Analytics Dashboard]
```

**Componentes (112h)**

1. **Data Ingestion (16h)**
   - Conectar a source de verdade
   - Tratamento de erros
   - Versionamento do raw data

2. **Orchestration com Airflow (24h)**
   - DAG completa
   - Scheduling e SLA
   - Monitoramento e alertas

3. **Processing com Spark (24h)**
   - Transformações complexas
   - Performance otimizada
   - Tests unitários

4. **Storage (8h)**
   - Redshift ou Snowflake
   - Particionamento estratégico
   - Backup/disaster recovery

5. **Dbt Transformations (24h)**
   - Staging, intermediate, marts
   - Testes completos
   - Documentação

6. **Data Quality (16h)**
   - Great Expectations checks
   - Alertas de anomalias
   - SLA compliance report

7. **Documentação + Deployment (8h)**
   - Architecture diagram
   - Runbook para troubleshooting
   - Cost analysis

---

### Estrutura Final do Repositório

```
data-engineering-portfolio/
├── README.md (main documentation)
├── architecture/
│   ├── diagram.png
│   └── data-flow.md
├── airflow/
│   ├── dags/
│   ├── plugins/
│   └── docker-compose.yml
├── spark/
│   ├── jobs/
│   ├── tests/
│   └── requirements.txt
├── dbt/
│   ├── models/
│   ├── tests/
│   └── profiles.yml
├── data-quality/
│   ├── expectations/
│   └── validation-rules.yaml
├── infrastructure/
│   └── terraform/ (AWS setup)
├── tests/
│   ├── integration/
│   └── unit/
├── docs/
│   ├── setup.md
│   ├── troubleshooting.md
│   └── cost-analysis.md
└── .github/
    └── workflows/
        └── ci-cd.yml
```

---

## RESUMO POR SEMANA

| Semana | Foco | Horas | Entregável |
|--------|------|-------|-----------|
| 1-2 | Spark | 80h | GitHub com projeto ETL funcional |
| 3-4 | AWS | 72h | Infraestrutura em Terraform + estimativa custos |
| 5-6 | Airflow | 80h | DAG orquestrando pipeline completo |
| 7 | Dbt | 40h | Models testados e documentados |
| 8 | Qualidade + Final | 128h | Projeto completo integrado |

**Total: 480 horas**

---

## ROTINA DIÁRIA SUGERIDA (8h)

- **08:00-09:30**: Conceitos (1.5h) - video + documentação
- **09:30-13:00**: Prática (3.5h) - código
- **13:00-14:00**: Almoço
- **14:00-17:30**: Prática Intensiva (3.5h) - projeto
- **17:30-18:00**: Review + commit (0.5h)

---

## DICAS CRÍTICAS

1. **Commit todo dia**: Mesmo commits pequenos. Histórico importa em entrevista.
2. **Documente enquanto faz**: Não deixa pra final.
3. **Use dados reais**: Kaggle datasets são seus amigos.
4. **Teste tudo**: Unit tests, integration tests, não deixa pra depois.
5. **Reproduzibilidade**: Alguém consegue rodar seu código do zero? Dockerfile ajuda.
6. **GitHub é seu portfolio**: Código tem que estar impecável.
7. **Networking**: Compartilhe progresso no LinkedIn enquanto estuda.

---

## RECURSOS PRINCIPAIS

**Spark:**
- Databricks Academy (free)
- Learning Spark 2nd Edition (O'Reilly)

**AWS:**
- AWS Skill Builder
- acloudguru.com

**Airflow:**
- Oficialmente docs.airflow.apache.org
- Marc Lamberti no YouTube

**Dbt:**
- dbt Learn (free courses)
- dbt docs

**Geral:**
- DataCamp (premium but worth it)
- Coursera Data Engineering specializations

---

## CHECKLIST FINAL

Ao final dos 2 meses, você deve ter:

- ✅ 4+ projetos completos no GitHub
- ✅ Experiência real com Spark otimizado
- ✅ Infraestrutura AWS funcionando
- ✅ DAG Airflow em produção
- ✅ Models Dbt com testes
- ✅ Data quality checks implementados
- ✅ 1 projeto "Pleno-ready" que resume tudo
- ✅ Documentação impecável
- ✅ Repositórios públicos bem apresentados

**Isso é suficiente para ser competitivo em entrevistas Pleno.**