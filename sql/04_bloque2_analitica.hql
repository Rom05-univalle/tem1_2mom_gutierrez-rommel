-- Bloque II - Procesamiento y Consultas Analiticas (Preguntas 3, 4, 5 y 6)
USE db_superstore;
SET hive.cli.print.header=true;

-- Pregunta 3: Analisis de evolucion comercial por region
WITH resumen_regional AS (
    SELECT
        region,
        YEAR(order_date) AS anio,
        ROUND(SUM(sales), 2) AS ventas_totales,
        ROUND(SUM(profit), 2) AS ganancia_total,
        ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margen_rentabilidad_pct
    FROM superstore_sales
    GROUP BY region, YEAR(order_date)
),
evolucion_anual AS (
    SELECT
        region,
        anio,
        ventas_totales,
        ganancia_total,
        margen_rentabilidad_pct,
        LAG(ventas_totales, 1) OVER (PARTITION BY region ORDER BY anio) AS ventas_anio_anterior,
        ROUND(
            ((ventas_totales - LAG(ventas_totales, 1) OVER (PARTITION BY region ORDER BY anio))
            / LAG(ventas_totales, 1) OVER (PARTITION BY region ORDER BY anio)) * 100, 2
        ) AS variacion_ventas_pct,
        ROUND(
            ((ganancia_total - LAG(ganancia_total, 1) OVER (PARTITION BY region ORDER BY anio))
            / ABS(LAG(ganancia_total, 1) OVER (PARTITION BY region ORDER BY anio))) * 100, 2
        ) AS variacion_ganancia_pct
    FROM resumen_regional
)
SELECT
    region,
    anio,
    ventas_totales,
    ganancia_total,
    margen_rentabilidad_pct,
    ventas_anio_anterior,
    variacion_ventas_pct,
    variacion_ganancia_pct
FROM evolucion_anual
ORDER BY region, anio;

-- Consolidado por region para identificar mejor y peor desempeno comercial global
WITH desempeno_global AS (
    SELECT
        region,
        COUNT(DISTINCT order_id) AS total_ordenes,
        ROUND(SUM(sales), 2) AS ventas_acumuladas,
        ROUND(SUM(profit), 2) AS ganancia_acumulada,
        ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margen_global_pct
    FROM superstore_sales
    GROUP BY region
)
SELECT
    region,
    total_ordenes,
    ventas_acumuladas,
    ganancia_acumulada,
    margen_global_pct,
    RANK() OVER (ORDER BY ganancia_acumulada DESC) AS ranking_ganancia,
    RANK() OVER (ORDER BY ventas_acumuladas DESC) AS ranking_ventas
FROM desempeno_global
ORDER BY ranking_ganancia;

-- Pregunta 4: Segmentacion avanzada de clientes mediante RFM
WITH compras_cliente AS (
    SELECT
        customer_id,
        MAX(customer_name) AS customer_name,
        MAX(order_date) AS ultima_compra,
        COUNT(DISTINCT order_id) AS frequency_ordenes,
        ROUND(SUM(sales), 2) AS monetary_ventas,
        ROUND(SUM(profit), 2) AS ganancia_cliente
    FROM superstore_sales
    GROUP BY customer_id
),
metricas_cliente AS (
    SELECT
        customer_id,
        customer_name,
        DATEDIFF(MAX(ultima_compra) OVER (), ultima_compra) AS recency_dias,
        frequency_ordenes,
        monetary_ventas,
        ganancia_cliente
    FROM compras_cliente
),
puntajes_rfm AS (
    SELECT
        customer_id,
        customer_name,
        recency_dias,
        frequency_ordenes,
        monetary_ventas,
        ganancia_cliente,
        NTILE(5) OVER (ORDER BY recency_dias DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency_ordenes ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_ventas ASC) AS m_score
    FROM metricas_cliente
),
segmentacion_rfm AS (
    SELECT
        customer_id,
        customer_name,
        recency_dias,
        frequency_ordenes,
        monetary_ventas,
        r_score,
        f_score,
        m_score,
        (r_score + f_score + m_score) AS rfm_total,
        CONCAT(CAST(r_score AS STRING), CAST(f_score AS STRING), CAST(m_score AS STRING)) AS codigo_rfm,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Alto Valor (Campeones)'
            WHEN f_score >= 4 AND r_score >= 3 THEN 'Clientes Recurrentes (Leales)'
            WHEN r_score <= 2 AND (f_score >= 3 OR m_score >= 3) THEN 'En Riesgo de Abandono'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'Clientes Recientes / Potenciales'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Inactivos / Bajo Valor'
            ELSE 'Regulares / Promedio'
        END AS segmento_rfm
    FROM puntajes_rfm
)
SELECT
    segmento_rfm,
    COUNT(*) AS cantidad_clientes,
    ROUND((COUNT(*) / 793.0) * 100, 2) AS porcentaje_cartera,
    ROUND(AVG(recency_dias), 1) AS promedio_recency_dias,
    ROUND(AVG(frequency_ordenes), 2) AS promedio_ordenes,
    ROUND(AVG(monetary_ventas), 2) AS promedio_ventas,
    ROUND(SUM(monetary_ventas), 2) AS ventas_totales_segmento
