

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "inventario";


ALTER SCHEMA "inventario" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "pgsodium";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "inventario"."statusInventario" AS ENUM (
    'em_progresso',
    'finalizado',
    'cancelado'
);


ALTER TYPE "inventario"."statusInventario" OWNER TO "postgres";


CREATE TYPE "public"."role" AS ENUM (
    'default',
    'admin',
    'service'
);


ALTER TYPE "public"."role" OWNER TO "postgres";


CREATE TYPE "public"."status" AS ENUM (
    'ativo',
    'inativo',
    'suspenso',
    'bloqueado',
    'encerrado',
    'estoque'
);


ALTER TYPE "public"."status" OWNER TO "postgres";


CREATE TYPE "public"."unidade" AS ENUM (
    'volts',
    'kilos',
    'gramas',
    'centimetros',
    'metros',
    'kilometros',
    'aberturas',
    'unidades',
    'temperatura',
    'pessoas'
);


ALTER TYPE "public"."unidade" OWNER TO "postgres";


COMMENT ON TYPE "public"."unidade" IS 'unidade de medida';



CREATE OR REPLACE FUNCTION "public"."get_cliente"("user_id" "uuid") RETURNS SETOF bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $_$select "cdCliente" from profiles where id = $1$_$;


ALTER FUNCTION "public"."get_cliente"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_cliente_e_filhos"("user_id" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    AS $_$SELECT c."cdCliente"
    FROM "TbCliente" c
    WHERE c."cdCliente" = (SELECT p."cdCliente" FROM profiles p WHERE p.id = $1)
    OR c."cdClientePai" = (SELECT p."cdCliente" FROM profiles p WHERE p.id = $1);$_$;


ALTER FUNCTION "public"."get_cliente_e_filhos"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_clientes_user"("user_id" "uuid") RETURNS integer[]
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$DECLARE
    cd_clientes int[];
BEGIN
    select array(SELECT c."cdCliente"
    FROM public."TbCliente" c
    WHERE c."cdCliente" = (SELECT p."cdCliente" FROM public.profiles p WHERE p.id = user_id)
    OR c."cdClientePai" = (SELECT p."cdCliente" FROM public.profiles p WHERE p.id = user_id)) INTO cd_clientes;
    
    IF cd_clientes IS NULL THEN
        RETURN ARRAY[]::UUID[];
    ELSE
        RETURN cd_clientes;
    END IF;
END;$$;


ALTER FUNCTION "public"."get_clientes_user"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_clientes_user_by_dispositivo"("user_id" "uuid") RETURNS integer[]
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
    dispositivo_ids int[];
BEGIN
    SELECT ARRAY(
        SELECT d."cdDispositivo"
        FROM public."TbDispositivo" d
        JOIN public."TbCliente" c ON d."cdCliente" = c."cdCliente"
        WHERE c."cdCliente" = (SELECT pr."cdCliente" FROM public.profiles pr WHERE pr.id = user_id)
        OR c."cdClientePai" = (SELECT pr."cdCliente" FROM public.profiles pr WHERE pr.id = user_id)
    ) INTO dispositivo_ids;
    
    IF dispositivo_ids IS NULL THEN
        RETURN ARRAY[]::UUID[];
    ELSE
        RETURN dispositivo_ids;
    END IF;
END;
$$;


ALTER FUNCTION "public"."get_clientes_user_by_dispositivo"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_clientes_user_by_produto"("user_id" "uuid") RETURNS integer[]
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
    produto_ids int[];
BEGIN
    SELECT ARRAY(
        SELECT p."cdProduto"
        FROM public."TbProduto" p
        JOIN public."TbCliente" c ON p."cdCliente" = c."cdCliente"
        WHERE c."cdCliente" = (SELECT pr."cdCliente" FROM public.profiles pr WHERE pr.id = user_id)
        OR c."cdClientePai" = (SELECT pr."cdCliente" FROM public.profiles pr WHERE pr.id = user_id)
    ) INTO produto_ids;
    
    IF produto_ids IS NULL THEN
        RETURN ARRAY[]::UUID[];
    ELSE
        RETURN produto_ids;
    END IF;
END;
$$;


ALTER FUNCTION "public"."get_clientes_user_by_produto"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_clientes_user_by_produto_item"("user_id" "uuid") RETURNS integer[]
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
    produto_item_ids int[];
BEGIN
    SELECT ARRAY(
        SELECT pi."cdProdutoItem"
        FROM public."TbProdutoItem" pi
        JOIN public."TbProdutoItemJoinTable" pijt ON pijt."cdProdutoItem" = pi."cdProdutoItem"
        JOIN public."TbProduto" p ON pijt."cdProduto" = p."cdProduto"
        JOIN public."TbCliente" c ON p."cdCliente" = c."cdCliente"
        WHERE c."cdCliente" = (SELECT pr."cdCliente" FROM public.profiles pr WHERE pr.id = user_id)
        OR c."cdClientePai" = (SELECT pr."cdCliente" FROM public.profiles pr WHERE pr.id = user_id)
    ) INTO produto_item_ids;
    
    IF produto_item_ids IS NULL THEN
        RETURN ARRAY[]::UUID[];
    ELSE
        RETURN produto_item_ids;
    END IF;
END;
$$;


ALTER FUNCTION "public"."get_clientes_user_by_produto_item"("user_id" "uuid") OWNER TO "postgres";


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
    WHERE
        v."cdDispositivo" = ANY(dispositivos)
        AND (dt_registro_comeco IS NULL OR v."dtRegistro" >= dt_registro_comeco)
        AND (dt_registro_fim IS NULL OR v."dtRegistro" <= dt_registro_fim)
        AND v."dsTipoSensor" IN ('Camera de movimento', 'Abertura de Porta', 'Temperatura')
    GROUP BY
        v."cdDispositivo", v."dsTipoSensor";
END;
$$;


ALTER FUNCTION "public"."get_grouped_sensor_data"("dispositivos" integer[], "dt_registro_comeco" timestamp without time zone, "dt_registro_fim" timestamp without time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_lista_dispositivos_resumo"("dt_registro_inicio" timestamp without time zone DEFAULT NULL::timestamp without time zone, "dt_registro_fim" timestamp without time zone DEFAULT NULL::timestamp without time zone, "cd_status" "public"."status" DEFAULT NULL::"public"."status", "ds_uf" "text" DEFAULT NULL::"text", "bl_area" boolean DEFAULT NULL::boolean, "nr_bateria_min" double precision DEFAULT NULL::double precision, "nr_bateria_max" double precision DEFAULT NULL::double precision, "cd_cliente" integer DEFAULT NULL::integer) RETURNS TABLE("cdDispositivo" integer, "dsDispositivo" "text", "cdStatus" "public"."status", "dsLogradouro" "text", "nrNumero" "text", "dsComplemento" "text", "dsCidade" "text", "dsUF" "text", "blArea" boolean, "nrBat" double precision, "nrPorta" numeric, "nrPessoas" numeric, "nrTemp" numeric, "nrItens" integer)
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
        AND (cd_cliente IS NULL OR d."cdCliente" = cd_cliente);
END;
$$;


ALTER FUNCTION "public"."get_lista_dispositivos_resumo"("dt_registro_inicio" timestamp without time zone, "dt_registro_fim" timestamp without time zone, "cd_status" "public"."status", "ds_uf" "text", "bl_area" boolean, "nr_bateria_min" double precision, "nr_bateria_max" double precision, "cd_cliente" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.profiles (id, nome, sobrenome, cargo,"cdCliente", "cdChave")
  values (new.id, new.raw_user_meta_data ->> 'nome', new.raw_user_meta_data ->> 'sobrenome', new.raw_user_meta_data ->> 'cargo', (new.raw_user_meta_data ->> 'cdCliente')::integer, (new.raw_user_meta_data ->> 'cdChave')::integer);
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "inventario"."armazem" (
    "cdArmazem" bigint NOT NULL,
    "dtRegistro" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nome" "text",
    "cdCliente" integer NOT NULL
);


ALTER TABLE "inventario"."armazem" OWNER TO "postgres";


ALTER TABLE "inventario"."armazem" ALTER COLUMN "cdArmazem" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "inventario"."armazem_cdArmazem_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "inventario"."inventario" (
    "cdInventario" bigint NOT NULL,
    "cdArmazem" bigint NOT NULL,
    "dtComeco" timestamp with time zone DEFAULT "now"() NOT NULL,
    "dtFim" timestamp with time zone,
    "statusInventario" "inventario"."statusInventario" DEFAULT 'em_progresso'::"inventario"."statusInventario" NOT NULL,
    "dtCancelado" timestamp with time zone
);


ALTER TABLE "inventario"."inventario" OWNER TO "postgres";


COMMENT ON TABLE "inventario"."inventario" IS 'status e dados de inventarios. Agrupa leituras.';



ALTER TABLE "inventario"."inventario" ALTER COLUMN "cdInventario" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "inventario"."inventario_cdInventario_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "inventario"."leituras" (
    "id" bigint NOT NULL,
    "dtRegistro" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tipoDado" character varying,
    "dadoLeitura" character varying,
    "cdSessao" bigint NOT NULL,
    "idLeitura" "uuid",
    "blVazio" boolean DEFAULT false NOT NULL,
    "cdInventario" bigint
);


