# Spark Study - Setup Completo (Versão Final)

Guia passo-a-passo para reproduzir o ambiente completo com todas as correções aplicadas.

---

## PASSO 1: Pré-requisitos

Antes de começar, verifique se tem tudo instalado:

```bash
docker --version
# Output esperado: Docker version 24.x.x ou maior

docker-compose --version
# Output esperado: Docker Compose version 2.x.x ou maior

git --version
# Output esperado: git version 2.x.x ou maior
```

Se não tem Docker, instale em: https://docs.docker.com/get-docker/

---

## PASSO 2: Criar Estrutura de Pastas

Execute os comandos abaixo na ordem:

```bash
# Criar pasta raiz
mkdir spark-study
cd spark-study

# Criar pastas principais
mkdir -p docker
mkdir -p notebooks
mkdir -p scripts/spark_jobs
mkdir -p datasets
mkdir -p data/{raw,processed,output}

# Criar .gitkeep (mantém pastas vazias no Git)
touch scripts/.gitkeep
touch scripts/spark_jobs/.gitkeep
touch data/.gitkeep
touch data/raw/.gitkeep
touch data/processed/.gitkeep
touch data/output/.gitkeep

# Verificar estrutura criada
tree
# Ou: ls -R
```

**Estrutura esperada:**

```
spark-study/
├── docker/
├── datasets/
├── notebooks/
├── scripts/
│   ├── spark_jobs/
│   └── .gitkeep
├── data/
│   ├── raw/
│   ├── processed/
│   └── output/
└── (arquivos serão criados nos próximos passos)
```

---

## PASSO 3: Criar Arquivo `docker/Dockerfile`

Crie o arquivo: `spark-study/docker/Dockerfile`

```dockerfile
FROM eclipse-temurin:17-jdk-jammy

# Instalar Python e dependências
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3-pip \
    python3.11-distutils \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Criar link simbólico para python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Upgrade pip
RUN pip install --upgrade pip setuptools wheel

# Instalar Python packages
RUN pip install \
    pyspark==3.5.1 \
    jupyter==1.0.0 \
    jupyterlab==4.0.9 \
    pandas==2.0.3 \
    numpy==1.24.3 \
    matplotlib==3.7.2 \
    seaborn==0.12.2 \
    pyarrow==13.0.0

# Criar diretório de trabalho
WORKDIR /workspace

# Expor porta Jupyter
EXPOSE 8888

# Comando padrão
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
```

**Verificar:**
```bash
ls -la docker/Dockerfile
```

---

## PASSO 4: Criar Arquivo `docker-compose.yml`

Crie o arquivo: `spark-study/docker-compose.yml` (raiz do projeto)

```yaml
version: '3.8'

services:
  spark-jupyter:
    build:
      context: .
      dockerfile: docker/Dockerfile
    container_name: spark-study
    ports:
      - "8888:8888"      # Jupyter Lab
      - "4040:4040"      # Spark UI
    volumes:
      - ./notebooks:/workspace/notebooks
      - ./datasets:/workspace/datasets
      - ./scripts:/workspace/scripts
      - ./data:/workspace/data
    environment:
      - JUPYTER_ENABLE_LAB=yes
      - SPARK_LOCAL_IP=127.0.0.1
    networks:
      - spark-network

networks:
  spark-network:
    driver: bridge
```

**Verificar:**
```bash
cat docker-compose.yml
```

---

## PASSO 5: Criar `.gitignore`

Crie o arquivo: `spark-study/.gitignore` (raiz do projeto)

```
# Docker & Environment
.env
.env.local
.dockerignore

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
eggs/
.eggs/
lib/
parts/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual Environments
venv/
ENV/
env/
.venv
conda-env/

# Jupyter
.ipynb_checkpoints
*.ipynb_checkpoints
.jupyter/
.jupyterlab/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store
.project

# OS
Thumbs.db
.AppleDouble

# Dados (NÃO commita dados gerados, apenas scripts que geram)
datasets/*.csv
datasets/*.parquet
data/raw/*
data/processed/*
data/output/*
!datasets/README.md
!data/.gitkeep
!data/raw/.gitkeep
!data/processed/.gitkeep
!data/output/.gitkeep

# Logs
*.log
logs/

# Spark
metastore_db/
spark-warehouse/

# Arquivos temporários
*.tmp
*.bak
*~

# Credenciais (NUNCA commitar)
*credentials*
*secrets*
*.pem
*.key
```

