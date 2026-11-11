-- Bloque III - Analitica Avanzada (Preguntas 7 y 8)
USE db_superstore;
SET hive.cli.print.header=true;

-- Pregunta 7: Analisis de tendencias temporales (Evolucion mensual)
WITH serie_mensual AS (
    SELECT
        YEAR(order_date) AS anio,
        MONTH(order_date) AS mes,
        DATE_FORMAT(order_date, 'yyyy-MM') AS periodo,
        ROUND(SUM(sales), 2) AS ventas_mensuales,
        ROUND(SUM(profit), 2) AS ganancias_mensuales
    FROM superstore_sales
    GROUP BY YEAR(order_date), MONTH(order_date), DATE_FORMAT(order_date, 'yyyy-MM')
),
indicadores_temporales AS (
    SELECT
        periodo,
        anio,
        mes,
        ventas_mensuales,
        ganancias_mensuales,
        LAG(ventas_mensuales, 1) OVER (ORDER BY periodo) AS ventas_mes_anterior,
        ROUND(
            ((ventas_mensuales - LAG(ventas_mensuales, 1) OVER (ORDER BY periodo))
            / LAG(ventas_mensuales, 1) OVER (ORDER BY periodo)) * 100, 2
        ) AS var_mes_anterior_pct,
        LAG(ventas_mensuales, 12) OVER (ORDER BY periodo) AS ventas_mismo_mes_anio_ant,
        ROUND(
            ((ventas_mensuales - LAG(ventas_mensuales, 12) OVER (ORDER BY periodo))
            / LAG(ventas_mensuales, 12) OVER (ORDER BY periodo)) * 100, 2
        ) AS var_interanual_pct,
        ROUND(
            AVG(ventas_mensuales) OVER (
                ORDER BY periodo
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ), 2
        ) AS promedio_movil_3m
    FROM serie_mensual
)
SELECT
    periodo,
    ventas_mensuales,
    ganancias_mensuales,
    ventas_mes_anterior,
    var_mes_anterior_pct,
    ventas_mismo_mes_anio_ant,
    var_interanual_pct,
    promedio_movil_3m
FROM indicadores_temporales
ORDER BY periodo;

-- 7.2 Identificacion de los tres meses con mayor y menor volumen de ventas
WITH serie_mensual AS (
    SELECT
        DATE_FORMAT(order_date, 'yyyy-MM') AS periodo,
        ROUND(SUM(sales), 2) AS ventas_mensuales,
        ROUND(SUM(profit), 2) AS ganancias_mensuales
    FROM superstore_sales
    GROUP BY DATE_FORMAT(order_date, 'yyyy-MM')
),
extremos AS (
    SELECT
        periodo,
        ventas_mensuales,
        ganancias_mensuales,
        RANK() OVER (ORDER BY ventas_mensuales DESC) AS rnk_mayor,
        RANK() OVER (ORDER BY ventas_mensuales ASC) AS rnk_menor
    FROM serie_mensual
)
SELECT
    CASE WHEN rnk_mayor <= 3 THEN CONCAT('TOP MAYOR #', CAST(rnk_mayor AS STRING))
         ELSE CONCAT('TOP MENOR #', CAST(rnk_menor AS STRING))
    END AS clasificacion,
    periodo,
    ventas_mensuales,
    ganancias_mensuales
FROM extremos
WHERE rnk_mayor <= 3 OR rnk_menor <= 3
ORDER BY ventas_mensuales DESC;

