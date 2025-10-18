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
