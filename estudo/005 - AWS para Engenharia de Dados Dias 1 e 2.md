# AWS para Engenharia de Dados - Análise Aprofundada

Com base em 20 anos de experiência em dados, vou desmontar cada componente desta semana crítica. Este é o alicerce onde construímos pipelines de dados sólidos.

---

## 1. REGIÕES, AZs E VPC (2h)

### Explicação Profunda

**Regiões AWS**: São áreas geográficas separadas, cada uma com infraestrutura completamente independente. Quando você implanta em `us-east-1` versus `eu-west-1`, está literalmente em datacenters diferentes em países diferentes.

**Zonas de Disponibilidade (AZs)**: Dentro de cada região, há múltiplas AZs (geralmente 3-4). Cada AZ é um datacenter isolado com energia, rede e refrigeração redundantes. A latência entre AZs é mínima (sub-milissegundo), mas são falhas independentes.

**VPC (Virtual Private Cloud)**: É sua rede isolada na AWS. Você controla subnets, routing, security groups e network ACLs. Essencial para dados sensíveis.

**Por que importa para Engenharia de Dados:**
- Replicação de dados entre regiões (disaster recovery, GDPR compliance)
- Latência para pipelines em tempo real
- Custo de transferência entre regiões (caro!)
- Multi-AZ para alta disponibilidade de RDS/Redshift

### Fontes Oficiais
- [AWS Regions and Availability Zones](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)
- [VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [AWS Infrastructure Diagram](https://aws.amazon.com/about-aws/global-infrastructure/)

---

## 2. IAM E PERMISSÕES (2h)

### Explicação Profunda

IAM é o controle de acesso de toda AWS. Não é opcional - é crítico.

**Conceitos-chave:**
- **Identidades**: Usuários, Roles, Service Accounts
- **Policies**: Documentos JSON que definem permissões
- **Princípio do Menor Privilégio**: Seu engenheiro de dados não precisa de acesso ao RDS de produção para processar dados de staging

**Para Engenharia de Dados, você precisa entender:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::meu-bucket-dados",
        "arn:aws:s3:::meu-bucket-dados/*"
      ]
    }
  ]
}
```

Isso permite ler dados de S3, mas não deletar ou escrever.

### Fontes Oficiais
- [IAM User Guide](https://docs.aws.amazon.com/iam/latest/userguide/)
- [IAM Best Practices](https://docs.aws.amazon.com/iam/latest/userguide/best-practices.html)
- [AWS Managed Policies for Data Services](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_managed-vs-inline.html)

---

## 3. S3 PROFUNDO: BUCKETS, PREFIXES, STORAGE CLASSES (4h)

### Este é o mais importante para Engenharia de Dados

**S3 é seu data lake**. Entender S3 profundamente é diferença entre pipeline eficiente e caro.

#### Buckets e Prefixes

```
meu-bucket-dados/
├── raw/
│   ├── 2025/01/20/
│   │   ├── vendas_20250120_001.parquet
│   │   ├── vendas_20250120_002.parquet
│   └── 2025/01/21/
├── processed/
│   ├── vendas_curated/
│   │   ├── data=2025-01-20/
│   │   └── data=2025-01-21/
└── archive/
```

Essa estrutura importa porque:
- **Particionamento por data**: Query apenas dados necessários (crucial para Athena/Spark)
- **Prefixes**: Permitem paralelização em S3 - múltiplas conexões simultâneas
- **Organização**: Facilita gestão de retenção e custos

#### Storage Classes (o grande segredo de custo)

| Classe | Custo/GB | Caso de Uso |
|--------|----------|-----------|
| **S3 Standard** | $0.023/mês | Dados quentes, acessados frequentemente |
| **S3 Intelligent-Tiering** | ~$0.016/mês | Padrão desconhecido - deixa AWS decidir |
| **S3 Standard-IA** | $0.0125/mês | Acessado < 1x/mês (com taxa de retrieval) |
| **Glacier Instant** | $0.004/mês | Arquivos, retrieval em minutos |
| **Glacier Deep Archive** | $0.00099/mês | Compliance, retrieval em horas |

**Exemplo real de economia:**
- Dados de backup: 100TB em Standard = $2.300/mês
- Moved para Deep Archive = $99/mês
- **Economia: $26.700/ano**

#### Lifecycle Policies

```json
{
  "Rules": [
    {
      "Id": "MoveToIA",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        }
      ]
    }
  ]
}
```

### Fontes Oficiais
- [S3 User Guide](https://docs.aws.amazon.com/s3/latest/userguide/)
- [S3 Storage Classes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html)
- [S3 Lifecycle Policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [S3 Best Practices for Data Lakes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/data-lake-best-practices.html)

---

## 4. EC2 BÁSICO PARA DADOS (2h)

### Explicação Profunda

EC2 é uma máquina virtual. Para dados, você não quer usar EC2 direto (use Spark/EMR). Mas precisa entender para troubleshooting.

**Tipos de instância relevantes para dados:**
- **m5.xlarge**: Balanced (CPU/Memória) - pipelines gerais
- **r5.2xlarge**: Memory-optimized - processamento em memória, caching
- **c5.4xlarge**: Compute-optimized - transformações pesadas

**Por que não usar EC2 direto?**
- EMR (Elastic MapReduce) gerencia clusters Spark/Hadoop
- Glue é serverless para ETL
- Lambda para processamento leve

### Fontes Oficiais
- [EC2 User Guide](https://docs.aws.amazon.com/ec2/latest/userguide/)
- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [EMR User Guide](https://docs.aws.amazon.com/emr/latest/ManagementGuide/) (melhor para dados)

---

## 5. RDS E BANCO RELACIONAL GERENCIADO (2h)

### Explicação Profunda

RDS é PostgreSQL/MySQL/Oracle na nuvem, mas gerenciado pela AWS.

**Conceitos críticos:**

**Multi-AZ**: Réplica síncrona em outra AZ. Falha automática em < 2 minutos.

```
Primary (us-east-1a) ←→ Standby (us-east-1b)
                  ↓
         Automatic Failover
