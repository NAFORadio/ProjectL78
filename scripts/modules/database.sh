#!/bin/bash
# Database initialization module

source "$(dirname "$0")/../common/utils.sh"

initialize_databases() {
    log_message "Initializing databases..."
    
    # Install database packages
    apt-get install -y \
        postgresql \
        postgresql-contrib \
        timescaledb-postgresql-13 \
        redis-server
    
    # Configure PostgreSQL
    setup_postgresql
    
    # Configure TimescaleDB
    setup_timescaledb
    
    # Setup Redis
    setup_redis
    
    # Create application databases
    create_application_databases
    
    log_message "${GREEN}Database initialization complete${NC}"
}

setup_postgresql() {
    # Configure PostgreSQL for better performance
    cat >> /etc/postgresql/13/main/postgresql.conf << EOF
# Memory Configuration
shared_buffers = '1GB'
effective_cache_size = '3GB'
maintenance_work_mem = '256MB'
work_mem = '64MB'

# Write Ahead Log
wal_buffers = '16MB'
checkpoint_completion_target = 0.9
max_wal_size = '1GB'
min_wal_size = '80MB'

# Query Planning
random_page_cost = 1.1
effective_io_concurrency = 200

# Parallel Query
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_parallel_maintenance_workers = 4
EOF

    systemctl restart postgresql
}

setup_timescaledb() {
    # Enable TimescaleDB
    cat >> /etc/postgresql/13/main/postgresql.conf << EOF
shared_preload_libraries = 'timescaledb'
EOF

    systemctl restart postgresql
}

setup_redis() {
    # Configure Redis for better persistence
    cat >> /etc/redis/redis.conf << EOF
maxmemory 1gb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
EOF

    systemctl restart redis
}

create_application_databases() {
    # Create databases and users
    sudo -u postgres psql << EOF
CREATE DATABASE nafo_radio;
CREATE USER nafo_admin WITH ENCRYPTED PASSWORD 'secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE nafo_radio TO nafo_admin;

\c nafo_radio

-- Create sensor data table
CREATE TABLE sensor_data (
    time        TIMESTAMPTZ NOT NULL,
    sensor_id   TEXT NOT NULL,
    type        TEXT NOT NULL,
    value       DOUBLE PRECISION NOT NULL
);

-- Convert to TimescaleDB hypertable
SELECT create_hypertable('sensor_data', 'time');

-- Create radio logs table
CREATE TABLE radio_logs (
    time        TIMESTAMPTZ NOT NULL,
    frequency   DOUBLE PRECISION NOT NULL,
    mode        TEXT NOT NULL,
    signal      INTEGER,
    message     TEXT
);

SELECT create_hypertable('radio_logs', 'time');

-- Create inventory table
CREATE TABLE inventory (
    id          SERIAL PRIMARY KEY,
    item_name   TEXT NOT NULL,
    category    TEXT NOT NULL,
    quantity    INTEGER NOT NULL,
    location    TEXT,
    last_check  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
EOF
} 