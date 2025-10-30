from collections import defaultdict
from typing import Any, Dict, List

import pandas as pd
import requests
from flask import jsonify

from db_utils import supabase_api
from utils import (
    calcular_distancia,
    valida_e_constroi_insert,
    convert_sao_paulo_date_to_utc_range,
)
import pytz
from datetime import datetime, time


def Selecionar_VwTbProdutoTotalStatus(filtros, db_client=supabase_api):
    query = db_client.table("VwTbProdutoTotalStatus").select(
        "cdProduto",
        "dsDescricao",
        "dsNome",
        "nrAlt",
        "nrCodigo",
        "nrComp",
        "nrLarg",
        "nrQtde",
        "StatusDispositivo",
        "QtdeTotal",
        "cdCliente",
        "imagens:TbImagens(cdCodigo, dsCaminho)",
    )

    # aplica filtros
    for campo, valor in filtros.items():
        if campo == "dtRegistro":
            start_dt, end_dt = convert_sao_paulo_date_to_utc_range(valor)
            query = query.gte(campo, start_dt)
            query = query.lte(campo, end_dt)
        else:
            query = query.eq(campo, valor)

    resultado = query.execute()

    produtos_dict: Dict[str, Any] = defaultdict(
        lambda: {
            "cdProduto": None,
            "dsDescricao": None,
            "dsNome": None,
            "nrAlt": None,
            "nrCodigo": None,
            "nrComp": None,
            "nrLarg": None,
            "QtdeTotal": None,
            "imagens": None,
            "status": [],
        }
    )

    for produto in resultado.data:
        cdProduto = produto["cdProduto"]

        # inicializa o produto se ele ainda nao existe no dict
        if produtos_dict[cdProduto]["cdProduto"] is None:
            produtos_dict[cdProduto].update(
                {
                    "cdProduto": produto["cdProduto"],
                    "dsDescricao": produto["dsDescricao"],
                    "dsNome": produto["dsNome"],
                    "nrAlt": produto["nrAlt"],
                    "nrCodigo": produto["nrCodigo"],
                    "nrComp": produto["nrComp"],
                    "nrLarg": produto["nrLarg"],
                    "QtdeTotal": produto["QtdeTotal"],
                    "imagens": produto["imagens"],
                }
            )

        # adiciona status a lista
        if produto["nrQtde"] and produto["StatusDispositivo"]:
            produtos_dict[cdProduto]["status"].append(
                {"cdStatus": produto["StatusDispositivo"], "nrQtde": produto["nrQtde"]}
            )

    # lista de cdProdutos
    cdProdutos = [item["cdProduto"] for item in resultado.data]

    # busca quantidade de dispositivos fora de area por produto
    prodForaRes = (
        supabase_api.table("VwProdutosFora")
        .select("*")
        .in_("cdProduto", cdProdutos)
        .execute()
    )

    # adiciona no dicionario de produtos a ser retornado
    for item in prodForaRes.data:
        produtos_dict[item["cdProduto"]]["nrFora"] = item["dispositivo_count"]

    # Converte para lista para poder serializar como json
    produtos_list: List[Dict[str, Any]] = list(produtos_dict.values())

    return jsonify(produtos_list)


def Selecionar_TbCliente():
    resultado = (
        supabase_api.table("TbCliente")
        .select(
            "cdCliente",
            "dsNome",
            "nrCnpj",
            "nrIe",
            "nrInscMun",
            "dsLogradouro",
            "nrNumero",
            "dsComplemento",
            "dsBairro",
            "dsCep",
            "dsCidade",
            "dsUF",
            "dsObs",
            "cdStatus",
            "cdUser",
            "dtRegistro",
        )
        .execute()
    )

    return resultado.data


def Selecionar_TbDestinatario(cdDestinatario, cdCliente, db_client=supabase_api):
    query = db_client.table("TbDestinatario").select("*")

    if cdDestinatario != "0":
        query.eq("cdDestinatario", cdDestinatario)

    query.eq("cdCliente", cdCliente)

    resultado = query.execute()

    return resultado.data


def Inserir_TbDestinatario(data):
    resultado = supabase_api.table("TbDestinatario").insert(data).execute()
    return resultado.data


def Selecionar_TbDispositivo(codigo, db_client=supabase_api):
    query = db_client.table("TbDispositivo").select("*")

    if codigo != "0":
        query.eq("cdDispositivo", codigo)

    resultado = query.execute()

    return resultado.data


