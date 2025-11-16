#!/bin/bash

echo "========================================="
echo "Setting up MySQL Source and Target"
echo "========================================="

# Create table in MySQL Source
echo ""
echo "📋 Creating table in MySQL Source..."
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
DROP TABLE IF EXISTS source.nicole_paixao;
CREATE TABLE source.nicole_paixao (
  id INT AUTO_INCREMENT PRIMARY KEY,
  seller_id INT NOT NULL,
  score DECIMAL(10,2) NOT NULL,
  score_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
"

if [ $? -eq 0 ]; then
    echo "✅ Table created successfully in source"
else
    echo "❌ Failed to create table in source"
    exit 1
fi

# Create table in MySQL Target
echo ""
echo "📋 Creating table in MySQL Target..."
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
DROP TABLE IF EXISTS targetdb.nicole_paixao;
CREATE TABLE targetdb.nicole_paixao (
  id INT AUTO_INCREMENT PRIMARY KEY,
  seller_id INT NOT NULL,
  score DECIMAL(10,2) NOT NULL,
  score_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
"

if [ $? -eq 0 ]; then
    echo "✅ Table created successfully in target"
else
    echo "❌ Failed to create table in target"
    exit 1
fi

# Grant permissions for Debezium Source (read_user)
echo ""
echo "🔐 Granting permissions for Debezium Source (read_user)..."
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT 
ON *.* TO 'read_user'@'%';
FLUSH PRIVILEGES;
"

if [ $? -eq 0 ]; then
    echo "✅ Permissions granted successfully for read_user"
else
    echo "❌ Failed to grant permissions for read_user"
    exit 1
fi

# Grant permissions for JDBC Sink (dbadmin)
echo ""
echo "🔐 Granting permissions for JDBC Sink (dbadmin)..."
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
GRANT ALL PRIVILEGES ON targetdb.* TO 'dbadmin'@'%';
FLUSH PRIVILEGES;
"

if [ $? -eq 0 ]; then
    echo "✅ Permissions granted successfully for dbadmin"
else
    echo "❌ Failed to grant permissions for dbadmin"
    exit 1
fi

# Validate initial counts (should be 0/0)
echo ""
echo "📊 Validating initial counts..."
SOURCE_COUNT=$(docker exec -it mysql-source mysql -uroot -prootpass1234 -se "SELECT COUNT(*) FROM source.nicole_paixao;")
TARGET_COUNT=$(docker exec -it mysql-target mysql -uroot -ptargetroot1234 -se "SELECT COUNT(*) FROM targetdb.nicole_paixao;")

echo "Source records: $SOURCE_COUNT"
echo "Target records: $TARGET_COUNT"

echo ""
echo "========================================="
echo "✅ Database setup completed successfully!"
echo "========================================="