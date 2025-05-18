drop view public."VwRelDadosDispositivo";
drop view public."VwRelHistoricoDispositivoProduto";
drop view public."VwTbDestinatarioDispositivo";
drop view public."VwTbPosicaoAtual";

create view public."VwTbPosicaoAtual" as
select
  "A"."cdPosicao",
  "A"."dtRegistro",
  "A"."cdDispositivo",
  "en"."dsLat",
  "en"."dsLong",
  "en"."dsLogradouro" as "dsEndereco",
  "en"."nrNumero" as "dsNum",
  "en"."dsCep",
  "en"."dsBairro",
  "en"."dsCidade",
  "en"."dsUF",
  "A"."nrBat",
  "B"."nrCodigo",
  "B"."cdProduto",
  "B"."dsNome" as "dsProduto",
  "B"."dsDescricao",
  "E"."cdStatus",
  "A"."blArea",
  "E"."cdCliente"
from
  "TbPosicao" "A"
  join "TbEndereco" en on en."cdEndereco" = "A"."cdEndereco"
  join "TbDispositivo" "E" on "A"."cdDispositivo" = "E"."cdDispositivo"
  join "TbProduto" "B" on "E"."cdProduto" = "B"."cdProduto"
  join (
    select
      max("TbPosicao"."cdPosicao") as "cdPosicao"
    from
      "TbPosicao"
    group by
      "TbPosicao"."cdDispositivo"
  ) "D" on "A"."cdPosicao" = "D"."cdPosicao";


create view public."VwRelHistoricoDispositivoProduto" as
select
  pd."cdProduto",
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
    select
      srr."nrValor"
    from
      "TbSensorRegistro" srr
      join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
      join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
    where
      srr."cdDispositivo" = p."cdDispositivo"
      and srr."cdPosicao" = p."cdPosicao"
      and tts.id = 2
  ) as "nrPorta",
  (
    select
      srr."nrValor"
    from
      "TbSensorRegistro" srr
      join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
      join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
    where
      srr."cdDispositivo" = p."cdDispositivo"
      and srr."cdPosicao" = p."cdPosicao"
      and tts.id = 4
  ) as "nrTemperatura",
  (
    (
      select
        srr."nrValor"
      from
        "TbSensorRegistro" srr
        join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
        join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
      where
        srr."cdDispositivo" = p."cdDispositivo"
        and srr."cdPosicao" = p."cdPosicao"
        and ts_1."cdSensor" = s."cdSensor"
        and tts.id = 5
    )
  )::double precision as "nrPessoas",
  pi."dsNome" as "dsProdutoItem",
  (
    (
      select
        srr."nrValor"
      from
        "TbSensorRegistro" srr
        join "TbSensor" ts_1 on ts_1."cdSensor" = srr."cdSensor"
        join "TbTipoSensor" tts on ts_1."cdTipoSensor" = tts.id
      where
        srr."cdDispositivo" = p."cdDispositivo"
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
from
  "TbSensor" s
  left join "TbProdutoItem" pi on s."cdProdutoItem" = pi."cdProdutoItem"
  join "TbDispositivo" d on d."cdDispositivo" = s."cdDispositivo"
  join "TbSensorRegistro" sr on sr."cdSensor" = s."cdSensor"
  join "TbTipoSensor" ts on ts.id = s."cdTipoSensor"
  join "TbPosicao" p on p."cdPosicao" = sr."cdPosicao"
  join "TbEndereco" e on e."cdEndereco" = p."cdEndereco"
  join "TbDestinatario" dest on dest."cdDestinatario" = d."cdDestinatario"
  join "TbProduto" pd on pd."cdProduto" = d."cdProduto"
order by
  p."dtRegistro" desc;



create view public."VwTbDestinatarioDispositivo" as
select
  a."cdDestinatario",
  e."dsLat",
  e."dsLong",
  a."nrRaio",
  b."cdDispositivo",
  b."cdCliente"
from
  "TbDestinatario" a
  join "TbDispositivo" b on a."cdDestinatario" = b."cdDestinatario"
  join "TbEndereco" e on e."cdEndereco" = a."cdEndereco";


create view public."VwRelDadosDispositivo" as
select
  "A"."cdProduto",
  "A"."dsNome",
  "C"."cdDispositivo",
  (
    case
      when "C"."nrBat" > 3.7::double precision then 3.7::double precision
      else "C"."nrBat"
    end / 3.7::double precision * 100::double precision
  )::numeric(15, 2) as "nrBat",
  "E"."dsNome" as "dsNomeDest",
  "endereco"."dsLogradouro" as "dsEnderecoDest",
  "endereco"."nrNumero" as "nrNumeroDest",
  "endereco"."dsBairro" as "dsBairroDest",
  "endereco"."dsCidade" as "dsCidadeDest",
  "endereco"."dsUF" as "dsUfDest",
  "endereco"."dsCep" as "dsCepDest",
  "endereco"."dsLat" as "dsLatDest",
  "endereco"."dsLong" as "dsLongDest",
  "E"."nrRaio" as "dsRaio",
  "C"."dsEndereco" as "dsEnderecoAtual",
  "C"."dsNum" as "dsNumeroAtual",
  "C"."dsBairro" as "dsBairroAtual",
  "C"."dsCidade" as "dsCidadeAtual",
  "C"."dsUF" as "dsUFAtual",
  "C"."dsCep" as "dsCEPAtual",
  "C"."dsLat" as "dsLatAtual",
  "C"."dsLong" as "dsLongAtual",
  "C"."blArea",
  "C"."dtRegistro",
  "F"."dtRegistro" as "dtCadastro",
  "F"."cdCliente"
from
  "TbProduto" "A"
  join "TbDispositivo" "F" on "F"."cdProduto" = "A"."cdProduto"
  join "VwTbPosicaoAtual" "C" on "F"."cdDispositivo" = "C"."cdDispositivo"
  join "TbDestinatario" "E" on "F"."cdDestinatario" = "E"."cdDestinatario"
  join "TbEndereco" "endereco" on "E"."cdEndereco" = "endereco"."cdEndereco";