def Inserir_TbDispositivo(data):
    resultado = supabase_api.table("TbDispositivo").insert(data).execute()
    return resultado.data


def Selecionar_TbImagens(codigo, db_client=supabase_api):
    query = db_client.table("TbImagens").select("*")

    if codigo != "0":
        query.eq("cdProduto", codigo)

    resultado = query.execute()

    return resultado.data


def Inserir_TbImagens(data, db_client=supabase_api):
    resultado = db_client.table("TbImagens").insert(data).execute()
    return resultado.data


def Selecionar_TbPosicao(filtros, db_client=supabase_api):
    query = db_client.table("TbPosicao").select("*")

    # aplica filtros
    for campo, valor in filtros.items():
        if campo == "dtRegistro":
            start_dt, end_dt = convert_sao_paulo_date_to_utc_range(valor)
            query = query.gte(campo, start_dt)
            query = query.lte(campo, end_dt)
        else:
            query = query.eq(campo, valor)

    resultado = query.execute()

    return resultado.data


def get_endereco_coordenada(lat, lon):
    resultado = {}
    url = f"https://nominatim.openstreetmap.org/reverse"
    params = {
        "format": "json",
        "lat": lat,
        "lon": lon,
        "addressdetails": 1,
        "zoom": 18,
    }
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "Intellimetrics/1.0 (augusto@intellimetrics.tec.br)",
    }

    try:
        response = requests.get(url, params=params, headers=headers, timeout=10)

        # Lida com rate limiting
        if response.status_code == 429:
            print("Rate limit exceeded for Nominatim API")
            return None, "Rate limit exceeded. Please try again later."

        # Lida com outros erros HTTP
        if response.status_code != 200:
            print(
                f"Erro na requisição de endereço: {response.status_code}, {response.text}"
            )
            return None, f"Error fetching address: {response.status_code}"

        data = response.json()

        # Verifica se a resposta é válida
        if not data or "address" not in data:
            return None, "Nenhum endereço encontrado para essas coordenadas"

        endereco = data.get("address", {})

        # Constrói o resultado com fallback para campos ausentes
        resultado = {
            "dsLogradouro": endereco.get("road", "Nome da rua não encontrado"),
            "dsNumero": endereco.get("house_number", ""),
            "dsBairro": endereco.get("suburb", ""),
            "dsCidade": endereco.get("city", endereco.get("town", "")),
            "dsUF": endereco.get("state", ""),
            "dsCep": endereco.get("postcode", ""),
            "dsLat": lat,
            "dsLong": lon,
            "dsPais": endereco.get("country_code", ""),
        }

        return resultado, None

    except requests.exceptions.Timeout:
        print("Timeout ao buscar endereço do Nominatim")
        return None, "Timeout ao buscar endereço"
    except requests.exceptions.RequestException as e:
        print(f"Erro de rede ao buscar endereço: {str(e)}")
        return None, f"Erro de rede: {str(e)}"
    except ValueError as e:
        print(f"Erro ao analisar resposta do Nominatim: {str(e)}")
        return None, "Erro ao analisar dados do endereço"
    except Exception as e:
        print(f"Erro inesperado em get_endereco_coordenada: {str(e)}")
        return None, f"Erro inesperado: {str(e)}"


def get_endereco_coordenadanew(lat, long):
    url = f"https://nominatim.openstreetmap.org/reverse"
    params = {'format': 'json','lat': lat,'lon': long,'addressdetails': 1}
    response = requests.get(url, params=params)
    resultado = {}
    
    endereco = response.json()
        #print(data)
    
    resultado["dsLogradouro"] = endereco.get("road")
    resultado["dsEndereco"] = endereco.get("road")
    resultado["dsNum"] = "0"
    resultado["dsBairro"] = endereco.get("suburb")
    resultado["dsCidade"] = endereco.get("city_district")
    resultado["dsUF"] = "SP" # endereco.get("state")
    resultado["dsCep"] = endereco.get("postcode")
    resultado["dsPais"] = "BR" #endereco.get("country_code")
        
        
        #print(resultado)
        #return data['display_name'], data['address']
    return resultado
        
         
        
   

def is_dentro_area(cdDispositivo, dsLat, dsLong):
    dic_endereco_pdv = Selecionar_VwTbDestinatarioDispositivo(codigoDisp=cdDispositivo)
    dic_endereco_pdv = dict(dic_endereco_pdv[0])

    dsLatPdv = dic_endereco_pdv["dsLat"]
    dsLongPdv = dic_endereco_pdv["dsLong"]
    nrRaio = dic_endereco_pdv["nrRaio"]
    nrDistancia = calcular_distancia(dsLat, dsLong, dsLatPdv, dsLongPdv)

    return float(nrDistancia) <= float(nrRaio)


