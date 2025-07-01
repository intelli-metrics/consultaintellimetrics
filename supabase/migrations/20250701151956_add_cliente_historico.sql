drop view if exists "public"."VwRelHistoricoDispositivoProduto";

create or replace view "public"."VwRelHistoricoDispositivoProduto" as  SELECT pd."cdProduto",
    pd."cdCliente",
    pd."nrCodigo",
    pd."dsDescricao",
    p."dtRegistro",
    d."cdDispositivo",
    dest."dsNome",
    e."dsLogradouro" AS "dsEndereco",
    s."cdSensor",
    concat((((
        CASE
            WHEN (p."nrBat" > (3.7)::double precision) THEN (3.7)::double precision
            ELSE p."nrBat"
        END / (3.7)::double precision) * (100)::double precision))::numeric(15,2), '%') AS "nrBatPercentual",
    ( SELECT srr."nrValor"
           FROM (("TbSensorRegistro" srr
             JOIN "TbSensor" ts_1 ON ((ts_1."cdSensor" = srr."cdSensor")))
             JOIN "TbTipoSensor" tts ON ((ts_1."cdTipoSensor" = tts.id)))
          WHERE ((srr."cdDispositivo" = p."cdDispositivo") AND (srr."cdPosicao" = p."cdPosicao") AND (tts.id = 2))) AS "nrPorta",
    ( SELECT srr."nrValor"
           FROM (("TbSensorRegistro" srr
             JOIN "TbSensor" ts_1 ON ((ts_1."cdSensor" = srr."cdSensor")))
             JOIN "TbTipoSensor" tts ON ((ts_1."cdTipoSensor" = tts.id)))
          WHERE ((srr."cdDispositivo" = p."cdDispositivo") AND (srr."cdPosicao" = p."cdPosicao") AND (tts.id = 4))) AS "nrTemperatura",
    (( SELECT srr."nrValor"
           FROM (("TbSensorRegistro" srr
             JOIN "TbSensor" ts_1 ON ((ts_1."cdSensor" = srr."cdSensor")))
             JOIN "TbTipoSensor" tts ON ((ts_1."cdTipoSensor" = tts.id)))
          WHERE ((srr."cdDispositivo" = p."cdDispositivo") AND (srr."cdPosicao" = p."cdPosicao") AND (ts_1."cdSensor" = s."cdSensor") AND (tts.id = 5))))::double precision AS "nrPessoas",
    pi."dsNome" AS "dsProdutoItem",
    (( SELECT srr."nrValor"
           FROM (("TbSensorRegistro" srr
             JOIN "TbSensor" ts_1 ON ((ts_1."cdSensor" = srr."cdSensor")))
             JOIN "TbTipoSensor" tts ON ((ts_1."cdTipoSensor" = tts.id)))
          WHERE ((srr."cdDispositivo" = p."cdDispositivo") AND (srr."cdPosicao" = p."cdPosicao") AND (tts.id = 1) AND (pi."cdProdutoItem" = ts_1."cdProdutoItem"))))::double precision AS "nrQtdItens",
    (sr."nrValor")::double precision AS "nrLeituraSensor",
    ts."dsNome" AS "dsTipoSensor",
    ts."dsUnidade" AS "dsUnidadeMedida",
        CASE
            WHEN (p."blArea" = false) THEN 'Fora de Área'::text
            ELSE 'Dentro da Área'::text
        END AS "dsStatus",
    d."cdStatus" AS "dsStatusDispositivo",
    pi."nrPesoUnit" AS "nrPesoUnitario",
    pi."nrLarg",
    pi."nrComp",
    pi."nrAlt",
    s."nrUnidadeIni",
    s."nrUnidadeFim",
    p."cdPosicao"
   FROM (((((((("TbSensor" s
     LEFT JOIN "TbProdutoItem" pi ON ((s."cdProdutoItem" = pi."cdProdutoItem")))
     JOIN "TbDispositivo" d ON ((d."cdDispositivo" = s."cdDispositivo")))
     JOIN "TbSensorRegistro" sr ON ((sr."cdSensor" = s."cdSensor")))
     JOIN "TbTipoSensor" ts ON ((ts.id = s."cdTipoSensor")))
     JOIN "TbPosicao" p ON ((p."cdPosicao" = sr."cdPosicao")))
     JOIN "TbEndereco" e ON ((e."cdEndereco" = p."cdEndereco")))
     JOIN "TbDestinatario" dest ON ((dest."cdDestinatario" = d."cdDestinatario")))
     JOIN "TbProduto" pd ON ((pd."cdProduto" = d."cdProduto")))
  ORDER BY p."dtRegistro" DESC;



