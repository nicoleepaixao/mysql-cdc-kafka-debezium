#!/bin/bash

echo "========================================="
echo "Creating Debezium Source Connector"
echo "========================================="

echo ""
echo "🔌 Creating MySQL Source Connector (Debezium)..."

RESPONSE=$(curl -s -X POST http://localhost:8083/connectors \
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
  }')

# Check if connector was created successfully
if echo "$RESPONSE" | grep -q "mysql-source-nicole-paixao-v3"; then
    echo "✅ Connector created successfully"
else
    echo "❌ Failed to create connector"
    echo "Response: $RESPONSE"
    exit 1
fi

# Wait a few seconds for connector to initialize
echo ""
echo "⏳ Waiting 5 seconds for connector to initialize..."
sleep 5

# Check connector status
echo ""
echo "📊 Checking connector status..."
STATUS=$(curl -s http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/status)

CONNECTOR_STATE=$(echo $STATUS | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
TASK_STATE=$(echo $STATUS | grep -o '"state":"[^"]*"' | tail -1 | cut -d'"' -f4)

echo "Connector State: $CONNECTOR_STATE"
echo "Task State: $TASK_STATE"

if [ "$CONNECTOR_STATE" == "RUNNING" ] && [ "$TASK_STATE" == "RUNNING" ]; then
    echo ""
    echo "========================================="
    echo "✅ Source Connector is RUNNING!"
    echo "Debezium is now capturing changes from MySQL"
    echo "========================================="
else
    echo ""
    echo "⚠️  Warning: Connector or task is not running"
    echo "Full status:"
    echo "$STATUS" | jq '.'
    exit 1
fi

# Show Kafka topics
echo ""
echo "📋 Kafka topics created:"
docker exec -it kafka kafka-topics --bootstrap-server kafka:9092 --list | grep -E "(localtest|schema-changes)"