def get_produto_item_from_sensores_result(sensores_result, cdSensor):
    for sensor in sensores_result:
        if cdSensor == sensor["cdSensor"]:
            return sensor["cdProdutoItem"], None

    return None, f"sensor com id {cdSensor} nao foi encontrado"


def prepara_insert_registros(dic_sensores, cdDispositivo):
    dataSensoresRegistro = []

    # busca produto itens pelos sensores
    sensores_query = supabase_api.table("TbSensor").select("cdSensor", "cdProdutoItem")
    id_sensores = []

    for sensor in dic_sensores:
        if "cdSensor" not in sensor:
            return None, "Objeto sensor sem cdSensor"
        if "nrValor" not in sensor:
            return None, "Objeto sensor sem nrValor"

        id_sensores.append(sensor["cdSensor"])

    sensores_result = sensores_query.in_("cdSensor", id_sensores).execute()

    for sensor in dic_sensores:
        cdProdutoItem, error = get_produto_item_from_sensores_result(
            sensores_result=sensores_result.data, cdSensor=sensor["cdSensor"]
        )

        if error:
            return None, error

        payload_sensor_registro = {
            "cdDispositivo": cdDispositivo,
            "cdSensor": sensor["cdSensor"],
            "nrValor": sensor["nrValor"],
        }
        if cdProdutoItem:
            payload_sensor_registro["cdProdutoItem"] = cdProdutoItem

        data, error = valida_e_constroi_insert(
            table="TbSensorRegistro",
            payload=payload_sensor_registro,
            ignorar_fields=["cdPosicao"],
        )

        if error:
            return None, error

        dataSensoresRegistro.append(data)

    return dataSensoresRegistro, None


def Inserir_TbSensorRegistro(data):
    resultado = supabase_api.table("TbSensorRegistro").insert(data).execute()
    return resultado.data


def Inserir_TbPosicao(data):
    resultado = supabase_api.table("TbPosicao").insert(data).execute()
    return resultado.data


def Selecionar_VwTbDestinatarioDispositivo(codigoDisp):
    resultado = (
        supabase_api.table("VwTbDestinatarioDispositivo")
        .select("*")
        .eq("cdDispositivo", codigoDisp)
        .execute()
    )
    return resultado.data


def Inserir_TbProduto(data, db_client=supabase_api):
    resultado = db_client.table("TbProduto").insert(data).execute()
    return resultado.data


def Alterar_TbProduto(Campo, Dado, UpData, db_client=supabase_api):
    response = db_client.table("TbProduto").update(UpData).eq(Campo, Dado).execute()
    return response.data


def Inserir_TbSensor(data):
    resultado = supabase_api.table("TbSensor").insert(data).execute()
    return resultado.data


def Selecionar_VwTbProdutoTipo(codigo, db_client=supabase_api):
    query = db_client.table("VwTbProdutoTipo").select("*")

    if codigo != "0":
        query.eq("cdProduto", codigo)

    resultado = query.execute()

    return resultado.data


def Selecionar_VwRelHistoricoDispositivoProduto(filtros, db_client=supabase_api):
    query = db_client.table("VwRelHistoricoDispositivoProduto").select("*")

    # Date range logic for São Paulo timezone
    dt_inicio = filtros.pop("dtRegistroComeco", None)
    dt_fim = filtros.pop("dtRegistroFim", None)
    if dt_inicio and dt_fim:
        start_dt, _ = convert_sao_paulo_date_to_utc_range(dt_inicio)
        _, end_dt = convert_sao_paulo_date_to_utc_range(dt_fim)
        query = query.gte("dtRegistro", start_dt)
        query = query.lte("dtRegistro", end_dt)
    elif dt_inicio:
        start_dt, _ = convert_sao_paulo_date_to_utc_range(dt_inicio)
        query = query.gte("dtRegistro", start_dt)
    elif dt_fim:
        _, end_dt = convert_sao_paulo_date_to_utc_range(dt_fim)
        query = query.lte("dtRegistro", end_dt)

    # aplica outros filtros
    for campo, valor in filtros.items():
        if campo == "dtRegistro":
            start_dt, end_dt = convert_sao_paulo_date_to_utc_range(valor)
            query = query.gte(campo, start_dt)
            query = query.lte(campo, end_dt)
        else:
            query = query.eq(campo, valor)

    # TODO: trocar quando tivermos paginação no server
    query.limit(100000)

    # se o cliente nao tem acesso a nenhuma informaçao, o supabase retorna um erro 400. Esse try
    # previne um erro 500 a ser enviado ao cliente
    # TODO: rever isso. Idealmente o supabase so retornaria um []
    try:
        resultado = query.execute()
    except Exception as e:
        print("Erro buscando VwRelHistoricoDispositivoProduto")
        print(e)
        return []

    return resultado.data


