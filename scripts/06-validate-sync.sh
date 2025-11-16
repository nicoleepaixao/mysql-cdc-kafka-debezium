#!/bin/bash

echo "========================================="
echo "Creating Debezium JDBC Sink Connector"
echo "========================================="

echo ""
echo "🔌 Creating JDBC Sink Connector (Debezium)..."

RESPONSE=$(curl -s -X POST http://localhost:8083/connectors \
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
  }')

# Check if connector was created successfully
if echo "$RESPONSE" | grep -q "jdbc-sink-nicole-paixao"; then
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
STATUS=$(curl -s http://localhost:8083/connectors/jdbc-sink-nicole-paixao/status)

CONNECTOR_STATE=$(echo $STATUS | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
TASK_STATE=$(echo $STATUS | grep -o '"state":"[^"]*"' | tail -1 | cut -d'"' -f4)

echo "Connector State: $CONNECTOR_STATE"
echo "Task State: $TASK_STATE"

if [ "$CONNECTOR_STATE" == "RUNNING" ] && [ "$TASK_STATE" == "RUNNING" ]; then
    echo ""
    echo "========================================="
    echo "✅ Sink Connector is RUNNING!"
    echo "Data is now being synchronized to MySQL Target"
    echo "========================================="
else
    echo ""
    echo "⚠️  Warning: Connector or task is not running"
    echo "Full status:"
    echo "$STATUS" | jq '.'
    exit 1
fi

# Wait a bit for initial snapshot to complete
echo ""
echo "⏳ Waiting 10 seconds for snapshot to complete..."
sleep 10

# Quick validation
echo ""
echo "📊 Quick validation..."
SOURCE_COUNT=$(docker exec -it mysql-source mysql -uroot -prootpass1234 -se "SELECT COUNT(*) FROM source.nicole_paixao;")
TARGET_COUNT=$(docker exec -it mysql-target mysql -uroot -ptargetroot1234 -se "SELECT COUNT(*) FROM targetdb.nicole_paixao;")

echo "Source records: $SOURCE_COUNT"
echo "Target records: $TARGET_COUNT"

if [ "$SOURCE_COUNT" == "$TARGET_COUNT" ]; then
    echo ""
    echo "✅ Snapshot completed! Databases are synchronized!"
else
    echo ""
    echo "⚠️  Databases not yet synchronized. Wait a few more seconds and check again."
fi