```

**Read Replicas**: Réplicas assíncronas (mesma região ou cross-region) para escalar leitura.

```
Primary (escrita) 
    ↓
├─ Read Replica 1 (SELECT queries)
├─ Read Replica 2 (SELECT queries)
└─ Read Replica 3 (Read-heavy analytics)
```

**Backup e Point-in-Time Recovery**: AWS mantém backups automáticos até 35 dias.

**Performance Insights**: Monitora queries lentas - essencial para pipeline troubleshooting.

### Fontes Oficiais
- [RDS User Guide](https://docs.aws.amazon.com/rds/latest/userguide/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [Performance Insights](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.html)

---

## 6. CUSTOS E COST EXPLORER (2h)

### A realidade que ninguém fala

AWS é barato em escala, caro em desatenção. Um engenheiro desavisado pode custar $50k/mês para sua empresa.

**Maiores vilões em Engenharia de Dados:**

1. **Transferência de dados entre regiões**: $0.02/GB (CARO)
2. **Queries no Athena**: $6.25 por TB scaneado
3. **RDS com IOPS provisionado não otimizado**: Pode 10x o custo
4. **S3 retrieval de Glacier**: Taxa por retrieval + por GB
5. **NAT Gateway**: $0.045/hora + $0.045/GB processado

**Cost Explorer Strategy:**
- Visualize por serviço, por tag (ambiente, projeto)
- Busque anomalias (spike súbito = query mal escrita)
- Forecasting de gastos futuros

### Fontes Oficiais
- [AWS Cost Explorer](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/ce-what-is.html)
- [AWS Pricing Calculator](https://calculator.aws/)
- [Reserved Instances vs On-Demand](https://docs.aws.amazon.com/whitepapers/latest/cost-optimization-reservation-models/)

---

---

# EXEMPLOS DO MUNDO REAL

Agora vou aplicar tudo isso em cenários que você encontrará:

## Caso 1: Pipeline ETL de E-commerce (Real-Time Sales Analytics)

### Arquitetura

```
Aplicação PHP (sua loja) 
    ↓
    → Kinesis Data Streams
    ↓
    → Lambda (transformação)
    ↓
    → S3 (raw/vendas/2025-01-20/)
    ↓
    → Glue (Spark job)
    ↓
    → S3 (processed/analytics/)
    ↓
    → Athena + QuickSight (Dashboards)
