

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



CREATE TABLE IF NOT EXISTS "public"."TbDestinatario" (
    "cdDestinatario" integer NOT NULL,
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
    "dsLat" character varying(45) DEFAULT NULL::character varying,
    "dsLong" character varying(45) DEFAULT NULL::character varying,
    "nrRaio" double precision,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cdCliente" integer,
    "cdUser" "uuid",
    "cdEndereco" integer
);


ALTER TABLE "public"."TbDestinatario" OWNER TO "postgres";


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
    "cdCliente" integer,
    "cdUser" "uuid"
);


ALTER TABLE "public"."TbDispositivo" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TbPosicao" (
    "cdPosicao" integer NOT NULL,
    "dsModelo" "text",
    "dtData" "text",
    "dtHora" "text",
    "dsLat" "text",
    "dsLong" "text",
    "nrTemp" double precision,
    "nrBat" double precision,
    "nrSeq" integer,
    "dsArquivo" "text",
    "cdDispositivo" integer,
    "dsEndereco" "text",
    "dsNum" character varying(45) DEFAULT NULL::character varying,
    "dsCep" character varying(9) DEFAULT NULL::character varying,
    "dsBairro" character varying(100) DEFAULT NULL::character varying,
    "dsCidade" character varying(100) DEFAULT NULL::character varying,
    "dsUF" character varying(2) DEFAULT NULL::character varying,
    "dsPais" character varying(100) DEFAULT NULL::character varying,
    "blArea" boolean,
    "nrDistancia" real,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "cdDestinatario" integer,
    "cdUser" "uuid",
    "cdEndereco" integer
);


ALTER TABLE "public"."TbPosicao" OWNER TO "postgres";


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
    "cdUser" "uuid",
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
    "nrTempMin" double precision,
    "nrTempMax" double precision,
    "nrQtdeTotalSensor" integer,
    "cdStatus" "public"."status",
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "cdUser" "uuid"
);


ALTER TABLE "public"."TbProdutoItem" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TbSensor" (
    "cdSensor" integer NOT NULL,
    "cdDispositivo" integer NOT NULL,
    "cdProdutoItem" integer,
    "cdUnidade" "public"."unidade",
    "nrUnidadeIni" integer,
    "nrUnidadeFim" integer,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "cdTipoSensor" bigint NOT NULL,
    "cdUser" "uuid"
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


CREATE TABLE IF NOT EXISTS "public"."TbTipoSensor" (
    "id" bigint NOT NULL,
    "dsNome" "text" NOT NULL,
    "dsDescricao" "text",
    "dtRegistro" timestamp with time zone DEFAULT "now"() NOT NULL,
    "cdUser" "uuid" NOT NULL,
    "dsUnidade" "text"
);


ALTER TABLE "public"."TbTipoSensor" OWNER TO "postgres";


COMMENT ON TABLE "public"."TbTipoSensor" IS 'Detalhes dos tipos de sensores que usamos';



COMMENT ON COLUMN "public"."TbTipoSensor"."dsUnidade" IS 'unidade de medida que o sensor lê';



CREATE OR REPLACE VIEW "public"."AntigoVwRelHistoricoDispositivoProduto" WITH ("security_invoker"='true') AS
 SELECT "A"."cdProduto",
    "A"."nrCodigo",
    "A"."dsDescricao",
    "C"."dtRegistro",
    "C"."cdDispositivo",
    "E"."dsNome",
    "C"."dsEndereco",
    "L"."cdSensor",
    "concat"((((
        CASE
            WHEN ("C"."nrBat" > (3.7)::double precision) THEN (3.7)::double precision
            ELSE "C"."nrBat"
        END / (3.7)::double precision) * (100)::double precision))::numeric(15,2), '%') AS "nrBatPercentual",
    ( SELECT "X"."nrValor"
           FROM (("public"."TbSensorRegistro" "X"
             JOIN "public"."TbSensor" "ts" ON (("ts"."cdSensor" = "X"."cdSensor")))
             JOIN "public"."TbTipoSensor" "tts" ON (("ts"."cdTipoSensor" = "tts"."id")))
          WHERE (("X"."cdDispositivo" = "C"."cdDispositivo") AND ("X"."cdPosicao" = "C"."cdPosicao") AND ("tts"."id" = 2))) AS "nrPorta",
    ( SELECT "X"."nrValor"
           FROM (("public"."TbSensorRegistro" "X"
             JOIN "public"."TbSensor" "ts" ON (("ts"."cdSensor" = "X"."cdSensor")))
             JOIN "public"."TbTipoSensor" "tts" ON (("ts"."cdTipoSensor" = "tts"."id")))
          WHERE (("X"."cdDispositivo" = "C"."cdDispositivo") AND ("X"."cdPosicao" = "C"."cdPosicao") AND ("tts"."id" = 4))) AS "nrTemperatura",
    "K"."dsNome" AS "dsProdutoItem",
    ("L"."nrValor")::double precision AS "nrQtdItens",
        CASE
            WHEN ("C"."blArea" = false) THEN 'Fora de Área'::"text"
            ELSE 'Dentro da Área'::"text"
        END AS "dsStatus",
    "M"."cdStatus" AS "dsStatusDispositivo"
   FROM (((((("public"."TbProduto" "A"
     JOIN "public"."TbDispositivo" "M" ON (("M"."cdProduto" = "A"."cdProduto")))
     JOIN "public"."TbPosicao" "C" ON (("M"."cdDispositivo" = "C"."cdDispositivo")))
     LEFT JOIN "public"."TbDestinatario" "E" ON (("E"."cdDestinatario" = "C"."cdDispositivo")))
     LEFT JOIN "public"."TbSensor" "J" ON (("J"."cdDispositivo" = "M"."cdDispositivo")))
     JOIN "public"."TbProdutoItem" "K" ON (("J"."cdProdutoItem" = "K"."cdProdutoItem")))
     JOIN "public"."TbSensorRegistro" "L" ON (("C"."cdPosicao" = "L"."cdPosicao")))
  ORDER BY "C"."dtRegistro" DESC;


