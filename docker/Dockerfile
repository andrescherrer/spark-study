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