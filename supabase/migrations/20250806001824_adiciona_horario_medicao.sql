-- Add measurement hours configuration to TbDispositivo table
ALTER TABLE "public"."TbDispositivo" 
ADD COLUMN "horarioMedicaoInicio" time,
ADD COLUMN "horarioMedicaoFim" time;

-- Add comment to document the column purpose
COMMENT ON COLUMN "public"."TbDispositivo"."horarioMedicaoInicio" IS 'UTC start time for when this device should collect measurements (e.g., 11:00 for 8AM Sao Paulo time)';
COMMENT ON COLUMN "public"."TbDispositivo"."horarioMedicaoFim" IS 'UTC end time for when this device should collect measurements (e.g., 01:00 for 10PM Sao Paulo time)';

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
        -- Filtro por horário de medição. Nao coletar dados fora do horario de medição.
        AND (d."horarioMedicaoInicio" IS NULL OR 
             (CASE 
                -- Handle midnight crossing (e.g., 11:00 to 01:00)
                WHEN d."horarioMedicaoInicio" > d."horarioMedicaoFim" THEN
                    CAST(v."dtRegistro" AS time) >= d."horarioMedicaoInicio" 
                    OR CAST(v."dtRegistro" AS time) <= d."horarioMedicaoFim"
                ELSE
                    CAST(v."dtRegistro" AS time) >= d."horarioMedicaoInicio" 
                    AND CAST(v."dtRegistro" AS time) <= d."horarioMedicaoFim"
             END))
    GROUP BY
        v."cdDispositivo", v."dsTipoSensor";
END;
$$;
