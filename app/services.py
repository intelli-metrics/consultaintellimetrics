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
        except (ValueError, TypeError):
            # If there's any error converting the times, skip filtering for this row
            filtered_resultado.append(row)
            continue

        # Check if time is within range
        if inicio > fim:  # Crosses midnight
            if hora >= inicio or hora <= fim:
                filtered_resultado.append(row)
        else:  # Normal range
            if inicio <= hora <= fim:
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


def Selecionar_HistoricoPaginado(filtros, db_client, page=1, page_size=20):
    dt_inicio = filtros.get("dtRegistroComeco")
    dt_fim = filtros.get("dtRegistroFim")
    cd_cliente = filtros.get("cdCliente")
    cd_dispositivo = filtros.get("cdDispositivo")

    params = {
        "p_page": page,
        "p_page_size": page_size,
    }

    if cd_cliente:
        params["p_cd_cliente"] = int(cd_cliente)
    if cd_dispositivo and cd_dispositivo != "0":
        params["p_cd_dispositivo"] = int(cd_dispositivo)
    if dt_inicio:
        start_dt, _ = convert_sao_paulo_date_to_utc_range(dt_inicio)
        params["p_dt_registro_comeco"] = start_dt
    if dt_fim:
        _, end_dt = convert_sao_paulo_date_to_utc_range(dt_fim)
        params["p_dt_registro_fim"] = end_dt

    try:
        resultado = db_client.rpc("get_historico_paginado", params).execute()
    except Exception as e:
        print("Erro buscando get_historico_paginado")
        print(e)
        return {"data": [], "total": 0, "page": page, "pageSize": page_size}

    return resultado.data


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


def Selecionar_VwTbPosicaoAtualV2(
    cd_produto: str = None,
    cd_dispositivos: list = None,
    db_client=supabase_api
):
    """
    Select current positions from VwTbPosicaoAtual view with improved filtering.
    
    This function provides better filtering capabilities than the original:
    - Supports filtering by product ID
    - Supports filtering by multiple device IDs using IN clause
    - Properly handles type conversion and validation
    
    Args:
        cd_produto: Product ID to filter by (string, will be converted to int)
        cd_dispositivos: List of device IDs to filter by (list of integers)
        db_client: Supabase client instance
        
    Returns:
        List of position records matching the filters
        
    Example:
        # Filter by product only
        Selecionar_VwTbPosicaoAtualV2(cd_produto="123", db_client=client)
        
        # Filter by product and specific devices
        Selecionar_VwTbPosicaoAtualV2(
            cd_produto="123",
            cd_dispositivos=[1, 2, 3],
            db_client=client
        )
    """
    query = db_client.table("VwTbPosicaoAtual").select("*")
    
    # Apply product filter if provided
    if cd_produto and cd_produto.strip():
        try:
            cd_produto_int = int(cd_produto.strip())
            query = query.eq("cdProduto", cd_produto_int)
        except (ValueError, TypeError):
            # If conversion fails, return empty result
            return []
    
    # Apply device filter if provided
    if cd_dispositivos and len(cd_dispositivos) > 0:
        # Validate all items are integers
        try:
            # Ensure all are integers (in case they're strings)
            cd_dispositivos_int = [int(d) for d in cd_dispositivos]
            # Use .in_() for multiple device IDs
            query = query.in_("cdDispositivo", cd_dispositivos_int)
        except (ValueError, TypeError):
            # If any conversion fails, return empty result
            return []
    
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
        from .aggregations import aggregate_all_sensors, CATEGORY_FIELDS
        sensor_data, tiposSensores = aggregate_all_sensors(
            dispositivos_ids,
            dt_registro_inicio,
            dt_registro_fim,
            db_client
        )
        print(f"DEBUG: Sensor aggregations completed for {len(sensor_data)} devices")

        # Merge sensor data into device records
        default_aggregations = {
            'nrPorta': 0, 'nrPessoas': 0, 'nrTemp': 0, 'nrItens': 0
        }
        for field in CATEGORY_FIELDS:
            default_aggregations[field] = 0

        for dispositivo in resultado.data:
            cd = dispositivo["cdDispositivo"]
            aggregations = sensor_data.get(cd, dict(default_aggregations))
            dispositivo.update(aggregations)

        # Get the product name from the first device record (all devices have the same product)
        dsNome = None
        if len(resultado.data) > 0:
            dsNome = resultado.data[0].get("dsNomeProduto")

        # Get the product image from TbImagens
        dsCaminhoImagem = None
        cdCodigoImagem = None
        cd_produto = filtros.get("cd_produto")
        if cd_produto:
            try:
                img_result = db_client.table("TbImagens") \
                    .select("dsCaminho, cdCodigo") \
                    .eq("cdProduto", cd_produto) \
                    .order("nrImagem") \
                    .limit(1) \
                    .execute()
                if img_result.data and len(img_result.data) > 0:
                    dsCaminhoImagem = img_result.data[0].get("dsCaminho")
                    cdCodigoImagem = img_result.data[0].get("cdCodigo")
            except Exception as img_err:
                print(f"WARNING: Failed to fetch product image: {img_err}")

        return {
            "dispositivos": resultado.data,
            "nomeProduto": dsNome,
            "tiposSensores": tiposSensores,
            "dsCaminhoImagem": dsCaminhoImagem,
            "cdCodigoImagem": cdCodigoImagem,
        }
        
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


