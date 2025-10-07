-- Create unified RPC function for movimento-pessoas aggregation (hourly and day-of-week)
CREATE OR REPLACE FUNCTION get_movimento_pessoas_aggregation(
    p_cd_produto INTEGER,
    p_dt_inicio TIMESTAMP WITH TIME ZONE,
    p_dt_fim TIMESTAMP WITH TIME ZONE,
    p_cd_dispositivos INTEGER[] DEFAULT NULL,
    p_cd_cliente INTEGER DEFAULT NULL,
    p_aggregation_type TEXT DEFAULT 'hourly'
)
RETURNS TABLE (
    time_period INTEGER,
    total_value BIGINT,
    record_count BIGINT,
    last_read TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validate aggregation type
    IF p_aggregation_type NOT IN ('hourly', 'by_day_of_week') THEN
        RAISE EXCEPTION 'Invalid aggregation_type. Must be "hourly" or "by_day_of_week"';
    END IF;

    IF p_aggregation_type = 'hourly' THEN
        -- Hourly aggregation (0-23)
        RETURN QUERY
        SELECT 
            EXTRACT(HOUR FROM sr."dtRegistro")::INTEGER as time_period,
            SUM(sr."nrValor")::BIGINT as total_value,
            COUNT(*)::BIGINT as record_count,
            MAX(sr."dtRegistro")::TIMESTAMP WITH TIME ZONE as last_read
        FROM "TbSensorRegistro" sr
        INNER JOIN "TbSensor" s ON sr."cdSensor" = s."cdSensor"
        INNER JOIN "TbDispositivo" d ON s."cdDispositivo" = d."cdDispositivo"
        WHERE s."cdTipoSensor" = 5  -- Movimento de Pessoas
            AND d."cdProduto" = p_cd_produto
            AND sr."dtRegistro" >= p_dt_inicio
            AND sr."dtRegistro" <= p_dt_fim
            AND (p_cd_dispositivos IS NULL OR d."cdDispositivo" = ANY(p_cd_dispositivos))
            AND (p_cd_cliente IS NULL OR d."cdCliente" = p_cd_cliente)
        GROUP BY EXTRACT(HOUR FROM sr."dtRegistro")
        ORDER BY time_period;
    ELSE
        -- Day of week aggregation (0-6, where 0=Sunday)
        RETURN QUERY
        SELECT 
            EXTRACT(DOW FROM sr."dtRegistro")::INTEGER as time_period,
            SUM(sr."nrValor")::BIGINT as total_value,
            COUNT(*)::BIGINT as record_count,
            MAX(sr."dtRegistro")::TIMESTAMP WITH TIME ZONE as last_read
        FROM "TbSensorRegistro" sr
        INNER JOIN "TbSensor" s ON sr."cdSensor" = s."cdSensor"
        INNER JOIN "TbDispositivo" d ON s."cdDispositivo" = d."cdDispositivo"
        WHERE s."cdTipoSensor" = 5  -- Movimento de Pessoas
            AND d."cdProduto" = p_cd_produto
            AND sr."dtRegistro" >= p_dt_inicio
            AND sr."dtRegistro" <= p_dt_fim
            AND (p_cd_dispositivos IS NULL OR d."cdDispositivo" = ANY(p_cd_dispositivos))
            AND (p_cd_cliente IS NULL OR d."cdCliente" = p_cd_cliente)
        GROUP BY EXTRACT(DOW FROM sr."dtRegistro")
        ORDER BY time_period;
    END IF;
END;
$$;