# busca dados de VwRelHistoricoDispositivoProduto, mas retorna cada produtoItem como uma coluna.
def Selecionar_HistoricoPaginaDispositivo(filtros, db_client=supabase_api):
    resultado = Selecionar_VwRelHistoricoDispositivoProduto(filtros, db_client)

    if len(resultado) == 0:
        return resultado

    # Get device configurations for time filtering
    dispositivos = list(set(row["cdDispositivo"] for row in resultado))
    horarios = (
        db_client.table("TbDispositivo")
        .select("cdDispositivo", "horarioMedicaoInicio", "horarioMedicaoFim")
        .in_("cdDispositivo", dispositivos)
        .execute()
        .data
    )

    # Create a dict for quick lookup
    horarios_dict = {
        d["cdDispositivo"]: (d["horarioMedicaoInicio"], d["horarioMedicaoFim"])
        for d in horarios
    }

    # filtra por horario de medição. Remover dados fora do horario de medição.
    filtered_resultado = []
    for row in resultado:
        horario = horarios_dict.get(row["cdDispositivo"])
        if not horario or horario[0] is None:  # No time restriction
            filtered_resultado.append(row)
            continue

        inicio_str, fim_str = horario

        # Convert string times to datetime.time objects
        try:
            inicio = (
                datetime.strptime(inicio_str, "%H:%M:%S").time() if inicio_str else None
            )
            fim = datetime.strptime(fim_str, "%H:%M:%S").time() if fim_str else None
            hora = datetime.fromisoformat(row["dtRegistro"]).time()
            print(inicio, fim, hora)
        except (ValueError, TypeError):
            # If there's any error converting the times, skip filtering for this row
            filtered_resultado.append(row)
            continue

        # Check if time is within range
        if inicio > fim:  # Crosses midnight
            if hora >= inicio or hora <= fim:
                print("dentro do horario")
                filtered_resultado.append(row)
        else:  # Normal range
            if inicio <= hora <= fim:
                print("dentro do horario")
                filtered_resultado.append(row)

    # processa cada linha para calcular nrQtdItens e nrTemperatura baseado no tipo de sensor
    for row in filtered_resultado:
        if row["dsUnidadeMedida"] == "celcius":
            row["nrTemperatura"] = row["nrLeituraSensor"]
            row["nrQtdItens"] = 0
        elif row["dsUnidadeMedida"] == "abertura":
            row["nrQtdItens"] = 0
            row["nrPorta"] = row["nrLeituraSensor"]
        elif row["dsUnidadeMedida"] == "gramas":
            leitura_sem_tara = row["nrLeituraSensor"] - (row["nrUnidadeIni"] or 0)
            row["nrQtdItens"] = (
                leitura_sem_tara / row["nrPesoUnitario"] if row["nrPesoUnitario"] else 0
            )
            row["nrTemperatura"] = 0
        elif row["dsUnidadeMedida"] == "milimetros":
            row["nrQtdItens"] = (
                row["nrLeituraSensor"] / row["nrAlt"] if row["nrAlt"] else 0
            )
            row["nrTemperatura"] = 0
        elif row["dsUnidadeMedida"] == "unidade":
            row["nrQtdItens"] = row["nrLeituraSensor"]
            row["nrTemperatura"] = 0

    if len(filtered_resultado) == 0:
        return filtered_resultado

    # converte em pandas dataframe
    df = pd.DataFrame(filtered_resultado)

    # Create base dataframe with non-sensor specific columns
    base_columns = [
        "cdProduto",
        "nrCodigo",
        "dsDescricao",
        "dtRegistro",
        "cdDispositivo",
        "dsNome",
        "dsEndereco",
        "nrBatPercentual",
        "dsStatus",
        "dsStatusDispositivo",
        "cdPosicao",
    ]

    base_df = df[base_columns].drop_duplicates()

    # Add sensor-specific aggregated columns
    temp_df = (
        df[df["dsUnidadeMedida"] == "celcius"]
        .groupby("cdPosicao")["nrTemperatura"]
        .first()
        .reset_index()
    )
    porta_df = (
        df[df["dsUnidadeMedida"] == "abertura"]
        .groupby("cdPosicao")["nrPorta"]
        .first()
        .reset_index()
    )
    pessoas_df = (
        df[df["dsUnidadeMedida"] == "Qtde de pessoas"]
        .groupby("cdPosicao")["nrPessoas"]
        .first()
        .reset_index()
    )
    masculino_df = (
        df[df["dsUnidadeMedida"] == "masculino"]
        .groupby("cdPosicao")["nrMasculino"]
        .first()
        .reset_index()
    )
    feminino_df = (
        df[df["dsUnidadeMedida"] == "feminino"]
        .groupby("cdPosicao")["nrFeminino"]
        .first()
        .reset_index()
    )
    crianca_df = (
        df[df["dsUnidadeMedida"] == "crianca"]
        .groupby("cdPosicao")["nrCrianca"]
        .first()
        .reset_index()
    )
    jovem_df = (
        df[df["dsUnidadeMedida"] == "jovem"]
        .groupby("cdPosicao")["nrJovem"]
        .first()
        .reset_index()
    )
    adulto_df = (
        df[df["dsUnidadeMedida"] == "adulto"]
        .groupby("cdPosicao")["nrAdulto"]
        .first()
        .reset_index()
    )
    senior_df = (
        df[df["dsUnidadeMedida"] == "senior"]
        .groupby("cdPosicao")["nrSenior"]
        .first()
        .reset_index()
    )
    alegre_df = (
        df[df["dsUnidadeMedida"] == "alegre"]
        .groupby("cdPosicao")["nrAlegre"]
        .first()
        .reset_index()
    )
    triste_df = (
        df[df["dsUnidadeMedida"] == "triste"]
        .groupby("cdPosicao")["nrTriste"]
        .first()
        .reset_index()
    )
    neutro_df = (
        df[df["dsUnidadeMedida"] == "neutro"]
        .groupby("cdPosicao")["nrNeutro"]
        .first()
        .reset_index()
    )
    categoria_total_df = (
        df[df["dsUnidadeMedida"] == "categoria_total"]
        .groupby("cdPosicao")["nrCategoriaTotal"]
        .first()
        .reset_index()
    )

    # Pivot the quantities
    pivot_df = df.pivot_table(
        index="cdPosicao",
        columns=["dsProdutoItem", "cdSensor"],
        values="nrQtdItens",
        fill_value=0,
    )

    # Flatten the multi-index columns
    pivot_df.columns = [f"{item[0]}_{item[1]}" for item in pivot_df.columns]
    pivot_df = pivot_df.reset_index()

    # Merge all the dataframes
    final_df = base_df.merge(temp_df, on="cdPosicao", how="left")
    final_df = final_df.merge(porta_df, on="cdPosicao", how="left")
    final_df = final_df.merge(pessoas_df, on="cdPosicao", how="left")
    final_df = final_df.merge(masculino_df, on="cdPosicao", how="left")
    final_df = final_df.merge(feminino_df, on="cdPosicao", how="left")
    final_df = final_df.merge(crianca_df, on="cdPosicao", how="left")
    final_df = final_df.merge(jovem_df, on="cdPosicao", how="left")
    final_df = final_df.merge(adulto_df, on="cdPosicao", how="left")
    final_df = final_df.merge(senior_df, on="cdPosicao", how="left")
    final_df = final_df.merge(alegre_df, on="cdPosicao", how="left")
    final_df = final_df.merge(triste_df, on="cdPosicao", how="left")
    final_df = final_df.merge(neutro_df, on="cdPosicao", how="left")
    final_df = final_df.merge(categoria_total_df, on="cdPosicao", how="left")
    final_df = final_df.merge(pivot_df, on="cdPosicao", how="left")

    result_json = final_df.to_json(orient="records", date_format="iso")

    return result_json


