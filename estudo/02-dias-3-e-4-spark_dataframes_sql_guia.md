# Dias 3-4: DataFrames e SQL - Guia Especializado

Bom, vejo que você está em um programa estruturado de aprendizado em Engenharia de Dados. Vou quebrar cada tópico com profundidade e realismo de quem trabalha com isso há duas décadas.

---

## 1. OPERAÇÕES COM DataFrames (SELECT, FILTER, GROUPBY, AGG)

### Conceito Essencial

A maioria dos engenheiros de dados começa pensando em DataFrames como "tabelas na memória". Na verdade, eles são **abstrações distribuídas que otimizam execução lazy**. Você define o plano, o Spark otimiza e executa quando necessário.

**As 4 operações fundamentais:**

- **SELECT**: Projeção de colunas (reduz volume de dados)
- **FILTER**: Predicados que eliminam linhas (mais crítico do que parece para performance)
- **GROUPBY**: Agregação por chaves
- **AGG**: Funções de agregação (sum, avg, max, count, etc.)

### Exemplo Prático:

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum, avg, count

spark = SparkSession.builder.appName("DataFrameOps").getOrCreate()

# Simulando vendas
vendas_df = spark.read.parquet("vendas.parquet")

# SELECT + FILTER
resultado = (vendas_df
    .select("produto_id", "categoria", "valor_venda", "data_venda")  # projeção
    .filter(col("data_venda") >= "2024-01-01")  # predicado
    .filter(col("valor_venda") > 0)  # sempre filtrar outliers
)

# GROUPBY + AGG - agregação multi-coluna
resultado_agg = (resultado
    .groupBy("categoria", "produto_id")
    .agg(
        sum("valor_venda").alias("total_vendas"),
        avg("valor_venda").alias("ticket_medio"),
        count("*").alias("quantidade_transacoes")
    )
)
```

**Por que a ordem importa:** SELECT depois FILTER → menos dados trafegando entre partições.

### 📚 Fontes Oficiais:

- **Apache Spark DataFrame API** (Python): https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/dataframe.html
- **Spark SQL Functions**: https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/functions.html
- **Databricks Learning Path**: https://www.databricks.com/discover/pages/getting-started-with-apache-spark

---

## 2. JOINS - O Coração da Engenharia de Dados

### Os 4 Tipos e Quando Usar

**INNER JOIN**: Retorna apenas registros com correspondência em ambas as tabelas
```
Tabela A: [1, 2, 3]
Tabela B: [2, 3, 4]
Resultado: [2, 3] ✓
```

**LEFT JOIN**: Todos de A + correspondências de B
```
Resultado: [1, 2, 3] (1 com NULL em B)
```

**RIGHT JOIN**: Todos de B + correspondências de A

**OUTER JOIN**: Todos de A E B (união completa)

### Implementação Real:

```python
# DataFrames de exemplo
clientes_df = spark.read.table("clientes")  # [cliente_id, nome, segmento]
pedidos_df = spark.read.table("pedidos")    # [pedido_id, cliente_id, valor]
produtos_df = spark.read.table("pedidos_itens") # [pedido_id, produto_id, qty]

# INNER JOIN - clientes com pedidos
resultado = (clientes_df
    .join(pedidos_df, on="cliente_id", how="inner")
    .join(produtos_df, on="pedido_id", how="inner")
)

# LEFT JOIN - todos os clientes, mesmo sem pedidos
resultado_com_nulls = (clientes_df
    .join(pedidos_df, on="cliente_id", how="left")
)
```

### ⚠️ Performance - O Fator Crítico

```python
from pyspark.sql import broadcast

# ❌ LENTO: Join sem broadcast (default shuffle)
resultado_lento = pedidos_df.join(lookup_pequena, "id")

# ✅ RÁPIDO: Broadcast para dimensões pequenas (<100MB)
resultado_rapido = pedidos_df.join(
    broadcast(lookup_pequena), 
    "id"
)

# 📊 Monitorar execução
resultado_rapido.explain(extended=True)
```

**Regra de ouro em Engenharia de Dados:** Se uma tabela cabe em memória (< 100MB por executor), use `broadcast()`.

### 📚 Fontes Oficiais:

- **Spark SQL Joins Guide**: https://spark.apache.org/docs/latest/sql-ref-syntax-qry-select-join.html
- **Performance Tuning - Join Strategies**: https://spark.apache.org/docs/latest/sql-performance-tuning.html
- **Databricks - Advanced Joins**: https://docs.databricks.com/en/sql/language-manual/sql-ref-syntax-qry-select-join.html

---

## 3. WINDOW FUNCTIONS - O Diferencial

### Conceito: Computação em Grupos Ordenados

Window functions permitem cálculos **por linha mantendo contexto do grupo**. É aqui que a maioria dos iniciantes fica confusa.

```python
from pyspark.sql.window import Window
from pyspark.sql.functions import rank, row_number, dense_rank, lag, lead

