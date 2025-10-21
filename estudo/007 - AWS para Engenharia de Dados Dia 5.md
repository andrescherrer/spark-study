# AWS CloudWatch + Troubleshooting: Guia Especializado

Como especialista com 20 anos na área, vou estruturar isso de forma progressiva, começando pelos fundamentos até casos reais complexos.

---

## 📊 1. LOGS, MÉTRICAS E ALARMES (2h)

### O que é CloudWatch?

CloudWatch é o sistema nervoso da AWS. Funciona como um agregador centralizado de **observabilidade** - coleta tudo que acontece na sua infraestrutura (EC2, RDS, Lambda, etc) e te permite investigar quando algo dá errado.

**Componentes fundamentais:**

**Logs** são registros textuais de eventos. Imagine que cada aplicação grita "ei, algo aconteceu aqui!" e CloudWatch escuta. Diferente de métricas numéricas, logs contêm contexto completo - stack traces, queries SQL lentas, erros de autenticação.

**Métricas** são valores numéricos pontuais no tempo. CPU em 78%, memória em 2.1GB, requisições processadas em 150/segundo. São agregadas em períodos (1min, 5min, 1h).

**Alarmes** são regras que você define: "se CPU > 80% por mais de 5 minutos, envie um SNS (notificação)". São ações automáticas baseadas em limites.

### Documentação oficial para estudar:
- **CloudWatch Overview**: https://docs.aws.amazon.com/cloudwatch/
- **Logs Insights (query language)**: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html
- **Métricas padrão**: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/working_with_metrics.html

### Exemplo prático - Engenharia de Dados:

```
Cenário: ETL pipeline em Lambda processa 10GB de dados diariamente

Logs que você vê no CloudWatch:
[ERROR] S3 object key not found: s3://data-lake/inputs/2025-10-20/sales.parquet
[WARN] Row count mismatch: expected 1,000,000 rows, got 999,855
[INFO] Data transformation completed in 312 seconds

Métricas correlacionadas:
- Duration: 312 segundos (aumentou 50% vs ontem)
- Memory Used: 2,150 MB (quase no limite de 3GB)
- Errors: 3 (vs 0 ontem)

Alarme disparado: "Lambda duration > 300s para 3 execuções consecutivas"
```

---

## 📈 2. DASHBOARD CUSTOMIZADO (2h)

Um dashboard é sua "sala de controle". Em vez de clicar em 15 abas diferentes, você vê tudo de uma vez.

### Por que é crítico em Engenharia de Dados:

Em pipelines complexos, você precisa monitorar **simultaneamente**:
- Performance do pipeline (quanto tempo levou?)
- Qualidade dos dados (quantas linhas processadas?)
- Custos (quanto gastei neste job?)
- Saúde da infraestrutura (RDS CPU, disco disponível)

### Documentação:
- **Creating Dashboards**: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html
- **Dashboard widgets**: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards_Widgets.html

### Exemplo prático - Dashboard de Data Pipeline:

Imagine um dashboard com 6 widgets:

**Widget 1: Timeline de execução do pipeline**
```
16:00 - Extração de dados (5 min) ✓
16:05 - Transformação (45 min) ✓
16:50 - Carga para Data Warehouse (12 min) ✓
17:02 - Validação de qualidade (2 min) ✓
```
(Métrica: Duration do Step Functions)

**Widget 2: Evolução de registros processados**
```
Gráfico em linha:
- Dia 18: 1,200,000 registros
- Dia 19: 1,185,000 registros ⚠️ (queda de 1.2%)
- Dia 20: 890,000 registros 🔴 (queda de 25%)
```
(Métrica customizada: Row count enviada por Lambda)

**Widget 3: Taxa de erro**
```
Erros por tipo:
- Schema mismatch: 2
- Missing values: 15
- Duplicates: 0
```

**Widget 4: Custo acumulado**
```
Hoje: $12.50 (Lambda + S3 + RDS)
Essa semana: $84.30
Mês: $1,240
```

**Widget 5: Saúde da RDS**
```
CPU: 45% | Memória: 62% | Conexões: 28/100 | IOPS: 180/1000
```

**Widget 6: Alertas ativos**
```
⚠️ Lambda timeout em 2 execuções
🔴 RDS disk space 78% utilizado
```

---

## 💰 3. ENTENDER CUSTOS (2h)

Este é o ponto mais **subestimado** e mais **caro** de se ignorar.

### Como CloudWatch cobra:

1. **Métricas**: $0.30 por métrica customizada/mês (as default EC2 são grátis)
2. **Logs**: $0.50 por GB ingerido + $0.03 por GB armazenado/mês
3. **API calls**: Grátis (até um ponto, então não é relevante)
4. **Dashboards**: Grátis

**O verdadeiro custo está nos LOGS.**

### Documentação de custos:
- **CloudWatch Pricing**: https://aws.amazon.com/cloudwatch/pricing/

### Cenário real - Você está vazando dinheiro:

Uma equipe de engenharia de dados tem um Lambda que:
- Executa 100 vezes/dia
- Loga 50MB de output por execução (DEBUG level ativo por engano)

