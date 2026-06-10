-- Create schemas and grant permissions
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS logs;
CREATE SCHEMA IF NOT EXISTS vectors;

GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';
GRANT ALL PRIVILEGES ON analytics.* TO 'appuser'@'%';
GRANT ALL PRIVILEGES ON logs.* TO 'appuser'@'%';
GRANT ALL PRIVILEGES ON vectors.* TO 'appuser'@'%';

-- Create vector-like table structure (MySQL doesn't have pgvector equivalent natively)
CREATE TABLE IF NOT EXISTS vectors.embeddings (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    source_id VARCHAR(255) NOT NULL,
    embedding JSON NOT NULL,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_source_id (source_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

FLUSH PRIVILEGES;