def get_temperatura_aggregation(
    cd_produto, dt_inicio, dt_fim, cd_dispositivos=None, cd_cliente=None, aggregation_type='daily', db_client=supabase_api
):
    """
    Get aggregation for temperatura sensors (daily or by day of week)
    
    Args:
        cd_produto (int): Product ID
        dt_inicio (str): Start date in ISO format
        dt_fim (str): End date in ISO format
        cd_dispositivos (list, optional): List of device IDs to filter
        cd_cliente (int, optional): Client ID to filter
        aggregation_type (str): 'daily' or 'by_day_of_week'
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
        # First, get device IDs for the product
        dispositivos_query = db_client.table("TbDispositivo").select("cdDispositivo, cdCliente").eq("cdProduto", cd_produto)
        dispositivos_result = dispositivos_query.execute()
        
        # Filter devices by cliente if provided
        dispositivo_ids = []
        for d in dispositivos_result.data:
            if cd_cliente and d.get("cdCliente") != cd_cliente:
                continue
            dispositivo_ids.append(d["cdDispositivo"])
        
        # Filter devices by cd_dispositivos if provided
        if cd_dispositivos:
            dispositivo_ids = [did for did in dispositivo_ids if did in cd_dispositivos]
        
        if not dispositivo_ids:
            # Return empty structure based on aggregation type
            if aggregation_type == 'daily':
                return {
                    "daily": {},
                    "total": 0,
                    "average_daily": 0,
                    "record_count": 0,
                    "last_read": None
                }
            else:  # by_day_of_week
                day_names = {
                    0: 'sunday', 1: 'monday', 2: 'tuesday', 3: 'wednesday',
                    4: 'thursday', 5: 'friday', 6: 'saturday'
                }
                return {
                    "by_day_of_week": {day_name: 0 for day_name in day_names.values()},
                    "total": 0,
                    "average_per_day_of_week": 0,
                    "record_count": 0,
                    "last_read": None
                }
        
        # Get temperatura sensor IDs for these devices
        sensores_query = (
            db_client.table("TbSensor")
            .select("cdSensor")
            .eq("cdTipoSensor", 4)  # Temperatura
            .in_("cdDispositivo", dispositivo_ids)
        )
        sensores_result = sensores_query.execute()
        
        temperatura_sensor_ids = [s["cdSensor"] for s in sensores_result.data]
        
        if not temperatura_sensor_ids:
            # Return empty structure based on aggregation type
            if aggregation_type == 'daily':
                return {
                    "daily": {},
                    "total": 0,
                    "average_daily": 0,
                    "record_count": 0,
                    "last_read": None
                }
            else:  # by_day_of_week
                day_names = {
                    0: 'sunday', 1: 'monday', 2: 'tuesday', 3: 'wednesday',
                    4: 'thursday', 5: 'friday', 6: 'saturday'
                }
                return {
                    "by_day_of_week": {day_name: 0 for day_name in day_names.values()},
                    "total": 0,
                    "average_per_day_of_week": 0,
                    "record_count": 0,
                    "last_read": None
                }
        
        # Query temperatura sensor registros
        registros_query = (
            db_client.table("TbSensorRegistro")
            .select("nrValor, dtRegistro")
            .in_("cdSensor", temperatura_sensor_ids)
            .gte("dtRegistro", dt_inicio)
            .lte("dtRegistro", dt_fim)
            .order("dtRegistro")
        )
        resultado = registros_query.execute()
        
        temperatura_registros = resultado.data
        
        if not temperatura_registros:
            # Return empty structure based on aggregation type
            if aggregation_type == 'daily':
                return {
                    "daily": {},
                    "total": 0,
                    "average_daily": 0,
                    "record_count": 0,
                    "last_read": None
                }
            else:  # by_day_of_week
                day_names = {
                    0: 'sunday', 1: 'monday', 2: 'tuesday', 3: 'wednesday',
                    4: 'thursday', 5: 'friday', 6: 'saturday'
                }
                return {
                    "by_day_of_week": {day_name: 0 for day_name in day_names.values()},
                    "total": 0,
                    "average_per_day_of_week": 0,
                    "record_count": 0,
                    "last_read": None
                }
        
        # Process the results based on aggregation type
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
        
        if aggregation_type == 'daily':
            # Group by date (YYYY-MM-DD)
            daily_temps = {}
            
            for registro in temperatura_registros:
                if registro.get("nrValor") is None:
                    continue
                
                # Extract date from timestamp
                dt = datetime.fromisoformat(registro["dtRegistro"].replace('Z', '+00:00'))
                date_key = dt.date().isoformat()  # YYYY-MM-DD
                
                if date_key not in daily_temps:
                    daily_temps[date_key] = []
                
                daily_temps[date_key].append(float(registro["nrValor"]))
                total_records += 1
                
                # Track last read
                if last_read_timestamp is None or registro["dtRegistro"] > last_read_timestamp:
                    last_read_timestamp = registro["dtRegistro"]
            
            # Calculate average temperature per day
            for date_key, temps in daily_temps.items():
                avg_temp = sum(temps) / len(temps)
                time_data[date_key] = round(avg_temp, 2)
                total_value += avg_temp
            
            # Calculate overall average
            num_days = len(daily_temps) if daily_temps else 1
            average_value = total_value / num_days if total_value > 0 else 0
            
            result = {
                "daily": time_data,
                "total": round(total_value, 2),
                "average_daily": round(average_value, 2),
                "record_count": total_records,
                "last_read": last_read_timestamp,
            }
            
        else:  # by_day_of_week
            # Initialize all 7 days with empty lists
            day_temps = {day_name: [] for day_name in day_names.values()}
            
            for registro in temperatura_registros:
                if registro.get("nrValor") is None:
                    continue
                
                # Extract day of week from timestamp
                dt = datetime.fromisoformat(registro["dtRegistro"].replace('Z', '+00:00'))
                day_of_week = dt.weekday()  # 0=Monday, 6=Sunday
                # Convert to PostgreSQL DOW (0=Sunday, 6=Saturday)
                pg_dow = (day_of_week + 1) % 7
                day_name = day_names[pg_dow]
                
                day_temps[day_name].append(float(registro["nrValor"]))
                total_records += 1
                
                # Track last read
                if last_read_timestamp is None or registro["dtRegistro"] > last_read_timestamp:
                    last_read_timestamp = registro["dtRegistro"]
            
            # Calculate average temperature per day of week
            for day_name, temps in day_temps.items():
                if temps:
                    avg_temp = sum(temps) / len(temps)
                    time_data[day_name] = round(avg_temp, 2)
                    total_value += avg_temp
                else:
                    time_data[day_name] = 0
            
            # Calculate average per day of week
            average_value = total_value / 7 if total_value > 0 else 0
            
            result = {
                "by_day_of_week": time_data,
                "total": round(total_value, 2),
                "average_per_day_of_week": round(average_value, 2),
                "record_count": total_records,
                "last_read": last_read_timestamp,
            }
        
        return result

    except Exception as e:
        print(f"Error in get_temperatura_aggregation: {e}")
        raise e


def get_camera_categorias_aggregation(
    cd_produto, dt_inicio, dt_fim, cd_dispositivos=None, cd_cliente=None, db_client=supabase_api
):
    """
    Get aggregation for camera category sensors (gender, age, emotion) by hour of day

    Args:
        cd_produto (int): Product ID
        dt_inicio (str): Start date in YYYYMMDD format
        dt_fim (str): End date in YYYYMMDD format
        cd_dispositivos (list, optional): List of device IDs to filter
        cd_cliente (int, optional): Client ID to filter
        db_client: Supabase client instance

    Returns:
        dict: Aggregated data with hourly breakdown for gender, age, and emotion categories
    """
    # Convert date strings to proper format if provided
    if dt_inicio:
        start_dt, _ = convert_sao_paulo_date_to_utc_range(dt_inicio)
        dt_inicio_utc = start_dt

    if dt_fim:
        _, end_dt = convert_sao_paulo_date_to_utc_range(dt_fim)
        dt_fim_utc = end_dt

    try:
        # First, get device IDs for the product
        dispositivos_query = db_client.table("TbDispositivo").select("cdDispositivo, cdCliente").eq("cdProduto", cd_produto)
        dispositivos_result = dispositivos_query.execute()

        # Filter devices by cliente if provided
        dispositivo_ids = []
        for d in dispositivos_result.data:
            if cd_cliente and d.get("cdCliente") != cd_cliente:
                continue
            dispositivo_ids.append(d["cdDispositivo"])

        # Filter devices by cd_dispositivos if provided
        if cd_dispositivos:
            dispositivo_ids = [did for did in dispositivo_ids if did in cd_dispositivos]

        # Check if any devices have category sensors
        has_category_sensors = False
        if dispositivo_ids:
            sensores_check = (
                db_client.table("TbSensor")
                .select("cdSensor, cdTipoSensor")
                .in_("cdDispositivo", dispositivo_ids)
                .in_("cdTipoSensor", [6, 7, 8, 9, 10, 11, 12, 13, 14, 15])  # Category sensor types
                .execute()
            )
            has_category_sensors = len(sensores_check.data) > 0

        if not dispositivo_ids or not has_category_sensors:
            # Return empty structure
            empty_hourly = {f"{h:02d}": {"masculino": 0, "feminino": 0} for h in range(24)}
            empty_hourly_age = {f"{h:02d}": {"crianca": 0, "jovem": 0, "adulto": 0, "senior": 0} for h in range(24)}
            empty_hourly_emotion = {f"{h:02d}": {"alegre": 0, "concentrado": 0, "neutro": 0} for h in range(24)}
            return {
                "metadata": {
                    "last_read": None,
                    "date_range": {"start": dt_inicio, "end": dt_fim},
                    "has_category_sensors": has_category_sensors,
                },
                "data": {
                    "hourly": {
                        "gender": empty_hourly,
                        "age": empty_hourly_age,
                        "emotion": empty_hourly_emotion,
                    },
                    "totals": {
                        "gender": {"masculino": 0, "feminino": 0},
                        "age": {"crianca": 0, "jovem": 0, "adulto": 0, "senior": 0},
                        "emotion": {"alegre": 0, "concentrado": 0, "neutro": 0},
                    },
                    "emotion_by_age": {
                        "crianca": {"alegre": 0, "concentrado": 0, "neutro": 0},
                        "jovem": {"alegre": 0, "concentrado": 0, "neutro": 0},
                        "adulto": {"alegre": 0, "concentrado": 0, "neutro": 0},
                        "senior": {"alegre": 0, "concentrado": 0, "neutro": 0},
                    },
                },
            }

        # Query VwRelHistoricoDispositivoProduto for category data
        query = (
            db_client.table("VwRelHistoricoDispositivoProduto")
            .select("dtRegistro, nrMasculino, nrFeminino, nrCrianca, nrJovem, nrAdulto, nrSenior, nrAlegre, nrTriste, nrNeutro")
            .in_("cdDispositivo", dispositivo_ids)
            .gte("dtRegistro", dt_inicio_utc)
            .lte("dtRegistro", dt_fim_utc)
            .limit(100000)
        )

        resultado = query.execute()
        registros = resultado.data

        # Initialize data structures
        tz_sp = pytz.timezone("America/Sao_Paulo")

        # Hourly data
        hourly_gender = {f"{h:02d}": {"masculino": 0, "feminino": 0} for h in range(24)}
        hourly_age = {f"{h:02d}": {"crianca": 0, "jovem": 0, "adulto": 0, "senior": 0} for h in range(24)}
        hourly_emotion = {f"{h:02d}": {"alegre": 0, "concentrado": 0, "neutro": 0} for h in range(24)}

        # Totals
        totals_gender = {"masculino": 0, "feminino": 0}
        totals_age = {"crianca": 0, "jovem": 0, "adulto": 0, "senior": 0}
        totals_emotion = {"alegre": 0, "concentrado": 0, "neutro": 0}

        # Emotion by age group (for cross-tabulation chart)
        emotion_by_age = {
            "crianca": {"alegre": 0, "concentrado": 0, "neutro": 0},
            "jovem": {"alegre": 0, "concentrado": 0, "neutro": 0},
            "adulto": {"alegre": 0, "concentrado": 0, "neutro": 0},
            "senior": {"alegre": 0, "concentrado": 0, "neutro": 0},
        }

        last_read_timestamp = None

        for registro in registros:
            # Parse timestamp and convert to Sao Paulo timezone
            dt_str = registro["dtRegistro"]
            if dt_str:
                dt = datetime.fromisoformat(dt_str.replace('Z', '+00:00'))
                dt_sp = dt.astimezone(tz_sp)
                hour_key = f"{dt_sp.hour:02d}"

                # Track last read
                if last_read_timestamp is None or dt_str > last_read_timestamp:
                    last_read_timestamp = dt_str
            else:
                continue

            # Gender data
            masculino = registro.get("nrMasculino") or 0
            feminino = registro.get("nrFeminino") or 0

            if masculino > 0 or feminino > 0:
                hourly_gender[hour_key]["masculino"] += masculino
                hourly_gender[hour_key]["feminino"] += feminino
                totals_gender["masculino"] += masculino
                totals_gender["feminino"] += feminino

            # Age data
            crianca = registro.get("nrCrianca") or 0
            jovem = registro.get("nrJovem") or 0
            adulto = registro.get("nrAdulto") or 0
            senior = registro.get("nrSenior") or 0

            if crianca > 0 or jovem > 0 or adulto > 0 or senior > 0:
                hourly_age[hour_key]["crianca"] += crianca
                hourly_age[hour_key]["jovem"] += jovem
                hourly_age[hour_key]["adulto"] += adulto
                hourly_age[hour_key]["senior"] += senior
                totals_age["crianca"] += crianca
                totals_age["jovem"] += jovem
                totals_age["adulto"] += adulto
                totals_age["senior"] += senior

            # Emotion data
            alegre = registro.get("nrAlegre") or 0
            concentrado = registro.get("nrTriste") or 0  # nrTriste maps to "Concentrado"
            neutro = registro.get("nrNeutro") or 0

            if alegre > 0 or concentrado > 0 or neutro > 0:
                hourly_emotion[hour_key]["alegre"] += alegre
                hourly_emotion[hour_key]["concentrado"] += concentrado
                hourly_emotion[hour_key]["neutro"] += neutro
                totals_emotion["alegre"] += alegre
                totals_emotion["concentrado"] += concentrado
                totals_emotion["neutro"] += neutro

        # Compute emotion_by_age using global totals (proportional distribution)
        # This works even when age and emotion data come from different records
        global_total_age = sum(totals_age.values())
        global_total_emotion = sum(totals_emotion.values())

        if global_total_age > 0 and global_total_emotion > 0:
            for age_key in ["crianca", "jovem", "adulto", "senior"]:
                age_count = totals_age[age_key]
                if age_count > 0:
                    age_ratio = age_count / global_total_age
                    emotion_by_age[age_key]["alegre"] = int(totals_emotion["alegre"] * age_ratio)
                    emotion_by_age[age_key]["concentrado"] = int(totals_emotion["concentrado"] * age_ratio)
                    emotion_by_age[age_key]["neutro"] = int(totals_emotion["neutro"] * age_ratio)

        return {
            "metadata": {
                "last_read": last_read_timestamp,
                "date_range": {"start": dt_inicio, "end": dt_fim},
                "has_category_sensors": True,
            },
            "data": {
                "hourly": {
                    "gender": hourly_gender,
                    "age": hourly_age,
                    "emotion": hourly_emotion,
                },
                "totals": {
                    "gender": totals_gender,
                    "age": totals_age,
                    "emotion": totals_emotion,
                },
                "emotion_by_age": emotion_by_age,
            },
        }

    except Exception as e:
        print(f"Error in get_camera_categorias_aggregation: {e}")
        raise e
