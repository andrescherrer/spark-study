# AWS Lambda + EventBridge + Glue: Arquitetura de Dados em Tempo Real

Ótimo, vou desbravar isso com você como um especialista que já implementou centenas dessas pipelines.

## 🏗️ Entendendo os Componentes

### **1. AWS Lambda - O Executor Serverless**

Lambda é uma função de computação que roda código sem gerenciar servidores. No contexto de Engenharia de Dados:

- **Sem estado**: cada execução é isolada
- **Trigger-based**: dispara por eventos (S3, SQS, SNS, EventBridge)
- **Billing por execução**: paga por uso real
- **Timeout**: máximo 15 minutos (importante para dados)
- **Memória**: 128MB a 10,240MB (afeta CPU e custo)

**Documentação oficial:**
- https://docs.aws.amazon.com/lambda/latest/dg/getting-started.html
- https://docs.aws.amazon.com/lambda/latest/dg/lambda-functions.html
- https://docs.aws.amazon.com/lambda/latest/dg/python-handler-using-command-line.html

### **2. EventBridge - O Orquestrador de Eventos**

EventBridge é um barramento de eventos que enruta eventos de diferentes fontes para destinos:

- **Event Pattern Matching**: filtra eventos por regras (não apenas "tudo ou nada")
- **Múltiplas fontes**: S3, EC2, Glue, aplicações customizadas
- **Retry automático**: falhas são retentadas (até 2 horas)
- **DLQ (Dead Letter Queue)**: eventos que falham várias vezes vão para fila de erro
- **Schedule**: também funciona com Cron/Rate expressions

**Documentação oficial:**
- https://docs.aws.amazon.com/eventbridge/latest/userguide/what-is-eventbridge.html
- https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rules.html
- https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html

### **3. S3 Events - O Gatilho**

S3 emite eventos quando arquivos são criados/deletados:

- **s3:ObjectCreated:*** - qualquer criação
- **s3:ObjectRemoved** - deletions
- **Notificações**: podem ir direto para Lambda, SNS, SQS ou EventBridge

**Documentação oficial:**
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/how-to-enable-disable-notification-types.html

### **4. AWS Glue - ETL Escalável**

Glue é o motor de processamento de dados:

- **Glue Jobs**: scripts Python/Scala que processam dados
- **Glue Catalog**: metadados centralizados (importante!)
- **Escalabilidade automática**: escala workers conforme necessário
- **Spark sob o capô**: usa Apache Spark distribuído

**Documentação oficial:**
- https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html
- https://docs.aws.amazon.com/glue/latest/dg/add-job.html
- https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-etl-libraries.html

### **5. CloudWatch Logs - Observabilidade**

Sistema centralizado de logs e métricas:

- **Log Groups**: agrupam logs de um aplicativo/função
- **Log Streams**: sequência de logs de uma execução
- **Insights**: SQL-like queries nos logs (MUITO útil para debugging)
- **Alarms**: dispara alertas quando métrica fica fora dos limites

**Documentação oficial:**
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html

---

## 🔗 Como Funcionam Juntos

```
[S3 Bucket]
     ↓ (novo arquivo)
[S3 Event Notification] 
     ↓
[EventBridge Rule] (matching patterns)
     ↓
[Lambda] (validação/preparação)
     ↓
[Glue Job] (processamento pesado)
     ↓
[Resultado em S3/RDS/Redshift]
     
[CloudWatch] (monitora tudo!)
```

---

## 💡 Exemplos Reais de Engenharia de Dados

### **Exemplo 1: Pipeline de Ingestão de Dados de Vendas**

**Cenário Real**: Você recebe arquivos CSV de vendas diárias de múltiplas lojas em um bucket S3. Precisa:
1. Validar o arquivo (formato, colunas obrigatórias)
2. Transformar em Parquet
3. Carregar no Data Warehouse

**Fluxo**:
```
loja-123_2025-10-20.csv (chega em s3://vendas-raw/)
         ↓
[Lambda: validacao_vendas]
  - Verifica se tem coluna produto_id, valor, data
  - Se inválido → envia email via SNS
  - Se válido → publica evento customizado no EventBridge
         ↓
[EventBridge Rule: "arquivo-vendas-validado"]
         ↓
[Glue Job: transform_vendas]
  - Lê CSV
  - Transforma em Parquet
  - Aplica deduplicação
  - Escreve em s3://vendas-processed/
         ↓
[Redshift] (via Spectrum ou COPY direto)
```

**Por que assim?**
- Lambda é rápida para validação (< 30s)
- Glue é poderosa para transformações complexas (suporta 1TB+)
- EventBridge orquestra tudo com retry automático

---

### **Exemplo 2: Processamento de Logs de Aplicação em Tempo Real**

**Cenário**: Sua app gera 100GB/dia de logs estruturados em JSON

**Fluxo**:
```
app.log.2025-10-20.json (→ s3://logs-raw/)
         ↓
[EventBridge Rule: "pattern matching"]
  {
    "source": ["aws.s3"],
    "detail-type": ["Object Created"],
    "detail": {
      "bucket": {"name": ["logs-raw"]},
      "object": {"key": [{"prefix": "app.log"}]}
    }
  }
         ↓
[Lambda: extract_metrics]
  - Extrai erros críticos
  - Conta eventos por tipo
  - Escreve em DynamoDB para dashboard real-time
         ↓
[Glue Job Paralelo: aggregate_logs]
  - Lê ALL logs do dia
  - Agrupa por erro_tipo, timestamp, user_id
  - Cria Parquet particionado em s3://logs-processed/date=2025-10-20/
         ↓
[Athena] (queries SQL nos Parquets)
ou [QuickSight] (visualizações)
```