```

### Implementação com IAM

Você teria 3 roles:

**1. Role Application (sua app PHP)**

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "kinesis:PutRecords",
      "Resource": "arn:aws:kinesis:us-east-1:123456:stream/vendas-stream"
    }
  ]
}
```

**2. Role Glue Job**

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::meu-bucket-dados/raw/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::meu-bucket-dados/processed/*"
    }
  ]
}
```

**3. Role Analytics (Athena)**

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::meu-bucket-dados/processed/*"
    }
  ]
}
```

### Otimização de Custos

**Problema:** Queries do Athena custando $500/mês

**Solução aplicada:**

1. **Particionamento por data** (Athena só escaneia dia necessário)
   - Antes: 100GB scaneado por query
   - Depois: 2GB scaneado
   - Economia: 98% 🎯

2. **Storage Class no S3**
   - Raw data: Standard (precisa rápido)
   - Processed data: Intelligent-Tiering
   - Archive após 90 dias: Glacier

3. **Resultado:** $500/mês → $45/mês

---

## Caso 2: Data Warehouse com RDS Multi-AZ

### Setup

```sql
-- Seu data warehouse transacional
CREATE TABLE vendas (
    id BIGINT PRIMARY KEY,
    data DATE,
    valor DECIMAL(10,2),
    regiao VARCHAR(50)
);

-- Índice crítico para queries
CREATE INDEX idx_vendas_data_regiao 
ON vendas(data, regiao);
```

### Cenário Real

Sua empresa processa 10 milhões de linhas/dia. RDS precisa:

1. **Multi-AZ ativado** (failover automático)
2. **Read Replicas** para analytics não impactarem transações
3. **Backup automático** com retenção de 35 dias

```
Primary (us-east-1a) - OLTP escritas
    ↓
├─ Standby (us-east-1b) - Failover automático
├─ Read Replica 1 (us-east-1c) - Relatórios pesados
└─ Read Replica 2 (eu-west-1) - Analytics Europa
```

### Problema: Query lenta

Performance Insights mostra que tabela `vendas` está com lock. Solução:

```sql
-- Antes: Full table scan lento
SELECT COUNT(*) FROM vendas WHERE data = '2025-01-20';

-- Depois: Index utilizado
SELECT COUNT(*) FROM vendas 
WHERE data = '2025-01-20' 
AND regiao = 'SUDESTE';
```

---

## Caso 3: Data Lake Architecture com S3 Lifecycle

### Estrutura Real

```
data-lake-prod/
├── raw/ (chegam dados brutos)
│   ├── erp/2025-01/20/
│   ├── web-logs/2025-01/20/
│   └── api-events/2025-01/20/
│
├── bronze/ (validado, semtransformação)
│   ├── customers/ (Parquet particionado)
│   │   └── year=2025/month=01/day=20/
│   └── transactions/
│
├── silver/ (limpo, transformado)
│   ├── dim_customers/ (Dimensão)
│   └── fact_sales/ (Fato)
│
├── gold/ (pronto para BI)
│   ├── sales_dashboard/
│   └── customer_analytics/
│
└── archive/ (histórico, rare access)
```

### Lifecycle Policy Automática

```python
import boto3

s3 = boto3.client('s3')

lifecycle_policy = {
    'Rules': [
        {
            'Id': 'raw-to-ia',
            'Filter': {'Prefix': 'raw/'},
            'Status': 'Enabled',
            'Transitions': [
                {
                    'Days': 30,
                    'StorageClass': 'STANDARD_IA'
                },
                {
                    'Days': 90,
                    'StorageClass': 'GLACIER_IR'
                }
            ]
        },
        {
            'Id': 'archive-deep-archive',
            'Filter': {'Prefix': 'archive/'},
            'Status': 'Enabled',
            'Transitions': [
                {
                    'Days': 1,
                    'StorageClass': 'DEEP_ARCHIVE'
                }
            ]
        }
    ]
}

s3.put_bucket_lifecycle_configuration(
    Bucket='data-lake-prod',
    LifecycleConfiguration=lifecycle_policy
)
```

### Custo Anual

- **Raw (1TB/dia, 365TB/ano)**: Standard → IA after 30 days = ~$6.000/ano
- **Archive (backup)**: Deep Archive = ~$500/ano
- **Total**: ~$6.500/ano vs $8.500/ano sem policy
- **Economia**: 24%

---

## Caso 4: Cross-Region Replication para GDPR

### Requisito
Dados da UE não podem sair de eu-west-1, mas precisa backup global.

```
Bucket Primary (eu-west-1)
    ↓ [Replicação automática]
    → Bucket Replica (us-east-1) [Read-only, compliance]
    
Custo adicional: $0.02/GB replicado
Para 50TB: $1.000/mês
```

### VPC Setup

```
VPC eu-west-1 (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24)
│   └── NAT Gateway [conecta para fora seguro]
├── Private Subnet (10.0.2.0/24)
│   └── RDS [sem acesso direto internet]
└── Private Subnet (10.0.3.0/24)
    └── EC2 [processamento de dados]

S3 Access: Via VPC Endpoint (sem custo de transferência!)
```

---

## Caso 5: Cost Optimization em Ação

### Antes (Startup mal organizada)

```
Janeiro:
- EC2 sempre ligado (forgotten instances): $2.000/mês
- RDS sem Read Replicas, processando tudo: $800/mês
- Athena queries ineficientes: $400/mês
- S3 tudo em Standard (old logs): $500/mês
Total: $3.700/mês
```

### Depois (Após otimização)

```
Janeiro:
- EC2 → Reserved Instances + auto-scaling: $600/mês
- RDS + Read Replicas (lite): $600/mês
- Athena + Particionamento: $50/mês
- S3 + Lifecycle: $150/mês
Total: $1.400/mês

Economia: 62% ($27.600/ano) ✅
```

---

# Recursos de Estudo Organizados

## Documentação Oficial (Principal)
- [AWS Learning Path - Data Engineering](https://aws.amazon.com/training/learn-aws-fundamentals/data-engineering/)
- [AWS Skill Builder (30 dias grátis)](https://skillbuilder.aws.com/)

## Cursos Específicos Recomendados
1. **AWS for Data Engineering** - CloudAcademy (mencionado no seu plano)
2. **Udemy**: "Complete Hands-On Introduction to Apache Spark" (contexto Spark no EMR)
3. **A Cloud Guru**: "AWS Data Lake" (prático)

## Livros Técnicos
- *"Data Pipelines Pocket Reference"* - James Densmore (AWS patterns)
- *"Fundamentals of Data Engineering"* - Joe Reis, Matt Housley

## Labs Práticos
- [AWS well-architected labs](https://www.wellarchitectedlabs.com/)
- [AWS hands-on tutorials](https://aws.amazon.com/getting-started/hands-on/)

---

**Próximo passo**: Você quer que eu aprofunde em algum caso específico? Podemos fazer um laboratório prático de Data Lake com código Python/Java, ou focar em otimização de custos reais?