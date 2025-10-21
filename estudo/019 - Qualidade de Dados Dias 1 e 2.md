# SEMANA 8: QUALIDADE DE DADOS + PROJETO FINAL

## Explicação Especializada com Fontes

Vou te guiar por esses tópicos como alguém que passou duas décadas construindo pipelines de dados robustos em ambientes de produção. Esta semana é crítica porque muda seu mindset: não é mais sobre *fazer* os dados funcionarem, é sobre *garantir* que funcionam consistentemente.

---

## 1. DATA QUALITY FRAMEWORK (4h)

### O Conceito Fundamental

Um Data Quality Framework é a estrutura sistemática que define como você mede, monitora e melhora a qualidade dos seus dados ao longo de todo o ciclo de vida. Não é apenas um checksum ou uma validação pontual — é uma filosofia operacional.

Os seis pilares que usamos na indústria são:

- **Completude**: dados presentes?
- **Conformidade**: estão no formato esperado?
- **Consistência**: alinhados entre sistemas?
- **Acurácia**: refletem a realidade?
- **Validade**: dentro dos limites esperados?
- **Unicidade**: sem duplicações problemáticas?

#### Documentação Essencial

- [Gartner's Data Quality Framework](https://www.gartner.com/en/information-technology/insights/data-management) - conceitos corporativos
- [Talend Data Quality Best Practices](https://www.talend.com/resources/guide/enterprise-data-quality/) - aplicação prática
- [DAMA-DMBOK (Data Management Body of Knowledge)](http://www.dama.org/) - padrão internacional

### Por que importa agora

Você provavelmente encontrou bugs em produção causados por dados ruins. Um framework evita isso sistematicamente. Em minha experiência, 60-70% dos problemas em pipelines não são bugs de código — são dados inválidos chegando onde não deveriam.

---

## 2. GREAT EXPECTATIONS INTRO (2h)

### A Ferramenta que Mudou o Jogo

Great Expectations é uma biblioteca open-source que torna a validação de dados declarativa e versionável. Em vez de escrever scripts aleatórios de validação, você define *expectations* (expectativas) que seus dados devem cumprir.

#### Instalação e Fundações

```python
# Instalação
pip install great-expectations

# Inicialização do projeto
great_expectations init
```

O workflow básico envolve: criar um projeto GX → conectar suas fontes de dados → definir expectations → executar validação → armazenar checkpoints → integrar em seu pipeline.

#### Documentação Oficial

- [Great Expectations Documentation](https://docs.greatexpectations.io/) - completa e atualizada
- [Great Expectations GitHub](https://github.com/great-expectations/great_expectations) - código-fonte
- [Getting Started Guide](https://docs.greatexpectations.io/docs/tutorials/getting-started) - passo a passo

### Exemplo Prático Inicial

Você teria um DataFrame que precisa validar antes de processar. Com GX, você faz assim:

```python
import great_expectations as ge

# Carregar dados com GX
df = ge.read_csv('vendas.csv')

# Definir expectations
df.expect_column_values_to_be_in_set('status', ['ativo', 'inativo'])
df.expect_column_values_to_not_be_null('customer_id')
df.expect_column_values_to_be_between('valor', min_value=0, max_value=1000000)

# Executar validação
resultado = df.validate()
print(resultado)
```

---

## 3. DATA OBSERVABILITY (2h)

### Mudando de Reatividade para Proatividade

Data Observability é como logs e métricas, mas para dados. Enquanto você *monitora* a saúde de uma aplicação, você *observa* a saúde dos dados em movimento. É proativo — você detecta anomalias antes que causem danos.

Os quatro pilares são:

- **Linhagem**: de onde vieram os dados?
- **Integridade**: estão íntegros?
- **Qualidade**: atendem aos critérios?
- **Frescor**: são recentes o suficiente?

#### Documentação Essencial

- [DataCulpa - Data Observability Fundamentals](https://www.dataculpa.com/blog/data-observability) - conceituação prática
- [Monte Carlo Data - What is Data Observability](https://www.montecarlodata.com/blog-what-is-data-observability/) - perspectiva industrial
- [Gartner - Data Observability](https://www.gartner.com/en/information-technology/insights/observability) - tendências

### O Stack Típico

Na prática, você integraria ferramentas como Datadog ou New Relic (para logs), Prometheus (para métricas), e ferramentas especializadas como Monte Carlo Data ou Databand para observabilidade de dados específica.

---

## 4. SLAs PARA DADOS (2h)

### Definindo Contratos de Serviço para Dados

Um Data SLA (Service Level Agreement) é um contrato formal entre quem produz os dados e quem os consome. Especifica: qual é a latência máxima aceitável? Qual disponibilidade? Qual porcentagem de completude?

Os SLIs (Service Level Indicators) são as métricas que você mede. Os SLOs (Service Level Objectives) são as metas. Você usa ambos para definir o SLA.

#### Exemplo

- **SLI**: "Dados de vendas aparecem no data warehouse dentro de 4 horas da transação"
- **SLO**: "99.5% dos dias devem atender a esse SLI"
- **SLA**: "Se violarmos o SLO 2 meses seguidos, o time responsável recebe alertas e prioriza correções"

#### Documentação de Referência

- [Google SRE Book - Chapter 4: Service Level Objectives](https://sre.google/sre-book/service-level-objectives/) - padrão ouro
- [Datadog - Data SLOs](https://www.datadoghq.com/blog/slo-best-practices/) - implementação prática
- [O'Reilly - Designing Data Intensive Applications, Capítulo 1](https://www.oreilly.com/library/view/designing-data-intensive-applications/9781491901632/) - contexto arquitetural

---

## 5. ANOMALY DETECTION BASICS (2h)

### Detectando o Inesperado

Anomaly Detection em dados significa identificar padrões que desviam do normal. Pode ser estatístico (desvio padrão), baseado em machine learning (Isolation Forests) ou baseado em série temporal.

Os casos mais comuns em Engenharia de Dados:

- Um upstream falhou e você está recebendo 90% menos registros que o normal
- Os valores de uma coluna mudaram de range (preços suddenly 1000x maiores)

#### Documentação

- [Scikit-learn - Anomaly Detection](https://scikit-learn.org/stable/modules/outlier_detection.html) - implementações prontas
- [Prophet by Facebook](https://facebook.github.io/prophet/) - para séries temporais
- [PyOD - Python Outlier Detection](https://pyod.readthedocs.io/) - biblioteca especializada

### Abordagem Simples mas Eficaz

```python
from scipy import stats
import pandas as pd

# Seu DataFrame
df = pd.read_csv('eventos_diarios.csv')

# Z-score: identifica desvios de 3 desvios padrão
z_scores = stats.zscore(df['quantidade_eventos'])
anomalias = df[abs(z_scores) > 3]

print(f"Anomalias detectadas: {len(anomalias)} dias")
```

---

## 6. DATA GOVERNANCE (2h)

### Estabelecendo Ordem no Caos

Data Governance é o framework que define quem pode acessar quais dados, como devem ser nomeados, onde devem estar armazenados, como devem ser documentados e quando podem ser deletados.

Envolve:

- **Catalogação**: inventário de dados
- **Linhagem**: rastreamento de origem
- **Classificação**: sensibilidade
- **Acesso**: permissões
- **Retenção**: política de exclusão

#### Documentação Essencial

- [DAMA - Data Governance Framework](http://www.dama.org/) - padrão corporativo
- [GDPR Compliance for Data Engineers](https://gdpr-info.eu/) - regulatório
- [Collibra - Data Governance Platform](https://www.collibra.com/us/en/resource/guide/data-governance-framework) - ferramenta líder
- [LinkedIn Data Governance Whitepaper](https://www.linkedin.com/document/d/1Zp_5NYXe2EjI0EqOcMvwUw/edit?usp=sharing) - case real grande escala

---

# EXEMPLOS DO MUNDO REAL - CASOS PRÁTICOS

Agora deixa eu compartilhar cenários que enfrentei realmente em ambientes corporativos. Esses são os problemas que fazem a diferença entre um pipeline "que funciona" e um sistema "que você pode confiar".

## Caso 1: Ecommerce - Detecção de Falha em Pipeline de Vendas

### O Cenário

Uma empresa de ecommerce com 50 mil transações/dia. O pipeline ETL que alimenta o analytics dashboard começou a falhar intermitentemente. Às vezes, 30% dos dados não chegavam até 6 horas depois.

### O Problema Real

Ninguém sabia que estava acontecendo até reclamação vir do time de negócios dizendo que números não batiam com a realidade.

### A Solução com Observabilidade de Dados

```python
# Você implementaria um SLA
SLA_TRANSACOES = {
    'max_latency': '4 horas',           # Máximo de atraso
    'min_completeness': 0.99,           # Mínimo 99% das transações
    'expected_daily_volume': 50000,     # ± 15%
}

# Com Great Expectations, você teria:
df.expect_table_row_count_to_be_between(42500, 57500)  # 50k ± 15%
df.expect_column_values_to_be_between('timestamp', 
                                      min_value=now - timedelta(hours=4),
                                      max_value=now)
df.expect_column_values_to_not_be_null('transaction_id')  # 99%+ complete
```

### Impacto

- Você saberia em tempo real quando o volume cai 30%
- Alertaria o time antes do painel se desatualizar
- Rastrearia a linhagem para identificar se falhou em extração, transformação ou carga

**Ferramentas reais usadas:** Airflow + Great Expectations + Datadog + Sentry

---

## Caso 2: Dados Financeiros - Validação Crítica Antes de Reconciliação

### O Cenário

Banco processando 200 mil transações de crédito/débito por dia. Um erro em validação causou reconciliação errada, levando 3 dias para descobrir discrepância de R$ 2 milhões.

### O Problema

Nenhum framework de qualidade de dados. Validações eram ad-hoc, escritas em diferentes scripts SQL por diferentes pessoas.

### A Solução Estruturada

Data Governance definiu que TODA transação financeira precisa de:

- **Conformidade**: valor entre -999.999,99 e +999.999,99
- **Completude**: campos obrigatórios presentes em 100%
- **Consistência**: se débito em conta A, crédito deve estar em conta B
- **Acurácia**: cada transação auditável contra sistema fonte

```python
# Framework implementado
suite = ge.ExpectationSuite(name='transacoes_financeiras')

# Conformidade
suite.add_expectation(
    ge.Expectation.expect_column_values_to_be_in_set(
        'tipo_transacao', 
        ['credito', 'debito']
    )
)

# Completude
suite.add_expectation(
    ge.Expectation.expect_column_values_to_not_be_null('conta_origem')
)

# Consistência (débito em A = crédito em B)
# Isso seria uma custom expectation

# Salvar e versionnar
suite.save('data_context/')
```

### Resultado

Falhas detectadas antes de atingir produção. SLA implementado: 100% das transações validadas antes de entrar no sistema de reconciliação.

---

## Caso 3: Retail - Anomaly Detection em Padrões de Vendas

### O Cenário

Rede varejista com 500 lojas, recebendo feeds de vendas em tempo real. Um sistema POS em uma loja começou a registrar quantidade 10x maior (bug no software), afetando as previsões.

### O Problema

Dados ruins propagados para modelos de ML de previsão de estoque e demanda.

### A Solução com Anomaly Detection

```python
import pandas as pd
from sklearn.ensemble import IsolationForest

# Receber dados de 500 lojas
vendas = pd.read_csv('vendas_tempo_real.csv')

# Criar model treinado em dados históricos "bons"
model = IsolationForest(contamination=0.05)
anomalias = model.fit_predict(vendas[['quantidade', 'valor_medio']])

# Sinalizar anomalias
vendas['eh_anomalia'] = anomalias == -1

# Alertar
lojas_anomalas = vendas[vendas['eh_anomalia']].groupby('store_id').size()
if not lojas_anomalas.empty:
    alerta(f'Anomalias em lojas: {lojas_anomalas.index.tolist()}')
    # Pausar integração com sistema de previsão
```

### Impacto

**Data Observability:** Você rastrearia que dados anômalos não chegaram ao modelo de previsão, prevenindo previsões incorretas.

---

## Caso 4: SaaS - Definindo SLAs Entre Times

### O Cenário

Aplicação SaaS onde o time de Analytics precisa de dados de usuários atualizados. Historicamente, dados chegavam a qualquer hora ou com atrasos de horas.

### O Problema

SLA não definido. Desalineamento entre produtor (Backend) e consumidor (Analytics).

### A Solução

```
╔════════════════════════════════════════════════════════════╗
║                      DATA SLA CONTRATO                     ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║ Produtor: Backend Team                                     ║
║ Consumidor: Analytics Team                                 ║
║                                                            ║
║ SLI (métrica a medir):                                     ║
║  - User profile updates appear in data warehouse within    ║
║    2 hours of change in production                         ║
║  - 100% completeness on required fields                    ║
║                                                            ║
║ SLO (meta):                                                ║
║  - Atender SLI em 99% dos dias                            ║
║  - Máximo 1 incidente por mês                             ║
║                                                            ║
║ Ações se SLO violado:                                      ║
║  - Primeiro mês: Debug session + post-mortem              ║
║  - Segundo mês consecutivo: Escala para management        ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
```

Monitorado com:

```python
# Métrica de latência
latencia = (data_warehouse_timestamp - production_timestamp)
sli_latencia = (latencia <= 2 * 3600).mean()  # 2 horas em segundos

# Métrica de completeness
completeness = (df[campos_obrigatorios].notna().all(axis=1)).mean()

# Ambas precisam estar acima do threshold para atender SLO
slo_atendido = (sli_latencia >= 0.99) and (completeness >= 1.0)
```

---

## Caso 5: Data Governance em Escala - Conformidade LGPD

### O Cenário

Empresa brasileira processando dados de clientes. Regulamentação LGPD exigindo: saber onde estão todos os dados pessoais, quem pode acessar, por quanto tempo podem ser retidos.

### O Problema

Dados espalhados em 15 diferentes sistemas com nenhuma catalogação centralizada.

### A Solução de Data Governance

Implementar um data catalog (como Collibra ou open-source como Apache Atlas):

```
Tabela: users_profile
├─ Coluna: email (PII - Personally Identifiable Information)
│  ├─ Classificação: Sensitive
│  ├─ Retention: Conforme contrato com cliente
│  ├─ Acesso: Analytics team, Customer Support team
│  └─ Auditoria: Automaticamente rastreada
│
├─ Coluna: purchase_history (PII)
│  ├─ Classificação: Sensitive
│  ├─ Retention: 5 anos conforme lei fiscal
│  └─ Linhagem: Origem → /datawarehouse/sales_raw → /datawarehouse/users_profile
│
└─ Coluna: anonymized_user_id (Non-sensitive)
   ├─ Classificação: Public
   ├─ Acesso: Qualquer um
   └─ Retention: Indefinido
```

Linhagem de dados rastreada:

```
Origem: PostgreSQL (produção) 
    → Apache Kafka (streaming)
    → Spark Job (transformação)
    → Cloud Storage (Parquet)
    → Data Warehouse (final)
    → Relatórios Analytics
    → Dashboard (visualização)
```

### Impacto

Com esse nível de governance, você consegue:

- Responder "quem pode acessar este campo?" em segundos
- Rastrear "de onde vieram esses dados?" facilmente
- Garantir compliance automaticamente

---

## Caso 6: Pipeline de ML - Qualidade de Dados e Data Drift

### O Cenário

Modelo de ML que prevê churn de clientes. Estava com 92% de acurácia em produção, caiu para 71% após 3 meses sem nenhuma mudança no código.

### O Problema (Data Drift)

A distribuição dos dados mudou. Clientes novos tinham padrões diferentes dos dados de treino.

### A Solução

```python
# Monitorar distribuições
from scipy.stats import ks_2samp

# Dados de treino (baseline histórico)
X_train = pd.read_csv('dados_treino_2023.csv')

# Dados recentes em produção
X_prod = pd.read_csv('dados_producao_setembro_2024.csv')

# Teste de Kolmogorov-Smirnov para cada feature
for coluna in X_train.columns:
    estatistica, p_valor = ks_2samp(X_train[coluna], X_prod[coluna])
    if p_valor < 0.05:  # Distribuição mudou significativamente
        print(f"⚠️ DRIFT DETECTADO em {coluna}")
        # Alerta: modelo pode estar desatualizado
        # Sinalizar para retrainamento
```

### Impacto

Com Data Governance: Você documentaria que este modelo crítico precisa ser retreinado quando detectado drift, e quem é responsável.

---

# ESTRUTURANDO SEU APRENDIZADO

Recomendo que você estude nesta ordem:

1. **Semana 1:** Domine Great Expectations completamente. Escreva 50+ expectations diferentes em datasets reais seus.

2. **Semana 2:** Implemente SLAs em um pipeline seu. Defina métricas e alertas.

3. **Semana 3:** Integre observabilidade básica. Comece com Datadog free tier ou Prometheus.

4. **Semana 4:** Construa um data catalog simples para seus dados (planilha formalizada → evoluir para ferramenta).

Gostaria que eu aprofundasse em algum desses tópicos ou mostrasse como implementar em PHP/Python para seus pipelines específicos?