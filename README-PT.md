<div align="center">
  
![MySQL CDC](https://img.icons8.com/color/96/mysql-logo.png)
![Apache Kafka](https://img.icons8.com/?size=96&id=fOhLNqGJsUbJ&format=png)

# Pipeline Completo de Change Data Capture com Zero Duplicatas

**Atualizado: 14 de Janeiro de 2026**

[![Follow @nicoleepaixao](https://img.shields.io/github/followers/nicoleepaixao?label=Follow&style=social)](https://github.com/nicoleepaixao)
[![Star this repo](https://img.shields.io/github/stars/nicoleepaixao/mysql-cdc-kafka-debezium?style=social)](https://github.com/nicoleepaixao/mysql-cdc-kafka-debezium)
[![Medium Article](https://img.shields.io/badge/Medium-12100E?style=for-the-badge&logo=medium&logoColor=white)](https://nicoleepaixao.medium.com/replicação-cdc-de-mysql-para-mysql-usando-kafka-debezium-da-frustração-à-solução-de6d2fb2a3eb)

<p align="center">
  <a href="README-PT.md">🇧🇷</a>
  <a href="README.md">🇺🇸</a>
</p>

</div>

---

<p align="center">
  <img src="img/mysql-cdc-kafka-debezium.png" alt="CDC Architecture" width="1200">
</p>

## **Visão Geral**

Este projeto implementa um pipeline automatizado de Change Data Capture (CDC) para replicação MySQL usando Kafka e Debezium. A solução aborda um desafio crítico: garantir que a replicação CDC capture apenas novos registros após a restauração de backup do banco de dados sem duplicar dados existentes. Toda a configuração roda localmente via Docker Compose, permitindo validação e testes rápidos de configurações CDC.

---

## **O Problema**

Ao restaurar um banco de dados MySQL de um backup, a replicação CDC deve:

| **Requisito** | **Desafio** |
|-----------------|---------------|
| **Capturar apenas novos registros** | Evitar reprocessamento de dados históricos já no backup |
| **Prevenir duplicatas** | Garantir que o destino não receba inserções duplicadas |
| **Sincronizar do ponto de backup** | Iniciar CDC do timestamp exato do backup |
| **Validar automaticamente** | Validação manual é demorada e propensa a erros |

### **Cenário do Mundo Real**

```text
Backup do Banco de Dados de Produção (3 registros) → Restaurar no Destino
    ↓
Novas transações ocorrem (2 registros)
    ↓
CDC deve capturar APENAS esses 2 novos registros
    ↓
Destino deve ter: 3 (backup) + 2 (novos) = 5 registros total
```

### **Por Que Isso Importa**

✅ **Integridade de Dados**: Previne registros duplicados no banco de dados de destino  
✅ **Eficiência de Recursos**: Evita processamento e armazenamento desnecessários de dados  
✅ **Confiança Operacional**: Validação automatizada reduz erro humano  
✅ **Velocidade de Desenvolvimento**: Testes locais permitem iteração rápida  
✅ **Prontidão para Produção**: Valida comportamento CDC antes do deployment em produção

---

## **Como Funciona**

### **Fluxo de Validação**

O projeto automatiza um cenário completo de validação CDC:

| **Estágio** | **Registros Origem** | **Registros Destino** | **Status** |
|-----------|-------------------|-------------------|------------|
| **1. Estado Inicial** | 3 | 3 | Ambos bancos idênticos (pós-backup) |
| **2. Inserção de Backlog** | 5 | 3 | 2 novos registros apenas na origem |
| **3. Ativação CDC** | 5 | 5 | Conectores replicam registros faltantes |
| **4. Teste Tempo Real** | 6 | 6 | Nova inserção propaga imediatamente |

### **Componentes Principais**

| **Componente** | **Propósito** | **Configuração** |
|---------------|-------------|-------------------|
| **MySQL Origem** | Banco similar à produção com binlog | Porta 3307, binlog_format=ROW |
| **MySQL Destino** | Simula destino de backup restaurado | Porta 3308, config padrão |
| **Apache Kafka** | Plataforma de streaming de eventos | Broker único, auto-criação de tópicos |
| **Zookeeper** | Coordenação do cluster Kafka | Requerido para Kafka 2.x |
| **Debezium Source** | Captura mudanças do binlog MySQL | Modo snapshot: initial |
| **Debezium Sink** | Escreve mudanças no banco de destino | Modo insert: upsert |

### **Estratégia de Captura CDC**

```text
Comportamento do Conector Debezium Source:
├── snapshot.mode: initial
│   ├── Faz snapshot inicial dos dados existentes
│   ├── Publica snapshot no tópico Kafka
│   └── Depois muda para streaming binlog
├── Rastreamento de Posição do Binlog
│   ├── Armazena posição no tópico Kafka
│   ├── Retoma da última posição ao reiniciar
│   └── Garante entrega exactly-once
└── Evolução de Schema
    ├── Captura mudanças DDL
    ├── Armazena em tópico de histórico de schema
    └── Permite sink adaptar automaticamente
```

---

## **Estrutura do Projeto**

```text
mysql-cdc-kafka-debezium/
│
├── README.md                          # Documentação completa
│
├── docker-compose.yml                 # Orquestração da infraestrutura
│   ├── mysql-source (3307)
│   ├── mysql-target (3308)
│   ├── zookeeper (2181)
│   ├── kafka (9092)
│   └── kafka-connect (8083)
│
├── connect-plugins/                   # Dependências do conector
│   └── mysql-connector-j-8.0.33.jar  # Driver JDBC para sink
│
├── dumps/                            # Volume compartilhado para backups
│
└── scripts/                          # Scripts de automação
    ├── 01-setup-databases.sh         # Criar tabelas e usuários
    ├── 02-insert-initial-data.sh     # Inserir 3 registros base
    ├── 03-insert-backlog.sh          # Inserir 2 registros adicionais
    ├── 04-create-source-connector.sh # Configurar Debezium source
    ├── 05-create-sink-connector.sh   # Configurar Debezium sink
    └── 06-validate-sync.sh           # Verificar contagens de registros
```

---

## **Início Rápido**

### **Pré-requisitos**

| **Requisito** | **Versão** | **Propósito** |
|-----------------|-------------|-------------|
| Docker | 20.10+ | Runtime de container |
| Docker Compose | 2.0+ | Orquestração multi-container |
| curl | Qualquer | Interação com API REST |
| 8GB RAM | Mínimo | Executar todos os serviços localmente |

### **1. Clonar Repositório**

```bash
git clone https://github.com/nicoleepaixao/mysql-cdc-kafka-debezium.git
cd mysql-cdc-kafka-debezium
```

### **2. Baixar Driver JDBC (Opcional)**

```bash
mkdir -p connect-plugins
curl -L -o connect-plugins/mysql-connector-j-8.0.33.jar \
  https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/mysql-connector-j-8.0.33.jar
```

**Nota:** Necessário apenas para testes com Confluent JDBC Sink. Debezium JDBC Sink tem driver embutido.

### **3. Iniciar Infraestrutura**

```bash
# Iniciar todos os serviços
docker-compose up -d

# Verificar saúde dos serviços (aguardar ~30 segundos)
docker-compose ps

# Saída esperada: Todos os serviços "Up" ou "healthy"
```

### **4. Configurar Bancos de Dados e Permissões**

```bash
# Criar tabela origem
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

# Criar tabela destino
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

# Conceder permissões CDC (origem)
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT 
ON *.* TO 'read_user'@'%';
FLUSH PRIVILEGES;
"

# Conceder permissões de escrita (destino)
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
GRANT ALL PRIVILEGES ON targetdb.* TO 'dbadmin'@'%';
FLUSH PRIVILEGES;
"
```

### **5. Inserir Dataset Inicial**

```bash
# Inserir 3 registros na origem (simula dados de produção)
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
INSERT INTO source.nicole_paixao (seller_id, score, score_date)
VALUES
  (11111, 80.50, '2025-01-01'),
  (22222, 90.00, '2025-01-02'),
  (33333, 75.25, '2025-01-03');
"

# Inserir mesmos 3 registros no destino (simula restauração de backup)
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
INSERT INTO targetdb.nicole_paixao (seller_id, score, score_date)
VALUES
  (11111, 80.50, '2025-01-01'),
  (22222, 90.00, '2025-01-02'),
  (33333, 75.25, '2025-01-03');
"

# Verificar estado inicial
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
SELECT COUNT(*) AS source_count FROM source.nicole_paixao;"

docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
SELECT COUNT(*) AS target_count FROM targetdb.nicole_paixao;"
```

**Resultado esperado:** Ambos bancos têm 3 registros ✅

### **6. Criar Backlog (Novas Transações)**

```bash
# Inserir 2 registros adicionais APENAS na origem
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
INSERT INTO source.nicole_paixao (seller_id, score, score_date)
VALUES
  (44444, 88.80, '2025-02-01'),
  (55555, 77.77, '2025-02-02');
"

# Verificar estado pré-CDC
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
SELECT COUNT(*) AS source_count FROM source.nicole_paixao;"
# Saída: 5 registros

docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
SELECT COUNT(*) AS target_count FROM targetdb.nicole_paixao;"
# Saída: 3 registros (inalterado)
```

**Estado esperado:** Origem = 5, Destino = 3 ✅

### **7. Ativar Conector CDC Source**

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

# Verificar status do conector
curl http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/status | jq
```

**Saída esperada:** `"state": "RUNNING"` ✅

### **8. Ativar Conector CDC Sink**

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

# Verificar status do conector
curl http://localhost:8083/connectors/jdbc-sink-nicole-paixao/status | jq
```

**Saída esperada:** `"state": "RUNNING"` ✅

### **9. Validar Sincronização**

```bash
# Aguardar 5-10 segundos para processamento CDC
sleep 10

# Verificar contagem de registros no destino
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
SELECT COUNT(*) AS total_records FROM targetdb.nicole_paixao;
"
# Esperado: 5 registros

# Ver todos os registros para verificar ausência de duplicatas
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
SELECT id, seller_id, score, score_date 
FROM targetdb.nicole_paixao 
ORDER BY id;
"
```

**Resultado esperado:** 5 registros únicos (3 iniciais + 2 backlog), sem duplicatas ✅

### **10. Testar Replicação em Tempo Real**

```bash
# Inserir novo registro na origem
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
INSERT INTO source.nicole_paixao (seller_id, score, score_date)
VALUES (66666, 99.99, '2025-03-10');
"

# Verificar propagação imediata (aguardar 2-3 segundos)
sleep 3

docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
SELECT COUNT(*) AS total_records FROM targetdb.nicole_paixao;
"
# Esperado: 6 registros

# Ver último registro
docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
SELECT * FROM targetdb.nicole_paixao WHERE seller_id = 66666;
"
```

**Resultado esperado:** Novo registro aparece no destino em segundos ✅

---

## **Entendendo os Resultados**

### **Linha do Tempo de Validação**

| **Estágio** | **Contagem Origem** | **Contagem Destino** | **Delta** | **Status** |
|-----------|-----------------|-----------------|-----------|------------|
| Setup inicial | 3 | 3 | 0 | ⚠️ Baseline pré-sync |
| Após inserção backlog | 5 | 3 | 2 | ⚠️ Replicação necessária |
| Após ativação CDC | 5 | 5 | 0 | ✅ Sincronizado |
| Após inserção tempo real | 6 | 6 | 0 | ✅ Streaming ativo |

### **Dados Esperados no Destino**

```sql
-- Resultados da consulta após sincronização CDC
mysql> SELECT * FROM targetdb.nicole_paixao ORDER BY id;
+----+-----------+-------+------------+---------------------+---------------------+
| id | seller_id | score | score_date | created_at          | updated_at          |
+----+-----------+-------+------------+---------------------+---------------------+
|  1 |     11111 | 80.50 | 2025-01-01 | 2025-01-02 10:00:00 | 2025-01-02 10:00:00 |
|  2 |     22222 | 90.00 | 2025-01-02 | 2025-01-02 10:00:00 | 2025-01-02 10:00:00 |
|  3 |     33333 | 75.25 | 2025-01-03 | 2025-01-02 10:00:00 | 2025-01-02 10:00:00 |
|  4 |     44444 | 88.80 | 2025-02-01 | 2025-01-02 10:05:00 | 2025-01-02 10:05:00 |
|  5 |     55555 | 77.77 | 2025-02-02 | 2025-01-02 10:05:00 | 2025-01-02 10:05:00 |
+----+-----------+-------+------------+---------------------+---------------------+
5 rows in set (0.00 sec)
```

### **Checklist de Verificação**

- ✅ Sem registros duplicados (verificar unicidade de `id`)
- ✅ Todos os 5 registros presentes (3 iniciais + 2 backlog)
- ✅ Timestamps preservados corretamente
- ✅ Chaves primárias sequenciais (1-5)
- ✅ Valores de dados coincidem exatamente com origem

---

## **Problemas Comuns e Soluções**

### **Problema 1: Tópico de Histórico de Schema Faltando**

**Sintomas:**
```text
ERROR: The db history topic is missing. 
You may attempt to recover it by reconfiguring the connector...
```

**Causa Raiz:** Tópico de histórico de schema foi deletado ou ficou inconsistente entre reinícios do conector.

**Solução:**
```bash
# Deletar conector antigo
curl -X DELETE http://localhost:8083/connectors/mysql-source-nicole-paixao-v3

# Usar novo nome de tópico de histórico de schema
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "mysql-source-nicole-paixao-v4",
    "config": {
      "schema.history.internal.kafka.topic": "schema-changes.nicole_paixao_v4",
      ...
    }
  }'
```

### **Problema 2: Erros de Conversão de Data**

**Sintomas:**
```text
ERROR: Data truncation: Incorrect date value: '20091' for column 'score_date'
```

**Causa Raiz:** Confluent JDBC Sink não lida com o tipo lógico `io.debezium.time.Date` do Debezium.

**Solução:** Use Debezium JDBC Sink ao invés de Confluent:
```json
{
  "connector.class": "io.debezium.connector.jdbc.JdbcSinkConnector",
  "database.type": "mysql"
}
```

**Comparação de Conectores:**

| **Aspecto** | **Confluent JDBC Sink** | **Debezium JDBC Sink** |
|------------|------------------------|----------------------|
| Classe | `io.confluent.connect.jdbc.JdbcSinkConnector` | `io.debezium.connector.jdbc.JdbcSinkConnector` |
| Propriedade username | `connection.user` | `connection.username` |
| Tipo de banco | Auto-detectado | `database.type` necessário |
| Tipos Debezium | ❌ Suporte limitado | ✅ Suporte completo |
| Conversão DATE | ❌ Falha | ✅ Converte corretamente |
| Conversão TIMESTAMP | ❌ Pode falhar | ✅ Funciona nativamente |
| Melhor para | Fontes JDBC genéricas | Fontes CDC Debezium |

### **Problema 3: Erro de Configuração do Conector**

**Sintomas:**
```text
ERROR: Error configuring JdbcSinkConnectorConfig
```

**Causa Raiz:** Propriedades obrigatórias faltando ou nomes de propriedades incorretos.

**Solução:** Certifique-se de que todas as propriedades obrigatórias estão presentes:
```json
{
  "connector.class": "io.debezium.connector.jdbc.JdbcSinkConnector",
  "database.type": "mysql",
  "connection.username": "dbadmin",  // NÃO connection.user
  "connection.password": "targetpass1234",
  "insert.mode": "upsert",
  "primary.key.mode": "record_key",
  "primary.key.fields": "id"
}
```

### **Problema 4: Registros Duplicados Aparecendo**

**Sintomas:** Banco de dados de destino tem mais registros que o esperado, com valores duplicados.

**Causa Raiz:** Conector sink não configurado para modo upsert corretamente ou configuração de chave primária faltando.

**Solução:**
```json
{
  "insert.mode": "upsert",              // Habilita update em conflito
  "primary.key.mode": "record_key",     // Usa chave da mensagem Kafka
  "primary.key.fields": "id",           // Especifica coluna de conflito
  "delete.enabled": "true"              // Lida com eventos DELETE
}
```

### **Problema 5: API Kafka Connect Não Respondendo**

**Sintomas:**
```bash
curl: (7) Failed to connect to localhost port 8083: Connection refused
```

**Causa Raiz:** Kafka Connect não iniciou completamente ou travou.

**Solução:**
```bash
# Verificar status do serviço
docker-compose ps kafka-connect

# Ver logs
docker-compose logs -f kafka-connect

# Reiniciar se necessário
docker-compose restart kafka-connect

# Aguardar API ficar pronta (~30 segundos)
curl http://localhost:8083/ | jq
```

---

## **Comandos Úteis**

### **Gerenciamento de Conectores**

```bash
# Listar todos os conectores
curl http://localhost:8083/connectors | jq

# Obter status de conector específico
curl http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/status | jq

# Obter configuração do conector
curl http://localhost:8083/connectors/mysql-source-nicole-paixao-v3 | jq

# Deletar conector
curl -X DELETE http://localhost:8083/connectors/mysql-source-nicole-paixao-v3

# Reiniciar conector
curl -X POST http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/restart

# Pausar conector
curl -X PUT http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/pause

# Resumir conector
curl -X PUT http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/resume
```

### **Gerenciamento de Tópicos Kafka**

```bash
# Listar todos os tópicos
docker exec -it kafka kafka-topics \
  --bootstrap-server kafka:9092 \
  --list

# Descrever tópico específico
docker exec -it kafka kafka-topics \
  --bootstrap-server kafka:9092 \
  --describe \
  --topic localtest.source.nicole_paixao

# Consumir mensagens do início
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic localtest.source.nicole_paixao \
  --from-beginning

# Consumir com chave e timestamp
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic localtest.source.nicole_paixao \
  --property print.key=true \
  --property print.timestamp=true \
  --from-beginning

# Deletar tópico (requer limpeza)
docker exec -it kafka kafka-topics \
  --bootstrap-server kafka:9092 \
  --delete \
  --topic localtest.source.nicole_paixao
```

### **Operações de Banco de Dados MySQL**

```bash
# Conectar ao banco de dados origem
docker exec -it mysql-source mysql -uroot -prootpass1234 source

# Conectar ao banco de dados destino
docker exec -it mysql-target mysql -uroot -ptargetroot1234 targetdb

# Verificar status do binlog (origem)
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "SHOW BINARY LOGS;"

# Ver posição do binlog (origem)
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "SHOW MASTER STATUS;"

# Contar registros em ambos bancos
docker exec -it mysql-source mysql -uroot -prootpass1234 -e "
SELECT 'ORIGEM' AS db, COUNT(*) AS registros FROM source.nicole_paixao;"

docker exec -it mysql-target mysql -uroot -ptargetroot1234 -e "
SELECT 'DESTINO' AS db, COUNT(*) AS registros FROM targetdb.nicole_paixao;"
```

### **Reset Completo do Ambiente**

```bash
# Parar todos os containers
docker-compose down

# Remover todos os volumes (AVISO: deleta todos os dados)
docker-compose down -v

# Remover plugins Kafka Connect (opcional)
rm -rf connect-plugins/*

# Reiniciar do zero
docker-compose up -d

# Aguardar serviços ficarem prontos
sleep 30
docker-compose ps
```

### **Debugging e Monitoramento**

```bash
# Ver todos os logs de serviços
docker-compose logs -f

# Ver logs de serviço específico
docker-compose logs -f kafka-connect
docker-compose logs -f mysql-source

# Verificar uso de recursos do container
docker stats

# Inspecionar tarefas do conector
curl http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/tasks | jq

# Ver offsets do conector
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic connect-offsets \
  --from-beginning
```

---

## **Mergulho Profundo na Configuração**

### **Parâmetros do Conector Debezium Source**

| **Parâmetro** | **Valor** | **Propósito** |
|---------------|-----------|-------------|
| `snapshot.mode` | `initial` | Fazer snapshot completo depois streaming de mudanças |
| `database.server.id` | `888` | ID único do servidor para replicação binlog |
| `topic.prefix` | `localtest` | Prefixo de nomenclatura do tópico Kafka |
| `include.schema.changes` | `false` | Não capturar mudanças DDL |
| `key.converter` | `JsonConverter` | Formato JSON para chaves de mensagem |
| `value.converter` | `JsonConverter` | Formato JSON para valores de mensagem |
| `schemas.enable` | `true` | Incluir schema nas mensagens |

### **Parâmetros do Conector Debezium Sink**

| **Parâmetro** | **Valor** | **Propósito** |
|---------------|-----------|-------------|
| `insert.mode` | `upsert` | Update em conflito, insert se novo |
| `delete.enabled` | `true` | Processar eventos DELETE da origem |
| `primary.key.mode` | `record_key` | Usar chave da mensagem Kafka como PK |
| `schema.evolution` | `basic` | Permitir adições de coluna automaticamente |
| `table.name.format` | Customizado | Mapear tópico para nome de tabela específico |

### **Opções de Modo Snapshot**

| **Modo** | **Comportamento** | **Caso de Uso** |
|----------|-------------|-------------|
| `initial` | Snapshot completo → streaming binlog | Setup inicial |
| `initial_only` | Apenas snapshot, sem streaming | Migração única de dados |
| `never` | Apenas streaming binlog | Retomar de posição conhecida |
| `when_needed` | Snapshot se nenhuma posição salva | Recuperação automática |
| `schema_only` | Capturar schema, pular dados | Apenas evolução de schema |

---

## **Funcionalidades**

| **Funcionalidade** | **Descrição** |
|-------------|-----------------|
| **Zero Duplicatas** | Modo upsert previne inserções duplicadas |
| **Validação Automatizada** | Scripts verificam contagens de registros em cada estágio |
| **Rastreamento de Posição Binlog** | Retoma da última posição ao reiniciar |
| **Evolução de Schema** | Adapta automaticamente a mudanças DDL |
| **Teste Local** | Pipeline CDC completo no Docker |
| **Replicação Tempo Real** | Latência sub-segundo para novos registros |
| **Tolerância a Falhas** | Kafka armazena eventos para replay |
| **Suporte Multi-Tabela** | Fácil extensão para múltiplas tabelas |
| **Propagação de DELETE** | Lida corretamente com operações DELETE |
| **Rastreamento de UPDATE** | Captura operações UPDATE com antes/depois |

---

## **Tecnologias Utilizadas**

| **Tecnologia** | **Versão** | **Propósito** |
|----------------|-------------|-------------|
| Docker | 20.10+ | Runtime de container |
| Docker Compose | 2.0+ | Orquestração multi-container |
| MySQL | 8.0 | Bancos de dados origem e destino |
| Apache Kafka | 2.13-3.4 | Plataforma de streaming de eventos |
| Debezium | 2.6 | Conectores Change Data Capture |
| Kafka Connect | 2.6 | Framework de runtime do conector |
| Zookeeper | 3.8 | Coordenação do cluster Kafka |

---

## **Casos de Uso**

| **Caso de Uso** | **Aplicação** |
|--------------|-----------------|
| **Migração de Banco de Dados** | Validar CDC antes do cutover de produção |
| **Restauração de Backup** | Garantir sem dados duplicados após restauração |
| **Recuperação de Desastres** | Testar cenários de failover localmente |
| **Sincronização Multi-Região** | Replicar dados através de regiões |
| **Pipeline de Analytics** | Streaming de mudanças de banco para data warehouse |
| **Trilha de Auditoria** | Capturar todas as modificações de banco de dados |
| **Integração de Microserviços** | Compartilhar mudanças de dados através de serviços |
| **Testes de Desenvolvimento** | Ambiente seguro para configuração CDC |

---

## **Melhores Práticas de Segurança**

### **Considerações de Produção**

| **Aspecto** | **Recomendação** |
|------------|-------------------|
| **Credenciais** | Usar AWS Secrets Manager ou HashiCorp Vault |
| **Rede** | Colocar Kafka em subnet privada com VPC peering |
| **Criptografia** | Habilitar SSL/TLS para conexões Kafka e MySQL |
| **Controle de Acesso** | Implementar RBAC para API Kafka Connect |
| **Monitoramento** | Configurar alarmes CloudWatch para lag e falhas |
| **Backup** | Configurar políticas de retenção de tópicos Kafka |

### **Permissões de Usuário MySQL**

**Permissões mínimas necessárias para CDC:**

```sql
-- Usuário banco origem (CDC somente-leitura)
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT 
ON *.* TO 'cdc_user'@'%';

-- Usuário banco destino (acesso escrita)
GRANT INSERT, UPDATE, DELETE ON targetdb.* TO 'sink_user'@'%';
```

---

## **Monitoramento e Observabilidade**

### **Métricas Principais para Rastrear**

| **Métrica** | **O Que Monitorar** | **Limite de Alerta** |
|------------|-------------------|-------------------|
| **Lag de Replicação** | Tempo entre mudança origem e atualização destino | > 5 segundos |
| **Status do Conector** | Estado RUNNING vs FAILED | Qualquer estado FAILED |
| **Tamanho do Tópico Kafka** | Backlog de mensagens no tópico | > 10.000 mensagens |
| **Taxa de Erro** | Processamento de mensagem falhou | > 1% taxa de erro |
| **Throughput** | Mensagens por segundo | Quedas súbitas |

### **Comandos de Health Check**

```bash
# Verificar saúde do conector
curl http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/status | \
  jq '.connector.state, .tasks[].state'

# Monitorar lag do consumer Kafka
docker exec -it kafka kafka-consumer-groups \
  --bootstrap-server kafka:9092 \
  --describe \
  --group connect-jdbc-sink-nicole-paixao

# Ver erros recentes
docker-compose logs --tail=50 kafka-connect | grep ERROR
```

---

## **Ajuste de Performance**

### **Estratégias de Otimização**

| **Componente** | **Configuração** | **Impacto** |
|---------------|------------------|-----------|
| **Conector Source** | `max.batch.size: 2048` | Batches maiores, menos requisições |
| **Tópico Kafka** | `partitions: 3` | Processamento paralelo |
| **Conector Sink** | `tasks.max: 3` | Múltiplos writers |
| **Processamento em Batch** | `batch.size: 1000` | Reduz overhead de insert |
| **Rede** | Habilitar compressão | Reduz uso de banda |

### **Configuração Otimizada Exemplo**

```json
{
  "name": "mysql-source-optimized",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "max.batch.size": "2048",
    "max.queue.size": "8192",
    "poll.interval.ms": "100",
    "tasks.max": "1"
  }
}
```

---

## **Guia de Troubleshooting**

### **Problema: Conector Preso em Estado PAUSED**

```bash
# Resumir o conector
curl -X PUT http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/resume

# Verificar mudança de estado
curl http://localhost:8083/connectors/mysql-source-nicole-paixao-v3/status
```

### **Problema: Mensagens Não Aparecem no Destino**

```bash
# 1. Verificar se conector source está produzindo mensagens
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic localtest.source.nicole_paixao \
  --max-messages 5

# 2. Verificar logs do conector sink
docker-compose logs kafka-connect | grep -i error

# 3. Verificar conectividade do banco destino
docker exec -it mysql-target mysql -udbadmin -ptargetpass1234 -e "SELECT 1"
```

### **Problema: Registros Duplicados Após Reinício**

**Causa:** Conector sink não usando modo upsert corretamente.

**Solução:**
```bash
# Deletar e recriar sink com configuração adequada
curl -X DELETE http://localhost:8083/connectors/jdbc-sink-nicole-paixao

# Recriar com modo upsert
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "jdbc-sink-nicole-paixao",
    "config": {
      "insert.mode": "upsert",
      "primary.key.mode": "record_key",
      "primary.key.fields": "id"
    }
  }'
```

---

## **Cenários Avançados**

### **Filtrar Colunas Específicas**

```json
{
  "name": "mysql-source-filtered",
  "config": {
    "column.include.list": "source.nicole_paixao.id,source.nicole_paixao.seller_id,source.nicole_paixao.score"
  }
}
```

### **Lidar com Mudanças de Schema**

```sql
-- Adicionar nova coluna à tabela origem
ALTER TABLE source.nicole_paixao ADD COLUMN region VARCHAR(50);

-- Debezium automaticamente captura DDL e atualiza sink
-- Verificar no destino
DESCRIBE targetdb.nicole_paixao;
```

### **Replicação Multi-Tabela**

```json
{
  "name": "mysql-source-multi-table",
  "config": {
    "table.include.list": "source.nicole_paixao,source.sales_data,source.inventory"
  }
}
```

---

## **Artigo Completo no Medium**

Para um mergulho profundo abrangente nos desafios enfrentados e como cada problema foi resolvido, leia a história completa:

**[Replicação CDC de MySQL para MySQL usando Kafka + Debezium: da frustração à solução](https://nicoleepaixao.medium.com/replicação-cdc-de-mysql-para-mysql-usando-kafka-debezium-da-frustração-à-solução-de6d2fb2a3eb)**

---

## **Recursos Adicionais**

### **Documentação Oficial**

- [Debezium MySQL Connector](https://debezium.io/documentation/reference/stable/connectors/mysql.html) - Referência completa do conector
- [Debezium JDBC Sink](https://debezium.io/documentation/reference/stable/connectors/jdbc.html) - Guia do conector sink
- [Kafka Connect](https://kafka.apache.org/documentation/#connect) - Docs do framework Connect
- [MySQL Binlog](https://dev.mysql.com/doc/refman/8.0/en/binary-log.html) - Configuração do log binário
- [Kafka Topic Configuration](https://kafka.apache.org/documentation/#topicconfigs) - Parâmetros de ajuste de tópicos

### **Recursos da Comunidade**

- [Debezium Community](https://debezium.io/community/) - Fóruns e chat
- [Kafka Users Mailing List](https://kafka.apache.org/contact) - Suporte da comunidade
- [Stack Overflow - Debezium Tag](https://stackoverflow.com/questions/tagged/debezium) - Q&A

---

## **Melhorias Futuras**

| **Funcionalidade** | **Descrição** | **Status** |
|-------------|-----------------|------------|
| **Schema Registry** | Gerenciamento de schema Avro | Planejado |
| **Integração ksqlDB** | Capacidades de stream processing | Em Desenvolvimento |
| **Dashboard de Monitoramento** | Dashboards Grafana para métricas | Planejado |
| **Multi-Datacenter** | Setup de replicação cross-region | Futuro |
| **Automação Terraform** | Deployment Infrastructure as Code | Planejado |
| **Suporte AWS MSK** | Integração Kafka gerenciado | Futuro |
| **Filtragem de Change Data** | Filtros de replicação nível de linha | Planejado |

---

## **Conecte-se & Siga**

Mantenha-se atualizado com melhores práticas CDC, streaming Kafka e engenharia de dados:

<div align="center">

[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/nicoleepaixao)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?logo=linkedin&logoColor=white&style=for-the-badge)](https://www.linkedin.com/in/nicolepaixao/)
[![Medium](https://img.shields.io/badge/Medium-12100E?style=for-the-badge&logo=medium&logoColor=white)](https://medium.com/@nicoleepaixao)

</div>

---

## **Aviso Legal**

Este projeto é para propósitos educacionais e de teste. O setup Docker Compose é projetado para ambientes de desenvolvimento local. Configurações CDC, settings Kafka e parâmetros de banco de dados podem precisar de ajuste para uso em produção. Sempre valide comportamento de replicação em ambientes de staging antes de implantar em produção. Consulte documentação oficial do Debezium e Apache Kafka para melhores práticas de produção.

---

<div align="center">

**Replique seus dados com CDC com confiança!**

*Documento Criado: 2 de Janeiro de 2026*

Made with ❤️ by [Nicole Paixão](https://github.com/nicoleepaixao)

</div>
