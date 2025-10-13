drop view if exists "public"."VwRelHistoricoDispositivoProduto";
create or replace view "public"."VwRelHistoricoDispositivoProduto" as
select pd."cdProduto",
    pd."cdCliente",
    pd."nrCodigo",
    pd."dsDescricao",
    p."dtRegistro",
    d."cdDispositivo",
    dest."dsNome",
    e."dsLogradouro" as "dsEndereco",
    s."cdSensor",
    concat(
        (
            case
                when p."nrBat" > 3.7::double precision then 3.7::double precision
                else p."nrBat"
            end / 3.7::double precision * 100::double precision
        )::numeric(15, 2),
        '%'
    ) as "nrBatPercentual",
    (
        select srr."nrValor"
        from "TbSensorRegistro" srr
            join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
            join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
        where srr."cdDispositivo" = p."cdDispositivo"
            and srr."cdPosicao" = p."cdPosicao"
            and tts.id = 2
    ) as "nrPorta",
    (
        select srr."nrValor"
        from "TbSensorRegistro" srr
            join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
            join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
        where srr."cdDispositivo" = p."cdDispositivo"
            and srr."cdPosicao" = p."cdPosicao"
            and tts.id = 4
    ) as "nrTemperatura",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 5
        )
    )::double precision as "nrPessoas",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 9
        )
    )::double precision as "nrMasculino",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 10
        )
    )::double precision as "nrFeminino",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 11
        )
    )::double precision as "nrCrianca",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 12
        )
    )::double precision as "nrJovem",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 13
        )
    )::double precision as "nrAdulto",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 14
        )
    )::double precision as "nrSenior",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 15
        )
    )::double precision as "nrAlegre",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 16
        )
    )::double precision as "nrTriste",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 17
        )
    )::double precision as "nrNeutro",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and ts_1."cdSensor" = s."cdSensor"
                and tts.id = 18
        )
    )::double precision as "nrCategoriaTotal",
    pi."dsNome" as "dsProdutoItem",
    (
        (
            select srr."nrValor"
            from "TbSensorRegistro" srr
                join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
                join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
            where srr."cdDispositivo" = p."cdDispositivo"
                and srr."cdPosicao" = p."cdPosicao"
                and tts.id = 1
                and pi."cdProdutoItem" = ts_1."cdProdutoItem"
        )
    )::double precision as "nrQtdItens",
    sr."nrValor"::double precision as "nrLeituraSensor",
    ts."dsNome" as "dsTipoSensor",
    ts."dsUnidade" as "dsUnidadeMedida",
    case
        when p."blArea" = false then 'Fora de Área'::text
        else 'Dentro da Área'::text
    end as "dsStatus",
    d."cdStatus" as "dsStatusDispositivo",
    pi."nrPesoUnit" as "nrPesoUnitario",
    pi."nrLarg",
    pi."nrComp",
    pi."nrAlt",
    s."nrUnidadeIni",
    s."nrUnidadeFim",
    p."cdPosicao"
from "TbSensor" s
    left join "TbProdutoItem" pi on s."cdProdutoItem" = pi."cdProdutoItem"
    join "TbDispositivo" d on d."cdDispositivo" = s."cdDispositivo"
    join "TbSensorRegistro" sr on sr."cdSensor" = s."cdSensor"
    join "TbTipoSensor" ts on ts.id = s."cdTipoSensor"
    join "TbPosicao" p on p."cdPosicao" = sr."cdPosicao"
    join "TbEndereco" e on e."cdEndereco" = p."cdEndereco"
    join "TbDestinatario" dest on dest."cdDestinatario" = d."cdDestinatario"
    join "TbProduto" pd on pd."cdProduto" = d."cdProduto"
order by p."dtRegistro" desc;