ALTER TABLE "public"."AntigoVwRelHistoricoDispositivoProduto" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TbAcessoIntelBras" (
    "cdAcessoIntelBras" integer NOT NULL,
    "dsUserId" character varying(45) DEFAULT NULL::character varying,
    "dsCardName" character varying(200) DEFAULT NULL::character varying,
    "dsCardNo" character varying(45) DEFAULT NULL::character varying,
    "dsUserType" character varying(45) DEFAULT NULL::character varying,
    "dsPassword" character varying(45) DEFAULT NULL::character varying,
    "dsDoor" character varying(45) DEFAULT NULL::character varying,
    "dsErrorCode" character varying(45) DEFAULT NULL::character varying,
    "dsMethod" character varying(45) DEFAULT NULL::character varying,
    "dsReaderID" character varying(45) DEFAULT NULL::character varying,
    "dsStatus" character varying(45) DEFAULT NULL::character varying,
    "dsType" character varying(45) DEFAULT NULL::character varying,
    "dsEntry" character varying(45) DEFAULT NULL::character varying,
    "dsUtc" character varying(45) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."TbAcessoIntelBras" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbAcessoIntelBras_cdAcessoIntelBras_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbAcessoIntelBras_cdAcessoIntelBras_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbAcessoIntelBras_cdAcessoIntelBras_seq" OWNED BY "public"."TbAcessoIntelBras"."cdAcessoIntelBras";



