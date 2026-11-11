-- Bloque I - Pregunta 1: Verificacion de carga y registros importados
USE db_superstore;
SET hive.cli.print.header=true;

DESCRIBE FORMATTED superstore_sales;

SELECT
    COUNT(*) AS total_registros_importados,
    MIN(order_date) AS fecha_minima_pedido,
    MAX(order_date) AS fecha_maxima_pedido,
    ROUND(SUM(sales), 2) AS ventas_totales,
    ROUND(SUM(profit), 2) AS ganancia_total
FROM superstore_sales;

SELECT row_id, order_id, order_date, ship_date, customer_id, region, category, sales, quantity, discount, profit
FROM superstore_sales
LIMIT 10;
