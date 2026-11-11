# Examen Practico Individual - 2do Momento

Proyecto de procesamiento y analisis de datos con Apache Hive usando el dataset **Superstore Sales Dataset (Sample Superstore)**.

**Estudiante:** Rommel Gutierrez  
**Materia:** Tecnologias Emergentes  
**Docente:** Ing. Efrain Luna Mamani  

## Contenido del repositorio
- `Informe_Examen_Practico_Apache_Hive_Rommel_Gutierrez.docx`: Documento con el diccionario de datos, desarrollo de las preguntas, capturas de ejecucion, resultados, optimizacion y conclusiones.
- `data/`: Dataset original (`Sample - Superstore.csv`) y archivo preparado sin cabecera para carga en Hive (`superstore_rommel.csv`).
- `sql/`: Scripts HiveQL de creacion de tabla (`01_ddl_modelo.hql`), verificacion de carga (`02_dml_carga.hql`), calidad de datos (`03_bloque1_calidad.hql`), consultas del bloque 2 (`04_bloque2_analitica.hql`), consultas del bloque 3 (`05_bloque3_avanzada.hql`) y optimizacion (`06_optimizacion.hql`).
- `img/`: Capturas de ejecucion en Apache Hive.

## Ejecucion en Docker + Hive
1. Subir el CSV a HDFS:
```
docker cp data/superstore_rommel.csv docker-hive_namenode_1:/superstore_rommel.csv
docker exec docker-hive_namenode_1 hdfs dfs -mkdir -p /user/hive/warehouse/db_superstore.db/superstore_sales
docker exec docker-hive_namenode_1 hdfs dfs -put -f /superstore_rommel.csv /user/hive/warehouse/db_superstore.db/superstore_sales/superstore_rommel.csv
```

2. Ejecutar los scripts `.hql` en el contenedor de Hive:
```
docker cp sql/. docker-hive_hive-server_1:/
docker exec docker-hive_hive-server_1 hive -f /01_ddl_modelo.hql
docker exec docker-hive_hive-server_1 hive -f /02_dml_carga.hql
docker exec docker-hive_hive-server_1 hive -f /03_bloque1_calidad.hql
docker exec docker-hive_hive-server_1 hive -f /04_bloque2_analitica.hql
docker exec docker-hive_hive-server_1 hive -f /05_bloque3_avanzada.hql
docker exec docker-hive_hive-server_1 hive -f /06_optimizacion.hql
```
