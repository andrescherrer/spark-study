# SEMANA 3-4: AWS - Guia Completo de Engenharia de Dados

## Índice
1. [Explicação dos Componentes](#explicação-dos-componentes)
2. [Documentação Oficial](#documentação-oficial)
3. [Exemplos do Mundo Real](#exemplos-do-mundo-real)
4. [Estrutura do Repositório](#estrutura-recomendada-do-repositório)
5. [Boas Práticas](#boas-práticas-terraform)
6. [Próximos Passos](#próximos-passos-para-a-semana-3-4)
7. [Recursos Essenciais](#recursos-essenciais)

---

## Explicação dos Componentes

### A. Infrastructure as Code (IaC) com Terraform

**O que é e por quê usar:**

Terraform é uma ferramenta declarativa que descreve sua infraestrutura em código. Em Engenharia de Dados, isso significa: reprodutibilidade, versionamento, e destruir/recriar ambientes em minutos.

**Conceitos fundamentais para dados:**

- **Provider AWS**: Autenticação e região
- **Resources**: EC2, RDS, S3, Lambda, Glue, DMS
- **Variables & Outputs**: Parametrização de ambientes (dev, staging, prod)
- **State Management**: Sincronização entre seu código e infraestrutura real
- **Modules**: Reutilização (pipeline de ETL encapsulado)

**Por que você (PHP developer) vai amar:** É como versionamento de banco de dados com migrations, mas para TODA infraestrutura.

---

### B. Diagrama de Arquitetura AWS

Uma arquitetura típica de Engenharia de Dados segue este fluxo:

```
[Dados Fonte] → [Ingestão] → [Processing] → [Storage] → [Analytics]
     ↓              ↓             ↓            ↓           ↓
  On-Prem      S3/Kinesis/   EC2/Glue/    S3/RDS/     QuickSight/
  Banco Local   DMS/Lambda    Spark       Redshift     Tableau
```

**Componentes essenciais:**

| Camada | Serviço AWS | Função |
|--------|-----------|--------|
| **Ingestão** | DMS, Kinesis, Glue Crawlers | Capturar dados de múltiplas fontes |
| **Processing** | Glue ETL, EMR, Lambda | Transformar e limpar dados |
| **Storage** | S3 (Data Lake), RDS, Redshift | Persistir dados processados |
| **Orquestração** | Airflow/MWAA, Step Functions | Agendar e controlar pipelines |
| **Analytics** | Athena, Redshift Spectrum | Consultar dados |

---

### C. Estimativa de Custos AWS

**Modelo de custo em Engenharia de Dados:**

```
Custo Mensal ≈ 
  [S3 Storage] + [Data Transfer] + [Lambda Invocations] 
  + [EC2/EMR Hours] + [Redshift Compute] + [DMS Replication]
```

**Exemplo prático (pipeline típico):**

- **S3**: 100 GB = ~$2,30/mês (com intelligent tiering)
- **Glue ETL**: 5 DPU, 10 horas/dia = ~$150/mês
- **Lambda**: 1M invocações = ~$0,20/mês
- **Redshift**: dc2.large, 2 nós = ~$800/mês
- **Data Transfer**: ~50 GB egress = ~$4,50/mês

**Total estimado: ~$956,50/mês**

---

## Documentação Oficial

### Terraform & AWS
1. **Terraform AWS Provider Official** → https://registry.terraform.io/providers/hashicorp/aws/latest/docs
2. **AWS Terraform Examples** → https://github.com/hashicorp/terraform-aws-examples
3. **Terraform State Management** → https://www.terraform.io/language/state

### AWS Services para Dados
1. **AWS Glue Documentation** → https://docs.aws.amazon.com/glue/
2. **Amazon S3 Best Practices** → https://docs.aws.amazon.com/AmazonS3/latest/userguide/BestPractices.html
3. **AWS DMS (Database Migration Service)** → https://docs.aws.amazon.com/dms/
4. **Amazon Redshift Architecture** → https://docs.aws.amazon.com/redshift/latest/dg/welcome.html
5. **AWS Pricing Calculator** → https://calculator.aws/

### Orquestração & Pipelines
1. **AWS Managed Workflows for Apache Airflow** → https://docs.aws.amazon.com/mwaa/
2. **AWS Step Functions** → https://docs.aws.amazon.com/step-functions/

---

## Exemplos do Mundo Real

### Exemplo 1: E-commerce Data Pipeline (Real-time Analytics)

**Contexto:** Você é responsável pelos dados de vendas de um marketplace com 1M transações/dia.

**Arquitetura:**

```
Apps (PHP) → [API Logs em S3] → [Kinesis Stream] → [Lambda] 
  ↓                                                    ↓
User Events                                      Transformação
                                                     ↓
                                          [S3 Processed/Parquet]
                                                     ↓
                                     [Athena Queries] + [Redshift]
                                                     ↓
                                          [Tableau Dashboard]
```

**Terraform para este caso:**

Ver arquivo `ecommerce_pipeline_tf` (IaC Terraform completo)

**Custo mensal estimado para este cenário:**
- Kinesis (ON_DEMAND): ~$400/mês
- Lambda (100M invocações): ~$2/mês
- S3 (1TB): ~$23/mês
- Redshift (2 nós): ~$1,600/mês
- **Total: ~$2,025/mês**

**Pontos críticos aprendidos:**

1. **Idempotência**: Seu Lambda deve ser idempotente (rodar 2x = mesmo resultado)
2. **Particionamento S3**: Use `s3://bucket/year=2024/month=10/day=20/hour=15/` para otimizar queries
3. **State Management**: Terraform mantém estado em `.tfstate` - use S3 remoto em produção!

---

### Exemplo 2: DMS (Database Migration Service) - Real-time Replication

**Contexto:** Você tem um banco MySQL local com 500GB de dados transacionais e precisa replicar em tempo real para Redshift.

**Fluxo:**

```
MySQL (On-Prem) --[CDC: Change Data Capture]--> DMS Instance 
                                                  ↓
                                            AWS Redshift
                                                  ↓
                                            Tableau Reports
```

**Terraform DMS:**

```hcl
# DMS Replication Instance
resource "aws_dms_replication_subnet_group" "example" {
  replication_subnet_group_class   = "dms.t3.medium"
  replication_subnet_group_id      = "dms-repinstance-tf"
  replication_subnet_ids           = [aws_subnet.dms.id]
}

resource "aws_dms_replication_instance" "example" {
  replication_instance_id   = "dms-repinstance"
  replication_instance_class = "dms.t3.large"
  allocated_storage          = 100
  engine_version            = "3.4.6"
  subnet_group_id           = aws_dms_replication_subnet_group.example.id
  publicly_accessible       = false
  
  tags = {
    Name = "dms-replication"
  }
}

# Source Endpoint (MySQL On-Prem)
resource "aws_dms_endpoint" "source" {
  endpoint_type               = "source"
  engine_name                 = "mysql"
  server_name                 = "mysql.example.com"
  port                        = 3306
  database_name               = "production_db"
  username                    = "dms_user"
  password                    = "SecurePassword123!"
}

# Target Endpoint (Redshift)
resource "aws_dms_endpoint" "target" {
  endpoint_type               = "target"
  engine_name                 = "redshift"
  server_name                 = aws_redshift_cluster.data_warehouse.endpoint
  port                        = 5439
  database_name               = "analytics_db"
  username                    = "admin"
}

# Replication Task
resource "aws_dms_replication_task" "example" {
  replication_instance_arn    = aws_dms_replication_instance.example.arn
  replication_task_id         = "mysql-to-redshift"
  migration_type              = "cdc"  # Change Data Capture
  source_endpoint_arn         = aws_dms_endpoint.source.arn
  target_endpoint_arn         = aws_dms_endpoint.target.arn
  table_mappings              = jsonencode({
    rules = [{
      rule_type   = "selection"
      rule_id     = "1"
      rule_name   = "include-all-tables"
      object_locator = {
        schema_name = "%"
        table_name  = "%"
      }
      rule_action = "include"
    }]
  })
}
```

**Custo mensal:**
- DMS t3.large: ~$450/mês
- Storage: ~$50/mês
- Data transfer: ~$100/mês
- **Total: ~$600/mês**

---

### Exemplo 3: Glue ETL + S3 + Athena (Data Lake Architecture)

**Contexto:** 10 fontes diferentes (CRM, ERP, APIs, CSVs) precisam ser consolidadas em um Data Lake para analytics.

**Fluxo:**

```
[10 Fontes] → [S3 Raw] → [Glue Crawler] → [Glue Catalog] 
                                              ↓
                                        [Glue ETL Jobs]
                                              ↓
                                    [S3 Processed/Parquet]
                                              ↓
                          [Athena SQL Queries] + [QuickSight]
```

**Por que Glue é poderoso:** Você escreve Python/Scala uma vez, e roda massivamente em paralelo (com Apache Spark).

```hcl
# Glue Catalog Database
resource "aws_glue_catalog_database" "data_lake" {
  name = "data_lake_db"
}

# Glue Crawler (Automatically discovers schema)
resource "aws_glue_crawler" "s3_crawler" {
  database_name = aws_glue_catalog_database.data_lake.name
  name          = "s3-data-crawler"
  role          = aws_iam_role.glue_role.arn
  
  s3_target {
    path = "s3://${aws_s3_bucket.data_lake_raw.id}/crm/"
  }
}

# Glue Job (ETL Processing)
resource "aws_glue_job" "etl_job" {
  name     = "crm-to-warehouse"
  role_arn = aws_iam_role.glue_role.arn
  
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.id}/crm_etl.py"
  }
  
  default_arguments = {
    "--TempDir"             = "s3://${aws_s3_bucket.temp.id}/"
    "--job-bookmark-option" = "job-bookmark-enable"
  }
  
  glue_version = "4.0"
  max_retries  = 1
  timeout      = 2880
}

# Glue Trigger (Schedule daily at 2 AM)
resource "aws_glue_trigger" "daily_etl" {
  name       = "daily-etl-trigger"
  type       = "ScheduleEvent"
  schedule   = "cron(0 2 * * ? *)"
  actions {
    job_name = aws_glue_job.etl_job.name
  }
}
```

**Exemplo de script Glue ETL (Python):**

```python
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_INPUT', 'S3_OUTPUT'])
sc = SparkContext()
glueContext = GlueContext(sc)
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Read from S3
dyf = glueContext.create_dynamic_frame.from_options(
    format_options={"multiline": False},
    connection_type="s3",
    format="json",
    connection_options={"paths": [args['S3_INPUT']]},
    transformation_ctx="source_data"
)

# Apply transformations
filtered_dyf = Filter.apply(frame=dyf, f=lambda x: x["status"] == "active")
mapped_dyf = ApplyMapping.apply(
    frame=filtered_dyf,
    mappings=[
        ("customer_id", "string", "customer_id", "string"),
        ("email", "string", "email", "string"),
        ("created_at", "string", "created_date", "date"),
    ]
)

# Write to Parquet (optimized columnar format)
glueContext.write_dynamic_frame.from_options(
    frame=mapped_dyf,
    connection_type="s3",
    format="parquet",
    connection_options={"path": args['S3_OUTPUT']},
    transformation_ctx="target_data"
)

job.commit()
```

**Custo mensal:**
- Glue ETL (2 DPU, 8 horas/dia): ~$120/mês
- S3 (500GB): ~$11/mês
- Athena (5TB scanned): ~$25/mês
- **Total: ~$156/mês** (MUITO mais barato!)

---

### Exemplo 4: Breakdown de Custos Realista

#### Cenário: 500GB dados/mês, 10M eventos/dia, 50 usuários Analytics

**1. INGESTÃO & ORQUESTRAÇÃO**

| Serviço | Uso | Custo/Mês |
|---------|-----|-----------|
| DMS Replication | t3.large, 24/7 | $450 |
| Kinesis Streams | ON_DEMAND, 10M events/dia | $420 |
| Lambda | 2B invocações/mês | $40 |
| **Subtotal Ingestão** | | **$910** |

**2. ARMAZENAMENTO**

| Serviço | Uso | Custo/Mês |
|---------|-----|-----------|
| S3 Raw (Bronze) | 500GB | $11.50 |
| S3 Processed (Silver) | 300GB Parquet | $7 |
| S3 Logs & Backups | 100GB | $2.30 |
| **Subtotal Storage** | | **$20.80** |

**3. PROCESSAMENTO & ETL**

| Serviço | Uso | Custo/Mês |
|---------|-----|-----------|
| Glue ETL Jobs | 5 DPU, 20h/dia | $300 |
| Glue Catalog | First 1M = Free, $1/100k acima | $5 |
| EMR (opcional) | m5.xlarge x3, 40h/mês | $120 |
| **Subtotal Processing** | | **$425** |

**4. DATA WAREHOUSE & ANALYTICS**

| Serviço | Uso | Custo/Mês |
|---------|-----|-----------|
| Redshift | 2x dc2.large, 24/7 | $1,600 |
| Redshift Spectrum | 2TB scanned | $20 |
| Athena | 5TB scanned | $25 |
| QuickSight | 50 usuarios | $450 |
| **Subtotal Analytics** | | **$2,095** |

**5. ORQUESTRAÇÃO & CONTROLE**

| Serviço | Uso | Custo/Mês |
|---------|-----|-----------|
| Airflow (MWAA) | 1x worker c5.xlarge | $280 |
| Step Functions | 50k state transitions | $25 |
| **Subtotal Orquestração** | | **$305** |

**6. MONITORAMENTO & SEGURANÇA**

| Serviço | Uso | Custo/Mês |
|---------|-----|-----------|
| CloudWatch Logs | 100GB ingestion | $50 |
| CloudTrail | 50M events | $2 |
| Secrets Manager | 2 secrets | $0.40 |
| **Subtotal Monitoring** | | **$52.40** |

**7. DATA TRANSFER**

| Tipo | Volume | Custo/Mês |
|------|--------|-----------|
| EC2 → S3 (within region) | 1TB | $0 |
| Internet egress | 200GB | $18 |
| Cross-region replication | 100GB | $20 |
| **Subtotal Transfer** | | **$38** |

**RESUMO FINANCEIRO**

| Categoria | Custo |
|-----------|-------|
| Ingestão & Orquestração | $910 |
| Armazenamento | $20.80 |
| Processamento | $425 |
| Analytics & BI | $2,095 |
| Orquestração Avançada | $305 |
| Monitoramento | $52.40 |
| Data Transfer | $38 |
| **TOTAL MENSAL** | **$3,846.20** |
| **TOTAL ANUAL** | **$46,154.40** |

**OTIMIZAÇÕES PARA REDUZIR CUSTOS**

1. **Redshift (Custo maior)**
   - **Atividade reduzida?** → Use Redshift Spectrum + Athena apenas
   - **Economia:** -$1,600/mês
   - **Pausar clusters fora de horário** → -20-30%

2. **Glue → Spark (EMR)**
   - Glue é mais caro para jobs intensivos
   - EMR spot instances = -70% em compute
   - **Economia:** -$180/mês

3. **S3 Intelligent Tiering**
   - Move dados automáticamente entre access tiers
   - **Economia:** -30-40% em storage

4. **Reduzir retençã de dados**
   - Manter apenas 90 dias em hot storage
   - Arquivar em Glacier
   - **Economia:** -$10-15/mês em storage

5. **Reserved Capacity (1-3 anos)**
   - Redshift: -50-60% (prepay)
   - **Economia:** -$800-1000/mês

**CUSTOS OCULTOS (Não aparecem na conta)**

1. **NAT Gateway** (if applicable): $32/mês + $0.045/GB transfer
2. **VPC Endpoints**: $7.20/mês por endpoint
3. **KMS Encryption**: $1/chave/mês + $0.03/10k requests
4. **Backup Storage** (automated): $0.10/GB/mês
5. **Support Plan**: $100-15,000/mês (depending on level)

**RECOMENDAÇÕES**

✅ **Use Reserved Capacity** para Redshift/RDS (big savings)
✅ **Implement S3 Lifecycle Policies** (archive old data)
✅ **Monitor CloudWatch alarms** para overspending
✅ **Use Compute Savings Plans** para lambda/Glue
✅ **Considere multi-region** apenas se necessário
❌ **Evite sobre-provisioning** de recursos
❌ **Não deixe instâncias idle** rodando

---

## Estrutura Recomendada do Repositório

```
ecommerce-data-pipeline/
├── terraform/
│   ├── main.tf                 # Resources principais
│   ├── variables.tf            # Todas as variables
│   ├── outputs.tf              # Outputs
│   ├── s3.tf                   # S3 buckets
│   ├── redshift.tf             # Redshift cluster
│   ├── kinesis.tf              # Kinesis streams
│   ├── lambda.tf               # Lambda functions
│   ├── iam.tf                  # Roles & Policies
│   ├── terraform.tfvars        # Values (ADD TO .gitignore!)
│   ├── backend.tf              # Remote state config
│   └── modules/                # Reusable modules
│       ├── glue_etl/           # Glue job module
│       ├── redshift/           # Redshift module
│       └── monitoring/         # CloudWatch alerts
├── lambda/
│   ├── etl_processor/
│   │   ├── index.py
│   │   ├── requirements.txt
│   │   └── build.sh
│   └── data_validator/
├── glue_scripts/
│   ├── crm_etl.py
│   ├── order_etl.py
│   └── lib/
│       └── common.py           # Shared functions
├── airflow/
│   ├── dags/
│   │   ├── daily_pipeline.py
│   │   └── weekly_sync.py
│   └── plugins/
├── sql/
│   ├── redshift_schemas.sql
│   └── views/
│       ├── customer_360.sql
│       └── order_summary.sql
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   └── COST_OPTIMIZATION.md
├── .gitignore
├── README.md
└── requirements.txt            # Python deps
```

---

## Boas Práticas Terraform

### 1. **Sempre use Remote State**

```hcl
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state"
    key            = "prod/data-pipeline/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### 2. **Separar por Ambientes**

```
terraform/
├── dev/
│   ├── main.tf
│   └── terraform.tfvars
├── staging/
└── prod/
```

### 3. **Use Modules para Reutilização**

```hcl
# modules/glue_etl/main.tf
module "customer_etl" {
  source = "./modules/glue_etl"
  
  job_name = "customer-etl"
  input_path = "s3://raw/crm/"
  output_path = "s3://processed/customers/"
}
```

### 4. **Secrets Management (NUNCA hardcode!)**

```hcl
# Use AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.project_name}/rds/password"
}

# E no código:
resource "aws_redshift_cluster" "warehouse" {
  master_password = aws_secretsmanager_secret_version.db.secret_string
}
```

### 5. **Validação & Formato**

```bash
# Antes de commit
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan

# Code review
terraform show tfplan
```

---

## Próximos Passos para a Semana 3-4

### Dia 1-2: Fundamentos Terraform
- [ ] Instale Terraform + AWS CLI
- [ ] Leia: https://www.terraform.io/language/syntax/configuration
- [ ] Crie um S3 bucket simples com TF (hands-on!)

### Dia 3-4: AWS Services Deep-dive
- [ ] Estude S3 + Lifecycle policies
- [ ] Entenda Kinesis vs SQS (quando usar cada um)
- [ ] Leia: https://docs.aws.amazon.com/whitepapers/latest/building-data-lakes-on-aws/

### Dia 5: Integração AWS + Terraform
- [ ] Crie Kinesis + Lambda trigger com TF
- [ ] Teste o pipeline localmente (sam local)

### Dia 6-7: Diagrama + Custos
- [ ] Desenhe sua arquitetura (Lucidchart/Draw.io)
- [ ] Use AWS Pricing Calculator para estimativa real
- [ ] Documente decisões arquiteturais

---

## Recursos Essenciais

### Documentação
1. **Terraform AWS**: https://registry.terraform.io/providers/hashicorp/aws/latest
2. **AWS Well-Architected Framework**: https://docs.aws.amazon.com/wellarchitected/
3. **Data Lakes on AWS**: https://docs.aws.amazon.com/whitepapers/
4. **AWS Glue Python API**: https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-python.html

### Ferramentas Práticas
- **AWS CLI**: `pip install awscli`
- **Terraform**: https://www.terraform.io/downloads
- **Draw.io** (diagramas): https://app.diagrams.net
- **AWS Pricing Calculator**: https://calculator.aws/

### Comunidade
- **HashiCorp Learn**: https://learn.hashicorp.com/terraform
- **AWS Data Engineering Path**: https://aws.amazon.com/training/
- **GitHub Awesome Data Engineering**: https://github.com/igorbarinov/awesome-data-engineering

---

## Dica Final (De veterano)

Você vem de PHP, certo? A maior mudança mental será passar de **requisição-resposta** para **batch processing + event streams**. 

Em PHP você pensa:
```
POST /api/order → Processa → JSON Response
```

Em Engenharia de Dados você pensa:
```
Events → Stream Infinito → Processa em lotes → Armazena → Consulta analítica
```

O Terraform é seu amigo aqui. Use-o desde o dia 1 - versione TUDO. Isso que diferencia "scripts de data" de "engenharia profissional".

**Sucesso! 🚀**