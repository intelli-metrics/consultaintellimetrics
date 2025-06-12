CREATE OR REPLACE FUNCTION get_grouped_sensor_data(
    dispositivos INTEGER[], -- Array of cdDispositivo values
    dt_registro_comeco TIMESTAMP DEFAULT NULL, -- Optional start date
    dt_registro_fim TIMESTAMP DEFAULT NULL -- Optional end date
)
RETURNS TABLE (
    "cdDispositivo" INTEGER,
    "dsTipoSensor" TEXT,
    "totalLeitura" DOUBLE PRECISION,
    "mediaLeitura" DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        v."cdDispositivo",
        v."dsTipoSensor",
        SUM(v."nrLeituraSensor") AS totalLeitura,
        AVG(v."nrLeituraSensor") AS mediaLeitura
    FROM
        "VwRelHistoricoDispositivoProduto" v 
    WHERE
        v."cdDispositivo" = ANY(dispositivos)
        AND (dt_registro_comeco IS NULL OR v."dtRegistro" >= dt_registro_comeco)
        AND (dt_registro_fim IS NULL OR v."dtRegistro" <= dt_registro_fim)
        AND v."dsTipoSensor" IN ('Camera de movimento', 'Abertura de Porta', 'Temperatura')
    GROUP BY
        v."cdDispositivo", v."dsTipoSensor";
END;
$$ LANGUAGE plpgsql;