# Definir "janela" - partição + ordem
window_por_categoria = (
    Window
    .partitionBy("categoria")
    .orderBy(col("vendas_totais").desc())
)

resultado = (vendas_por_produto
    .withColumn("rank", rank().over(window_por_categoria))
    .withColumn("row_num", row_number().over(window_por_categoria))
    .withColumn("dense_rank", dense_rank().over(window_por_categoria))
    .filter(col("rank") <= 3)  # TOP 3 POR CATEGORIA
)
```

### Diferenças Críticas:

| Função | Comportamento | Uso |
|--------|---------------|-----|
| `rank()` | Pula números após empate (1,1,3) | Quando empates importam |
| `row_number()` | Sequencial, sem pulos (1,2,3) | Ordem absoluta |
| `dense_rank()` | Sem pulos (1,1,2) | Rankings compactos |

```python
# Exemplo prático: Margem do cliente ANTES do pedido atual
window_cliente_tempo = (
    Window
    .partitionBy("cliente_id")
    .orderBy("data_pedido")
)

resultado = (pedidos_df
    .withColumn(
        "pedido_anterior_valor",
        lag("valor").over(window_cliente_tempo)
    )
    .withColumn(
        "proxima_data_pedido",
        lead("data_pedido").over(window_cliente_tempo)
    )
)
```

### 📚 Fontes Oficiais:

- **Spark Window Functions**: https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/window.html
- **SQL Window Functions Reference**: https://spark.apache.org/docs/latest/sql-ref-syntax-qry-select-window.html
- **Databricks - Advanced Analytics with Window Functions**: https://docs.databricks.com/en/sql/language-manual/sql-ref-syntax-qry-select-window.html

---

## 4. SPARK SQL QUERIES

### SQL vs DataFrame API

Spark permite **ambos os paradigmas** - escolha sua arma:

```python
# Abordagem 1: DataFrame API (Pythonic)
resultado_api = (spark
    .table("vendas")
    .filter(col("ano") == 2024)
    .groupBy("categoria")
    .agg(sum("valor").alias("total"))
)

# Abordagem 2: SQL (legível, optimizável)
resultado_sql = spark.sql("""
    SELECT 
        categoria,
        SUM(valor) as total
    FROM vendas
    WHERE ano = 2024
    GROUP BY categoria
""")

# São idênticos em performance!
resultado_api.explain(extended=True)
resultado_sql.explain(extended=True)
```

### 📚 Fontes Oficiais:

- **Spark SQL Guide**: https://spark.apache.org/docs/latest/sql-programming-guide.html
- **SQL Reference**: https://spark.apache.org/docs/latest/sql-ref.html
- **Databricks SQL**: https://docs.databricks.com/en/sql/

---

## 🎯 TAREFA DOS DIAS 3-4: 5 Queries Complexas

### Query 1: Top 3 Produtos por Categoria (seu exemplo)

```python
from pyspark.sql.functions import col, row_number
from pyspark.sql.window import Window

window_categoria = (
    Window
    .partitionBy("categoria")
    .orderBy(col("total_vendas").desc())
)

top3_por_categoria = (
    spark.table("vendas_por_produto")
    .withColumn("rank", row_number().over(window_categoria))
    .filter(col("rank") <= 3)
    .select("categoria", "produto", "total_vendas", "rank")
)
```

### Query 2: Clientes com Maior Crescimento YoY

```python
spark.sql("""
    WITH vendas_por_ano AS (
        SELECT 
            cliente_id,
            YEAR(data_venda) as ano,
            SUM(valor) as total_ano
        FROM vendas
        GROUP BY cliente_id, YEAR(data_venda)
    )
    SELECT 
        cliente_id,
        LAG(total_ano) OVER (PARTITION BY cliente_id ORDER BY ano) as vendas_ano_anterior,
        total_ano as vendas_ano_atual,
        ROUND(((total_ano - LAG(total_ano) OVER (PARTITION BY cliente_id ORDER BY ano)) / LAG(total_ano) OVER (PARTITION BY cliente_id ORDER BY ano) * 100), 2) as crescimento_pct
    FROM vendas_por_ano
    WHERE ano IN (2023, 2024)
    ORDER BY crescimento_pct DESC
""")
```

### Query 3: Produtos com Venda Abaixo da Média da Categoria

```python
spark.sql("""
    WITH media_categoria AS (
        SELECT 
            categoria,
            AVG(preco) as preco_medio
        FROM produtos
        GROUP BY categoria
    )
    SELECT 
        p.produto_id,
        p.categoria,
        p.preco,
        m.preco_medio,
        ROUND((p.preco - m.preco_medio), 2) as diferenca
    FROM produtos p
    LEFT JOIN media_categoria m ON p.categoria = m.categoria
    WHERE p.preco < m.preco_medio
    ORDER BY p.categoria, diferenca
""")
```

### Query 4: Sequência de Compras de Clientes (Next Product)

```python
from pyspark.sql.functions import lead

