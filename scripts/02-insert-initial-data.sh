#!/bin/bash

echo "========================================="
echo "Inserting Initial Data (3 records)"
echo "========================================="

# Insert 3 records in MySQL Source
echo ""
echo "📝 Inserting 3 records into MySQL Source..."
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
USE source;
INSERT INTO nicole_paixao (seller_id, score, score_date)
VALUES
  (11111, 80.50, '2025-01-01'),
  (22222, 90.00, '2025-01-02'),
  (33333, 75.25, '2025-01-03');
"

if [ $? -eq 0 ]; then
    echo "✅ Records inserted successfully in source"
else
    echo "❌ Failed to insert records in source"
    exit 1
fi

# Insert 3 records in MySQL Target (simulates backup restore)
echo ""
echo "📝 Inserting 3 records into MySQL Target (simulates backup)..."
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
USE targetdb;
INSERT INTO nicole_paixao (seller_id, score, score_date)
VALUES
  (11111, 80.50, '2025-01-01'),
  (22222, 90.00, '2025-01-02'),
  (33333, 75.25, '2025-01-03');
"

if [ $? -eq 0 ]; then
    echo "✅ Records inserted successfully in target"
else
    echo "❌ Failed to insert records in target"
    exit 1
fi

# Validate counts (should be 3/3)
echo ""
echo "📊 Validating record counts..."
SOURCE_COUNT=$(docker exec -it mysql-source mysql -uroot -prootpass1234 -se "SELECT COUNT(*) FROM source.nicole_paixao;")
TARGET_COUNT=$(docker exec -it mysql-target mysql -uroot -ptargetroot1234 -se "SELECT COUNT(*) FROM targetdb.nicole_paixao;")

echo "Source records: $SOURCE_COUNT"
echo "Target records: $TARGET_COUNT"

if [ "$SOURCE_COUNT" == "3" ] && [ "$TARGET_COUNT" == "3" ]; then
    echo ""
    echo "========================================="
    echo "✅ Initial data inserted successfully!"
    echo "Both databases have 3 identical records"
    echo "========================================="
else
    echo ""
    echo "⚠️  Warning: Expected 3 records in both databases"
    exit 1
fi