CREATE TABLE IF NOT EXISTS "public"."TbChamados" (
    "cdChamados" integer NOT NULL,
    "dtOperacao" "text",
    "dsTipo" "text",
    "dsDescricao" "text",
    "nrQtde" integer,
    "dsUser" character varying(45) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."TbChamados" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbChamados_cdChamados_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbChamados_cdChamados_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbChamados_cdChamados_seq" OWNED BY "public"."TbChamados"."cdChamados";



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
    "cdUser" "uuid",
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



CREATE SEQUENCE IF NOT EXISTS "public"."TbDestinatario_cdDestinatario_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbDestinatario_cdDestinatario_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbDestinatario_cdDestinatario_seq" OWNED BY "public"."TbDestinatario"."cdDestinatario";



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
    "dsObs" "text",
    "dsLat" character varying(45) DEFAULT NULL::character varying,
    "dsLong" character varying(45) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cdUser" "uuid"
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


CREATE TABLE IF NOT EXISTS "public"."TbEtiqueta" (
    "cdEtiqueta" integer NOT NULL,
    "dsEtiqueta" character varying(200) DEFAULT NULL::character varying,
    "nrFator" real,
    "nrLargura" real,
    "nrAltura" real,
    "nrComprimento" real,
    "nrPeso" real,
    "nrCubado" real,
    "dsUser" character varying(100) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."TbEtiqueta" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbEtiqueta_cdEtiqueta_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbEtiqueta_cdEtiqueta_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbEtiqueta_cdEtiqueta_seq" OWNED BY "public"."TbEtiqueta"."cdEtiqueta";



CREATE TABLE IF NOT EXISTS "public"."TbFuncionario" (
    "cdFuncionario" integer NOT NULL,
    "nrCodEmpregado" character varying(40) DEFAULT NULL::character varying,
    "dsNomeEmpregado" character varying(250) DEFAULT NULL::character varying,
    "dsLogradouro" character varying(250) DEFAULT NULL::character varying,
    "dsNumCasa" character varying(45) DEFAULT NULL::character varying,
    "dsComplemento" character varying(100) DEFAULT NULL::character varying,
    "dsBairro" character varying(100) DEFAULT NULL::character varying,
    "dsCidade" character varying(100) DEFAULT NULL::character varying,
    "dsFuncao" character varying(100) DEFAULT NULL::character varying,
    "dsUser" integer,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "dsPis" character varying(45) DEFAULT NULL::character varying,
    "dsCpf" character varying(20) DEFAULT NULL::character varying,
    "dsSenha" character varying(45) DEFAULT NULL::character varying,
    "dsEmpresa" character varying(45) DEFAULT NULL::character varying
);


ALTER TABLE "public"."TbFuncionario" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbFuncionario_cdFuncionario_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbFuncionario_cdFuncionario_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbFuncionario_cdFuncionario_seq" OWNED BY "public"."TbFuncionario"."cdFuncionario";



CREATE TABLE IF NOT EXISTS "public"."TbImagens" (
    "cdImagens" integer NOT NULL,
    "dsCaminho" character varying(200) NOT NULL,
    "cdCodigo" character varying(20) NOT NULL,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "cdProduto" integer,
    "nrImagem" integer,
    "cdUser" "uuid"
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



CREATE TABLE IF NOT EXISTS "public"."TbLeituraCameraInventario" (
    "id" bigint NOT NULL,
    "tipoDado" character varying NOT NULL,
    "dadoLeitura" character varying,
    "endereco" "text",
    "dtRegistro" timestamp with time zone DEFAULT "now"(),
    "idLeitura" "uuid"
);


ALTER TABLE "public"."TbLeituraCameraInventario" OWNER TO "postgres";


COMMENT ON TABLE "public"."TbLeituraCameraInventario" IS 'Salvar os dados coletados pela câmera do drone/celular e/ou outro dispositivo.';



COMMENT ON COLUMN "public"."TbLeituraCameraInventario"."endereco" IS 'local onde a leitura se encontra';



COMMENT ON COLUMN "public"."TbLeituraCameraInventario"."dtRegistro" IS 'timestamp de quando dado foi inserido';



COMMENT ON COLUMN "public"."TbLeituraCameraInventario"."idLeitura" IS 'id da leitura';



ALTER TABLE "public"."TbLeituraCameraInventario" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."TbLeituraCameraInventario_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."TbMunicipio" (
    "cdMunicipioIBGE" character varying(5) NOT NULL,
    "cdEstadoIBGE" integer NOT NULL,
    "cdMunicipioCompleto" character varying(7) DEFAULT NULL::character varying,
    "dsMunicipio" character varying(60) DEFAULT NULL::character varying
);


ALTER TABLE "public"."TbMunicipio" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TbPonto" (
    "cdPonto" integer NOT NULL,
    "cdAcessoIntelbras" integer,
    "dsCardNo" character varying(45) DEFAULT NULL::character varying,
    "dsCardName" character varying(200) DEFAULT NULL::character varying,
    "dsRegistro01" timestamp without time zone,
    "dsRegistro02" timestamp without time zone,
    "dsRegistro03" timestamp without time zone,
    "dsRegistro04" timestamp without time zone,
    "dsRegistro05" timestamp without time zone,
    "dsRegistro06" timestamp without time zone,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."TbPonto" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbPonto_cdPonto_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbPonto_cdPonto_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbPonto_cdPonto_seq" OWNED BY "public"."TbPonto"."cdPonto";



CREATE SEQUENCE IF NOT EXISTS "public"."TbPosicao_cdPosicao_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbPosicao_cdPosicao_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbPosicao_cdPosicao_seq" OWNED BY "public"."TbPosicao"."cdPosicao";



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



CREATE SEQUENCE IF NOT EXISTS "public"."TbSensor_cdSensor_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbSensor_cdSensor_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbSensor_cdSensor_seq" OWNED BY "public"."TbSensor"."cdSensor";



CREATE TABLE IF NOT EXISTS "public"."TbTag" (
    "cdTag" integer NOT NULL,
    "dsDescricao" "text",
    "dsConteudo" "text",
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "cdUser" "uuid"
);


ALTER TABLE "public"."TbTag" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbTag_cdTag_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbTag_cdTag_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbTag_cdTag_seq" OWNED BY "public"."TbTag"."cdTag";



CREATE TABLE IF NOT EXISTS "public"."TbTicket" (
    "cdTicket" integer NOT NULL,
    "dtOperacao" "text",
    "dsAtendimento" "text",
    "nrAbertos" integer,
    "nrFechados" integer,
    "nrPendentes" integer,
    "dsUser" character varying(45) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."TbTicket" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TbTicketResumo" (
    "cdTicketResumo" integer NOT NULL,
    "dtOperacao" "text",
    "dsAtendimento" "text",
    "dsNaoAtribuido" integer,
    "dsSemResolucao" integer,
    "dsAtualizado" integer,
    "dsPendente" integer,
    "dsResolvido" integer,
    "dsUser" character varying(45) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."TbTicketResumo" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbTicketResumo_cdTicketResumo_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbTicketResumo_cdTicketResumo_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbTicketResumo_cdTicketResumo_seq" OWNED BY "public"."TbTicketResumo"."cdTicketResumo";



CREATE SEQUENCE IF NOT EXISTS "public"."TbTicket_cdTicket_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbTicket_cdTicket_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbTicket_cdTicket_seq" OWNED BY "public"."TbTicket"."cdTicket";



ALTER TABLE "public"."TbTipoSensor" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."TbTipoSensor_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."TbUnidade" (
    "cdUnidade" integer NOT NULL,
    "dsUnidade" "text",
    "dsSimbolo" "text",
    "dsUser" character varying(45) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."TbUnidade" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbUnidade_cdUnidade_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbUnidade_cdUnidade_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbUnidade_cdUnidade_seq" OWNED BY "public"."TbUnidade"."cdUnidade";



CREATE TABLE IF NOT EXISTS "public"."TbUsuario" (
    "cdUsuario" integer NOT NULL,
    "dsNome" "text",
    "dsLogin" "text",
    "dsSenha" "text",
    "cdPerfil" integer,
    "dsUser" character varying(45) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."TbUsuario" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbUsuario_cdUsuario_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbUsuario_cdUsuario_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbUsuario_cdUsuario_seq" OWNED BY "public"."TbUsuario"."cdUsuario";



CREATE TABLE IF NOT EXISTS "public"."TbVisita" (
    "cdVisita" integer NOT NULL,
    "cdCliente" integer NOT NULL,
    "cdVisitante" integer NOT NULL,
    "dtData" timestamp without time zone,
    "dsUser" character varying(45) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE "public"."TbVisita" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbVisita_cdVisita_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbVisita_cdVisita_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbVisita_cdVisita_seq" OWNED BY "public"."TbVisita"."cdVisita";



CREATE TABLE IF NOT EXISTS "public"."TbVisitante" (
    "cdVisitante" integer NOT NULL,
    "dsNome" character varying(255) NOT NULL,
    "nrTelefone" character varying(45) DEFAULT NULL::character varying,
    "nrDocumento" character varying(45) NOT NULL,
    "dsEmail" character varying(45) DEFAULT NULL::character varying,
    "dsUser" character varying(45) DEFAULT NULL::character varying,
    "dtRegistro" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE "public"."TbVisitante" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."TbVisitante_cdVisitante_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."TbVisitante_cdVisitante_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."TbVisitante_cdVisitante_seq" OWNED BY "public"."TbVisitante"."cdVisitante";



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


CREATE OR REPLACE VIEW "public"."VwTbPosicaoAtual" AS
 SELECT "A"."cdPosicao",
    "A"."dtRegistro",
    "A"."cdDispositivo",
    "A"."dsLat",
    "A"."dsLong",
    "A"."dsEndereco",
    "A"."dsNum",
    "A"."dsCep",
    "A"."dsBairro",
    "A"."dsCidade",
    "A"."dsUF",
    "A"."dsPais",
    "A"."nrBat",
    "B"."nrCodigo",
    "B"."cdProduto",
    "B"."dsNome" AS "dsProduto",
    "B"."dsDescricao",
    "E"."cdStatus",
    "A"."blArea",
    "E"."cdCliente"
   FROM ((("public"."TbPosicao" "A"
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
    "E"."dsLogradouro" AS "dsEnderecoDest",
    "E"."nrNumero" AS "nrNumeroDest",
    "E"."dsBairro" AS "dsBairroDest",
    "E"."dsCidade" AS "dsCidadeDest",
    "E"."dsUF" AS "dsUfDest",
    "E"."dsCep" AS "dsCepDest",
    "E"."dsLat" AS "dsLatDest",
    "E"."dsLong" AS "dsLongDest",
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
   FROM ((("public"."TbProduto" "A"
     JOIN "public"."TbDispositivo" "F" ON (("F"."cdProduto" = "A"."cdProduto")))
     JOIN "public"."VwTbPosicaoAtual" "C" ON (("F"."cdDispositivo" = "C"."cdDispositivo")))
     JOIN "public"."TbDestinatario" "E" ON (("F"."cdDestinatario" = "E"."cdDestinatario")));


ALTER TABLE "public"."VwRelDadosDispositivo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."VwRelHistoricoDispositivoProduto" WITH ("security_invoker"='true') AS
 SELECT "pd"."cdProduto",
    "pd"."nrCodigo",
    "pd"."dsDescricao",
    "p"."dtRegistro",
    "d"."cdDispositivo",
    "dest"."dsNome",
    "p"."dsEndereco",
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
   FROM ((((((("public"."TbSensor" "s"
     LEFT JOIN "public"."TbProdutoItem" "pi" ON (("s"."cdProdutoItem" = "pi"."cdProdutoItem")))
     JOIN "public"."TbDispositivo" "d" ON (("d"."cdDispositivo" = "s"."cdDispositivo")))
     JOIN "public"."TbSensorRegistro" "sr" ON (("sr"."cdSensor" = "s"."cdSensor")))
     JOIN "public"."TbTipoSensor" "ts" ON (("ts"."id" = "s"."cdTipoSensor")))
     JOIN "public"."TbPosicao" "p" ON (("p"."cdPosicao" = "sr"."cdPosicao")))
     JOIN "public"."TbDestinatario" "dest" ON (("dest"."cdDestinatario" = "d"."cdDestinatario")))
     JOIN "public"."TbProduto" "pd" ON (("pd"."cdProduto" = "d"."cdProduto")))
  ORDER BY "p"."dtRegistro" DESC;


ALTER TABLE "public"."VwRelHistoricoDispositivoProduto" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."VwTbDestinatarioDispositivo" WITH ("security_invoker"='true') AS
 SELECT "a"."cdDestinatario",
    "a"."dsLat",
    "a"."dsLong",
    "a"."nrRaio",
    "b"."cdDispositivo",
    "b"."cdCliente"
   FROM ("public"."TbDestinatario" "a"
     JOIN "public"."TbDispositivo" "b" ON (("a"."cdDestinatario" = "b"."cdDestinatario")));


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
    "dtRegistro" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."cdChave" IS 'chave convite usada para cadastro';



COMMENT ON COLUMN "public"."profiles"."cdCliente" IS 'cliente vinculado com o usuario';



COMMENT ON COLUMN "public"."profiles"."dtRegistro" IS 'data que o usuario fez cadastro';



CREATE OR REPLACE VIEW "public"."vwrelhistoricodispositivoproduto" AS
 SELECT "A"."cdProduto",
    "A"."nrCodigo",
    "A"."dsDescricao",
    "C"."dtRegistro",
    "C"."cdDispositivo",
    "E"."dsNome",
    "C"."dsEndereco",
    "L"."cdSensor",
    "concat"((((
        CASE
            WHEN ("C"."nrBat" > (3.7)::double precision) THEN (3.7)::double precision
            ELSE "C"."nrBat"
        END / (3.7)::double precision) * (100)::double precision))::numeric(15,2), '%') AS "nrBatPercentual",
    ( SELECT "X"."nrValor"
           FROM (("public"."TbSensorRegistro" "X"
             JOIN "public"."TbSensor" "ts" ON (("ts"."cdSensor" = "X"."cdSensor")))
             JOIN "public"."TbTipoSensor" "tts" ON (("ts"."cdTipoSensor" = "tts"."id")))
          WHERE (("X"."cdDispositivo" = "C"."cdDispositivo") AND ("X"."cdPosicao" = "C"."cdPosicao") AND ("tts"."id" = 2))) AS "nrPorta",
    ( SELECT "X"."nrValor"
           FROM (("public"."TbSensorRegistro" "X"
             JOIN "public"."TbSensor" "ts" ON (("ts"."cdSensor" = "X"."cdSensor")))
             JOIN "public"."TbTipoSensor" "tts" ON (("ts"."cdTipoSensor" = "tts"."id")))
          WHERE (("X"."cdDispositivo" = "C"."cdDispositivo") AND ("X"."cdPosicao" = "C"."cdPosicao") AND ("tts"."id" = 4))) AS "nrTemperatura",
    "K"."dsNome" AS "dsProdutoItem",
    ("L"."nrValor")::double precision AS "nrQtdItens",
        CASE
            WHEN ("C"."blArea" = false) THEN 'Fora de Área'::"text"
            ELSE 'Dentro da Área'::"text"
        END AS "dsStatus",
    "M"."cdStatus" AS "dsStatusDispositivo"
   FROM (((((("public"."TbProduto" "A"
     JOIN "public"."TbDispositivo" "M" ON (("M"."cdProduto" = "A"."cdProduto")))
     JOIN "public"."TbPosicao" "C" ON (("M"."cdDispositivo" = "C"."cdDispositivo")))
     LEFT JOIN "public"."TbDestinatario" "E" ON (("E"."cdDestinatario" = "C"."cdDispositivo")))
     LEFT JOIN "public"."TbSensor" "J" ON (("J"."cdDispositivo" = "M"."cdDispositivo")))
     JOIN "public"."TbProdutoItem" "K" ON (("J"."cdProdutoItem" = "K"."cdProdutoItem")))
     JOIN "public"."TbSensorRegistro" "L" ON (("C"."cdPosicao" = "L"."cdPosicao")))
  ORDER BY "C"."dtRegistro" DESC;


ALTER TABLE "public"."vwrelhistoricodispositivoproduto" OWNER TO "postgres";


ALTER TABLE ONLY "public"."TbAcessoIntelBras" ALTER COLUMN "cdAcessoIntelBras" SET DEFAULT "nextval"('"public"."TbAcessoIntelBras_cdAcessoIntelBras_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbChamados" ALTER COLUMN "cdChamados" SET DEFAULT "nextval"('"public"."TbChamados_cdChamados_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbCliente" ALTER COLUMN "cdCliente" SET DEFAULT "nextval"('"public"."TbCliente_cdCliente_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbDestinatario" ALTER COLUMN "cdDestinatario" SET DEFAULT "nextval"('"public"."TbDestinatario_cdDestinatario_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbDispositivo" ALTER COLUMN "cdDispositivo" SET DEFAULT "nextval"('"public"."TbDispositivo_cdDispositivo_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbEndereco" ALTER COLUMN "cdEndereco" SET DEFAULT "nextval"('"public"."TbEndereco_cdEndereco_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbEtiqueta" ALTER COLUMN "cdEtiqueta" SET DEFAULT "nextval"('"public"."TbEtiqueta_cdEtiqueta_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbFuncionario" ALTER COLUMN "cdFuncionario" SET DEFAULT "nextval"('"public"."TbFuncionario_cdFuncionario_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbImagens" ALTER COLUMN "cdImagens" SET DEFAULT "nextval"('"public"."TbImagens_cdImagens_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbPonto" ALTER COLUMN "cdPonto" SET DEFAULT "nextval"('"public"."TbPonto_cdPonto_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbPosicao" ALTER COLUMN "cdPosicao" SET DEFAULT "nextval"('"public"."TbPosicao_cdPosicao_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbProduto" ALTER COLUMN "cdProduto" SET DEFAULT "nextval"('"public"."TbProduto_cdProduto_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbProdutoItem" ALTER COLUMN "cdProdutoItem" SET DEFAULT "nextval"('"public"."TbProdutoItem_cdProdutoItem_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbSensor" ALTER COLUMN "cdSensor" SET DEFAULT "nextval"('"public"."TbSensor_cdSensor_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbTag" ALTER COLUMN "cdTag" SET DEFAULT "nextval"('"public"."TbTag_cdTag_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbTicket" ALTER COLUMN "cdTicket" SET DEFAULT "nextval"('"public"."TbTicket_cdTicket_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbTicketResumo" ALTER COLUMN "cdTicketResumo" SET DEFAULT "nextval"('"public"."TbTicketResumo_cdTicketResumo_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbUnidade" ALTER COLUMN "cdUnidade" SET DEFAULT "nextval"('"public"."TbUnidade_cdUnidade_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbUsuario" ALTER COLUMN "cdUsuario" SET DEFAULT "nextval"('"public"."TbUsuario_cdUsuario_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbVisita" ALTER COLUMN "cdVisita" SET DEFAULT "nextval"('"public"."TbVisita_cdVisita_seq"'::"regclass");



ALTER TABLE ONLY "public"."TbVisitante" ALTER COLUMN "cdVisitante" SET DEFAULT "nextval"('"public"."TbVisitante_cdVisitante_seq"'::"regclass");



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



ALTER TABLE ONLY "public"."TbAcessoIntelBras"
    ADD CONSTRAINT "TbAcessoIntelBras_pkey" PRIMARY KEY ("cdAcessoIntelBras");



ALTER TABLE ONLY "public"."TbChamados"
    ADD CONSTRAINT "TbChamados_pkey" PRIMARY KEY ("cdChamados");



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



ALTER TABLE ONLY "public"."TbEtiqueta"
    ADD CONSTRAINT "TbEtiqueta_pkey" PRIMARY KEY ("cdEtiqueta");



ALTER TABLE ONLY "public"."TbFuncionario"
    ADD CONSTRAINT "TbFuncionario_pkey" PRIMARY KEY ("cdFuncionario");



ALTER TABLE ONLY "public"."TbImagens"
    ADD CONSTRAINT "TbImagens_pkey" PRIMARY KEY ("cdImagens");



ALTER TABLE ONLY "public"."TbLeituraCameraInventario"
    ADD CONSTRAINT "TbLeituraCameraInventario_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."TbMunicipio"
    ADD CONSTRAINT "TbMunicipio_pkey" PRIMARY KEY ("cdMunicipioIBGE", "cdEstadoIBGE");



ALTER TABLE ONLY "public"."TbPonto"
    ADD CONSTRAINT "TbPonto_pkey" PRIMARY KEY ("cdPonto");



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



ALTER TABLE ONLY "public"."TbTag"
    ADD CONSTRAINT "TbTag_pkey" PRIMARY KEY ("cdTag");



ALTER TABLE ONLY "public"."TbTicketResumo"
    ADD CONSTRAINT "TbTicketResumo_pkey" PRIMARY KEY ("cdTicketResumo");



ALTER TABLE ONLY "public"."TbTicket"
    ADD CONSTRAINT "TbTicket_pkey" PRIMARY KEY ("cdTicket");



ALTER TABLE ONLY "public"."TbTipoSensor"
    ADD CONSTRAINT "TbTipoSensor_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."TbTipoSensor"
    ADD CONSTRAINT "TbTipoSensor_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."TbUnidade"
    ADD CONSTRAINT "TbUnidade_pkey" PRIMARY KEY ("cdUnidade");



ALTER TABLE ONLY "public"."TbUsuario"
    ADD CONSTRAINT "TbUsuario_pkey" PRIMARY KEY ("cdUsuario");



ALTER TABLE ONLY "public"."TbVisita"
    ADD CONSTRAINT "TbVisita_pkey" PRIMARY KEY ("cdVisita");



ALTER TABLE ONLY "public"."TbVisitante"
    ADD CONSTRAINT "TbVisitante_pkey" PRIMARY KEY ("cdVisitante");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."TbEndereco"
    ADD CONSTRAINT "tbendereco_pkey" PRIMARY KEY ("cdEndereco");



CREATE INDEX "TbCliente_cdClientePai_idx" ON "public"."TbCliente" USING "btree" ("cdClientePai");



CREATE INDEX "TbDestinatario_cdCliente_idx" ON "public"."TbDestinatario" USING "btree" ("cdCliente");



CREATE INDEX "TbDispositivo_cdCliente_idx" ON "public"."TbDispositivo" USING "btree" ("cdCliente");



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



ALTER TABLE ONLY "public"."TbClienteChave"
    ADD CONSTRAINT "TbClienteChave_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."TbCliente"
    ADD CONSTRAINT "TbCliente_cdClientePai_fkey" FOREIGN KEY ("cdClientePai") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."TbCliente"
    ADD CONSTRAINT "TbCliente_cdUser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."TbDestinatario"
    ADD CONSTRAINT "TbDestinatario_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."TbDestinatario"
    ADD CONSTRAINT "TbDestinatario_cdEndereco_fkey" FOREIGN KEY ("cdEndereco") REFERENCES "public"."TbEndereco"("cdEndereco");



ALTER TABLE ONLY "public"."TbDestinatario"
    ADD CONSTRAINT "TbDestinatario_cdUser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."TbDispositivo"
    ADD CONSTRAINT "TbDispositivo_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."TbDispositivo"
    ADD CONSTRAINT "TbDispositivo_cdDestinatario_fkey" FOREIGN KEY ("cdDestinatario") REFERENCES "public"."TbDestinatario"("cdDestinatario");



ALTER TABLE ONLY "public"."TbDispositivo"
    ADD CONSTRAINT "TbDispositivo_cdProduto_fkey" FOREIGN KEY ("cdProduto") REFERENCES "public"."TbProduto"("cdProduto");



ALTER TABLE ONLY "public"."TbDispositivo"
    ADD CONSTRAINT "TbDispositivo_cdUser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."TbImagens"
    ADD CONSTRAINT "TbImagens_cdProduto_fkey" FOREIGN KEY ("cdProduto") REFERENCES "public"."TbProduto"("cdProduto");



ALTER TABLE ONLY "public"."TbImagens"
    ADD CONSTRAINT "TbImagens_cdUser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."TbPosicao"
    ADD CONSTRAINT "TbPosicao_cdDestinatario_fkey" FOREIGN KEY ("cdDestinatario") REFERENCES "public"."TbDestinatario"("cdDestinatario");



ALTER TABLE ONLY "public"."TbPosicao"
    ADD CONSTRAINT "TbPosicao_cdDispositivo_fkey" FOREIGN KEY ("cdDispositivo") REFERENCES "public"."TbDispositivo"("cdDispositivo");



ALTER TABLE ONLY "public"."TbPosicao"
    ADD CONSTRAINT "TbPosicao_cdEndereco_fkey" FOREIGN KEY ("cdEndereco") REFERENCES "public"."TbEndereco"("cdEndereco");



ALTER TABLE ONLY "public"."TbPosicao"
    ADD CONSTRAINT "TbPosicao_cdUser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."TbProdutoItemJoinTable"
    ADD CONSTRAINT "TbProdutoItemJoinTable_cdProdutoItem_fkey" FOREIGN KEY ("cdProdutoItem") REFERENCES "public"."TbProdutoItem"("cdProdutoItem");



ALTER TABLE ONLY "public"."TbProdutoItemJoinTable"
    ADD CONSTRAINT "TbProdutoItemJoinTable_cdProduto_fkey" FOREIGN KEY ("cdProduto") REFERENCES "public"."TbProduto"("cdProduto");



ALTER TABLE ONLY "public"."TbProdutoItem"
    ADD CONSTRAINT "TbProdutoItem_cdUser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."TbProduto"
    ADD CONSTRAINT "TbProduto_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."TbProduto"
    ADD CONSTRAINT "TbProduto_cdUser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



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



ALTER TABLE ONLY "public"."TbSensor"
    ADD CONSTRAINT "TbSensor_cdUser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."TbTag"
    ADD CONSTRAINT "TbTag_cdUser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."TbTipoSensor"
    ADD CONSTRAINT "TbTipoSensor_cdUser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_cdChave_fkey" FOREIGN KEY ("cdChave") REFERENCES "public"."TbClienteChave"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_cdCliente_fkey" FOREIGN KEY ("cdCliente") REFERENCES "public"."TbCliente"("cdCliente");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."TbEndereco"
    ADD CONSTRAINT "tbendereco_cduser_fkey" FOREIGN KEY ("cdUser") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE;



CREATE POLICY "Enable read access for all users" ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbDestinatario" TO "authenticated" USING (("cdCliente" = ANY (ARRAY( SELECT "public"."get_clientes_user"("auth"."uid"()) AS "get_clientes_user"))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbDispositivo" TO "authenticated" USING (("cdCliente" = ANY (ARRAY( SELECT "public"."get_clientes_user"("auth"."uid"()) AS "get_clientes_user"))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbImagens" TO "authenticated" USING (("cdProduto" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_produto"("auth"."uid"()) AS "get_clientes_user_by_produto"))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbPosicao" TO "authenticated" USING (("cdDispositivo" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_dispositivo"("auth"."uid"()) AS "get_clientes_user_by_dispositivo"))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbProduto" TO "authenticated" USING (("cdCliente" = ANY (ARRAY( SELECT "public"."get_clientes_user"("auth"."uid"()) AS "get_clientes_user"))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbProdutoItem" USING (("cdProdutoItem" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_produto_item"("auth"."uid"()) AS "get_clientes_user_by_produto_item"))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbSensor" TO "authenticated" USING (("cdDispositivo" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_dispositivo"("auth"."uid"()) AS "get_clientes_user_by_dispositivo"))));



CREATE POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbSensorRegistro" TO "authenticated" USING (("cdDispositivo" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_dispositivo"("auth"."uid"()) AS "get_clientes_user_by_dispositivo"))));



ALTER TABLE "public"."TbCliente" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbClienteChave" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbDestinatario" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbDispositivo" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbImagens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbPosicao" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbProduto" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbProdutoItem" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbProdutoItemJoinTable" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbSensor" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbSensorRegistro" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TbTipoSensor" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "apenas autenticados podem ler" ON "public"."TbProdutoItemJoinTable" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "apenas usuarios com acesso podem modificar" ON "public"."TbProdutoItemJoinTable" TO "authenticator" USING (("cdProduto" = ANY (ARRAY( SELECT "public"."get_clientes_user_by_produto"("auth"."uid"()) AS "get_clientes_user_by_produto"))));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "somente api pode fazer mudanças na chave" ON "public"."TbClienteChave" TO "service_role" USING (true);



CREATE POLICY "somente autenticados podem ler" ON "public"."TbTipoSensor" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "somente usuarios com acesso ao cliente ou pai" ON "public"."TbCliente" TO "authenticated" USING (("cdCliente" = ANY (ARRAY( SELECT "public"."get_clientes_user"("auth"."uid"()) AS "get_clientes_user"))));



CREATE POLICY "todos podem ver" ON "public"."TbClienteChave" FOR SELECT TO "anon" USING (true);





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












GRANT ALL ON TABLE "public"."TbDestinatario" TO "anon";
GRANT ALL ON TABLE "public"."TbDestinatario" TO "authenticated";
GRANT ALL ON TABLE "public"."TbDestinatario" TO "service_role";



GRANT ALL ON TABLE "public"."TbDispositivo" TO "anon";
GRANT ALL ON TABLE "public"."TbDispositivo" TO "authenticated";
GRANT ALL ON TABLE "public"."TbDispositivo" TO "service_role";



GRANT ALL ON TABLE "public"."TbPosicao" TO "anon";
GRANT ALL ON TABLE "public"."TbPosicao" TO "authenticated";
GRANT ALL ON TABLE "public"."TbPosicao" TO "service_role";



GRANT ALL ON TABLE "public"."TbProduto" TO "anon";
GRANT ALL ON TABLE "public"."TbProduto" TO "authenticated";
GRANT ALL ON TABLE "public"."TbProduto" TO "service_role";



GRANT ALL ON TABLE "public"."TbProdutoItem" TO "anon";
GRANT ALL ON TABLE "public"."TbProdutoItem" TO "authenticated";
GRANT ALL ON TABLE "public"."TbProdutoItem" TO "service_role";



GRANT ALL ON TABLE "public"."TbSensor" TO "anon";
GRANT ALL ON TABLE "public"."TbSensor" TO "authenticated";
GRANT ALL ON TABLE "public"."TbSensor" TO "service_role";



GRANT ALL ON TABLE "public"."TbSensorRegistro" TO "anon";
GRANT ALL ON TABLE "public"."TbSensorRegistro" TO "authenticated";
GRANT ALL ON TABLE "public"."TbSensorRegistro" TO "service_role";



GRANT ALL ON TABLE "public"."TbTipoSensor" TO "anon";
GRANT ALL ON TABLE "public"."TbTipoSensor" TO "authenticated";
GRANT ALL ON TABLE "public"."TbTipoSensor" TO "service_role";



GRANT ALL ON TABLE "public"."AntigoVwRelHistoricoDispositivoProduto" TO "anon";
GRANT ALL ON TABLE "public"."AntigoVwRelHistoricoDispositivoProduto" TO "authenticated";
GRANT ALL ON TABLE "public"."AntigoVwRelHistoricoDispositivoProduto" TO "service_role";



GRANT ALL ON TABLE "public"."TbAcessoIntelBras" TO "anon";
GRANT ALL ON TABLE "public"."TbAcessoIntelBras" TO "authenticated";
GRANT ALL ON TABLE "public"."TbAcessoIntelBras" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbAcessoIntelBras_cdAcessoIntelBras_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbAcessoIntelBras_cdAcessoIntelBras_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbAcessoIntelBras_cdAcessoIntelBras_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbChamados" TO "anon";
GRANT ALL ON TABLE "public"."TbChamados" TO "authenticated";
GRANT ALL ON TABLE "public"."TbChamados" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbChamados_cdChamados_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbChamados_cdChamados_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbChamados_cdChamados_seq" TO "service_role";



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



GRANT ALL ON SEQUENCE "public"."TbDestinatario_cdDestinatario_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbDestinatario_cdDestinatario_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbDestinatario_cdDestinatario_seq" TO "service_role";



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



GRANT ALL ON TABLE "public"."TbEtiqueta" TO "anon";
GRANT ALL ON TABLE "public"."TbEtiqueta" TO "authenticated";
GRANT ALL ON TABLE "public"."TbEtiqueta" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbEtiqueta_cdEtiqueta_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbEtiqueta_cdEtiqueta_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbEtiqueta_cdEtiqueta_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbFuncionario" TO "anon";
GRANT ALL ON TABLE "public"."TbFuncionario" TO "authenticated";
GRANT ALL ON TABLE "public"."TbFuncionario" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbFuncionario_cdFuncionario_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbFuncionario_cdFuncionario_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbFuncionario_cdFuncionario_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbImagens" TO "anon";
GRANT ALL ON TABLE "public"."TbImagens" TO "authenticated";
GRANT ALL ON TABLE "public"."TbImagens" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbImagens_cdImagens_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbImagens_cdImagens_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbImagens_cdImagens_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbLeituraCameraInventario" TO "anon";
GRANT ALL ON TABLE "public"."TbLeituraCameraInventario" TO "authenticated";
GRANT ALL ON TABLE "public"."TbLeituraCameraInventario" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbLeituraCameraInventario_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbLeituraCameraInventario_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbLeituraCameraInventario_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbMunicipio" TO "anon";
GRANT ALL ON TABLE "public"."TbMunicipio" TO "authenticated";
GRANT ALL ON TABLE "public"."TbMunicipio" TO "service_role";



GRANT ALL ON TABLE "public"."TbPonto" TO "anon";
GRANT ALL ON TABLE "public"."TbPonto" TO "authenticated";
GRANT ALL ON TABLE "public"."TbPonto" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbPonto_cdPonto_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbPonto_cdPonto_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbPonto_cdPonto_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbPosicao_cdPosicao_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbPosicao_cdPosicao_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbPosicao_cdPosicao_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbProdutoItemJoinTable" TO "anon";
GRANT ALL ON TABLE "public"."TbProdutoItemJoinTable" TO "authenticated";
GRANT ALL ON TABLE "public"."TbProdutoItemJoinTable" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbProdutoItem_cdProdutoItem_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbProdutoItem_cdProdutoItem_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbProdutoItem_cdProdutoItem_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbProduto_cdProduto_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbProduto_cdProduto_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbProduto_cdProduto_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbSensor_cdSensor_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbSensor_cdSensor_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbSensor_cdSensor_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbTag" TO "anon";
GRANT ALL ON TABLE "public"."TbTag" TO "authenticated";
GRANT ALL ON TABLE "public"."TbTag" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbTag_cdTag_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbTag_cdTag_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbTag_cdTag_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbTicket" TO "anon";
GRANT ALL ON TABLE "public"."TbTicket" TO "authenticated";
GRANT ALL ON TABLE "public"."TbTicket" TO "service_role";



GRANT ALL ON TABLE "public"."TbTicketResumo" TO "anon";
GRANT ALL ON TABLE "public"."TbTicketResumo" TO "authenticated";
GRANT ALL ON TABLE "public"."TbTicketResumo" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbTicketResumo_cdTicketResumo_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbTicketResumo_cdTicketResumo_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbTicketResumo_cdTicketResumo_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbTicket_cdTicket_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbTicket_cdTicket_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbTicket_cdTicket_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbTipoSensor_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbTipoSensor_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbTipoSensor_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbUnidade" TO "anon";
GRANT ALL ON TABLE "public"."TbUnidade" TO "authenticated";
GRANT ALL ON TABLE "public"."TbUnidade" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbUnidade_cdUnidade_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbUnidade_cdUnidade_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbUnidade_cdUnidade_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbUsuario" TO "anon";
GRANT ALL ON TABLE "public"."TbUsuario" TO "authenticated";
GRANT ALL ON TABLE "public"."TbUsuario" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbUsuario_cdUsuario_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbUsuario_cdUsuario_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbUsuario_cdUsuario_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbVisita" TO "anon";
GRANT ALL ON TABLE "public"."TbVisita" TO "authenticated";
GRANT ALL ON TABLE "public"."TbVisita" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbVisita_cdVisita_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbVisita_cdVisita_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbVisita_cdVisita_seq" TO "service_role";



GRANT ALL ON TABLE "public"."TbVisitante" TO "anon";
GRANT ALL ON TABLE "public"."TbVisitante" TO "authenticated";
GRANT ALL ON TABLE "public"."TbVisitante" TO "service_role";



GRANT ALL ON SEQUENCE "public"."TbVisitante_cdVisitante_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."TbVisitante_cdVisitante_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."TbVisitante_cdVisitante_seq" TO "service_role";



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



GRANT ALL ON TABLE "public"."vwrelhistoricodispositivoproduto" TO "anon";
GRANT ALL ON TABLE "public"."vwrelhistoricodispositivoproduto" TO "authenticated";
GRANT ALL ON TABLE "public"."vwrelhistoricodispositivoproduto" TO "service_role";



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