def Selecionar_VwRelDadosDispositivo(filtros, db_client=supabase_api):
    query = db_client.table("VwRelDadosDispositivo").select("*")

    # Apply filters
    for campo, valor in filtros.items():
        if campo == "dtRegistro":
            start_dt, end_dt = convert_sao_paulo_date_to_utc_range(valor)
            query = query.gte(campo, start_dt)
            query = query.lte(campo, end_dt)
        else:
            query = query.eq(campo, valor)

    resultado = query.execute()

    return resultado.data


def Selecionar_VwTbPosicaoAtual(filtros, db_client=supabase_api):
    query = db_client.table("VwTbPosicaoAtual").select("*")

    for campo, valor in filtros.items():
        query = query.eq(campo, valor)

    resultado = query.execute()
    return resultado.data


def Selecionar_TbEndereco(dsLat, dsLong, db_client=supabase_api):
    query = (
        db_client.table("TbEndereco")
        .select("*")
        .eq("dsLat", dsLat)
        .eq("dsLong", dsLong)
    )
    resultado = query.execute()
    return resultado.data


def Inserir_TbEndereco(data, db_client=supabase_api):
    resultado = db_client.table("TbEndereco").insert(data).execute()
    return resultado.data


def convert_sao_paulo_date_to_utc_range_yyyymmdd(date_str):
    """
    Converts a yyyymmdd string to UTC datetimes for start (00:00:00) and end (23:59:59) in São Paulo timezone.
    Returns (start_utc_iso, end_utc_iso)
    """
    tz_sp = pytz.timezone("America/Sao_Paulo")
    date_obj = datetime.strptime(date_str, "%Y%m%d").date()
    dt_start_sp = tz_sp.localize(datetime.combine(date_obj, time(0, 0, 0)))
    dt_end_sp = tz_sp.localize(datetime.combine(date_obj, time(23, 59, 59)))
    return (
        dt_start_sp.astimezone(pytz.UTC).isoformat(),
        dt_end_sp.astimezone(pytz.UTC).isoformat(),
    )