-- Pregunta 8: Analisis Pareto (80/20) de ventas y rentabilidad
-- 8.a) Resumen Pareto de Ventas
WITH ventas_producto AS (
    SELECT
        product_name,
        ROUND(SUM(sales), 2) AS ventas_prod
    FROM superstore_sales
    GROUP BY product_name
),
pareto_ventas AS (
    SELECT
        product_name,
        ventas_prod,
        SUM(ventas_prod) OVER () AS ventas_totales_global,
        ROW_NUMBER() OVER (ORDER BY ventas_prod DESC) AS posicion,
        COUNT(*) OVER () AS total_productos_catalogo,
        ROUND((ventas_prod / SUM(ventas_prod) OVER ()) * 100, 4) AS participacion_individual_pct,
        ROUND(
            (SUM(ventas_prod) OVER (ORDER BY ventas_prod DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            / SUM(ventas_prod) OVER ()) * 100, 2
        ) AS participacion_acumulada_pct
    FROM ventas_producto
)
SELECT
    COUNT(*) AS total_productos_evaluados,
    SUM(CASE WHEN participacion_acumulada_pct <= 80.0 THEN 1 ELSE 0 END) + 1 AS productos_que_concentran_80pct_ventas,
    ROUND(((SUM(CASE WHEN participacion_acumulada_pct <= 80.0 THEN 1 ELSE 0 END) + 1) / COUNT(*)) * 100, 2) AS porcentaje_del_catalogo
FROM pareto_ventas;

-- Top 15 productos con mayor contribucion a las ventas (Pareto Ventas)
WITH ventas_producto AS (
    SELECT
        product_name,
        category,
        ROUND(SUM(sales), 2) AS ventas_prod
    FROM superstore_sales
    GROUP BY product_name, category
),
pareto_ventas AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY ventas_prod DESC) AS pos,
        product_name,
        category,
        ventas_prod,
        ROUND((ventas_prod / SUM(ventas_prod) OVER ()) * 100, 2) AS part_individual_pct,
        ROUND(
            (SUM(ventas_prod) OVER (ORDER BY ventas_prod DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            / SUM(ventas_prod) OVER ()) * 100, 2
        ) AS part_acumulada_pct
    FROM ventas_producto
)
SELECT pos, category, product_name, ventas_prod, part_individual_pct, part_acumulada_pct
FROM pareto_ventas
WHERE pos <= 15
ORDER BY pos;

-- 8.b) Resumen Pareto de Ganancias (Evaluado sobre productos rentables y sobre el total del catalogo)
WITH ganancia_producto AS (
    SELECT
        product_name,
        ROUND(SUM(profit), 2) AS ganancia_prod
    FROM superstore_sales
    GROUP BY product_name
),
pareto_ganancia_positiva AS (
    SELECT
        product_name,
        ganancia_prod,
        ROW_NUMBER() OVER (ORDER BY ganancia_prod DESC) AS posicion,
        ROUND((ganancia_prod / SUM(ganancia_prod) OVER ()) * 100, 4) AS part_individual_pct,
        ROUND(
            (SUM(ganancia_prod) OVER (ORDER BY ganancia_prod DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            / SUM(ganancia_prod) OVER ()) * 100, 2
        ) AS part_acumulada_positiva_pct
    FROM ganancia_producto
    WHERE ganancia_prod > 0
)
SELECT
    COUNT(*) AS productos_con_ganancia_positiva,
    SUM(CASE WHEN part_acumulada_positiva_pct <= 80.0 THEN 1 ELSE 0 END) + 1 AS productos_que_concentran_80pct_ganancias,
    ROUND(((SUM(CASE WHEN part_acumulada_positiva_pct <= 80.0 THEN 1 ELSE 0 END) + 1) / COUNT(*)) * 100, 2) AS pct_sobre_productos_rentables,
    ROUND(((SUM(CASE WHEN part_acumulada_positiva_pct <= 80.0 THEN 1 ELSE 0 END) + 1) / 1850.0) * 100, 2) AS pct_sobre_catalogo_total
FROM pareto_ganancia_positiva;

-- Top 15 productos con mayor contribucion a las ganancias (Pareto Ganancias)
WITH ganancia_producto AS (
    SELECT
        product_name,
        category,
        ROUND(SUM(profit), 2) AS ganancia_prod
    FROM superstore_sales
    GROUP BY product_name, category
    HAVING SUM(profit) > 0
),
pareto_ganancias AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY ganancia_prod DESC) AS pos,
        product_name,
        category,
        ganancia_prod,
        ROUND((ganancia_prod / SUM(ganancia_prod) OVER ()) * 100, 2) AS part_individual_pct,
        ROUND(
            (SUM(ganancia_prod) OVER (ORDER BY ganancia_prod DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            / SUM(ganancia_prod) OVER ()) * 100, 2
        ) AS part_acumulada_pct
    FROM ganancia_producto
)
SELECT pos, category, product_name, ganancia_prod, part_individual_pct, part_acumulada_pct
FROM pareto_ganancias
WHERE pos <= 15
ORDER BY pos;
