CREATE OR REPLACE FUNCTION "public"."get_lista_dispositivos_resumo"(
    "dt_registro_inicio" timestamp without time zone DEFAULT NULL::timestamp without time zone,
    "dt_registro_fim" timestamp without time zone DEFAULT NULL::timestamp without time zone,
    "cd_status" "public"."status" DEFAULT NULL::"public"."status",
    "ds_uf" "text" DEFAULT NULL::"text",
    "bl_area" boolean DEFAULT NULL::boolean,
    "nr_bateria_min" double precision DEFAULT NULL::double precision,
    "nr_bateria_max" double precision DEFAULT NULL::double precision,
    "cd_cliente" integer DEFAULT NULL::integer,
    "cd_produto" integer DEFAULT NULL::integer
) RETURNS TABLE(
    "cdDispositivo" integer,
    "dsDispositivo" "text",
    "cdStatus" "public"."status",
    "dsLogradouro" "text",
    "nrNumero" "text",
    "dsComplemento" "text",
    "dsCidade" "text",
    "dsUF" "text",
    "blArea" boolean,
    "nrBat" double precision,
    "nrPorta" numeric,
    "nrPessoas" numeric,
    "nrTemp" numeric,
    "nrItens" integer
)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        d."cdDispositivo",
        d."dsDispositivo",
        d."cdStatus",
        e."dsLogradouro",
        e."nrNumero",
        e."dsComplemento",
        e."dsCidade",
        e."dsUF",
        p."blArea",
        p."nrBat",
        COALESCE(porta_sensor."nrPorta", 0) AS "nrPorta",
        COALESCE(pessoas_sensor."nrPessoas", 0) AS "nrPessoas",
        COALESCE(temp_sensor."nrTemp", 0) AS "nrTemp",
        COALESCE(peso_itens."nrItensPeso", 0) + COALESCE(distancia_itens."nrItensDistancia", 0) AS "nrItens"
    FROM
        "public"."TbDispositivo" d
        LEFT JOIN (
            SELECT DISTINCT ON (p."cdDispositivo") 
                p."cdDispositivo",
                p."blArea",
                p."nrBat"
            FROM "public"."TbPosicao" p
            ORDER BY p."cdDispositivo", p."dtRegistro" DESC
        ) p ON d."cdDispositivo" = p."cdDispositivo"
        LEFT JOIN "public"."TbDestinatario" dest ON d."cdDestinatario" = dest."cdDestinatario"
        LEFT JOIN "public"."TbEndereco" e ON dest."cdEndereco" = e."cdEndereco"
        LEFT JOIN (
            SELECT 
                sr."cdDispositivo",
                SUM(sr."nrValor") AS "nrPorta"
            FROM 
                "public"."TbSensorRegistro" sr
                JOIN "public"."TbSensor" s ON sr."cdSensor" = s."cdSensor"
            WHERE 
                s."cdTipoSensor" = 2
                AND (dt_registro_inicio IS NULL OR sr."dtRegistro" >= dt_registro_inicio)
                AND (dt_registro_fim IS NULL OR sr."dtRegistro" <= dt_registro_fim)
            GROUP BY 
                sr."cdDispositivo"
        ) porta_sensor ON d."cdDispositivo" = porta_sensor."cdDispositivo"
        LEFT JOIN (
            SELECT 
                sr."cdDispositivo",
                SUM(sr."nrValor") AS "nrPessoas"
            FROM 
                "public"."TbSensorRegistro" sr
                JOIN "public"."TbSensor" s ON sr."cdSensor" = s."cdSensor"
            WHERE 
                s."cdTipoSensor" = 5
                AND (dt_registro_inicio IS NULL OR sr."dtRegistro" >= dt_registro_inicio)
                AND (dt_registro_fim IS NULL OR sr."dtRegistro" <= dt_registro_fim)
            GROUP BY 
                sr."cdDispositivo"
        ) pessoas_sensor ON d."cdDispositivo" = pessoas_sensor."cdDispositivo"
        LEFT JOIN (
            SELECT 
                sr."cdDispositivo",
                AVG(sr."nrValor") AS "nrTemp"
            FROM 
                "public"."TbSensorRegistro" sr
                JOIN "public"."TbSensor" s ON sr."cdSensor" = s."cdSensor"
            WHERE 
                s."cdTipoSensor" = 4
                AND (dt_registro_inicio IS NULL OR sr."dtRegistro" >= dt_registro_inicio)
                AND (dt_registro_fim IS NULL OR sr."dtRegistro" <= dt_registro_fim)
            GROUP BY 
                sr."cdDispositivo"
        ) temp_sensor ON d."cdDispositivo" = temp_sensor."cdDispositivo"
        LEFT JOIN (
            SELECT 
                sr."cdDispositivo",
                AVG(CASE 
                    WHEN pi."nrPesoUnit" > 0 THEN sr."nrValor" / pi."nrPesoUnit"
                    ELSE 0 
                END)::integer AS "nrItensPeso"
            FROM 
                "public"."TbSensorRegistro" sr
                JOIN "public"."TbSensor" s ON sr."cdSensor" = s."cdSensor"
                JOIN "public"."TbDispositivo" d ON sr."cdDispositivo" = d."cdDispositivo"
                JOIN "public"."TbProduto" p ON d."cdProduto" = p."cdProduto"
                JOIN "public"."TbProdutoItemJoinTable" pijt ON p."cdProduto" = pijt."cdProduto"
                JOIN "public"."TbProdutoItem" pi ON pijt."cdProdutoItem" = pi."cdProdutoItem"
            WHERE 
                s."cdTipoSensor" = 3
                AND (dt_registro_inicio IS NULL OR sr."dtRegistro" >= dt_registro_inicio)
                AND (dt_registro_fim IS NULL OR sr."dtRegistro" <= dt_registro_fim)
            GROUP BY 
                sr."cdDispositivo"
        ) peso_itens ON d."cdDispositivo" = peso_itens."cdDispositivo"
        LEFT JOIN (
            SELECT 
                sr."cdDispositivo",
                AVG(CASE 
                    WHEN pi."nrAlt" > 0 THEN sr."nrValor" / pi."nrAlt"
                    ELSE 0 
                END)::integer AS "nrItensDistancia"
            FROM 
                "public"."TbSensorRegistro" sr
                JOIN "public"."TbSensor" s ON sr."cdSensor" = s."cdSensor"
                JOIN "public"."TbDispositivo" d ON sr."cdDispositivo" = d."cdDispositivo"
                JOIN "public"."TbProduto" p ON d."cdProduto" = p."cdProduto"
                JOIN "public"."TbProdutoItemJoinTable" pijt ON p."cdProduto" = pijt."cdProduto"
                JOIN "public"."TbProdutoItem" pi ON pijt."cdProdutoItem" = pi."cdProdutoItem"
            WHERE 
                s."cdTipoSensor" = 1
                AND (dt_registro_inicio IS NULL OR sr."dtRegistro" >= dt_registro_inicio)
                AND (dt_registro_fim IS NULL OR sr."dtRegistro" <= dt_registro_fim)
            GROUP BY 
                sr."cdDispositivo"
        ) distancia_itens ON d."cdDispositivo" = distancia_itens."cdDispositivo"
    WHERE
        (cd_status IS NULL OR d."cdStatus" = cd_status)
        AND (ds_uf IS NULL OR e."dsUF" = ds_uf)
        AND (bl_area IS NULL OR p."blArea" = bl_area)
        AND (nr_bateria_min IS NULL OR p."nrBat" >= nr_bateria_min)
        AND (nr_bateria_max IS NULL OR p."nrBat" <= nr_bateria_max)
        AND (cd_cliente IS NULL OR d."cdCliente" = cd_cliente)
        AND (cd_produto IS NULL OR d."cdProduto" = cd_produto);
END;
$$;

ALTER FUNCTION "public"."get_lista_dispositivos_resumo"("dt_registro_inicio" timestamp without time zone, "dt_registro_fim" timestamp without time zone, "cd_status" "public"."status", "ds_uf" "text", "bl_area" boolean, "nr_bateria_min" double precision, "nr_bateria_max" double precision, "cd_cliente" integer, "cd_produto" integer) OWNER TO "postgres"; 