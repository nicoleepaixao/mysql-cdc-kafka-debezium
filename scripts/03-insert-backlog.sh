#!/bin/bash

echo "========================================="
echo "Inserting Backlog Data (2 records)"
echo "========================================="

echo ""
echo "📝 Inserting 2 additional records ONLY in MySQL Source..."
echo "(This simulates new data after the backup)"

docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
USE source;
INSERT INTO nicole_paixao (seller_id, score, score_date)
VALUES
  (44444, 88.80, '2025-02-01'),
  (55555, 77.77, '2025-02-02');
"

if [ $? -eq 0 ]; then
    echo "✅ Backlog records inserted successfully in source"
else
    echo "❌ Failed to insert backlog records in source"
    exit 1
fi

# Validate counts (should be 5/3)
echo ""
echo "📊 Validating record counts..."
SOURCE_COUNT=$(docker exec -it mysql-source mysql -uroot -prootpass1234 -se "SELECT COUNT(*) FROM source.nicole_paixao;")
TARGET_COUNT=$(docker exec -it mysql-target mysql -uroot -ptargetroot1234 -se "SELECT COUNT(*) FROM targetdb.nicole_paixao;")

echo "Source records: $SOURCE_COUNT"
echo "Target records: $TARGET_COUNT"

if [ "$SOURCE_COUNT" == "5" ] && [ "$TARGET_COUNT" == "3" ]; then
    echo ""
    echo "========================================="
    echo "✅ Backlog data inserted successfully!"
    echo "Source: 5 records | Target: 3 records"
    echo "Ready to test CDC connectors!"
    echo "========================================="
else
    echo ""
    echo "⚠️  Warning: Expected 5 records in source and 3 in target"
    exit 1
fi