ALTER TABLE "inventario"."leituras" OWNER TO "postgres";


COMMENT ON TABLE "inventario"."leituras" IS 'Leitura de qr code ou codigo de barras';



COMMENT ON COLUMN "inventario"."leituras"."blVazio" IS 'true se local estiver vazio';



COMMENT ON COLUMN "inventario"."leituras"."cdInventario" IS 'linka cada leitura a um inventario';



ALTER TABLE "inventario"."leituras" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "inventario"."leituras_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "inventario"."prateleira" (
    "cdPrateleira" bigint NOT NULL,
    "nome" "text" NOT NULL,
    "cdRua" bigint NOT NULL,
    "dtRegistro" timestamp with time zone DEFAULT "now"() NOT NULL,
    "position" integer NOT NULL
);


ALTER TABLE "inventario"."prateleira" OWNER TO "postgres";


ALTER TABLE "inventario"."prateleira" ALTER COLUMN "cdPrateleira" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "inventario"."prateleira_cdPrateleira_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "inventario"."rua" (
    "cdRua" bigint NOT NULL,
    "dtRegistro" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nome" "text" NOT NULL,
    "cdArmazem" bigint NOT NULL,
    "position" integer NOT NULL
);


ALTER TABLE "inventario"."rua" OWNER TO "postgres";


ALTER TABLE "inventario"."rua" ALTER COLUMN "cdRua" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "inventario"."rua_cdRua_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "inventario"."sessao" (
    "cdSessao" bigint NOT NULL,
    "nome" "text" NOT NULL,
    "cdPrateleira" bigint NOT NULL,
    "dtRegistro" timestamp with time zone DEFAULT "now"() NOT NULL,
    "position" integer NOT NULL
);


ALTER TABLE "inventario"."sessao" OWNER TO "postgres";


ALTER TABLE "inventario"."sessao" ALTER COLUMN "cdSessao" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "inventario"."sessao_cdSessao_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."TbApiKeys" (
    "cdApiKey" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cdUsuario" "uuid" NOT NULL,
    "dsKey" "text" NOT NULL,
    "dsNome" "text",
    "cdClientes" integer[],
    "blAtiva" boolean DEFAULT true NOT NULL,
    "dtRegistro" timestamp with time zone DEFAULT "now"(),
    "dtExpiracao" timestamp with time zone,
    "dsPermissoes" "text"[] DEFAULT ARRAY['read'::"text"]
);


ALTER TABLE "public"."TbApiKeys" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TbCliente" (
    "cdCliente" integer NOT NULL,
    "dsNome" "text",
    "nrCnpj" "text",
    "nrIe" "text",
    "nrInscMun" "text",
    "dsLogradouro" "text",
    "nrNumero" "text",
    "dsComplemento" "text",
    "dsBairro" "text",
    "dsCep" "text",
    "dsCidade" "text",
    "dsUF" "text",
    "dsObs" "text",
    "cdStatus" "public"."status",
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "cdClientePai" integer
);


ALTER TABLE "public"."TbCliente" OWNER TO "postgres";


COMMENT ON COLUMN "public"."TbCliente"."cdClientePai" IS 'cdCliente id que é o Cliente "pai" desse';



CREATE TABLE IF NOT EXISTS "public"."TbClienteChave" (
    "id" bigint NOT NULL,
    "dsChave" "text" NOT NULL,
    "dtRegistro" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nrLimite" integer DEFAULT 999 NOT NULL,
    "cdCliente" integer NOT NULL
);


ALTER TABLE "public"."TbClienteChave" OWNER TO "postgres";


COMMENT ON TABLE "public"."TbClienteChave" IS 'Chaves de acesso para cadastro dos clientes';



ALTER TABLE "public"."TbClienteChave" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."TbClienteChave_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE SEQUENCE IF NOT EXISTS "public"."TbCliente_cdCliente_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbCliente_cdCliente_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbCliente_cdCliente_seq" OWNED BY "public"."TbCliente"."cdCliente";



CREATE TABLE IF NOT EXISTS "public"."TbDestinatario" (
    "cdDestinatario" integer NOT NULL,
    "dsNome" "text",
    "nrCnpj" "text",
    "nrIe" "text",
    "nrInscMun" "text",
    "dsObs" "text",
    "cdStatus" "public"."status",
    "nrRaio" double precision,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cdCliente" integer,
    "cdEndereco" integer
);


ALTER TABLE "public"."TbDestinatario" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbDestinatario_cdDestinatario_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbDestinatario_cdDestinatario_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbDestinatario_cdDestinatario_seq" OWNED BY "public"."TbDestinatario"."cdDestinatario";



CREATE TABLE IF NOT EXISTS "public"."TbDispositivo" (
    "cdDispositivo" integer NOT NULL,
    "dsDispositivo" "text",
    "dsModelo" integer,
    "dsDescricao" "text",
    "dsObs" "text",
    "dsLayout" "text",
    "nrChip" bigint,
    "cdStatus" "public"."status",
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cdDestinatario" integer,
    "cdProduto" integer,
    "cdCliente" integer
);


ALTER TABLE "public"."TbDispositivo" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbDispositivo_cdDispositivo_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbDispositivo_cdDispositivo_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbDispositivo_cdDispositivo_seq" OWNED BY "public"."TbDispositivo"."cdDispositivo";



CREATE TABLE IF NOT EXISTS "public"."TbEndereco" (
    "cdEndereco" integer NOT NULL,
    "dsLogradouro" "text",
    "nrNumero" "text",
    "dsComplemento" "text",
    "dsBairro" "text",
    "dsCep" "text",
    "dsCidade" "text",
    "dsUF" "text",
    "dsLat" character varying(45) DEFAULT NULL::character varying,
    "dsLong" character varying(45) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE "public"."TbEndereco" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbEndereco_cdEndereco_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbEndereco_cdEndereco_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbEndereco_cdEndereco_seq" OWNED BY "public"."TbEndereco"."cdEndereco";



CREATE TABLE IF NOT EXISTS "public"."TbEstado" (
    "cdEstadoIBGE" integer NOT NULL,
    "dsUf" character varying(2) DEFAULT NULL::character varying,
    "dsEstado" character varying(20) DEFAULT NULL::character varying
);


ALTER TABLE "public"."TbEstado" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TbImagens" (
    "cdImagens" integer NOT NULL,
    "dsCaminho" character varying(200) NOT NULL,
    "cdCodigo" character varying(20) NOT NULL,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "cdProduto" integer,
    "nrImagem" integer
);


ALTER TABLE "public"."TbImagens" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbImagens_cdImagens_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbImagens_cdImagens_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbImagens_cdImagens_seq" OWNED BY "public"."TbImagens"."cdImagens";



CREATE TABLE IF NOT EXISTS "public"."TbMunicipio" (
    "cdMunicipioIBGE" character varying(5) NOT NULL,
    "cdEstadoIBGE" integer NOT NULL,
    "cdMunicipioCompleto" character varying(7) DEFAULT NULL::character varying,
    "dsMunicipio" character varying(60) DEFAULT NULL::character varying
);


ALTER TABLE "public"."TbMunicipio" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TbPosicao" (
    "cdPosicao" integer NOT NULL,
    "nrBat" double precision,
    "nrSeq" integer,
    "cdDispositivo" integer,
    "blArea" boolean,
    "nrDistancia" real,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "cdDestinatario" integer,
    "cdEndereco" integer
);


ALTER TABLE "public"."TbPosicao" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbPosicao_cdPosicao_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbPosicao_cdPosicao_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbPosicao_cdPosicao_seq" OWNED BY "public"."TbPosicao"."cdPosicao";



