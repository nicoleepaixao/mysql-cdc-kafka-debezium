# MySQL CDC Replication with Kafka + Debezium

## The Problem

When restoring a MySQL database from a backup, we need to ensure that CDC (Change Data Capture) replication:
- ✅ Captures **only new records** inserted after the backup
- ✅ Does **NOT duplicate** existing records in the destination
- ✅ Synchronizes correctly from the backup point

Manually validating this behavior is time-consuming and error-prone. This project automates the setup and validates the entire CDC flow locally.

## How It Works

Using Docker Compose, this project provisions:
- **MySQL Source** with binlog enabled for CDC
- **MySQL Target** simulating the restored backup
- **Kafka + Zookeeper** for event streaming
- **Debezium Source Connector** to capture changes from MySQL binlog
- **Debezium JDBC Sink Connector** to replicate changes to target database

The validation flow:
1. Both databases start with 3 identical records (simulates post-backup state)
2. 2 additional records are inserted only in source (simulates new data)
3. Connectors are activated
4. **Expected result**: Target should have 5 records total, with no duplicates

## Architecture

```
┌─────────────────┐      ┌─────────────┐      ┌──────────────────┐
│  mysql-source   │─────▶│    Kafka    │─────▶│  mysql-target    │
│  (porta 3307)   │      │  + Connect  │      │  (porta 3308)    │
│                 │      │             │      │                  │
│  DB: source     │      │  Debezium   │      │  DB: targetdb    │
│  Tabela:        │      │     CDC     │      │  Tabela:         │
│  nicole_paixao  │      │             │      │  nicole_paixao   │
└─────────────────┘      └─────────────┘      └──────────────────┘
```

## Structure

```
.
├── docker-compose.yml           # Complete infrastructure setup
├── connect-plugins/             # MySQL JDBC driver for Confluent sink (optional)
│   └── mysql-connector-j-8.0.33.jar
├── dumps/                       # Shared volume for database dumps
└── scripts/                     # Helper scripts for setup and validation
    ├── 01-setup-databases.sh    # Create tables and permissions
    ├── 02-insert-initial-data.sh # Insert initial 3 records
    ├── 03-insert-backlog.sh     # Insert 2 additional records in source
    ├── 04-create-source-connector.sh
    ├── 05-create-sink-connector.sh
    └── 06-validate-sync.sh      # Check record counts
```

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/nicoleepaixao/mysql-cdc-kafka-debezium.git
cd mysql-cdc-kafka-debezium
```

### 2. Download MySQL JDBC driver (optional, for Confluent sink tests)

```bash
mkdir -p connect-plugins
curl -L -o connect-plugins/mysql-connector-j-8.0.33.jar \
  https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/mysql-connector-j-8.0.33.jar
```

### 3. Start the infrastructure

```bash
docker-compose up -d

# Wait for all services to be healthy (~30 seconds)
docker-compose ps
```

### 4. Setup databases and tables

```bash
# Create tables in source
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
CREATE TABLE source.nicole_paixao (
  id INT AUTO_INCREMENT PRIMARY KEY,
  seller_id INT NOT NULL,
  score DECIMAL(10,2) NOT NULL,
  score_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
"

# Create tables in target
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
CREATE TABLE targetdb.nicole_paixao (
  id INT AUTO_INCREMENT PRIMARY KEY,
  seller_id INT NOT NULL,
  score DECIMAL(10,2) NOT NULL,
  score_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
"

# Grant permissions for Debezium source
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT 
ON *.* TO 'read_user'@'%';
FLUSH PRIVILEGES;
"

# Grant permissions for JDBC sink
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
GRANT ALL PRIVILEGES ON targetdb.* TO 'dbadmin'@'%';
FLUSH PRIVILEGES;
"
```

### 5. Insert initial data (3 records in both databases)

```bash
# Source
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
INSERT INTO source.nicole_paixao (seller_id, score, score_date)
VALUES
  (11111, 80.50, '2025-01-01'),
  (22222, 90.00, '2025-01-02'),
  (33333, 75.25, '2025-01-03');
"

# Target (simulates backup restore)
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
INSERT INTO targetdb.nicole_paixao (seller_id, score, score_date)
VALUES
  (11111, 80.50, '2025-01-01'),
  (22222, 90.00, '2025-01-02'),
  (33333, 75.25, '2025-01-03');
"
```

### 6. Insert backlog data (2 records only in source)

```bash
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
INSERT INTO source.nicole_paixao (seller_id, score, score_date)
VALUES
  (44444, 88.80, '2025-02-01'),
  (55555, 77.77, '2025-02-02');
"

# Validate state before CDC
# Source: 5 records | Target: 3 records
```

### 7. Create Debezium Source Connector

```bash
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "mysql-source-nicole-paixao-v3",
    "config": {
      "connector.class": "io.debezium.connector.mysql.MySqlConnector",
      "database.hostname": "mysql-source",
      "database.port": "3306",
      "database.user": "read_user",
      "database.password": "readpass1234",
      "database.server.id": "888",
      "topic.prefix": "localtest",
      "database.include.list": "source",
      "table.include.list": "source.nicole_paixao",
      "snapshot.mode": "initial",
      "include.schema.changes": "false",
      "database.allowPublicKeyRetrieval": "true",
      "schema.history.internal.kafka.bootstrap.servers": "kafka:9092",
      "schema.history.internal.kafka.topic": "schema-changes.nicole_paixao_v3",
      "key.converter": "org.apache.kafka.connect.json.JsonConverter",
      "key.converter.schemas.enable": "true",
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter.schemas.enable": "true"
    }
  }'

# Check status
curl http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/status
```

### 8. Create Debezium JDBC Sink Connector

```bash
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jdbc-sink-nicole-paixao",
    "config": {
      "connector.class": "io.debezium.connector.jdbc.JdbcSinkConnector",
      "tasks.max": "1",
      "topics": "localtest.source.nicole_paixao",
      "connection.url": "jdbc:mysql://mysql-target:3306/targetdb?useSSL=false&allowPublicKeyRetrieval=true",
      "connection.username": "dbadmin",
      "connection.password": "targetpass1234",
      "database.type": "mysql",
      "insert.mode": "upsert",
      "delete.enabled": "true",
      "primary.key.mode": "record_key",
      "primary.key.fields": "id",
      "schema.evolution": "basic",
      "table.name.format": "nicole_paixao"
    }
  }'