FROM segmentacion_rfm
GROUP BY segmento_rfm
ORDER BY ventas_totales_segmento DESC;

-- Muestra del Top 15 clientes segun puntuacion RFM y monto acumulado
WITH compras_cliente AS (
    SELECT
        customer_id,
        MAX(customer_name) AS customer_name,
        MAX(order_date) AS ultima_compra,
        COUNT(DISTINCT order_id) AS frequency_ordenes,
        ROUND(SUM(sales), 2) AS monetary_ventas
    FROM superstore_sales
    GROUP BY customer_id
),
metricas_cliente AS (
    SELECT
        customer_id,
        customer_name,
        DATEDIFF(MAX(ultima_compra) OVER (), ultima_compra) AS recency_dias,
        frequency_ordenes,
        monetary_ventas
    FROM compras_cliente
),
puntajes_rfm AS (
    SELECT
        customer_id,
        customer_name,
        recency_dias,
        frequency_ordenes,
        monetary_ventas,
        NTILE(5) OVER (ORDER BY recency_dias DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency_ordenes ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_ventas ASC) AS m_score
    FROM metricas_cliente
)
SELECT
    customer_id,
    customer_name,
    recency_dias,
    frequency_ordenes,
    monetary_ventas,
    CONCAT(CAST(r_score AS STRING), CAST(f_score AS STRING), CAST(m_score AS STRING)) AS codigo_rfm,
    (r_score + f_score + m_score) AS rfm_total,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Alto Valor (Campeones)'
        WHEN f_score >= 4 AND r_score >= 3 THEN 'Clientes Recurrentes (Leales)'
        WHEN r_score <= 2 AND (f_score >= 3 OR m_score >= 3) THEN 'En Riesgo de Abandono'
        ELSE 'Otros'
    END AS segmento_rfm
FROM puntajes_rfm
ORDER BY rfm_total DESC, monetary_ventas DESC
LIMIT 15;

-- Pregunta 5: Ranking de productos segun rentabilidad
-- 5.1 Los 5 productos con mayor ganancia acumulada por categoria
WITH metricas_producto AS (
    SELECT
        category,
        product_name,
        SUM(quantity) AS unidades_vendidas,
        ROUND(SUM(sales), 2) AS ventas_totales,
        ROUND(SUM(profit), 2) AS ganancia_total,
        ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margen_ganancia_pct
    FROM superstore_sales
    GROUP BY category, product_name
),
ranking_categoria AS (
    SELECT
        category,
        product_name,
        unidades_vendidas,
        ventas_totales,
        ganancia_total,
        margen_ganancia_pct,
        RANK() OVER (PARTITION BY category ORDER BY ganancia_total DESC) AS pos_rank,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY ganancia_total DESC) AS pos_dense_rank,
        ROUND(SUM(ganancia_total) OVER (
            PARTITION BY category
            ORDER BY ganancia_total DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2) AS ganancia_acumulada_cat
    FROM metricas_producto
)
SELECT
    category,
    pos_rank,
    pos_dense_rank,
    product_name,
    ventas_totales,
    ganancia_total,
    margen_ganancia_pct,
    ganancia_acumulada_cat