**Verificar:**
```bash
cat .gitignore
```

---

## PASSO 6: Criar `Makefile`

Crie o arquivo: `spark-study/Makefile` (raiz do projeto, **SEM extensão**)

```makefile
.PHONY: help build start stop logs restart clean shell python verify

# Variáveis
CONTAINER_NAME := spark-study

# Cores
GREEN := \033[0;32m
BLUE := \033[0;34m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

help:
	@echo "$(BLUE)==== Spark Study Commands ====$(NC)"
	@echo ""
	@echo "$(GREEN)Setup:$(NC)"
	@echo "  make build              Build Docker image"
	@echo "  make rebuild            Rebuild sem cache"
	@echo ""
	@echo "$(GREEN)Run:$(NC)"
	@echo "  make start              Start container (docker-compose up -d)"
	@echo "  make stop               Stop container"
	@echo "  make restart            Restart container"
	@echo ""
	@echo "$(GREEN)Access:$(NC)"
	@echo "  make logs               Ver logs Jupyter"
	@echo "  make shell              Bash no container"
	@echo "  make python             Python interativo"
	@echo "  make spark-shell        Spark shell"
	@echo ""
	@echo "$(GREEN)Clean:$(NC)"
	@echo "  make clean              Remove container"
	@echo "  make clean-all          Remove tudo (including datasets)"
	@echo ""
	@echo "$(GREEN)Verify:$(NC)"
	@echo "  make verify             Verifica Spark/Pandas/Jupyter"
	@echo "  make info               Mostra info do ambiente"
	@echo ""

build:
	@echo "$(BLUE)Building Docker image...$(NC)"
	docker-compose build
	@echo "$(GREEN)✓ Build completo$(NC)"

rebuild:
	@echo "$(BLUE)Rebuilding (sem cache)...$(NC)"
	docker-compose build --no-cache
	@echo "$(GREEN)✓ Rebuild completo$(NC)"

start:
	@echo "$(BLUE)Starting container...$(NC)"
	docker-compose up -d
	@sleep 3
	@echo "$(GREEN)✓ Container iniciado$(NC)"
	@echo "$(YELLOW)Jupyter Lab: http://127.0.0.1:8888$(NC)"
	@echo "$(YELLOW)Spark UI: http://127.0.0.1:4040$(NC)"
	@echo ""
	@echo "$(BLUE)Token Jupyter (copie e cole no navegador):$(NC)"
	@docker-compose logs spark-jupyter | grep token | tail -1

stop:
	@echo "$(BLUE)Stopping container...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ Container parado$(NC)"

restart: stop start
	@echo "$(GREEN)✓ Container reiniciado$(NC)"

logs:
	@docker-compose logs -f spark-jupyter

shell:
	@echo "$(BLUE)Entrando no container...$(NC)"
	@docker exec -it $(CONTAINER_NAME) bash

python:
	@echo "$(BLUE)Python interativo...$(NC)"
	@docker exec -it $(CONTAINER_NAME) python3

spark-shell:
	@echo "$(BLUE)Spark shell...$(NC)"
	@docker exec -it $(CONTAINER_NAME) pyspark

clean:
	@echo "$(RED)Removendo container...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ Limpeza completa$(NC)"

clean-all: clean
	@echo "$(RED)Removendo TUDO (including datasets)...$(NC)"
	docker-compose down -v
	@rm -rf data/processed/* data/raw/* data/output/* 2>/dev/null || true
	@rm -rf datasets/*.csv datasets/*.parquet 2>/dev/null || true
	@echo "$(GREEN)✓ Limpeza agressiva completa$(NC)"

verify:
	@echo "$(BLUE)Verificando Spark...$(NC)"
	@docker exec $(CONTAINER_NAME) python3 -c "import pyspark; print('$(GREEN)✓ PySpark ' + pyspark.__version__)"
	@echo "$(BLUE)Verificando Pandas...$(NC)"
	@docker exec $(CONTAINER_NAME) python3 -c "import pandas; print('$(GREEN)✓ Pandas ' + pandas.__version__)"

info:
	@echo "$(BLUE)==== Informações ====$(NC)"
	@echo "Docker:"
	@docker --version
	@echo ""
	@echo "Docker Compose:"
	@docker-compose --version
	@echo ""
	@echo "Container:"
	@docker ps -a | grep $(CONTAINER_NAME) || echo "Não rodando"
```