CREATE TABLE IF NOT EXISTS "public"."TbProduto" (
    "cdProduto" integer NOT NULL,
    "dsNome" "text",
    "dsDescricao" "text",
    "nrCodigo" "text",
    "nrLarg" double precision,
    "nrComp" double precision,
    "nrAlt" double precision,
    "cdStatus" "public"."status",
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "cdCliente" integer
);


ALTER TABLE "public"."TbProduto" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TbProdutoItem" (
    "cdProdutoItem" integer NOT NULL,
    "dsNome" character varying(200) DEFAULT NULL::character varying,
    "dsDescricao" character varying(200) DEFAULT NULL::character varying,
    "nrCodigo" character varying(45) DEFAULT NULL::character varying,
    "nrLarg" double precision,
    "nrComp" double precision,
    "nrAlt" double precision,
    "nrPesoUnit" double precision,
    "nrUnidade" character varying(20) DEFAULT NULL::character varying,
    "nrEmpilhamento" integer,
    "nrLastro" integer,
    "nrQtdeTotalSensor" integer,
    "cdStatus" "public"."status",
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."TbProdutoItem" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TbProdutoItemJoinTable" (
    "cdProdutoItem" integer NOT NULL,
    "cdProduto" integer NOT NULL
);


ALTER TABLE "public"."TbProdutoItemJoinTable" OWNER TO "postgres";


COMMENT ON TABLE "public"."TbProdutoItemJoinTable" IS 'Faz o relacionamento muitos-muitos entre produto e produtoItem';



CREATE SEQUENCE IF NOT EXISTS "public"."TbProdutoItem_cdProdutoItem_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbProdutoItem_cdProdutoItem_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbProdutoItem_cdProdutoItem_seq" OWNED BY "public"."TbProdutoItem"."cdProdutoItem";



CREATE SEQUENCE IF NOT EXISTS "public"."TbProduto_cdProduto_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbProduto_cdProduto_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbProduto_cdProduto_seq" OWNED BY "public"."TbProduto"."cdProduto";



CREATE TABLE IF NOT EXISTS "public"."TbSensor" (
    "cdSensor" integer NOT NULL,
    "cdDispositivo" integer NOT NULL,
    "cdProdutoItem" integer,
    "cdUnidade" "public"."unidade",
    "nrUnidadeIni" integer,
    "nrUnidadeFim" integer,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "cdTipoSensor" bigint NOT NULL
);


ALTER TABLE "public"."TbSensor" OWNER TO "postgres";


COMMENT ON TABLE "public"."TbSensor" IS 'detalha sensores fisicos que existem em um dispositivo, com detalhes especificos a esse sensor';