**Vantagem**: Lambda pega insights quentes em 2s, Glue faz análise profunda após

---

### **Exemplo 3: Reconciliação de Dados Multi-Fonte (Bancário)**

**Cenário**: 
- Arquivo de débitos (Banco A) → 8:00 AM
- Arquivo de créditos (Banco B) → 9:30 AM
- Precisa reconciliar e achar discrepâncias

```
[S3 - s3://bank-reconciliation/]
  ├─ debits_2025-10-20.csv
  └─ credits_2025-10-20.csv
         ↓
[EventBridge Rule: "quando AMBOS os arquivos chegam"]
  (usa EventBridge Archive + Replay ou lógica em Lambda)
         ↓
[Lambda: check_files_ready]
  - Consulta S3 list objects
  - Se ambos existem → triggers Glue
  - Se falta → espera próxima execução
         ↓
[Glue Job: reconcile_transactions]
  ```python
  debits_df = glueContext.create_dynamic_frame.from_options(
      "s3", 
      {"paths": ["s3://bank-reconciliation/debits_*.csv"]},
      format="csv"
  )
  
  credits_df = glueContext.create_dynamic_frame.from_options(
      "s3",
      {"paths": ["s3://bank-reconciliation/credits_*.csv"]},
      format="csv"
  )
  
  # Full outer join
  reconciled = debits_df.join(credits_df, ["transaction_id"])
  
  # Encontra registros não-reconciliados
  discrepancies = reconciled.filter(lambda x: x["status"] == "unmatched")
  
  # Escreve em data lake
  glueContext.write_dynamic_frame.from_options(
      discrepancies,
      "s3",
      {"path": "s3://reconciliation-results/"},
      format="parquet"
  )
  ```
         ↓
[SNS Notification]
  - Se discrepâncias > threshold → alerta analista
```

---

### **Exemplo 4: Data Quality Check Automatizado**

**Cenário**: Você quer garantir que dados que chegam em S3 tem qualidade mínima

```
novo_arquivo.parquet → s3://raw-data/
         ↓
[EventBridge: dispara por padrão]
         ↓
[Lambda: data_quality_checker]
def lambda_handler(event, context):
    s3_key = event['detail']['object']['key']
    
    # Lê amostra do arquivo
    df = pd.read_parquet(f's3://raw-data/{s3_key}')
    
    # Checks
    checks = {
        'null_count': df.isnull().sum().sum(),
        'row_count': len(df),
        'duplicates': df.duplicated().sum(),
        'data_types_valid': validate_schema(df)
    }
    
    if checks['null_count'] > 1000:
        return {'status': 'FAILED', 'reason': 'Too many nulls'}
    
    # Se passou, publica evento pro Glue
    eventbridge.put_events(
        Entries=[{
            'Source': 'lambda.data-quality',
            'DetailType': 'Quality Check Passed',
            'Detail': json.dumps({'s3_key': s3_key})
        }]
    )
    
    return {'status': 'PASSED'}
         ↓
[Glue Job: process_validated_data]
```

---

## 📚 Documentação Essencial por Tópico

| Tópico | Documentação | Recurso Extra |
|--------|--------------|---------------|
| **Lambda + S3** | https://docs.aws.amazon.com/lambda/latest/dg/with-s3.html | AWS Workshop: https://serverless-data-analytics.workshop.aws/ |
| **EventBridge + Lambda** | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-targets.html | Best Practices: https://docs.aws.amazon.com/eventbridge/latest/userguide/eventbridge-best-practices.html |
| **Glue PySpark API** | https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-python-libraries.html | GitHub Examples: https://github.com/aws-samples/aws-glue-samples |
| **CloudWatch Insights** | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html | CloudWatch Logs Workshop: https://catalog.us-east-1.prod.workshops.aws/ |
| **S3 Event Notifications** | https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html | SNS vs SQS vs EventBridge: https://docs.aws.amazon.com/AmazonS3/latest/userguide/notification-how-to-setup.html |

---

## 🎯 Dica de Ouro (20 anos falando aqui)

**Sempre use EventBridge em vez de notificações diretas do S3 para Lambda porque:**

1. **Retry automático**: S3 → Lambda direto não tem retry (se Lambda falha, perdeu)
2. **DLQ (Dead Letter Queue)**: EventBridge envia eventos que falharam para fila de erro
3. **Filtering**: EventBridge faz pattern matching (S3 é "tudo ou nada")
4. **Auditoria**: EventBridge Archive guarda todos os eventos (compliance!)
5. **Decoupling**: Lambda não precisa "conhecer" S3

```json
// ERRADO: S3 Event Notification direto para Lambda
"LambdaFunctionConfigurations": [...]
// Problema: falha silenciosa se Lambda cai

// CERTO: S3 → EventBridge → Lambda
// EventBridge re-tenta 2 horas, guarda em DLQ
```

---

## Próximos Passos

Quer que eu desenvolva mais em algum desses exemplos? Posso fazer um código completo em Python para você clonar + adaptar, ou explorar Glue Catalog que é crítico mas muita gente ignora.