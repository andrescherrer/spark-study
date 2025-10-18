# Datasets

Este diretório contém datasets para prática de Spark.

## NYC Taxi Sample

- **Gerado por:** `scripts/generate_dataset.py`
- **Linhas:** 100.000
- **Tamanho:** ~6 MB
- **Período:** 2025 (simulado)

### Como Gerar

**Local (na sua máquina):**
```bash
python3 scripts/generate_dataset.py
```

**Dentro do Docker:**
```bash
make start
make shell
python3 scripts/generate_dataset.py
exit
```

### Colunas

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| pickup_datetime | string | Hora de saída (YYYY-MM-DD HH:MM:SS) |
| dropoff_datetime | string | Hora de chegada (YYYY-MM-DD HH:MM:SS) |
| passenger_count | int | Número de passageiros (1-6) |
| trip_distance | float | Distância em km |
| fare_amount | float | Tarifa em dólares |

### Importante

Este arquivo é **gerado, não versionado** (veja `.gitignore`). Para reproducibilidade, o script Python está versionado no Git.

### Regenerar Dados

Se precisar gerar novamente:
```bash
rm datasets/nyc_taxi_sample.csv
python3 scripts/generate_dataset.py
```