CREATE TABLE IF NOT EXISTS "public"."TbSensorRegistro" (
    "cdDispositivo" integer NOT NULL,
    "cdSensor" integer NOT NULL,
    "cdPosicao" integer NOT NULL,
    "cdProdutoItem" integer,
    "nrValor" numeric(10,3) DEFAULT NULL::numeric,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."TbSensorRegistro" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbSensor_cdSensor_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbSensor_cdSensor_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbSensor_cdSensor_seq" OWNED BY "public"."TbSensor"."cdSensor";



CREATE TABLE IF NOT EXISTS "public"."TbTipoSensor" (
    "id" bigint NOT NULL,
    "dsNome" "text" NOT NULL,
    "dsDescricao" "text",
    "dtRegistro" timestamp with time zone DEFAULT "now"() NOT NULL,
    "dsUnidade" "text"
);


ALTER TABLE "public"."TbTipoSensor" OWNER TO "postgres";


COMMENT ON TABLE "public"."TbTipoSensor" IS 'Detalhes dos tipos de sensores que usamos';



COMMENT ON COLUMN "public"."TbTipoSensor"."dsUnidade" IS 'unidade de medida que o sensor lê';



ALTER TABLE "public"."TbTipoSensor" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."TbTipoSensor_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."VwProdutoCompleto" WITH ("security_invoker"='true') AS
 SELECT "p"."cdProduto",
    "p"."dsNome" AS "dsNomeProduto",
    "p"."cdStatus" AS "cdStatusProduto",
    "p"."dtRegistro" AS "dtRegistroProduto",
    "p"."cdCliente",
    "img"."dsCaminho" AS "dsCaminhoImagem",
    "img"."cdCodigo" AS "cdCodigoImagem",
    "img"."nrImagem",
    ( SELECT "string_agg"(DISTINCT "ts2"."dsNome", ', '::"text" ORDER BY "ts2"."dsNome") AS "string_agg"
           FROM (("public"."TbDispositivo" "d2"
             LEFT JOIN "public"."TbSensor" "s2" ON (("d2"."cdDispositivo" = "s2"."cdDispositivo")))
             LEFT JOIN "public"."TbTipoSensor" "ts2" ON (("s2"."cdTipoSensor" = "ts2"."id")))
          WHERE ("d2"."cdProduto" = "p"."cdProduto")) AS "dsTiposSensores",
    "count"(
        CASE
            WHEN ("d"."cdStatus" = 'ativo'::"public"."status") THEN 1
            ELSE NULL::integer
        END) AS "nrDispositivosAtivos",
    "count"(
        CASE
            WHEN ("d"."cdStatus" = 'inativo'::"public"."status") THEN 1
            ELSE NULL::integer
        END) AS "nrDispositivosInativos",
    "count"(
        CASE
            WHEN ("d"."cdStatus" = 'suspenso'::"public"."status") THEN 1
            ELSE NULL::integer
        END) AS "nrDispositivosSuspensos",
    "count"(
        CASE
            WHEN ("d"."cdStatus" = 'bloqueado'::"public"."status") THEN 1
            ELSE NULL::integer
        END) AS "nrDispositivosBloqueados",
    "count"(
        CASE
            WHEN ("d"."cdStatus" = 'encerrado'::"public"."status") THEN 1
            ELSE NULL::integer
        END) AS "nrDispositivosEncerrados",
    "count"(
        CASE
            WHEN ("d"."cdStatus" = 'estoque'::"public"."status") THEN 1
            ELSE NULL::integer
        END) AS "nrDispositivosEstoque",
    "count"(
        CASE
            WHEN ("d"."cdStatus" IS NULL) THEN 1
            ELSE NULL::integer
        END) AS "nrDispositivosSemStatus",
    "count"("d"."cdDispositivo") AS "nrTotalDispositivos"
   FROM (("public"."TbProduto" "p"
     LEFT JOIN "public"."TbImagens" "img" ON ((("p"."cdProduto" = "img"."cdProduto") AND ("img"."nrImagem" = ( SELECT "min"("img2"."nrImagem") AS "min"
           FROM "public"."TbImagens" "img2"
          WHERE ("img2"."cdProduto" = "p"."cdProduto"))))))
     JOIN "public"."TbDispositivo" "d" ON (("p"."cdProduto" = "d"."cdProduto")))
  GROUP BY "p"."cdProduto", "p"."dsNome", "p"."cdStatus", "p"."dtRegistro", "p"."cdCliente", "img"."dsCaminho", "img"."cdCodigo", "img"."nrImagem"
  ORDER BY "p"."dsNome";


ALTER TABLE "public"."VwProdutoCompleto" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."VwProdutosFora" WITH ("security_invoker"='true') AS
 SELECT "pr"."cdProduto",
    "count"(*) AS "dispositivo_count"
   FROM (("public"."TbPosicao" "ps"
     JOIN "public"."TbDispositivo" "d" ON (("d"."cdDispositivo" = "ps"."cdDispositivo")))
     JOIN "public"."TbProduto" "pr" ON (("pr"."cdProduto" = "d"."cdProduto")))
  WHERE (("ps"."blArea" = false) AND ("ps"."dtRegistro" IN ( SELECT "max"("TbPosicao"."dtRegistro") AS "max"
           FROM "public"."TbPosicao"
          GROUP BY "TbPosicao"."cdDispositivo")))
  GROUP BY "pr"."cdProduto"
  ORDER BY "pr"."cdProduto";


ALTER TABLE "public"."VwProdutosFora" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."VwTbPosicaoAtual" WITH ("security_invoker"='true') AS
 SELECT "A"."cdPosicao",
    "A"."dtRegistro",
    "A"."cdDispositivo",
    "en"."dsLat",
    "en"."dsLong",
    "en"."dsLogradouro" AS "dsEndereco",
    "en"."nrNumero" AS "dsNum",
    "en"."dsCep",
    "en"."dsBairro",
    "en"."dsCidade",
    "en"."dsUF",
    "A"."nrBat",
    "B"."nrCodigo",
    "B"."cdProduto",
    "B"."dsNome" AS "dsProduto",
    "B"."dsDescricao",
    "E"."cdStatus",
    "A"."blArea",
    "E"."cdCliente"
   FROM (((("public"."TbPosicao" "A"
     JOIN "public"."TbEndereco" "en" ON (("en"."cdEndereco" = "A"."cdEndereco")))
     JOIN "public"."TbDispositivo" "E" ON (("A"."cdDispositivo" = "E"."cdDispositivo")))
     JOIN "public"."TbProduto" "B" ON (("E"."cdProduto" = "B"."cdProduto")))
     JOIN ( SELECT "max"("TbPosicao"."cdPosicao") AS "cdPosicao"
           FROM "public"."TbPosicao"
          GROUP BY "TbPosicao"."cdDispositivo") "D" ON (("A"."cdPosicao" = "D"."cdPosicao")));


ALTER TABLE "public"."VwTbPosicaoAtual" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."VwRelDadosDispositivo" WITH ("security_invoker"='true') AS
 SELECT "A"."cdProduto",
    "A"."dsNome",
    "C"."cdDispositivo",
    (((
        CASE
            WHEN ("C"."nrBat" > (3.7)::double precision) THEN (3.7)::double precision
            ELSE "C"."nrBat"
        END / (3.7)::double precision) * (100)::double precision))::numeric(15,2) AS "nrBat",
    "E"."dsNome" AS "dsNomeDest",
    "endereco"."dsLogradouro" AS "dsEnderecoDest",
    "endereco"."nrNumero" AS "nrNumeroDest",
    "endereco"."dsBairro" AS "dsBairroDest",
    "endereco"."dsCidade" AS "dsCidadeDest",
    "endereco"."dsUF" AS "dsUfDest",
    "endereco"."dsCep" AS "dsCepDest",
    "endereco"."dsLat" AS "dsLatDest",
    "endereco"."dsLong" AS "dsLongDest",
    "E"."nrRaio" AS "dsRaio",
    "C"."dsEndereco" AS "dsEnderecoAtual",
    "C"."dsNum" AS "dsNumeroAtual",
    "C"."dsBairro" AS "dsBairroAtual",
    "C"."dsCidade" AS "dsCidadeAtual",
    "C"."dsUF" AS "dsUFAtual",
    "C"."dsCep" AS "dsCEPAtual",
    "C"."dsLat" AS "dsLatAtual",
    "C"."dsLong" AS "dsLongAtual",
    "C"."blArea",
    "C"."dtRegistro",
    "F"."dtRegistro" AS "dtCadastro",
    "F"."cdCliente"
   FROM (((("public"."TbProduto" "A"
     JOIN "public"."TbDispositivo" "F" ON (("F"."cdProduto" = "A"."cdProduto")))
     JOIN "public"."VwTbPosicaoAtual" "C" ON (("F"."cdDispositivo" = "C"."cdDispositivo")))
     JOIN "public"."TbDestinatario" "E" ON (("F"."cdDestinatario" = "E"."cdDestinatario")))
     JOIN "public"."TbEndereco" "endereco" ON (("E"."cdEndereco" = "endereco"."cdEndereco")));


ALTER TABLE "public"."VwRelDadosDispositivo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."VwRelHistoricoDispositivoProduto" AS
 SELECT "pd"."cdProduto",
    "pd"."cdCliente",
    "pd"."nrCodigo",
    "pd"."dsDescricao",
    "p"."dtRegistro",
    "d"."cdDispositivo",
    "dest"."dsNome",
    "e"."dsLogradouro" AS "dsEndereco",
    "s"."cdSensor",
    "concat"((((
        CASE
            WHEN ("p"."nrBat" > (3.7)::double precision) THEN (3.7)::double precision
            ELSE "p"."nrBat"
        END / (3.7)::double precision) * (100)::double precision))::numeric(15,2), '%') AS "nrBatPercentual",
    ( SELECT "srr"."nrValor"
           FROM (("public"."TbSensorRegistro" "srr"
             JOIN "public"."TbSensor" "ts_1" ON (("ts_1"."cdSensor" = "srr"."cdSensor")))
             JOIN "public"."TbTipoSensor" "tts" ON (("ts_1"."cdTipoSensor" = "tts"."id")))
          WHERE (("srr"."cdDispositivo" = "p"."cdDispositivo") AND ("srr"."cdPosicao" = "p"."cdPosicao") AND ("tts"."id" = 2))) AS "nrPorta",
    ( SELECT "srr"."nrValor"
           FROM (("public"."TbSensorRegistro" "srr"
             JOIN "public"."TbSensor" "ts_1" ON (("ts_1"."cdSensor" = "srr"."cdSensor")))
             JOIN "public"."TbTipoSensor" "tts" ON (("ts_1"."cdTipoSensor" = "tts"."id")))
          WHERE (("srr"."cdDispositivo" = "p"."cdDispositivo") AND ("srr"."cdPosicao" = "p"."cdPosicao") AND ("tts"."id" = 4))) AS "nrTemperatura",
    (( SELECT "srr"."nrValor"
           FROM (("public"."TbSensorRegistro" "srr"
             JOIN "public"."TbSensor" "ts_1" ON (("ts_1"."cdSensor" = "srr"."cdSensor")))
             JOIN "public"."TbTipoSensor" "tts" ON (("ts_1"."cdTipoSensor" = "tts"."id")))
          WHERE (("srr"."cdDispositivo" = "p"."cdDispositivo") AND ("srr"."cdPosicao" = "p"."cdPosicao") AND ("ts_1"."cdSensor" = "s"."cdSensor") AND ("tts"."id" = 5))))::double precision AS "nrPessoas",
    "pi"."dsNome" AS "dsProdutoItem",
    (( SELECT "srr"."nrValor"
           FROM (("public"."TbSensorRegistro" "srr"
             JOIN "public"."TbSensor" "ts_1" ON (("ts_1"."cdSensor" = "srr"."cdSensor")))
             JOIN "public"."TbTipoSensor" "tts" ON (("ts_1"."cdTipoSensor" = "tts"."id")))
          WHERE (("srr"."cdDispositivo" = "p"."cdDispositivo") AND ("srr"."cdPosicao" = "p"."cdPosicao") AND ("tts"."id" = 1) AND ("pi"."cdProdutoItem" = "ts_1"."cdProdutoItem"))))::double precision AS "nrQtdItens",
    ("sr"."nrValor")::double precision AS "nrLeituraSensor",
    "ts"."dsNome" AS "dsTipoSensor",
    "ts"."dsUnidade" AS "dsUnidadeMedida",
        CASE
            WHEN ("p"."blArea" = false) THEN 'Fora de Área'::"text"
            ELSE 'Dentro da Área'::"text"
        END AS "dsStatus",
    "d"."cdStatus" AS "dsStatusDispositivo",
    "pi"."nrPesoUnit" AS "nrPesoUnitario",
    "pi"."nrLarg",
    "pi"."nrComp",
    "pi"."nrAlt",
    "s"."nrUnidadeIni",
    "s"."nrUnidadeFim",
    "p"."cdPosicao"
   FROM (((((((("public"."TbSensor" "s"
     LEFT JOIN "public"."TbProdutoItem" "pi" ON (("s"."cdProdutoItem" = "pi"."cdProdutoItem")))
     JOIN "public"."TbDispositivo" "d" ON (("d"."cdDispositivo" = "s"."cdDispositivo")))
     JOIN "public"."TbSensorRegistro" "sr" ON (("sr"."cdSensor" = "s"."cdSensor")))
     JOIN "public"."TbTipoSensor" "ts" ON (("ts"."id" = "s"."cdTipoSensor")))
     JOIN "public"."TbPosicao" "p" ON (("p"."cdPosicao" = "sr"."cdPosicao")))
     JOIN "public"."TbEndereco" "e" ON (("e"."cdEndereco" = "p"."cdEndereco")))
     JOIN "public"."TbDestinatario" "dest" ON (("dest"."cdDestinatario" = "d"."cdDestinatario")))
     JOIN "public"."TbProduto" "pd" ON (("pd"."cdProduto" = "d"."cdProduto")))
  ORDER BY "p"."dtRegistro" DESC;


ALTER TABLE "public"."VwRelHistoricoDispositivoProduto" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."VwTbDestinatarioDispositivo" WITH ("security_invoker"='true') AS
 SELECT "a"."cdDestinatario",
    "e"."dsLat",
    "e"."dsLong",
    "a"."nrRaio",
    "b"."cdDispositivo",
    "b"."cdCliente"
   FROM (("public"."TbDestinatario" "a"
     JOIN "public"."TbDispositivo" "b" ON (("a"."cdDestinatario" = "b"."cdDestinatario")))
     JOIN "public"."TbEndereco" "e" ON (("e"."cdEndereco" = "a"."cdEndereco")));


ALTER TABLE "public"."VwTbDestinatarioDispositivo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."VwTbProdutoTipo" AS
SELECT
    NULL::integer AS "cdProduto",
    NULL::"text" AS "dsNome",
    NULL::"text" AS "dsDescricao",
    NULL::"text" AS "nrCodigo",
    NULL::double precision AS "nrLarg",
    NULL::double precision AS "nrComp",
    NULL::double precision AS "nrAlt",
    NULL::"public"."status" AS "cdStatus",
    NULL::integer AS "cdDispositivo",
    NULL::"text" AS "dsDispositivo",
    NULL::integer AS "dsModelo",
    NULL::"text" AS "DescDispositivo",
    NULL::"text" AS "dsObs",
    NULL::"text" AS "dsLayout",
    NULL::bigint AS "nrChip",
    NULL::"public"."status" AS "StatusDispositivo",
    NULL::integer AS "cdCliente";


ALTER TABLE "public"."VwTbProdutoTipo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."VwTbProdutoTotal" WITH ("security_invoker"='true') AS
 SELECT "VwTbProdutoTipo"."dsNome",
    "VwTbProdutoTipo"."cdProduto",
    "VwTbProdutoTipo"."dsDescricao",
    "VwTbProdutoTipo"."nrCodigo",
    "VwTbProdutoTipo"."nrLarg",
    "VwTbProdutoTipo"."nrComp",
    "VwTbProdutoTipo"."nrAlt",
    "count"("VwTbProdutoTipo"."cdProduto") AS "nrQtde",
    "VwTbProdutoTipo"."cdCliente"
   FROM "public"."VwTbProdutoTipo"
  GROUP BY "VwTbProdutoTipo"."cdProduto", "VwTbProdutoTipo"."dsNome", "VwTbProdutoTipo"."dsDescricao", "VwTbProdutoTipo"."nrCodigo", "VwTbProdutoTipo"."nrLarg", "VwTbProdutoTipo"."nrComp", "VwTbProdutoTipo"."nrAlt", "VwTbProdutoTipo"."dsDispositivo", "VwTbProdutoTipo"."dsModelo", "VwTbProdutoTipo"."cdCliente";


ALTER TABLE "public"."VwTbProdutoTotal" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."VwTbProdutoTotalStatus" WITH ("security_invoker"='true') AS
 SELECT "VwTbProdutoTipo"."cdProduto",
    "VwTbProdutoTipo"."dsNome",
    "VwTbProdutoTipo"."dsDescricao",
    "VwTbProdutoTipo"."nrCodigo",
    "VwTbProdutoTipo"."nrLarg",
    "VwTbProdutoTipo"."nrComp",
    "VwTbProdutoTipo"."nrAlt",
    "VwTbProdutoTipo"."StatusDispositivo",
    "count"("VwTbProdutoTipo"."StatusDispositivo") AS "nrQtde",
    "c"."nrQtde" AS "QtdeTotal",
    "VwTbProdutoTipo"."cdCliente"
   FROM ("public"."VwTbProdutoTipo"
     LEFT JOIN "public"."VwTbProdutoTotal" "c" ON (("VwTbProdutoTipo"."cdProduto" = "c"."cdProduto")))
  GROUP BY "c"."nrQtde", "VwTbProdutoTipo"."StatusDispositivo", "VwTbProdutoTipo"."cdProduto", "VwTbProdutoTipo"."dsNome", "VwTbProdutoTipo"."dsDescricao", "VwTbProdutoTipo"."nrCodigo", "VwTbProdutoTipo"."nrLarg", "VwTbProdutoTipo"."nrComp", "VwTbProdutoTipo"."nrAlt", "VwTbProdutoTipo"."dsDispositivo", "VwTbProdutoTipo"."dsModelo", "VwTbProdutoTipo"."DescDispositivo", "VwTbProdutoTipo"."cdCliente";


ALTER TABLE "public"."VwTbProdutoTotalStatus" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "nome" "text",
    "sobrenome" "text",
    "cargo" "text",
    "cdChave" bigint,
    "cdCliente" integer,
    "dtRegistro" timestamp with time zone DEFAULT "now"() NOT NULL,
    "role" "public"."role" DEFAULT 'default'::"public"."role"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."cdChave" IS 'chave convite usada para cadastro';



COMMENT ON COLUMN "public"."profiles"."cdCliente" IS 'cliente vinculado com o usuario';



COMMENT ON COLUMN "public"."profiles"."dtRegistro" IS 'data que o usuario fez cadastro';



ALTER TABLE ONLY "public"."TbCliente" ALTER COLUMN "cdCliente" SET DEFAULT "nextval"('"public"."TbCliente_cdCliente_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbDestinatario" ALTER COLUMN "cdDestinatario" SET DEFAULT "nextval"('"public"."TbDestinatario_cdDestinatario_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbDispositivo" ALTER COLUMN "cdDispositivo" SET DEFAULT "nextval"('"public"."TbDispositivo_cdDispositivo_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbEndereco" ALTER COLUMN "cdEndereco" SET DEFAULT "nextval"('"public"."TbEndereco_cdEndereco_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbImagens" ALTER COLUMN "cdImagens" SET DEFAULT "nextval"('"public"."TbImagens_cdImagens_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbPosicao" ALTER COLUMN "cdPosicao" SET DEFAULT "nextval"('"public"."TbPosicao_cdPosicao_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbProduto" ALTER COLUMN "cdProduto" SET DEFAULT "nextval"('"public"."TbProduto_cdProduto_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbProdutoItem" ALTER COLUMN "cdProdutoItem" SET DEFAULT "nextval"('"public"."TbProdutoItem_cdProdutoItem_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbSensor" ALTER COLUMN "cdSensor" SET DEFAULT "nextval"('"public"."TbSensor_cdSensor_seq"'::"regclass");



ALTER TABLE ONLY "inventario"."armazem"
    ADD CONSTRAINT "armazem_cdArmazem_key" UNIQUE ("cdArmazem");



ALTER TABLE ONLY "inventario"."armazem"
    ADD CONSTRAINT "armazem_pkey" PRIMARY KEY ("cdArmazem");



ALTER TABLE ONLY "inventario"."inventario"
    ADD CONSTRAINT "inventario_pkey" PRIMARY KEY ("cdInventario");



ALTER TABLE ONLY "inventario"."leituras"
    ADD CONSTRAINT "leituras_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "inventario"."prateleira"
    ADD CONSTRAINT "prateleira_pkey" PRIMARY KEY ("cdPrateleira");



ALTER TABLE ONLY "inventario"."rua"
    ADD CONSTRAINT "rua_pkey" PRIMARY KEY ("cdRua");



ALTER TABLE ONLY "inventario"."sessao"
    ADD CONSTRAINT "sessao_pkey" PRIMARY KEY ("cdSessao");



ALTER TABLE ONLY "public"."TbApiKeys"
    ADD CONSTRAINT "TbApiKeys_dsKey_key" UNIQUE ("dsKey");



ALTER TABLE ONLY "public"."TbApiKeys"
    ADD CONSTRAINT "TbApiKeys_pkey" PRIMARY KEY ("cdApiKey");



ALTER TABLE ONLY "public"."TbClienteChave"
    ADD CONSTRAINT "TbClienteChave_dsChave_key" UNIQUE ("dsChave");



ALTER TABLE ONLY "public"."TbClienteChave"
    ADD CONSTRAINT "TbClienteChave_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."TbCliente"
    ADD CONSTRAINT "TbCliente_pkey" PRIMARY KEY ("cdCliente");



ALTER TABLE ONLY "public"."TbDestinatario"
    ADD CONSTRAINT "TbDestinatario_pkey" PRIMARY KEY ("cdDestinatario");



ALTER TABLE ONLY "public"."TbDispositivo"
    ADD CONSTRAINT "TbDispositivo_pkey" PRIMARY KEY ("cdDispositivo");



ALTER TABLE ONLY "public"."TbImagens"
    ADD CONSTRAINT "TbImagens_pkey" PRIMARY KEY ("cdImagens");



ALTER TABLE ONLY "public"."TbMunicipio"
    ADD CONSTRAINT "TbMunicipio_pkey" PRIMARY KEY ("cdMunicipioIBGE", "cdEstadoIBGE");



ALTER TABLE ONLY "public"."TbPosicao"
    ADD CONSTRAINT "TbPosicao_pkey" PRIMARY KEY ("cdPosicao");



ALTER TABLE ONLY "public"."TbProdutoItemJoinTable"
    ADD CONSTRAINT "TbProdutoItemJoinTable_pkey" PRIMARY KEY ("cdProdutoItem", "cdProduto");



ALTER TABLE ONLY "public"."TbProdutoItem"
    ADD CONSTRAINT "TbProdutoItem_pkey" PRIMARY KEY ("cdProdutoItem");



ALTER TABLE ONLY "public"."TbProduto"
    ADD CONSTRAINT "TbProduto_pkey" PRIMARY KEY ("cdProduto");



ALTER TABLE ONLY "public"."TbSensorRegistro"
    ADD CONSTRAINT "TbSensorRegistro_pkey" PRIMARY KEY ("cdDispositivo", "cdSensor", "cdPosicao");



ALTER TABLE ONLY "public"."TbSensor"
    ADD CONSTRAINT "TbSensor_cdSensor_key" UNIQUE ("cdSensor");



ALTER TABLE ONLY "public"."TbSensor"
    ADD CONSTRAINT "TbSensor_pkey" PRIMARY KEY ("cdSensor");



ALTER TABLE ONLY "public"."TbTipoSensor"
    ADD CONSTRAINT "TbTipoSensor_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."TbTipoSensor"
    ADD CONSTRAINT "TbTipoSensor_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."TbEndereco"
    ADD CONSTRAINT "tbendereco_pkey" PRIMARY KEY ("cdEndereco");



CREATE INDEX "TbCliente_cdClientePai_idx" ON "public"."TbCliente" USING "btree" ("cdClientePai");



CREATE INDEX "TbDestinatario_cdCliente_idx" ON "public"."TbDestinatario" USING "btree" ("cdCliente");



CREATE INDEX "TbDispositivo_cdCliente_idx" ON "public"."TbDispositivo" USING "btree" ("cdCliente");



CREATE INDEX "TbEndereco_lat_long_idx" ON "public"."TbEndereco" USING "btree" ("dsLat", "dsLong");



CREATE INDEX "TbImagens_cdProduto_idx" ON "public"."TbImagens" USING "btree" ("cdProduto");



CREATE INDEX "TbProduto_cdCliente_idx" ON "public"."TbProduto" USING "btree" ("cdCliente");



CREATE INDEX "TbSensor_cdDispositivo_idx" ON "public"."TbSensor" USING "btree" ("cdDispositivo");



CREATE OR REPLACE VIEW "public"."VwTbProdutoTipo" WITH ("security_invoker"='true') AS
 SELECT "a"."cdProduto",
    "a"."dsNome",
    "a"."dsDescricao",
    "a"."nrCodigo",
    "a"."nrLarg",
    "a"."nrComp",
    "a"."nrAlt",
    "a"."cdStatus",
    "c"."cdDispositivo",
    "c"."dsDispositivo",
    "c"."dsModelo",
    "c"."dsDescricao" AS "DescDispositivo",
    "c"."dsObs",
    "c"."dsLayout",
    "c"."nrChip",
    "c"."cdStatus" AS "StatusDispositivo",
    "c"."cdCliente"
   FROM ("public"."TbProduto" "a"
     JOIN "public"."TbDispositivo" "c" ON (("a"."cdProduto" = "c"."cdProduto")))
  GROUP BY "a"."cdProduto", "a"."dsNome", "a"."dsDescricao", "a"."nrCodigo", "a"."nrLarg", "a"."nrComp", "a"."nrAlt", "a"."cdStatus", "c"."cdDispositivo", "c"."dsDispositivo", "c"."dsModelo", "c"."dsDescricao", "c"."dsObs", "c"."dsLayout", "c"."nrChip", "c"."cdStatus";



ALTER TABLE ONLY "inventario"."armazem"
    ADD CONSTRAINT "armazem_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "inventario"."inventario"
    ADD CONSTRAINT "inventario_cdArmazem_fkey" FOREIGN KEY ("cdArmazem") REFERENCES "inventario"."armazem"("cdArmazem") ON UPDATE CASCADE;



ALTER TABLE ONLY "inventario"."leituras"
    ADD CONSTRAINT "leituras_cdInventario_fkey" FOREIGN KEY ("cdInventario") REFERENCES "inventario"."inventario"("cdInventario") ON UPDATE CASCADE;



ALTER TABLE ONLY "inventario"."leituras"
    ADD CONSTRAINT "leituras_cdSessao_fkey" FOREIGN KEY ("cdSessao") REFERENCES "inventario"."sessao"("cdSessao");



ALTER TABLE ONLY "inventario"."prateleira"
    ADD CONSTRAINT "prateleira_cdRua_fkey" FOREIGN KEY ("cdRua") REFERENCES "inventario"."rua"("cdRua") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "inventario"."rua"
    ADD CONSTRAINT "rua_cdArmazem_fkey" FOREIGN KEY ("cdArmazem") REFERENCES "inventario"."armazem"("cdArmazem") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "inventario"."sessao"
    ADD CONSTRAINT "sessao_cdPrateleira_fkey" FOREIGN KEY ("cdPrateleira") REFERENCES "inventario"."prateleira"("cdPrateleira") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."TbApiKeys"
    ADD CONSTRAINT "TbApiKeys_cdUsuario_fkey" FOREIGN KEY ("cdUsuario") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."TbClienteChave"
    ADD CONSTRAINT "TbClienteChave_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."TbCliente"
    ADD CONSTRAINT "TbCliente_cdClientePai_fkey" FOREIGN KEY ("cdClientePai") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."TbDestinatario"
    ADD CONSTRAINT "TbDestinatario_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."TbDestinatario"
    ADD CONSTRAINT "TbDestinatario_cdEndereco_fkey" FOREIGN KEY ("cdEndereco") REFERENCES "public"."TbEndereco"("cdEndereco");



ALTER TABLE ONLY "public"."TbDispositivo"
    ADD CONSTRAINT "TbDispositivo_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."TbDispositivo"
    ADD CONSTRAINT "TbDispositivo_cdDestinatario_fkey" FOREIGN KEY ("cdDestinatario") REFERENCES "public"."TbDestinatario"("cdDestinatario");



ALTER TABLE ONLY "public"."TbDispositivo"
    ADD CONSTRAINT "TbDispositivo_cdProduto_fkey" FOREIGN KEY ("cdProduto") REFERENCES "public"."TbProduto"("cdProduto");



ALTER TABLE ONLY "public"."TbImagens"
    ADD CONSTRAINT "TbImagens_cdProduto_fkey" FOREIGN KEY ("cdProduto") REFERENCES "public"."TbProduto"("cdProduto");



ALTER TABLE ONLY "public"."TbPosicao"
    ADD CONSTRAINT "TbPosicao_cdDestinatario_fkey" FOREIGN KEY ("cdDestinatario") REFERENCES "public"."TbDestinatario"("cdDestinatario");



ALTER TABLE ONLY "public"."TbPosicao"
    ADD CONSTRAINT "TbPosicao_cdDispositivo_fkey" FOREIGN KEY ("cdDispositivo") REFERENCES "public"."TbDispositivo"("cdDispositivo");



ALTER TABLE ONLY "public"."TbPosicao"
    ADD CONSTRAINT "TbPosicao_cdEndereco_fkey" FOREIGN KEY ("cdEndereco") REFERENCES "public"."TbEndereco"("cdEndereco");



ALTER TABLE ONLY "public"."TbProdutoItemJoinTable"
    ADD CONSTRAINT "TbProdutoItemJoinTable_cdProdutoItem_fkey" FOREIGN KEY ("cdProdutoItem") REFERENCES "public"."TbProdutoItem"("cdProdutoItem");



ALTER TABLE ONLY "public"."TbProdutoItemJoinTable"
    ADD CONSTRAINT "TbProdutoItemJoinTable_cdProduto_fkey" FOREIGN KEY ("cdProduto") REFERENCES "public"."TbProduto"("cdProduto");



ALTER TABLE ONLY "public"."TbProduto"
    ADD CONSTRAINT "TbProduto_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."TbSensorRegistro"
    ADD CONSTRAINT "TbSensorRegistro_cdDispositivo_fkey" FOREIGN KEY ("cdDispositivo") REFERENCES "public"."TbDispositivo"("cdDispositivo");



ALTER TABLE ONLY "public"."TbSensorRegistro"
    ADD CONSTRAINT "TbSensorRegistro_cdPosicao_fkey" FOREIGN KEY ("cdPosicao") REFERENCES "public"."TbPosicao"("cdPosicao") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."TbSensorRegistro"
    ADD CONSTRAINT "TbSensorRegistro_cdProdutoItem_fkey" FOREIGN KEY ("cdProdutoItem") REFERENCES "public"."TbProdutoItem"("cdProdutoItem");



ALTER TABLE ONLY "public"."TbSensorRegistro"
    ADD CONSTRAINT "TbSensorRegistro_cdSensor_fkey" FOREIGN KEY ("cdSensor") REFERENCES "public"."TbSensor"("cdSensor");



ALTER TABLE ONLY "public"."TbSensor"
    ADD CONSTRAINT "TbSensor_cdDispositivo_fkey" FOREIGN KEY ("cdDispositivo") REFERENCES "public"."TbDispositivo"("cdDispositivo");



ALTER TABLE ONLY "public"."TbSensor"
    ADD CONSTRAINT "TbSensor_cdProdutoItem_fkey" FOREIGN KEY ("cdProdutoItem") REFERENCES "public"."TbProdutoItem"("cdProdutoItem");



ALTER TABLE ONLY "public"."TbSensor"
    ADD CONSTRAINT "TbSensor_cdTipoSensor_fkey" FOREIGN KEY ("cdTipoSensor") REFERENCES "public"."TbTipoSensor"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_cdChave_fkey" FOREIGN KEY ("cdChave") REFERENCES "public"."TbClienteChave"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Enable read access for all users" ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbDestinatario" TO "authenticated" USING (((( SELECT "profiles"."role"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = 'service'::"public"."role") OR ("cdCliente" = ANY (ARRAY( SELECT "public"."get_clientes_user"("auth"."uid"()) AS "get_clientes_user")))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbDispositivo" TO "authenticated" USING (((( SELECT "profiles"."role"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = 'service'::"public"."role") OR ("cdCliente" = ANY (ARRAY( SELECT "public"."get_clientes_user"("auth"."uid"()) AS "get_clientes_user")))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbImagens" TO "authenticated" USING (("cdProduto" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_produto"("auth"."uid"()) AS "get_clientes_user_by_produto"))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbPosicao" TO "authenticated" USING (((( SELECT "profiles"."role"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = 'service'::"public"."role") OR ("cdDispositivo" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_dispositivo"("auth"."uid"()) AS "get_clientes_user_by_dispositivo")))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbProduto" TO "authenticated" USING (((( SELECT "profiles"."role"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = 'service'::"public"."role") OR ("cdCliente" = ANY (ARRAY( SELECT "public"."get_clientes_user"("auth"."uid"()) AS "get_clientes_user")))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbProdutoItem" USING (("cdProdutoItem" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_produto_item"("auth"."uid"()) AS "get_clientes_user_by_produto_item"))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbSensor" TO "authenticated" USING (("cdDispositivo" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_dispositivo"("auth"."uid"()) AS "get_clientes_user_by_dispositivo"))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbSensorRegistro" TO "authenticated" USING (("cdDispositivo" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_dispositivo"("auth"."uid"()) AS "get_clientes_user_by_dispositivo"))));



CREATE POLICY "apenas autenticados podem ler" ON "public"."TbProdutoItemJoinTable" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "apenas usuarios com acesso podem modificar" ON "public"."TbProdutoItemJoinTable" TO "authenticator" USING (("cdProduto" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_produto"("auth"."uid"()) AS "get_clientes_user_by_produto"))));



CREATE POLICY "somente api pode fazer mudanças" ON "public"."TbEndereco" TO "service_role" USING (true);



CREATE POLICY "somente api pode fazer mudanças na chave" ON "public"."TbClienteChave" TO "service_role" USING (true);



CREATE POLICY "somente autenticados podem ler" ON "public"."TbTipoSensor" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "somente usuarios com acesso ao cliente ou pai" ON "public"."TbCliente" TO "authenticated" USING (("cdCliente" = ANY (ARRAY( SELECT "public"."get_clientes_user"("auth"."uid"()) AS "get_clientes_user"))));



CREATE POLICY "todos podem ver" ON "public"."TbClienteChave" FOR SELECT TO "anon" USING (true);



CREATE POLICY "todos podem ver" ON "public"."TbEndereco" FOR SELECT TO "anon" USING (true);





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "inventario" TO "anon";
GRANT USAGE ON SCHEMA "inventario" TO "authenticated";
GRANT USAGE ON SCHEMA "inventario" TO "service_role";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";




















































































































































































GRANT ALL ON FUNCTION "public"."get_cliente"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_cliente"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_cliente"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_cliente_e_filhos"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_cliente_e_filhos"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_cliente_e_filhos"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_clientes_user"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_clientes_user"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_clientes_user"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_clientes_user_by_dispositivo"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_clientes_user_by_dispositivo"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_clientes_user_by_dispositivo"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_clientes_user_by_produto"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_clientes_user_by_produto"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_clientes_user_by_produto"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_clientes_user_by_produto_item"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_clientes_user_by_produto_item"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_clientes_user_by_produto_item"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_grouped_sensor_data"("dispositivos" integer[], "dt_registro_comeco" timestamp without time zone, "dt_registro_fim" timestamp without time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."get_grouped_sensor_data"("dispositivos" integer[], "dt_registro_comeco" timestamp without time zone, "dt_registro_fim" timestamp without time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_grouped_sensor_data"("dispositivos" integer[], "dt_registro_comeco" timestamp without time zone, "dt_registro_fim" timestamp without time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_lista_dispositivos_resumo"("dt_registro_inicio" timestamp without time zone, "dt_registro_fim" timestamp without time zone, "cd_status" "public"."status", "ds_uf" "text", "bl_area" boolean, "nr_bateria_min" double precision, "nr_bateria_max" double precision, "cd_cliente" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_lista_dispositivos_resumo"("dt_registro_inicio" timestamp without time zone, "dt_registro_fim" timestamp without time zone, "cd_status" "public"."status", "ds_uf" "text", "bl_area" boolean, "nr_bateria_min" double precision, "nr_bateria_max" double precision, "cd_cliente" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_lista_dispositivos_resumo"("dt_registro_inicio" timestamp without time zone, "dt_registro_fim" timestamp without time zone, "cd_status" "public"."status", "ds_uf" "text", "bl_area" boolean, "nr_bateria_min" double precision, "nr_bateria_max" double precision, "cd_cliente" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";


















GRANT ALL ON TABLE "inventario"."armazem" TO "anon";
GRANT ALL ON TABLE "inventario"."armazem" TO "authenticated";
GRANT ALL ON TABLE "inventario"."armazem" TO "service_role";



GRANT ALL ON SEQUENCE "inventario"."armazem_cdArmazem_seq" TO "anon";
GRANT ALL ON SEQUENCE "inventario"."armazem_cdArmazem_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "inventario"."armazem_cdArmazem_seq" TO "service_role";



GRANT ALL ON TABLE "inventario"."inventario" TO "anon";
GRANT ALL ON TABLE "inventario"."inventario" TO "authenticated";
GRANT ALL ON TABLE "inventario"."inventario" TO "service_role";



GRANT ALL ON SEQUENCE "inventario"."inventario_cdInventario_seq" TO "anon";
GRANT ALL ON SEQUENCE "inventario"."inventario_cdInventario_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "inventario"."inventario_cdInventario_seq" TO "service_role";



GRANT ALL ON TABLE "inventario"."leituras" TO "anon";
GRANT ALL ON TABLE "inventario"."leituras" TO "authenticated";
GRANT ALL ON TABLE "inventario"."leituras" TO "service_role";



GRANT ALL ON SEQUENCE "inventario"."leituras_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "inventario"."leituras_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "inventario"."leituras_id_seq" TO "service_role";



GRANT ALL ON TABLE "inventario"."prateleira" TO "anon";
GRANT ALL ON TABLE "inventario"."prateleira" TO "authenticated";
GRANT ALL ON TABLE "inventario"."prateleira" TO "service_role";



GRANT ALL ON SEQUENCE "inventario"."prateleira_cdPrateleira_seq" TO "anon";
GRANT ALL ON SEQUENCE "inventario"."prateleira_cdPrateleira_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "inventario"."prateleira_cdPrateleira_seq" TO "service_role";



GRANT ALL ON TABLE "inventario"."rua" TO "anon";
GRANT ALL ON TABLE "inventario"."rua" TO "authenticated";
GRANT ALL ON TABLE "inventario"."rua" TO "service_role";



GRANT ALL ON SEQUENCE "inventario"."rua_cdRua_seq" TO "anon";
GRANT ALL ON SEQUENCE "inventario"."rua_cdRua_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "inventario"."rua_cdRua_seq" TO "service_role";



GRANT ALL ON TABLE "inventario"."sessao" TO "anon";
GRANT ALL ON TABLE "inventario"."sessao" TO "authenticated";
GRANT ALL ON TABLE "inventario"."sessao" TO "service_role";



GRANT ALL ON SEQUENCE "inventario"."sessao_cdSessao_seq" TO "anon";
GRANT ALL ON SEQUENCE "inventario"."sessao_cdSessao_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "inventario"."sessao_cdSessao_seq" TO "service_role";












GRANT ALL ON TABLE "public"."TbApiKeys" TO "anon";
GRANT ALL ON TABLE "public"."TbApiKeys" TO "authenticated";
GRANT ALL ON TABLE "public"."TbApiKeys" TO "service_role";



GRANT ALL ON TABLE "public"."TbCliente" TO "anon";
GRANT ALL ON TABLE "public"."TbCliente" TO "authenticated";
GRANT ALL ON TABLE "public"."TbCliente" TO "service_role";



GRANT ALL ON TABLE "public"."TbClienteChave" TO "anon";
GRANT ALL ON TABLE "public"."TbClienteChave" TO "authenticated";
GRANT ALL ON TABLE "public"."TbClienteChave" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbClienteChave_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbClienteChave_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbClienteChave_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbCliente_cdCliente_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbCliente_cdCliente_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbCliente_cdCliente_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbDestinatario" TO "anon";
GRANT ALL ON TABLE "public"."TbDestinatario" TO "authenticated";
GRANT ALL ON TABLE "public"."TbDestinatario" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbDestinatario_cdDestinatario_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbDestinatario_cdDestinatario_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbDestinatario_cdDestinatario_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbDispositivo" TO "anon";
GRANT ALL ON TABLE "public"."TbDispositivo" TO "authenticated";
GRANT ALL ON TABLE "public"."TbDispositivo" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbDispositivo_cdDispositivo_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbDispositivo_cdDispositivo_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbDispositivo_cdDispositivo_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbEndereco" TO "anon";
GRANT ALL ON TABLE "public"."TbEndereco" TO "authenticated";
GRANT ALL ON TABLE "public"."TbEndereco" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbEndereco_cdEndereco_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbEndereco_cdEndereco_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbEndereco_cdEndereco_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbEstado" TO "anon";
GRANT ALL ON TABLE "public"."TbEstado" TO "authenticated";
GRANT ALL ON TABLE "public"."TbEstado" TO "service_role";



GRANT ALL ON TABLE "public"."TbImagens" TO "anon";
GRANT ALL ON TABLE "public"."TbImagens" TO "authenticated";
GRANT ALL ON TABLE "public"."TbImagens" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbImagens_cdImagens_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbImagens_cdImagens_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbImagens_cdImagens_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbMunicipio" TO "anon";
GRANT ALL ON TABLE "public"."TbMunicipio" TO "authenticated";
GRANT ALL ON TABLE "public"."TbMunicipio" TO "service_role";



GRANT ALL ON TABLE "public"."TbPosicao" TO "anon";
GRANT ALL ON TABLE "public"."TbPosicao" TO "authenticated";
GRANT ALL ON TABLE "public"."TbPosicao" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbPosicao_cdPosicao_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbPosicao_cdPosicao_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbPosicao_cdPosicao_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbProduto" TO "anon";
GRANT ALL ON TABLE "public"."TbProduto" TO "authenticated";
GRANT ALL ON TABLE "public"."TbProduto" TO "service_role";



GRANT ALL ON TABLE "public"."TbProdutoItem" TO "anon";
GRANT ALL ON TABLE "public"."TbProdutoItem" TO "authenticated";
GRANT ALL ON TABLE "public"."TbProdutoItem" TO "service_role";



GRANT ALL ON TABLE "public"."TbProdutoItemJoinTable" TO "anon";
GRANT ALL ON TABLE "public"."TbProdutoItemJoinTable" TO "authenticated";
GRANT ALL ON TABLE "public"."TbProdutoItemJoinTable" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbProdutoItem_cdProdutoItem_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbProdutoItem_cdProdutoItem_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbProdutoItem_cdProdutoItem_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbProduto_cdProduto_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbProduto_cdProduto_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbProduto_cdProduto_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbSensor" TO "anon";
GRANT ALL ON TABLE "public"."TbSensor" TO "authenticated";
GRANT ALL ON TABLE "public"."TbSensor" TO "service_role";



GRANT ALL ON TABLE "public"."TbSensorRegistro" TO "anon";
GRANT ALL ON TABLE "public"."TbSensorRegistro" TO "authenticated";
GRANT ALL ON TABLE "public"."TbSensorRegistro" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbSensor_cdSensor_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbSensor_cdSensor_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbSensor_cdSensor_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbTipoSensor" TO "anon";
GRANT ALL ON TABLE "public"."TbTipoSensor" TO "authenticated";
GRANT ALL ON TABLE "public"."TbTipoSensor" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbTipoSensor_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbTipoSensor_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbTipoSensor_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."VwProdutoCompleto" TO "anon";
GRANT ALL ON TABLE "public"."VwProdutoCompleto" TO "authenticated";
GRANT ALL ON TABLE "public"."VwProdutoCompleto" TO "service_role";



GRANT ALL ON TABLE "public"."VwProdutosFora" TO "anon";
GRANT ALL ON TABLE "public"."VwProdutosFora" TO "authenticated";
GRANT ALL ON TABLE "public"."VwProdutosFora" TO "service_role";



GRANT ALL ON TABLE "public"."VwTbPosicaoAtual" TO "anon";
GRANT ALL ON TABLE "public"."VwTbPosicaoAtual" TO "authenticated";
GRANT ALL ON TABLE "public"."VwTbPosicaoAtual" TO "service_role";



GRANT ALL ON TABLE "public"."VwRelDadosDispositivo" TO "anon";
GRANT ALL ON TABLE "public"."VwRelDadosDispositivo" TO "authenticated";
GRANT ALL ON TABLE "public"."VwRelDadosDispositivo" TO "service_role";



GRANT ALL ON TABLE "public"."VwRelHistoricoDispositivoProduto" TO "anon";
GRANT ALL ON TABLE "public"."VwRelHistoricoDispositivoProduto" TO "authenticated";
GRANT ALL ON TABLE "public"."VwRelHistoricoDispositivoProduto" TO "service_role";



GRANT ALL ON TABLE "public"."VwTbDestinatarioDispositivo" TO "anon";
GRANT ALL ON TABLE "public"."VwTbDestinatarioDispositivo" TO "authenticated";
GRANT ALL ON TABLE "public"."VwTbDestinatarioDispositivo" TO "service_role";



GRANT ALL ON TABLE "public"."VwTbProdutoTipo" TO "anon";
GRANT ALL ON TABLE "public"."VwTbProdutoTipo" TO "authenticated";
GRANT ALL ON TABLE "public"."VwTbProdutoTipo" TO "service_role";



GRANT ALL ON TABLE "public"."VwTbProdutoTotal" TO "anon";
GRANT ALL ON TABLE "public"."VwTbProdutoTotal" TO "authenticated";
GRANT ALL ON TABLE "public"."VwTbProdutoTotal" TO "service_role";



GRANT ALL ON TABLE "public"."VwTbProdutoTotalStatus" TO "anon";
GRANT ALL ON TABLE "public"."VwTbProdutoTotalStatus" TO "authenticated";
GRANT ALL ON TABLE "public"."VwTbProdutoTotalStatus" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "inventario" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "inventario" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "inventario" GRANT ALL ON SEQUENCES  TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "inventario" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "inventario" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "inventario" GRANT ALL ON FUNCTIONS  TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "inventario" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "inventario" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "inventario" GRANT ALL ON TABLES  TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
