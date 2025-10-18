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
	@echo "  make start              Start container (docker compose up -d)"
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
	docker compose build
	@echo "$(GREEN)✓ Build completo$(NC)"

rebuild:
	@echo "$(BLUE)Rebuilding (sem cache)...$(NC)"
	docker compose build --no-cache
	@echo "$(GREEN)✓ Rebuild completo$(NC)"

start:
	@echo "$(BLUE)Starting container...$(NC)"
	docker compose up -d
	@sleep 3
	@echo "$(GREEN)✓ Container iniciado$(NC)"
	@echo "$(YELLOW)Jupyter Lab: http://127.0.0.1:8888$(NC)"
	@echo "$(YELLOW)Spark UI: http://127.0.0.1:4040$(NC)"
	@echo ""
	@echo "$(BLUE)Token Jupyter (copie e cole no navegador):$(NC)"
	@docker compose logs spark-jupyter | grep token | tail -1

stop:
	@echo "$(BLUE)Stopping container...$(NC)"
	docker compose down
	@echo "$(GREEN)✓ Container parado$(NC)"

restart: stop start
	@echo "$(GREEN)✓ Container reiniciado$(NC)"

logs:
	@docker compose logs -f spark-jupyter

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
	docker compose down
	@echo "$(GREEN)✓ Limpeza completa$(NC)"

clean-all: clean
	@echo "$(RED)Removendo TUDO (including datasets)...$(NC)"
	docker compose down -v
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
	@docker compose --version
	@echo ""
	@echo "Container:"
	@docker ps -a | grep $(CONTAINER_NAME) || echo "Não rodando"