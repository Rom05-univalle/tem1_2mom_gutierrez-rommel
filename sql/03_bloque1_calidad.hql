-- Bloque I - Pregunta 2: Auditoria de calidad e integridad de datos
USE db_superstore;
SET hive.cli.print.header=true;

-- 2.1 Resumen consolidado de auditoria de calidad de datos
SELECT
    COUNT(*) AS total_registros,
    COUNT(*) - COUNT(DISTINCT row_id) AS row_id_duplicados,
    COUNT(DISTINCT order_id) AS ordenes_unicas,
    COUNT(DISTINCT customer_id) AS clientes_unicos,
    SUM(CASE WHEN row_id IS NULL OR order_id IS NULL OR order_date IS NULL OR ship_date IS NULL
              OR customer_id IS NULL OR product_id IS NULL OR sales IS NULL OR quantity IS NULL
              OR discount IS NULL OR profit IS NULL THEN 1 ELSE 0 END) AS registros_con_nulos,
    SUM(CASE WHEN order_date IS NULL OR ship_date IS NULL THEN 1 ELSE 0 END) AS fechas_invalidas,
    SUM(CASE WHEN sales <= 0 THEN 1 ELSE 0 END) AS ventas_menores_o_iguales_cero,
    SUM(CASE WHEN discount < 0 OR discount > 1 THEN 1 ELSE 0 END) AS descuentos_fuera_intervalo,
    SUM(CASE WHEN ship_date < order_date THEN 1 ELSE 0 END) AS envio_anterior_a_pedido
FROM superstore_sales;

-- 2.2 Verificacion complementaria de unicidad de grano (Orden + Producto) y rentabilidad negativa
SELECT
    COUNT(*) AS total_lineas,
    COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '-', product_id)) AS combinaciones_orden_producto_repetidas,
    SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS registros_con_perdida,
    ROUND(SUM(CASE WHEN profit < 0 THEN profit ELSE 0 END), 2) AS monto_total_perdidas
FROM superstore_sales;