def Selecionar_GroupedSensorData(
    dispositivos: list,
    dtRegistroComeco: str = None,
    dtRegistroFim: str = None,
    db_client=supabase_api,
):
    # Convert dates if provided
    if dtRegistroComeco:
        dtRegistroComeco, _ = convert_sao_paulo_date_to_utc_range_yyyymmdd(
            dtRegistroComeco
        )
    if dtRegistroFim:
        _, dtRegistroFim = convert_sao_paulo_date_to_utc_range_yyyymmdd(dtRegistroFim)

    query = db_client.rpc(
        "get_grouped_sensor_data",
        {
            "dispositivos": dispositivos,
            "dt_registro_comeco": dtRegistroComeco,
            "dt_registro_fim": dtRegistroFim,
        },
    )

    resultado = query.execute()
    return resultado.data


# Api usada no frontend para a pagina de produtos
def Selecionar_VwProdutoCompleto(filtros, db_client=supabase_api):
    query = db_client.table("VwProdutoCompleto").select("*")

    # Apply filters
    for campo, valor in filtros.items():
        if campo == "dsNome":
            # Use ilike for case-insensitive partial matching
            query = query.ilike(campo, f"%{valor}%")
        else:
            query = query.eq(campo, valor)

    # Order by dtRegistro desc
    query = query.order("dtRegistroProduto", desc=True)

    resultado = query.execute()
    return resultado.data


