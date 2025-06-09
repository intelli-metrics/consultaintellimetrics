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
            print(f"Erro na requisição de endereço: {response.status_code}, {response.text}")
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


def Selecionar_VwTbProdutoTotal(codigo, db_client=supabase_api):
    query = db_client.table("VwTbProdutoTotal").select("*")

    if codigo != "0":
        query.eq("cdProduto", codigo)

    resultado = query.execute()

    return resultado.data


def Selecionar_VwRelHistoricoDispositivoProduto(filtros, db_client=supabase_api):
    query = db_client.table("VwRelHistoricoDispositivoProduto").select("*")

    # aplica filtros
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

    # processa cada linha para calcular nrQtdItens e nrTemperatura baseado no tipo de sensor
    for row in resultado:
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

    # converte em pandas dataframe
    df = pd.DataFrame(resultado)

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
        "nrPessoas",
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
