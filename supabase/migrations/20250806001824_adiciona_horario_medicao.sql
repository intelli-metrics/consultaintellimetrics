-- Add measurement hours configuration to TbDispositivo table
ALTER TABLE "public"."TbDispositivo" 
ADD COLUMN "horarioMedicao" timerange;

-- Add comment to document the column purpose
COMMENT ON COLUMN "public"."TbDispositivo"."horarioMedicao" IS 'UTC time range for when this device should collect measurements (e.g., ''11:00-01:00'' for 8AM-10PM Sao Paulo time)';

-- Update get_grouped_sensor_data function to filter by measurement hours
CREATE OR REPLACE FUNCTION "public"."get_grouped_sensor_data"("dispositivos" integer[], "dt_registro_comeco" timestamp without time zone DEFAULT NULL::timestamp without time zone, "dt_registro_fim" timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE("cdDispositivo" integer, "dsTipoSensor" "text", "totalLeitura" double precision, "mediaLeitura" double precision)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        v."cdDispositivo",
        v."dsTipoSensor",
        SUM(v."nrLeituraSensor") AS totalLeitura,
        AVG(v."nrLeituraSensor") AS mediaLeitura
    FROM
        "VwRelHistoricoDispositivoProduto" v 
        JOIN "public"."TbDispositivo" d ON v."cdDispositivo" = d."cdDispositivo"
    WHERE
        v."cdDispositivo" = ANY(dispositivos)
        AND (dt_registro_comeco IS NULL OR v."dtRegistro" >= dt_registro_comeco)
        AND (dt_registro_fim IS NULL OR v."dtRegistro" <= dt_registro_fim)
        AND v."dsTipoSensor" IN ('Camera de movimento', 'Abertura de Porta', 'Temperatura')
        -- Filter by measurement hours if configured
        AND (d."horarioMedicao" IS NULL OR 
             EXTRACT(time FROM v."dtRegistro")::time <@ d."horarioMedicao")
    GROUP BY
        v."cdDispositivo", v."dsTipoSensor";
END;
$$;
