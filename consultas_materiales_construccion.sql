CREATE TABLE IF NOT EXISTS precios_materiales (
    anio INT,
    mes INT,
    id_rubro INT,
    rubro VARCHAR(150),
    indice NUMERIC(12, 6),
    variacion_mensual NUMERIC(10, 6)
);

copy precios_materiales (anio, mes, id_rubro, rubro, indice, variacion_mensual) FROM 'D:\datos\escritorio\precios_materiales_construccion_11_2024.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');


CREATE TABLE dim_rubros (
    id_rubro INT PRIMARY KEY,
    rubro VARCHAR(150) NOT NULL
);

INSERT INTO dim_rubros (id_rubro, rubro)
SELECT DISTINCT id_rubro, rubro
FROM precios_materiales
ORDER BY id_rubro;



CREATE TABLE indices_materiales (
    id_registro SERIAL PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    id_rubro INT REFERENCES dim_rubros(id_rubro),
    indice NUMERIC(12, 6) NOT NULL,
    variacion_mensual NUMERIC(10, 6) NOT NULL
);


INSERT INTO indices_materiales (anio, mes, id_rubro, indice, variacion_mensual)
SELECT anio, mes, id_rubro, indice, variacion_mensual
FROM precios_materiales;


select * from precios_materiales
select * from dim_rubros
select * from indices_materiales


-- Medición de Riesgo --
-- promedio mensual, la desviación estándar y el salto histórico más brusco de cada material -- 

SELECT 
    r.rubro,
    ROUND(AVG(i.variacion_mensual)::numeric, 2) AS inflacion_promedio_mensual,
    ROUND(STDDEV(i.variacion_mensual)::numeric, 2) AS volatilidad,
    ROUND(MAX(i.variacion_mensual)::numeric, 2) AS peor_aumento_mensual
FROM indices_materiales i
JOIN dim_rubros r ON i.id_rubro = r.id_rubro
GROUP BY r.rubro
ORDER BY volatilidad DESC;

-- Inflación Acumulada por Rubro --
SELECT 
    r.rubro,
    ROUND(ini.indice::numeric, 2) AS indice_enero_2019,
    ROUND(fin.indice::numeric, 2) AS indice_actual,
    ROUND(((fin.indice - ini.indice) / ini.indice * 100)::numeric, 1) AS inflacion_acumulada_pct
FROM dim_rubros r
JOIN indices_materiales ini 
    ON r.id_rubro = ini.id_rubro AND ini.anio = 2019 AND ini.mes = 1
JOIN indices_materiales fin 
    ON r.id_rubro = fin.id_rubro AND fin.anio = 2024 AND fin.mes = 11
ORDER BY inflacion_acumulada_pct DESC;


-- Calculo la variación porcentual interanual --

WITH datos_con_lag AS (
    SELECT 
        i.anio,
        i.mes,
        r.rubro,
        ROUND(i.indice::numeric, 2) AS indice_actual,
        -- Obtenemos el índice de exactamente 12 filas atrás (1 año)
        ROUND(LAG(i.indice, 12) OVER (
            PARTITION BY i.id_rubro ORDER BY i.anio, i.mes
        )::numeric, 2) AS indice_hace_12m
    FROM indices_materiales i
    JOIN dim_rubros r ON i.id_rubro = r.id_rubro
)
SELECT 
    anio,
    mes,
    rubro,
    indice_actual,
    indice_hace_12m,
    -- Matemática simple y limpia: (actual - anterior) / anterior * 100
    ROUND(((indice_actual - indice_hace_12m) / indice_hace_12m * 100), 1) AS inflacion_interanual_pct
FROM datos_con_lag
WHERE anio >= 2020 AND indice_hace_12m IS NOT NULL
ORDER BY rubro, anio DESC, mes DESC;





















