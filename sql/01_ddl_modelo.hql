-- Bloque I - Pregunta 1: Diseno e implementacion del modelo de datos en Apache Hive
CREATE DATABASE IF NOT EXISTS db_superstore;
USE db_superstore;

DROP TABLE IF EXISTS superstore_sales;

CREATE TABLE superstore_sales (
    row_id INT,
    order_id STRING,
    order_date DATE,
    ship_date DATE,
    ship_mode STRING,
    customer_id STRING,
    customer_name STRING,
    segment STRING,
    country STRING,
    city STRING,
    state STRING,
    postal_code STRING,
    region STRING,
    product_id STRING,
    category STRING,
    sub_category STRING,
    product_name STRING,
    sales DECIMAL(12,4),
    quantity INT,
    discount DECIMAL(5,2),
    profit DECIMAL(12,4)
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/hive/warehouse/db_superstore.db/superstore_sales';