def Selecionar_ListaDispositivosResumo(filtros, db_client=supabase_api):
    """
    Call the simplified get_lista_dispositivos_resumo function and add sensor aggregations.

    Args:
        filtros (dict): Dictionary containing filter parameters:
            - dt_registro_inicio: Start date for sensor records
            - dt_registro_fim: End date for sensor records
            - cd_status: Device status filter
            - ds_uf: State filter
            - bl_area: Area flag filter
            - nr_bateria_min: Minimum battery level
            - nr_bateria_max: Maximum battery level
            - cd_cliente: Client filter
            - cd_produto: Product filter
        db_client: Supabase client instance

    Returns:
        dict: Query result data with sensor aggregations added
    """
    # Convert date strings to proper format if provided
    dt_registro_inicio = filtros.get("dt_registro_inicio")
    dt_registro_fim = filtros.get("dt_registro_fim")

    if dt_registro_inicio:
        start_dt, _ = convert_sao_paulo_date_to_utc_range(dt_registro_inicio)
        dt_registro_inicio = start_dt

    if dt_registro_fim:
        _, end_dt = convert_sao_paulo_date_to_utc_range(dt_registro_fim)
        dt_registro_fim = end_dt

    # Debug: Print parameters being passed to the function
    rpc_params = {
        "dt_registro_inicio": dt_registro_inicio,
        "dt_registro_fim": dt_registro_fim,
        "cd_status": filtros.get("cd_status"),
        "ds_uf": filtros.get("ds_uf"),
        "bl_area": filtros.get("bl_area"),
        "nr_bateria_min": filtros.get("nr_bateria_min"),
        "nr_bateria_max": filtros.get("nr_bateria_max"),
        "cd_cliente": filtros.get("cd_cliente"),
        "cd_produto": filtros.get("cd_produto"),
    }
    print(f"DEBUG: Calling get_lista_dispositivos_resumo with params: {rpc_params}")
    
    try:
        # Execute the simplified SQL function (returns base device data only)
        query = db_client.rpc(
            "get_lista_dispositivos_resumo",
            rpc_params,
        )
        resultado = query.execute()
        print(f"DEBUG: Main query executed successfully, returned {len(resultado.data)} records")
        
        # Extract dispositivo IDs for sensor aggregation
        dispositivos_ids = [d["cdDispositivo"] for d in resultado.data]
        
        # Get sensor aggregations using the new aggregation module
        from .aggregations import aggregate_all_sensors
        sensor_data = aggregate_all_sensors(
            dispositivos_ids, 
            dt_registro_inicio, 
            dt_registro_fim, 
            db_client
        )
        print(f"DEBUG: Sensor aggregations completed for {len(sensor_data)} devices")
        
        # Merge sensor data into device records
        for dispositivo in resultado.data:
            cd = dispositivo["cdDispositivo"]
            aggregations = sensor_data.get(cd, {
                'nrPorta': 0, 'nrPessoas': 0, 'nrTemp': 0, 'nrItens': 0
            })
            dispositivo.update(aggregations)
        
        # Get the product name from the first device record (all devices have the same product)
        dsNome = None
        if len(resultado.data) > 0:
            dsNome = resultado.data[0].get("dsNomeProduto")
            
        return {"dispositivos": resultado.data, "nomeProduto": dsNome}
        
    except Exception as e:
        print(f"ERROR: Failed to execute get_lista_dispositivos_resumo query: {e}")
        print(f"ERROR: Parameters were: {rpc_params}")
        print(f"ERROR: Exception type: {type(e)}")
        raise e


def get_abertura_porta_aggregation(
    cd_produto, dt_inicio, dt_fim, cd_dispositivos=None, cd_cliente=None, aggregation_type='hourly', db_client=supabase_api
):
    """
    Get aggregation for door opening sensors (hourly or by day of week)
    
    Args:
        cd_produto (int): Product ID
        dt_inicio (str): Start date in ISO format
        dt_fim (str): End date in ISO format
        cd_dispositivos (list, optional): List of device IDs to filter
        cd_cliente (int, optional): Client ID to filter
        aggregation_type (str): 'hourly' or 'by_day_of_week'
        db_client: Supabase client instance
    
    Returns:
        dict: Aggregated data with time period breakdown
    """

    # Convert date strings to proper format if provided
    if dt_inicio:
        start_dt, _ = convert_sao_paulo_date_to_utc_range(dt_inicio)
        dt_inicio = start_dt

    if dt_fim:
        _, end_dt = convert_sao_paulo_date_to_utc_range(dt_fim)
        dt_fim = end_dt

    try:
        # Call the unified RPC function
        response = db_client.rpc(
            "get_abertura_porta_aggregation",
            {
                "p_cd_produto": cd_produto,
                "p_dt_inicio": dt_inicio,
                "p_dt_fim": dt_fim,
                "p_cd_dispositivos": cd_dispositivos,
                "p_cd_cliente": cd_cliente,
                "p_aggregation_type": aggregation_type,
            },
        ).execute()

        # Process the results
        time_data = {}
        total_value = 0
        total_records = 0
        last_read_timestamp = None

        # Day of week mapping (PostgreSQL DOW: 0=Sunday, 1=Monday, etc.)
        day_names = {
            0: 'sunday',
            1: 'monday', 
            2: 'tuesday',
            3: 'wednesday',
            4: 'thursday',
            5: 'friday',
            6: 'saturday'
        }

        # Initialize all periods with zero values
        if aggregation_type == 'hourly':
            # Initialize all 24 hours (00-23)
            for hour in range(24):
                time_data[f"{hour:02d}"] = 0
        else:  # by_day_of_week
            # Initialize all 7 days
            for day_num, day_name in day_names.items():
                time_data[day_name] = 0

        # Process actual data from database
        for row in response.data:
            if aggregation_type == 'hourly':
                # Format as "00", "01", etc.
                time_key = f"{row['time_period']:02d}"
            else:  # by_day_of_week
                # Map numeric DOW to day name
                time_key = day_names.get(row['time_period'], f"unknown_{row['time_period']}")
            
            time_data[time_key] = row["total_value"]
            total_value += row["total_value"]
            total_records += row["record_count"]

            # Track the most recent timestamp
            if row["last_read"] and (
                last_read_timestamp is None or row["last_read"] > last_read_timestamp
            ):
                last_read_timestamp = row["last_read"]

        # Calculate average
        if aggregation_type == 'hourly':
            average_key = 'average_hourly'
            average_value = total_value / 24 if total_value > 0 else 0
        else:  # by_day_of_week
            average_key = 'average_per_day_of_week'
            average_value = total_value / 7 if total_value > 0 else 0

        result = {
            aggregation_type: time_data,
            "total": total_value,
            average_key: round(average_value, 2),
            "record_count": total_records,
            "last_read": last_read_timestamp,
        }

        return result

    except Exception as e:
        print(f"Error in get_abertura_porta_aggregation: {e}")
        raise e


