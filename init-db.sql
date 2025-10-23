-- Initialize databases for different services
CREATE DATABASE IF NOT EXISTS eda_db;
CREATE DATABASE IF NOT EXISTS aiops_db;
CREATE DATABASE IF NOT EXISTS infiniedge_main;

-- Create users for each service
CREATE USER IF NOT EXISTS 'eda_user'@'%' IDENTIFIED BY 'eda_password';
CREATE USER IF NOT EXISTS 'aiops_user'@'%' IDENTIFIED BY 'aiops_password';

-- Grant permissions
GRANT ALL PRIVILEGES ON eda_db.* TO 'eda_user'@'%';
GRANT ALL PRIVILEGES ON aiops_db.* TO 'aiops_user'@'%';

FLUSH PRIVILEGES;