-- Create RPC function for hourly door opening aggregation
CREATE OR REPLACE FUNCTION get_abertura_porta_hourly_aggregation(
    p_cd_produto INTEGER,
    p_dt_inicio TIMESTAMP WITH TIME ZONE,
    p_dt_fim TIMESTAMP WITH TIME ZONE,
    p_cd_dispositivos INTEGER[] DEFAULT NULL
)
RETURNS TABLE (
    hour_of_day INTEGER,
    total_value BIGINT,
    record_count BIGINT,
    last_read TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXTRACT(HOUR FROM sr."dtRegistro")::INTEGER as hour_of_day,
        SUM(sr."nrValor")::BIGINT as total_value,
        COUNT(*)::BIGINT as record_count,
        MAX(sr."dtRegistro")::TIMESTAMP WITH TIME ZONE as last_read
    FROM "TbSensorRegistro" sr
    INNER JOIN "TbSensor" s ON sr."cdSensor" = s."cdSensor"
    INNER JOIN "TbDispositivo" d ON s."cdDispositivo" = d."cdDispositivo"
    WHERE s."cdTipoSensor" = 2  -- Abertura de Porta
        AND d."cdProduto" = p_cd_produto
        AND sr."dtRegistro" >= p_dt_inicio
        AND sr."dtRegistro" <= p_dt_fim
        AND (p_cd_dispositivos IS NULL OR d."cdDispositivo" = ANY(p_cd_dispositivos))
    GROUP BY EXTRACT(HOUR FROM sr."dtRegistro")
    ORDER BY hour_of_day;
END;
$$;