def get_movimento_pessoas_aggregation(
    cd_produto, dt_inicio, dt_fim, cd_dispositivos=None, cd_cliente=None, aggregation_type='hourly', db_client=supabase_api
):
    """
    Get aggregation for movimento-pessoas sensors (hourly or by day of week)
    
    Args:
        cd_produto (int): Product ID
        dt_inicio (str): Start date in ISO format
        dt_fim (str): End date in ISO format
        cd_dispositivos (list, optional): List of device IDs to filter
        cd_cliente (int, optional): Client ID to filter
        aggregation_type (str): 'hourly' or 'by_day_of_week'
        db_client: Supabase client instance
    
    Returns:
        dict: Aggregated data with time period breakdown
    """

    # Convert date strings to proper format if provided
    if dt_inicio:
        start_dt, _ = convert_sao_paulo_date_to_utc_range(dt_inicio)
        dt_inicio = start_dt

    if dt_fim:
        _, end_dt = convert_sao_paulo_date_to_utc_range(dt_fim)
        dt_fim = end_dt

    try:
        # Call the unified RPC function
        response = db_client.rpc(
            "get_movimento_pessoas_aggregation",
            {
                "p_cd_produto": cd_produto,
                "p_dt_inicio": dt_inicio,
                "p_dt_fim": dt_fim,
                "p_cd_dispositivos": cd_dispositivos,
                "p_cd_cliente": cd_cliente,
                "p_aggregation_type": aggregation_type,
            },
        ).execute()

        # Process the results
        time_data = {}
        total_value = 0
        total_records = 0
        last_read_timestamp = None

        # Day of week mapping (PostgreSQL DOW: 0=Sunday, 1=Monday, etc.)
        day_names = {
            0: 'sunday',
            1: 'monday', 
            2: 'tuesday',
            3: 'wednesday',
            4: 'thursday',
            5: 'friday',
            6: 'saturday'
        }

        # Initialize all periods with zero values
        if aggregation_type == 'hourly':
            # Initialize all 24 hours (00-23)
            for hour in range(24):
                time_data[f"{hour:02d}"] = 0
        else:  # by_day_of_week
            # Initialize all 7 days
            for day_num, day_name in day_names.items():
                time_data[day_name] = 0

        # Process actual data from database
        for row in response.data:
            if aggregation_type == 'hourly':
                # Format as "00", "01", etc.
                time_key = f"{row['time_period']:02d}"
            else:  # by_day_of_week
                # Map numeric DOW to day name
                time_key = day_names.get(row['time_period'], f"unknown_{row['time_period']}")
            
            time_data[time_key] = row["total_value"]
            total_value += row["total_value"]
            total_records += row["record_count"]

            # Track the most recent timestamp
            if row["last_read"] and (
                last_read_timestamp is None or row["last_read"] > last_read_timestamp
            ):
                last_read_timestamp = row["last_read"]

        # Calculate average
        if aggregation_type == 'hourly':
            average_key = 'average_hourly'
            average_value = total_value / 24 if total_value > 0 else 0
        else:  # by_day_of_week
            average_key = 'average_per_day_of_week'
            average_value = total_value / 7 if total_value > 0 else 0

        result = {
            aggregation_type: time_data,
            "total": total_value,
            average_key: round(average_value, 2),
            "record_count": total_records,
            "last_read": last_read_timestamp,
        }

        return result

    except Exception as e:
        print(f"Error in get_movimento_pessoas_aggregation: {e}")
        raise e