```
Cálculo:
100 execuções × 50MB = 5GB/dia
5GB/dia × 30 dias = 150GB/mês
150GB × $0.50 = $75/mês EM LOGS APENAS
(Sem contar retenção)
```

**Se você guardar esses logs por 1 ano:**
```
150GB × 12 meses × $0.03 = $54/ano EM ARMAZENAMENTO
```

**Solução implementada (reduz custos 95%):**
- Logs DEBUG vão para S3 (apenas se erro ocorrer)
- CloudWatch recebe apenas INFO/ERROR (2MB/execução)
- 2GB/dia × 30 = 60GB/mês × $0.50 = $30/mês

**Economia: $45/mês = $540/ano**

### Documentação avançada de otimização:
- **Log Insights pricing**: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CloudWatch-Logs-Insights-Pricing.html

---

## 🔧 4. TROUBLESHOOTING PRÁTICO (2h)

Aqui é onde a experiência faz diferença.

### Documentação referência:
- **Monitoring AWS services**: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html
- **Troubleshooting guide**: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Troubleshooting.html

### Fluxo de diagnóstico que uso:

**1. O que está errado? (Identify)**
- Verifique Alarms na console
- Procure por métricas anormais no dashboard

**2. Quando começou? (Timeline)**
- CloudWatch Insights: `fields @timestamp, @message | sort @timestamp desc | limit 100`
- Correlacione com mudanças recentes (deployment, alteração de schema, pico de tráfego)

**3. Quem/O quê foi afetado? (Scope)**
- A todo o pipeline ou apenas uma etapa?
- Um usuário específico ou todos?

**4. Por que aconteceu? (Root Cause)**
- Verifique aplicação + infraestrutura + dados

---

## 🌍 EXEMPLOS DO MUNDO REAL - Engenharia de Dados

### Caso 1: Pipeline de ETL parou de produzir dados

**Sintomas:**
- Alarme: "Data Warehouse não recebeu nova carga em 4 horas"
- Dashboard mostra: Última execução bem-sucedida foi ontem 14:00

**Investigação com CloudWatch:**

```sql
-- Query no Logs Insights
fields @timestamp, @message, @duration
| filter @message like /ERROR|FAILED/
| stats count() as error_count by bin(5m)
```

**Descoberta:** Às 10:15 começaram erros de timeout em query SQL:

```
[ERROR] Query timeout after 300 seconds
SELECT COUNT(*) FROM raw_data WHERE date = '2025-10-20'
```

**Causa raiz:** A tabela `raw_data` cresceu de 2B para 5B de linhas (sem índice)

**Solução:** Criar índice em `date` column

```sql
CREATE INDEX idx_raw_data_date ON raw_data(date);
```

**Métrica após fix:** Tempo de query caiu de 320s para 2s

---

### Caso 2: Custos dispararam 400%

**Descoberta:** CloudWatch mostrava 800GB de logs/mês (vs 50GB mês anterior)

**Investigação:**

```sql
-- Descobrir qual serviço consome mais logs
fields @logStream
| stats sum(strtonum(@message)) as log_size by @logStream
| sort log_size desc
| limit 10
```

**Resultado:** Lambda que faz data processing estava logando TUDO (Arrays gigantes de dados brutos)

**Código problemático:**
```php
// RUIM - Loga array inteiro
logger->info("Processing data", ['raw_data' => $dataArray]);

// BOM - Loga apenas metadata
logger->info("Processing data", [
    'row_count' => count($dataArray),
    'processing_time_ms' => $elapsed,
    'status' => 'success'
]);
```

---

### Caso 3: Qualidade de dados piora progressivamente

**Observação:** Dashboard mostra métrica customizada "duplicate_records" subindo:

```
Dia 18: 10 duplicatas (0.001%)
Dia 19: 150 duplicatas (0.013%)
Dia 20: 2.100 duplicatas (0.2%)
```

**Investigação:** Verifique logs de transformação

```sql
fields @timestamp, transform_step, @message
| filter transform_step like /deduplication/
| stats count() as errors by @message
```

**Descoberta:** Falha silenciosa na deduplicação após mudança no schema de dados

**Causa:** Novo campo adicionado à source que quebrou lógica de hash

**Solução:** Atualizar função de deduplicação para incluir novo campo

---

## 📚 Resumo de Documentação Essencial

| Tópico | Link |
|--------|------|
| CloudWatch Core | https://docs.aws.amazon.com/cloudwatch/ |
| Logs Insights Query | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html |
| Métricas Customizadas | https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/publishingMetrics.html |
| Alarmes | https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html |
| Dashboards | https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html |
| Pricing | https://aws.amazon.com/cloudwatch/pricing/ |
| Best Practices | https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html |

---

## 💡 Conselho Final

O verdadeiro valor do CloudWatch não está em ver tudo em tempo real, mas em ter dados suficientes para fazer perguntas inteligentes quando algo quebra. Estruture seus logs para serem "queryáveis" - pense em campos estruturados, não em strings livres.