**Verificar:**
```bash
ls -la Makefile
make help
```

---

## PASSO 7: Inicializar Git

```bash
# Inicializar repositório
git init

# Configurar git (se não configurou ainda)
git config user.name "Seu Nome"
git config user.email "seu.email@example.com"

# Ver configuração
git config --list | grep user

# Adicionar arquivos (exceto dados, via .gitignore)
git add .

# Primeiro commit
git commit -m "Initial commit: Spark Study setup with Docker"

# Ver histórico
git log --oneline
```

---

## PASSO 8: Build Docker

Execute uma única vez (vai levar ~15 min na primeira vez):

```bash
make build
```

**Output esperado:**
```
Building Docker image...
[+] Building 15.5s (12/12) FINISHED
...
✓ Build completo
```

---

## PASSO 9: Testar Setup Inicial

```bash
# Iniciar container
make start

# Ver logs e copiar token
make logs

# Deve aparecer algo como:
# To access the server, open this file in a browser:
#     file:///root/.local/share/jupyter/lab/workspaces/lab/default.jpynb
# or click the link:
#     http://127.0.0.1:8888/lab?token=xxxxxxxxxxxxx
```

**Abrir no navegador:**
- http://127.0.0.1:8888
- Colar o token

**Deve abrir Jupyter Lab com editor de notebooks.**

---

## PASSO 10: Criar Script para Gerar Dataset

Na sua máquina local (não no container), crie o arquivo: `spark-study/scripts/generate_dataset.py`

Use um editor de texto (VS Code, Sublime, etc) ou terminal:

```bash
cat > scripts/generate_dataset.py << 'EOF'
#!/usr/bin/env python3
"""
Gera dataset NYC Taxi simulado para prática de Spark.
100.000 linhas com dados realistas.
"""

import csv
import os
from datetime import datetime, timedelta
import random
from pathlib import Path

def generate_nyc_taxi_dataset(output_path: str, num_rows: int = 100000):
    """Gera dataset NYC Taxi simulado"""
    
    # Criar diretório se não existir
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    
    print(f"Gerando {num_rows:,} linhas de dados NYC Taxi...")
    
    rows = []
    start_date = datetime(2025, 1, 1)
    
    for i in range(num_rows):
        # Hora de pickup aleatória no ano
        pickup_time = start_date + timedelta(minutes=random.randint(0, 525600))
        # Duração entre 5 e 60 minutos
        dropoff_time = pickup_time + timedelta(minutes=random.randint(5, 60))
        
        row = [
            pickup_time.strftime("%Y-%m-%d %H:%M:%S"),
            dropoff_time.strftime("%Y-%m-%d %H:%M:%S"),
            random.randint(1, 6),                    # passenger_count
            round(random.uniform(1, 20), 2),        # trip_distance (km)
            round(random.uniform(5, 100), 2)        # fare_amount ($)
        ]
        rows.append(row)
    
    # Salvar CSV
    with open(output_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow([
            'pickup_datetime',
            'dropoff_datetime',
            'passenger_count',
            'trip_distance',
            'fare_amount'
        ])
        writer.writerows(rows)
    
    file_size = os.path.getsize(output_path) / (1024 * 1024)  # MB
    print(f"✓ Dataset criado com sucesso!")
    print(f"  Arquivo: {output_path}")
    print(f"  Linhas: {num_rows:,}")
    print(f"  Tamanho: {file_size:.2f} MB")

if __name__ == "__main__":
    output_file = "datasets/nyc_taxi_sample.csv"
    generate_nyc_taxi_dataset(output_file)
EOF
```

