-- Replaces VwRelHistoricoDispositivoProduto + Python pandas processing
-- with a single efficient query using JOINs and conditional aggregation.
-- Returns paginated JSON: { data: [...], total, page, pageSize }

CREATE OR REPLACE FUNCTION get_historico_paginado(
    p_cd_cliente INTEGER DEFAULT NULL,
    p_cd_dispositivo INTEGER DEFAULT NULL,
    p_dt_registro_comeco TIMESTAMP DEFAULT NULL,
    p_dt_registro_fim TIMESTAMP DEFAULT NULL,
    p_page INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 20
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    v_offset INTEGER;
    v_total BIGINT;
    v_data JSON;
BEGIN
    v_offset := (p_page - 1) * p_page_size;

    -- Count query: lightweight, no sensor joins needed
    SELECT COUNT(DISTINCT p."cdPosicao")
    INTO v_total
    FROM "TbPosicao" p
    JOIN "TbDispositivo" d ON d."cdDispositivo" = p."cdDispositivo"
    WHERE
        (p_cd_cliente IS NULL OR d."cdCliente" = p_cd_cliente)
        AND (p_cd_dispositivo IS NULL OR p_cd_dispositivo = 0 OR d."cdDispositivo" = p_cd_dispositivo)
        AND (p_dt_registro_comeco IS NULL OR p."dtRegistro" >= p_dt_registro_comeco)
        AND (p_dt_registro_fim IS NULL OR p."dtRegistro" <= p_dt_registro_fim)
        -- Measurement time window filter
        AND (d."horarioMedicaoInicio" IS NULL OR
             (CASE
                WHEN d."horarioMedicaoInicio" > d."horarioMedicaoFim" THEN
                    CAST(p."dtRegistro" AS time) >= d."horarioMedicaoInicio"
                    OR CAST(p."dtRegistro" AS time) <= d."horarioMedicaoFim"
                ELSE
                    CAST(p."dtRegistro" AS time) >= d."horarioMedicaoInicio"
                    AND CAST(p."dtRegistro" AS time) <= d."horarioMedicaoFim"
             END));

    -- Data query: JOINs + conditional aggregation replace 14 correlated subqueries
    SELECT json_agg(row_data)
    INTO v_data
    FROM (
        SELECT
            pd."cdProduto",
            pd."nrCodigo",
            pd."dsDescricao",
            p."dtRegistro",
            d."cdDispositivo",
            dest."dsNome",
            e."dsLogradouro" AS "dsEndereco",
            CONCAT(
                (CASE
                    WHEN p."nrBat" > 3.7 THEN 3.7
                    ELSE p."nrBat"
                END / 3.7 * 100)::numeric(15, 2),
                '%'
            ) AS "nrBatPercentual",
            CASE
                WHEN p."blArea" = false THEN 'Fora de Área'
                ELSE 'Dentro da Área'
            END AS "dsStatus",
            d."cdStatus" AS "dsStatusDispositivo",
            p."cdPosicao",
            -- Sensor readings via conditional aggregation (replaces correlated subqueries)
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 2) AS "nrPorta",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 4) AS "nrTemperatura",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 5)::double precision AS "nrPessoas",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 9)::double precision AS "nrMasculino",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 10)::double precision AS "nrFeminino",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 11)::double precision AS "nrCrianca",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 12)::double precision AS "nrJovem",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 13)::double precision AS "nrAdulto",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 14)::double precision AS "nrSenior",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 15)::double precision AS "nrAlegre",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 16)::double precision AS "nrTriste",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 17)::double precision AS "nrNeutro",
            MAX(sr."nrValor") FILTER (WHERE s."cdTipoSensor" = 18)::double precision AS "nrCategoriaTotal"
        FROM "TbPosicao" p
        JOIN "TbDispositivo" d ON d."cdDispositivo" = p."cdDispositivo"
        JOIN "TbProduto" pd ON pd."cdProduto" = d."cdProduto"
        JOIN "TbDestinatario" dest ON dest."cdDestinatario" = d."cdDestinatario"
        JOIN "TbEndereco" e ON e."cdEndereco" = p."cdEndereco"
        LEFT JOIN "TbSensorRegistro" sr ON sr."cdPosicao" = p."cdPosicao"
            AND sr."cdDispositivo" = p."cdDispositivo"
        LEFT JOIN "TbSensor" s ON s."cdSensor" = sr."cdSensor"
        WHERE
            (p_cd_cliente IS NULL OR d."cdCliente" = p_cd_cliente)
            AND (p_cd_dispositivo IS NULL OR p_cd_dispositivo = 0 OR d."cdDispositivo" = p_cd_dispositivo)
            AND (p_dt_registro_comeco IS NULL OR p."dtRegistro" >= p_dt_registro_comeco)
            AND (p_dt_registro_fim IS NULL OR p."dtRegistro" <= p_dt_registro_fim)
            -- Measurement time window filter
            AND (d."horarioMedicaoInicio" IS NULL OR
                 (CASE
                    WHEN d."horarioMedicaoInicio" > d."horarioMedicaoFim" THEN
                        CAST(p."dtRegistro" AS time) >= d."horarioMedicaoInicio"
                        OR CAST(p."dtRegistro" AS time) <= d."horarioMedicaoFim"
                    ELSE
                        CAST(p."dtRegistro" AS time) >= d."horarioMedicaoInicio"
                        AND CAST(p."dtRegistro" AS time) <= d."horarioMedicaoFim"
                 END))
        GROUP BY
            p."cdPosicao",
            pd."cdProduto",
            pd."nrCodigo",
            pd."dsDescricao",
            p."dtRegistro",
            d."cdDispositivo",
            dest."dsNome",
            e."dsLogradouro",
            p."nrBat",
            p."blArea",
            d."cdStatus"
        ORDER BY p."dtRegistro" DESC
        LIMIT p_page_size
        OFFSET v_offset
    ) AS row_data;

    RETURN json_build_object(
        'data', COALESCE(v_data, '[]'::json),
        'total', v_total,
        'page', p_page,
        'pageSize', p_page_size
    );
END;
$$;
