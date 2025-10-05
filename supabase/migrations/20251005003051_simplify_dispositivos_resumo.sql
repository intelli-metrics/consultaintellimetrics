-- Simplified get_lista_dispositivos_resumo function
-- Returns only base device data without sensor aggregations
-- Sensor aggregations are now handled in Python code for better modularity

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
    "dsNomeProduto" "text"
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
        prod."dsNome" AS "dsNomeProduto"
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
        LEFT JOIN "public"."TbProduto" prod ON d."cdProduto" = prod."cdProduto"
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