**Verificar:**
```bash
ls -la scripts/generate_dataset.py
cat scripts/generate_dataset.py
```

---

## PASSO 11: Criar `datasets/README.md`

Crie o arquivo: `spark-study/datasets/README.md`

```bash
cat > datasets/README.md << 'EOF'
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
EOF
```

**Verificar:**
```bash
cat datasets/README.md
```

---

## PASSO 12: Gerar Dataset

Execute o script para gerar os dados:

```bash
# Na sua máquina local
python3 scripts/generate_dataset.py
```

**Output esperado:**
```
Gerando 100.000 linhas de dados NYC Taxi...
✓ Dataset criado com sucesso!
  Arquivo: datasets/nyc_taxi_sample.csv
  Linhas: 100.000
  Tamanho: 6.45 MB
```

**Verificar:**
```bash
ls -lh datasets/
file datasets/nyc_taxi_sample.csv
```

---

## PASSO 13: Testar Spark com Dataset

Abra Jupyter Lab em http://127.0.0.1:8888 e crie um novo notebook:

1. Create → Notebook → Python 3
2. Cole e execute:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("Test") \
    .getOrCreate()

# Ler CSV gerado pelo script
df = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv("/workspace/datasets/nyc_taxi_sample.csv")

# Teste
print(f"✓ Total de linhas: {df.count()}")
print(f"✓ Colunas: {df.columns}")
df.show(5)
```

**Output esperado:**
```
✓ Total de linhas: 100000
✓ Colunas: ['pickup_datetime', 'dropoff_datetime', 'passenger_count', 'trip_distance', 'fare_amount']
+-------------------+-------------------+---------------+-------------+-----------+
|    pickup_datetime|   dropoff_datetime|passenger_count|trip_distance|fare_amount|
+-------------------+-------------------+---------------+-------------+-----------+
|2025-03-11 09:38:00|2025-03-11 10:13:00|              6|        17.35|      44.85|
|2025-10-28 02:16:00|2025-10-28 03:13:00|              4|         3.73|      33.87|
|2025-08-01 20:56:00|2025-08-01 21:13:00|              5|         2.59|      14.44|
|2025-02-11 00:56:00|2025-02-11 01:53:00|              1|         1.64|      69.42|
|2025-08-28 07:42:00|2025-08-28 08:29:00|              3|         3.51|      76.38|
+-------------------+-------------------+---------------+-------------+-----------+
only showing top 5 rows
```

---

## PASSO 14: Primeiro Commit (Script + Documentação)

Saia do container se ainda estiver dentro:

```bash
exit
```

Commitar no Git:

```bash
# Adicionar script e documentação (CSV é ignorado por .gitignore)
git add scripts/generate_dataset.py datasets/README.md

# Commit
git commit -m "Add dataset generation script and documentation"

# Verificar status (deve estar clean)
git status

# Ver histórico
git log --oneline
```

**Resultado esperado:**
```
On branch main
nothing to commit, working tree clean
```

Isso significa:
- ✅ Script versionado (reproducível)
- ✅ Documentação versionada
- ✅ CSV gerado mas não commitado (`.gitignore`)

---

## PASSO 15: Criar `README.md` (Raiz do Projeto)

Crie o arquivo: `spark-study/README.md`

```markdown
# Spark Study - Engenheiro de Dados Pleno

Projeto de 2 meses para dominar Engenharia de Dados com Spark, AWS, Airflow e Dbt.

## Setup Rápido

### Pré-requisitos
- Docker instalado
- Docker Compose
- Git

### Iniciar

```bash
# Build (primeira vez, ~15 min)
make build

# Iniciar container
make start

# Ver token Jupyter
make logs
```

Abra http://127.0.0.1:8888 e cole o token dos logs.

### Gerar Dataset

```bash
python3 scripts/generate_dataset.py
```

### Parar

```bash
make stop
```

