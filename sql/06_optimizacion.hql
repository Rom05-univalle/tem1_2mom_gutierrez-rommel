-- Analisis de Optimizacion en Apache Hive (Particionamiento, Clusterizacion y Formato ORC)
USE db_superstore;
SET hive.cli.print.header=true;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.enforce.bucketing=true;

DROP TABLE IF EXISTS superstore_partitioned_orc;

CREATE TABLE superstore_partitioned_orc (
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
    product_id STRING,
    category STRING,
    sub_category STRING,
    product_name STRING,
    sales DECIMAL(12,4),
    quantity INT,
    discount DECIMAL(5,2),
    profit DECIMAL(12,4)
)
PARTITIONED BY (anio INT, region STRING)
CLUSTERED BY (customer_id) INTO 4 BUCKETS
STORED AS ORC
TBLPROPERTIES ("orc.compress"="SNAPPY", "orc.create.index"="true");

INSERT OVERWRITE TABLE superstore_partitioned_orc PARTITION (anio, region)
SELECT
    row_id, order_id, order_date, ship_date, ship_mode, customer_id, customer_name,
    segment, country, city, state, postal_code, product_id, category, sub_category,
    product_name, sales, quantity, discount, profit,
    YEAR(order_date) AS anio,
    region
FROM superstore_sales;

SHOW PARTITIONS superstore_partitioned_orc;