window_cliente_seq = (
    Window
    .partitionBy("cliente_id")
    .orderBy("data_pedido")
)

sequencia_compras = (
    spark.table("pedidos")
    .join(spark.table("itens_pedido"), "pedido_id")
    .withColumn("proximo_produto_id", 
        lead("produto_id").over(window_cliente_seq)
    )
    .withColumn("proxima_data_compra",
        lead("data_pedido").over(window_cliente_seq)
    )
    .filter(col("proximo_produto_id").isNotNull())
)
```

### Query 5: Percentil de Clientes por Valor Total Gasto

```python
spark.sql("""
    SELECT 
        cliente_id,
        SUM(valor) as gasto_total,
        PERCENT_RANK() OVER (ORDER BY SUM(valor)) as percentil,
        NTILE(4) OVER (ORDER BY SUM(valor)) as quartil
    FROM vendas
    GROUP BY cliente_id
    ORDER BY gasto_total DESC
""")
```

---

## 🌍 Exemplos do Mundo Real - Engenharia de Dados

### Cenário 1: E-commerce - Detecção de Churn

```python
spark.sql("""
    WITH cliente_atividade AS (
        SELECT 
            cliente_id,
            DATE_FORMAT(data_compra, 'yyyy-MM') as mes,
            COUNT(*) as qtd_compras,
            SUM(valor) as total_mes
        FROM vendas
        GROUP BY cliente_id, DATE_FORMAT(data_compra, 'yyyy-MM')
    ),
    ultima_atividade AS (
        SELECT 
            cliente_id,
            MAX(mes) as ultimo_mes_ativo,
            DATEDIFF(current_date(), MAX(CONCAT(mes, '-01'))) as dias_inativo
        FROM cliente_atividade
        GROUP BY cliente_id
    )
    SELECT 
        c.cliente_id,
        CASE 
            WHEN dias_inativo > 90 THEN 'Churned'
            WHEN dias_inativo > 60 THEN 'Risk'
            ELSE 'Active'
        END as status_cliente,
        dias_inativo,
        LAG(c.total_mes) OVER (PARTITION BY c.cliente_id ORDER BY c.mes) as mes_anterior_gasto
    FROM cliente_atividade c
    INNER JOIN ultima_atividade u ON c.cliente_id = u.cliente_id
    WHERE c.mes = u.ultimo_mes_ativo
""")
```

### Cenário 2: Fraud Detection - Padrões Anormais de Compra

```python
spark.sql("""
    WITH estatisticas_cliente AS (
        SELECT 
            cliente_id,
            AVG(valor_transacao) as valor_medio,
            STDDEV(valor_transacao) as desvio_padrao,
            MAX(valor_transacao) as valor_maximo,
            COUNT(*) as qtd_transacoes
        FROM transacoes
        WHERE data_transacao >= DATE_SUB(current_date(), 180)
        GROUP BY cliente_id
    )
    SELECT 
        t.cliente_id,
        t.valor_transacao,
        e.valor_medio,
        e.desvio_padrao,
        ROUND((t.valor_transacao - e.valor_medio) / e.desvio_padrao, 2) as z_score,
        CASE 
            WHEN ABS((t.valor_transacao - e.valor_medio) / e.desvio_padrao) > 3 THEN 'Anomalia Critica'
            WHEN ABS((t.valor_transacao - e.valor_medio) / e.desvio_padrao) > 2 THEN 'Anomalia Moderada'
            ELSE 'Normal'
        END as classificacao_risco
    FROM transacoes t
    INNER JOIN estatisticas_cliente e ON t.cliente_id = e.cliente_id
    WHERE t.data_transacao = current_date()
    AND ABS((t.valor_transacao - e.valor_medio) / e.desvio_padrao) >= 2
""")
```

### Cenário 3: Análise de Retenção - Cohort Analysis

```python
spark.sql("""
    WITH primeira_compra AS (
        SELECT 
            cliente_id,
            MIN(DATE_FORMAT(data_compra, 'yyyy-MM')) as cohort
        FROM vendas
        GROUP BY cliente_id
    ),
    atividade_cliente AS (
        SELECT 
            f.cliente_id,
            f.cohort,
            DATE_FORMAT(v.data_compra, 'yyyy-MM') as mes_atividade,
            DATEDIFF(
                DATE_FORMAT(v.data_compra, 'yyyy-MM-01'),
                DATE_FORMAT(DATE_ADD(DATE_PARSE(f.cohort, 'yyyy-MM'), 1), 'yyyy-MM-01')
            ) / 30 as meses_desde_primeira_compra
        FROM primeira_compra f
        INNER JOIN vendas v ON f.cliente_id = v.cliente_id
    )
    SELECT 
        cohort,
        meses_desde_primeira_compra,
        COUNT(DISTINCT cliente_id) as clientes_retidos
    FROM atividade_cliente
    GROUP BY cohort, meses_desde_primeira_compra
    ORDER BY cohort, meses_desde_primeira_compra
""")
```

### Cenário 4: Product Analytics - Análise de Funnels de Conversão

```python
spark.sql("""
    WITH eventos_ordenados AS (
        SELECT 
            usuario_id,
            evento,
            data_hora,
            ROW_NUMBER() OVER (PARTITION BY usuario_id ORDER BY data_hora) as seq,
            LAG(evento) OVER (PARTITION BY usuario_id ORDER BY data_hora) as evento_anterior,
            LEAD(evento) OVER (PARTITION BY usuario_id ORDER BY data_hora) as proximo_evento
        FROM eventos_aplicacao
        WHERE data_hora >= DATE_SUB(current_date(), 30)
    )
    SELECT 
        evento_anterior,
        evento,
        proximo_evento,
        COUNT(DISTINCT usuario_id) as usuarios_passou_por_essa_sequencia,
        COUNT(CASE WHEN proximo_evento IS NOT NULL THEN 1 END) as continuaram_navegando
    FROM eventos_ordenados
    WHERE evento_anterior IS NOT NULL
    GROUP BY evento_anterior, evento, proximo_evento
    ORDER BY usuarios_passou_por_essa_sequencia DESC
""")
```

### Cenário 5: Supply Chain - Análise de Delays

```python
spark.sql("""
    WITH tempos_processamento AS (
        SELECT 
            pedido_id,
            data_pedido,
            data_confirmacao,
            data_saida_deposito,
            data_entrega_estimada,
            data_entrega_real,
            DATEDIFF(data_confirmacao, data_pedido) as dias_para_confirmar,
            DATEDIFF(data_saida_deposito, data_confirmacao) as dias_para_processar,
            DATEDIFF(data_entrega_real, data_saida_deposito) as dias_entrega,
            DATEDIFF(data_entrega_real, data_entrega_estimada) as delay_dias
        FROM pedidos
    )
    SELECT 
        DATE_FORMAT(data_pedido, 'yyyy-MM') as mes_pedido,
        ROUND(AVG(dias_para_confirmar), 1) as media_dias_confirmacao,
        ROUND(AVG(dias_para_processar), 1) as media_dias_processamento,
        ROUND(AVG(dias_entrega), 1) as media_dias_entrega,
        ROUND(AVG(delay_dias), 1) as media_delay,
        COUNT(CASE WHEN delay_dias > 0 THEN 1 END) as pedidos_com_delay,
        ROUND(COUNT(CASE WHEN delay_dias > 0 THEN 1 END) * 100.0 / COUNT(*), 2) as pct_atraso
    FROM tempos_processamento
    GROUP BY DATE_FORMAT(data_pedido, 'yyyy-MM')
    ORDER BY mes_pedido DESC
""")
```

---

## 💡 Dicas Profissionais Que Levei 20 Anos Aprendendo

1. **Sempre FILTER antes de JOIN**: Reduz dados trafegando entre partições
2. **Use `explain()` religiosamente**: `df.explain(extended=True)` mostra o plano de execução real
3. **Broadcast é seu amigo**: Dimensões < 100MB? Broadcast. Sempre.
4. **Window functions antes de GROUP BY**: Window functions preservam mais contexto
5. **Evite múltiplos JOINs em dados grandes**: Considere CTEs ou denormalização incremental
6. **Monitore shuffle operations**: São o gargalo real. Veja no Spark UI
7. **Repartição estratégica**: Particione por colunas de JOIN/FILTER frequentes

---

Desejo estudar junto? Qual desses cenários do mundo real faz mais sentido para seu contexto? Posso detalhar ainda mais qualquer um deles com código completo em Spark + otimizações reais.