### Comandos Disponíveis

```bash
make help
```

## Estrutura

```
spark-study/
├── docker/              # Dockerfile
├── notebooks/           # Jupyter notebooks (seu trabalho)
├── scripts/
│   ├── generate_dataset.py  # Gera dados para prática
│   └── spark_jobs/          # Spark jobs
├── datasets/            # Dados (gerados, não versionados)
├── data/                # Outputs (não versionado)
└── docs/                # Documentação (próximo)
```

## Semanas

- **Semana 1-2:** Apache Spark
- **Semana 3-4:** AWS
- **Semana 5-6:** Airflow
- **Semana 7:** Dbt
- **Semana 8:** Data Quality + Projeto Final

## Recursos

- [Spark Docs](https://spark.apache.org/docs/latest/)
- [DataCamp](https://www.datacamp.com/)
- [Databricks Academy](https://www.databricks.com/academy/)
```

**Criar arquivo:**
```bash
cat > README.md << 'EOF'
# Spark Study - Engenheiro de Dados Pleno

Projeto de 2 meses para dominar Engenharia de Dados.

## Setup Rápido

1. Build Docker:
```bash
make build
```

2. Iniciar:
```bash
make start
make logs  # Copiar token
```

3. Gerar dataset:
```bash
python3 scripts/generate_dataset.py
```

4. Abrir Jupyter: http://127.0.0.1:8888

## Comandos

```bash
make help      # Ver todos
make start     # Iniciar
make stop      # Parar
make shell     # Entrar no container
```

## Semanas

1-2: Spark | 3-4: AWS | 5-6: Airflow | 7: Dbt | 8: Data Quality
EOF
```

---

## PASSO 16: Commit Final

```bash
git add README.md
git commit -m "Add project README"
git log --oneline
```

---

## CHECKLIST FINAL

Após seguir TODOS os passos acima:

- ✅ Pasta `spark-study/` criada com estrutura completa
- ✅ `docker/Dockerfile` criado (com eclipse-temurin)
- ✅ `docker-compose.yml` criado
- ✅ `.gitignore` criado (ignora CSV mas não README.md)
- ✅ `Makefile` criado
- ✅ `scripts/generate_dataset.py` criado e versionado
- ✅ `datasets/README.md` criado e versionado
- ✅ Git inicializado com commits
- ✅ Docker build executado (`make build`)
- ✅ Container rodando (`make start`)
- ✅ Jupyter Lab acessível em http://127.0.0.1:8888
- ✅ Dataset NYC Taxi gerado com 100k linhas
- ✅ Spark testado com sucesso
- ✅ `README.md` (raiz) criado
- ✅ Git status mostra working tree clean
- ✅ Histórico de commits limpo

---

## PRÓXIMOS PASSOS

1. **Git Remote:** (se quiser fazer backup no GitHub)
```bash
git remote add origin https://github.com/seu_usuario/spark-study.git
git push -u origin main
```

2. **Começar Semana 1:**
Ver documento: "Semana 1 Detalhada - Apache Spark"

3. **Commits Diários:**
```bash
make start
# ... trabalhar no Jupyter ...
git add .
git commit -m "Dia 1: Arquitetura Spark e RDDs"
git push
```

---

## TROUBLESHOOTING

**Dockerfile falha em build?**
Certifique-se que está usando `eclipse-temurin:17-jdk-jammy`

**Porta 8888 já em uso?**
```yaml
# docker-compose.yml - mude para 8889
ports:
  - "8889:8888"
```

**Container não inicia?**
```bash
make clean
make rebuild
make start
make logs
```

**Script generate_dataset.py não aparece no container?**
Crie o arquivo localmente (`scripts/generate_dataset.py`) no seu editor. Volumes sincronizam apenas o que existe.

**Dataset não foi gerado?**
```bash
python3 scripts/generate_dataset.py
ls -lh datasets/nyc_taxi_sample.csv
```

---

## Tempo Total de Setup

- Estrutura + arquivos: ~5 min
- Docker build: ~15 min
- Teste final: ~5 min

**Total: ~25 minutos**