FROM ranking_categoria
WHERE pos_rank <= 5
ORDER BY category, pos_rank;

-- 5.2 Los 5 productos con mayor volumen de ventas globales
WITH global_productos AS (
    SELECT
        category,
        product_name,
        SUM(quantity) AS unidades,
        ROUND(SUM(sales), 2) AS ventas_totales,
        ROUND(SUM(profit), 2) AS ganancia_total,
        ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margen_pct
    FROM superstore_sales
    GROUP BY category, product_name
),
ranked_ventas AS (
    SELECT
        category,
        product_name,
        unidades,
        ventas_totales,
        ganancia_total,
        margen_pct,
        RANK() OVER (ORDER BY ventas_totales DESC) AS rnk_ventas,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY ventas_totales DESC) AS pos_en_categoria
    FROM global_productos
)
SELECT rnk_ventas, category, pos_en_categoria, product_name, unidades, ventas_totales, ganancia_total, margen_pct
FROM ranked_ventas
WHERE rnk_ventas <= 5
ORDER BY rnk_ventas;

-- 5.3 Los 5 productos con menor rentabilidad (mayores perdidas acumuladas)
WITH global_productos AS (
    SELECT
        category,
        product_name,
        SUM(quantity) AS unidades,
        ROUND(SUM(sales), 2) AS ventas_totales,
        ROUND(SUM(profit), 2) AS ganancia_total,
        ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margen_pct
    FROM superstore_sales
    GROUP BY category, product_name
),
ranked_peores AS (
    SELECT
        category,
        product_name,
        unidades,
        ventas_totales,
        ganancia_total,
        margen_pct,
        RANK() OVER (ORDER BY ganancia_total ASC) AS rnk_peor_rentabilidad,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY ganancia_total ASC) AS pos_peor_cat
    FROM global_productos
)
SELECT rnk_peor_rentabilidad, category, pos_peor_cat, product_name, unidades, ventas_totales, ganancia_total, margen_pct
FROM ranked_peores
WHERE rnk_peor_rentabilidad <= 5
ORDER BY rnk_peor_rentabilidad;

-- Pregunta 6: Analisis del impacto de los descuentos
-- 6.1 Resumen por rango de descuento
WITH clasificacion_descuentos AS (
    SELECT
        row_id,
        category,
        sub_category,
        sales,
        profit,
        discount,
        CASE
            WHEN discount = 0 THEN '1. Sin descuento (0%)'
            WHEN discount > 0 AND discount <= 0.20 THEN '2. Descuento bajo (>0% a 20%)'
            WHEN discount > 0.20 AND discount <= 0.50 THEN '3. Descuento medio (>20% a 50%)'
            ELSE '4. Descuento alto (>50%)'
        END AS rango_descuento
    FROM superstore_sales
)
SELECT
    rango_descuento,
    COUNT(*) AS total_registros,
    ROUND(AVG(discount) * 100, 2) AS descuento_promedio_pct,
    ROUND(SUM(sales), 2) AS ventas_totales,
    ROUND(SUM(profit), 2) AS ganancia_total,
    ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margen_rentabilidad_pct,
    SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS registros_con_perdida,
    ROUND((SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS pct_registros_no_rentables
FROM clasificacion_descuentos
GROUP BY rango_descuento
ORDER BY rango_descuento;

-- 6.2 Categorias y subcategorias mas afectadas por descuentos y perdidas
SELECT
    category,
    sub_category,
    COUNT(*) AS total_operaciones,
    ROUND(AVG(discount) * 100, 2) AS descuento_promedio_pct,
    SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS operaciones_con_perdida,
    ROUND((SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS pct_no_rentables,
    ROUND(SUM(sales), 2) AS ventas_totales,
    ROUND(SUM(profit), 2) AS ganancia_neta,
    ROUND(SUM(CASE WHEN profit < 0 THEN profit ELSE 0 END), 2) AS perdida_acumulada
FROM superstore_sales
GROUP BY category, sub_category
HAVING SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) > 0
ORDER BY perdida_acumulada ASC
LIMIT 10;