# Check status
curl http://localhost:8083/connectors/jdbc-sink-nicole-paixao/status
```

### 9. Validate synchronization

```bash
# Check target count (should be 5 now)
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
SELECT COUNT(*) AS total_target FROM targetdb.nicole_paixao;
"

# View all records
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
SELECT * FROM targetdb.nicole_paixao ORDER BY id;
"
```

**Expected result:** 5 records in target (3 initial + 2 from backlog), no duplicates ✅

### 10. Test real-time CDC

```bash
# Insert new record in source
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
INSERT INTO source.nicole_paixao (seller_id, score, score_date)
VALUES (66666, 99.99, '2025-03-10');
"

# Validate in target (should show 6 records immediately)
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
SELECT COUNT(*) AS total_target FROM targetdb.nicole_paixao;
"
```

**Expected result:** 6 records in target ✅

## Common Issues & Solutions

### Error 1: `The db history topic is missing`

**Cause:** Schema history topic was deleted or is inconsistent.

**Solution:** Use a new history topic name:
```json
"schema.history.internal.kafka.topic": "schema-changes.nicole_paixao_v3"
```

### Error 2: `Data truncation: Incorrect date value: '20091'`

**Cause:** Confluent JDBC Sink doesn't understand `io.debezium.time.Date` logical type.

**Solution:** Use Debezium JDBC Sink instead:
```json
"connector.class": "io.debezium.connector.jdbc.JdbcSinkConnector",
"database.type": "mysql"
```

### Error 3: `Error configuring JdbcSinkConnectorConfig`

**Cause:** Missing required configuration or wrong property names.

**Solution:** Ensure these properties are set:
```json
"database.type": "mysql",
"connection.username": "dbadmin"  // not connection.user
```

## Key Configuration Differences

| Property | Confluent JDBC Sink | Debezium JDBC Sink |
|----------|---------------------|-------------------|
| Connector class | `io.confluent.connect.jdbc.JdbcSinkConnector` | `io.debezium.connector.jdbc.JdbcSinkConnector` |
| Username field | `connection.user` | `connection.username` |
| Required field | - | `database.type` |
| DATE conversion | ❌ Fails with `io.debezium.time.Date` | ✅ Converts correctly |
| Best for | Non-Debezium sources | Debezium sources |

## Useful Commands

### Connector management
```bash
# List all connectors
curl http://localhost:8083/connectors

# Get connector status
curl http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/status

# Delete connector
curl -X DELETE http://localhost:8083/connectors/mysql-source-nicole-paixao-v3

# Restart connector
curl -X POST http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/restart
```

### Kafka topic management
```bash
# List topics
docker exec -it kafka kafka-topics --bootstrap-server kafka:9092 --list

# Consume messages
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic localtest.source.nicole_paixao \
  --from-beginning

# Delete topic
docker exec -it kafka kafka-topics --bootstrap-server kafka:9092 \
  --delete --topic localtest.source.nicole_paixao
```

### Complete cleanup
```bash
# Remove all containers and volumes
docker-compose down -v

# Restart from scratch
docker-compose up -d
```

## Technologies Used

- **Docker Compose** - Container orchestration
- **MySQL 8.0** - Source and target databases
- **Apache Kafka** - Event streaming platform
- **Debezium 2.6** - CDC platform
- **Kafka Connect** - Connector framework

## Validation Results

| Metric | Source | Target | Status |
|--------|--------|--------|--------|
| Initial records | 3 | 3 | ⚠️ Pre-sync |
| After backlog insert | 5 | 3 | ⚠️ Pre-CDC |
| After connectors start | 5 | 5 | ✅ Synchronized |
| After real-time insert | 6 | 6 | ✅ Synchronized |

## Full Article on Medium

For complete details about the problems encountered and how everything was solved, check out the article on Medium:

**[Replicação CDC de MySQL para MySQL usando Kafka + Debezium: da frustração à solução](https://nicoleepaixao.medium.com/replicação-cdc-de-mysql-para-mysql-usando-kafka-debezium-da-frustração-à-solução-de6d2fb2a3eb)**

## References

- [Debezium MySQL Connector](https://debezium.io/documentation/reference/stable/connectors/mysql.html)
- [Debezium JDBC Sink](https://debezium.io/documentation/reference/stable/connectors/jdbc.html)
- [Kafka Connect](https://kafka.apache.org/documentation/#connect)
- [MySQL Binlog](https://dev.mysql.com/doc/refman/8.0/en/binary-log.html)

## License

MIT License