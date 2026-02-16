import os

from flask import Blueprint, jsonify, request

from db_utils import get_supabase_client_from_request, get_authenticated_client
from db_utils.storage import upload_file
from utils import valida_e_constroi_insert, valida_e_constroi_update, validate_date_range

from .services import (
    Alterar_TbProduto,
    Inserir_TbDestinatario,
    Inserir_TbDispositivo,
    Inserir_TbEndereco,
    Inserir_TbImagens,
    Inserir_TbPosicao,
    Inserir_TbProduto,
    Inserir_TbSensor,
    Inserir_TbSensorRegistro,
    Selecionar_HistoricoPaginaDispositivo,
    Selecionar_ListaDispositivosResumo,
    Selecionar_TbDestinatario,
    Selecionar_TbDispositivo,
    Selecionar_TbEndereco,
    Selecionar_TbImagens,
    Selecionar_TbPosicao,
    Selecionar_VwRelDadosDispositivo,
    Selecionar_VwRelHistoricoDispositivoProduto,
    Selecionar_VwTbPosicaoAtual,
    Selecionar_VwProdutoCompleto,
    Selecionar_VwTbProdutoTipo,
    Selecionar_VwTbProdutoTotalStatus,
    Selecionar_GroupedSensorData,
    get_abertura_porta_aggregation,
    get_movimento_pessoas_aggregation,
    get_temperatura_aggregation,
    get_camera_categorias_aggregation,
    get_endereco_coordenada,
    is_dentro_area,
    prepara_insert_registros,
)

main = Blueprint("main", __name__)

# Import v2 blueprint
from .routes_v2 import v2


@main.route("/TbProdutoTotalStatus/<codigo>")
def get_TbProdutoTotalStatus(codigo):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    filtros = {
        "cdCliente": request.args.get("cdCliente"),
    }

    # Adiciona o codigo como um filtro se for diferente de 0
    if codigo != "0":
        filtros["cdProduto"] = codigo

    # Remove filtros que nao tem valor
    filtros = {k: v for k, v in filtros.items() if v is not None}

    if ("cdCliente" not in filtros or len(filtros["cdCliente"]) == 0) and codigo == "0":
        print("cdCliente deve ser incluido quando buscando todos os produtos")
        return (
            jsonify(
                {
                    "message": "cdCliente deve ser incluido quando buscando todos os produtos"
                }
            ),
            400,
        )

    resultado = Selecionar_VwTbProdutoTotalStatus(
        filtros=filtros, db_client=supabase_client
    )
    return resultado


@main.route("/Destinatario/<cdDestinatario>")
def get_Destinatario(cdDestinatario):
    cdCliente = request.args.get("cdCliente")

    if not cdCliente:
        return jsonify({"message": "cdCliente necessário"}), 400

    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    resultado = Selecionar_TbDestinatario(
        cdDestinatario=cdDestinatario, cdCliente=cdCliente, db_client=supabase_client
    )

    return resultado


@main.route("/Destinatario", methods=["POST"])
def post_Destinatario():
    payload = request.get_json()
    data, error = valida_e_constroi_insert("TbDestinatario", payload)

    if error:
        return jsonify({"message": error}), 400
    resultado = Inserir_TbDestinatario(data)
    return resultado


@main.route("/Dispositivo/<codigo>")
def get_Dispositivo(codigo):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    resultado = Selecionar_TbDispositivo(codigo, db_client=supabase_client)
    return resultado


@main.route("/Dispositivo", methods=["POST"])
def post_Dispositivo():
    payload = request.get_json()
    data, error = valida_e_constroi_insert("TbDispositivo", payload)

    if error:
        return jsonify({"message": error}), 400
    resultado = Inserir_TbDispositivo(data)
    return resultado


@main.route("/CadastraImgProduto", methods=["POST"])
def CadastraImgProduto():
    supabase_client, error = get_supabase_client_from_request(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    file = request.files["arquivo"]
    pathfile = file.filename
    cdProduto = pathfile.split("-")[0]
    nrImagem = pathfile.split("-")[1]
    nrImagem = nrImagem.split(".")[0]
    file.save(pathfile)
    try:
        upload_file(file_name=pathfile, bucket="produtos", db_client=supabase_client)
    except Exception as e:
        os.remove(pathfile)
        print(e)
        print(pathfile)
        return jsonify({"message": "erro ao fazer upload da imagem"}), 400

    os.remove(pathfile)
    payload = {
        "dsCaminho": "produtos/",
        "cdCodigo": pathfile,
        "cdProduto": int(cdProduto),
        "nrImagem": int(nrImagem),
    }
    data, error = valida_e_constroi_insert("TbImagens", payload)

    if error:
        return jsonify({"message": error}), 400

    resultado = Inserir_TbImagens(data, db_client=supabase_client)
    return resultado


@main.route("/Imagens/<codigo>")
def get_Imagens(codigo):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    resultado = Selecionar_TbImagens(codigo, db_client=supabase_client)
    return resultado


@main.route("/Posicao/<codigo>")
def get_Posicao(codigo):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    filtros = {
        "dsLat": request.args.get("dsLat"),
        "dsLong": request.args.get("dsLong"),
        "nrTemp": request.args.get("nrTemp"),
        "nrBat": request.args.get("nrBat"),
        "dsEndereco": request.args.get("dsEndereco"),
        "dtRegistro": request.args.get("dtRegistro"),
    }

    # Remove filtros que nao tem valor
    filtros = {k: v for k, v in filtros.items() if v is not None}

    # Adiciona o codigo como um filtro se for diferente de 0
    if codigo != "0":
        filtros["cdDispositivo"] = codigo

    # Busca os primeiros 1000 resultados. Limite aplicado direto nas configs do supabase
    resultado = Selecionar_TbPosicao(filtros, db_client=supabase_client)
    return resultado


@main.route("/Posicao", methods=["POST"])
def post_Posicao():
    payload = request.get_json()

    print(payload)

    try:
        dsLat = float(payload["dsLat"])
        dsLong = float(payload["dsLong"])

        # Validate latitude range (-90 to 90)
        if not -90 <= dsLat <= 90:
            return jsonify({"message": "Latitude deve estar entre -90 e 90 graus"}), 400

        # Validate longitude range (-180 to 180)
        if not -180 <= dsLong <= 180:
            return (
                jsonify({"message": "Longitude deve estar entre -180 e 180 graus"}),
                400,
            )

        # Round to 5 decimal places and convert to string
        dsLat = str(round(dsLat, 5))
        dsLong = str(round(dsLong, 5))

    except (ValueError, TypeError):
        return (
            jsonify({"message": "Latitude e longitude devem ser números válidos"}),
            400,
        )

    cdDispositivo = payload["cdDispositivo"]

    if not dsLat or not dsLong or not cdDispositivo:
        return (
            jsonify({"message": "dsLat, dsLong e cdDispositivo são necessários"}),
            400,
        )

    # busca destinatario no dispositivo
    dispositivo = Selecionar_TbDispositivo(cdDispositivo)

    if not dispositivo or len(dispositivo) == 0:
        return (
            jsonify(
                {"message": f"dispositivo com o id {cdDispositivo} não foi encontrado"}
            ),
            500,
        )

    cdDestinatario = dispositivo[0]["cdDestinatario"]
    payload["cdDestinatario"] = cdDestinatario

    # Verifica se o endereco ja existe
    cdEndereco = None
    endereco = Selecionar_TbEndereco(dsLat, dsLong)

    if not endereco or len(endereco) == 0:
        dict_endereco_coord, error = get_endereco_coordenada(dsLat, dsLong)

        # TODO: remover esse for quando estiver pronto para usar so TbEndereco
        for key, value in dict_endereco_coord.items():
            if key != "cdEndereco" and key != "dtRegistro":
                payload[key] = value
            if key == "dsUF":
                payload["dsUF"] = "SP"
            if key == "dsLogradouro":
                payload["dsEndereco"] = value

        if error:
            return jsonify({"message": error}), 500

        if not dict_endereco_coord:
            return jsonify({"message": "Endereco nao encontrado"}), 400

        # Cria o endereco
        data, error = valida_e_constroi_insert("TbEndereco", dict_endereco_coord)
        if error:
            return jsonify({"message": error}), 400
        resultado = Inserir_TbEndereco(data)
        cdEndereco = resultado[0]["cdEndereco"]
    else:
        # TODO: remover esse for quando estiver pronto para usar so TbEndereco
        for key, value in endereco[0].items():
            if key != "cdEndereco" and key != "dtRegistro":
                payload[key] = value
            if key == "dsUF":
                payload["dsUF"] = "SP"
            if key == "dsLogradouro":
                payload["dsEndereco"] = value

        cdEndereco = endereco[0]["cdEndereco"]

    payload["cdEndereco"] = cdEndereco

    blArea = is_dentro_area(cdDispositivo, dsLat, dsLong)
    payload["blArea"] = blArea

    dic_sensores = payload["sensores"]
    del payload[
        "sensores"
    ]  # remove do payload para nao atrapalhar com o inserir tbPosicao

    # chama essa funcao novamente para validar novos campos e criar o objeto pro insert
    dataTbPosicao, error = valida_e_constroi_insert("TbPosicao", payload)
    if error:
        return jsonify({"message": error}), 400

    dataSensorRegistro, error = prepara_insert_registros(
        dic_sensores=dic_sensores, cdDispositivo=cdDispositivo
    )
    if error:
        return jsonify({"message": error}), 400

    # insere posicao e registros. AVISO: se o primeiro insert funcionar e o segundo falhar,
    # havera uma posicao sem um sensor registro correspondente
    # TODO: verificar como fazer em uma unica transacao (talvez seja necessario criar uma funcao para isso)
    try:
        resultado_posicao = Inserir_TbPosicao(dataTbPosicao)
    except Exception as e:
        return jsonify({"erro ao inserir posicao": str(e)}), 500

    for sensor in dataSensorRegistro:
        sensor["cdPosicao"] = resultado_posicao[0]["cdPosicao"]

    resultado_sensores = Inserir_TbSensorRegistro(dataSensorRegistro)

    resultado_posicao[0]["sensores"] = resultado_sensores

    return resultado_posicao


@main.route("/Produto", methods=["POST"])
def post_Produto():
    supabase_client, error = get_supabase_client_from_request(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    payload = request.get_json()
    data, error = valida_e_constroi_insert("TbProduto", payload)

    if error:
        return jsonify({"message": error}), 400

    resultado = Inserir_TbProduto(data=data, db_client=supabase_client)
    return resultado


@main.route("/Produto/<codigo>", methods=["PUT"])
def update_Produto(codigo):
    supabase_client, error = get_supabase_client_from_request(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    payload = request.get_json()
    data, error = valida_e_constroi_update("TbProduto", payload)
    if error:
        return jsonify({"message": error}), 400

    resultado = Alterar_TbProduto(
        Campo="cdProduto", Dado=codigo, UpData=data, db_client=supabase_client
    )

    return resultado


@main.route("/Sensor", methods=["POST"])
def post_Sensor():
    payload = request.get_json()
    data, error = valida_e_constroi_insert("TbSensor", payload)

    if error:
        return jsonify({"message": error}), 400
    resultado = Inserir_TbSensor(data)
    return resultado


@main.route("/TbProdutoTipo/<codigo>")
def get_TbProdutoTipo(codigo):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    resultado = Selecionar_VwTbProdutoTipo(codigo=codigo, db_client=supabase_client)
    return resultado


# endpoint usado para Pagina de Dispositivo. Mesmo do que o VwRelHistoricoDispositivoProduto,
# mas com produtos sendo retornados como colunas.
@main.route("/HistoricoPaginaDispositivo/<codigo>")
def get_HistoricoPaginaDispositivo(codigo):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    filtros = {
        "dtRegistro": request.args.get("dtRegistro"),
        "dtRegistroComeco": request.args.get("dtRegistroComeco"),
        "dtRegistroFim": request.args.get("dtRegistroFim"),
        "cdCliente": request.args.get("cdCliente"),
    }

    # Remove filtros que nao tem valor
    filtros = {k: v for k, v in filtros.items() if v is not None}

    # Adiciona o codigo como um filtro se for diferente de 0
    if codigo != "0":
        filtros["cdDispositivo"] = codigo

    resultado = Selecionar_HistoricoPaginaDispositivo(
        filtros=filtros, db_client=supabase_client
    )
    return resultado


@main.route("/VwRelHistoricoDispositivoProduto/<codigo>")
def get_RelHistoricoDispositivoProduto(codigo):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    filtros = {
        "dtRegistro": request.args.get("dtRegistro"),
        "dtRegistroComeco": request.args.get("dtRegistroComeco"),
        "dtRegistroFim": request.args.get("dtRegistroFim"),
        "cdCliente": request.args.get("cdCliente"),
    }

    # Remove filtros que nao tem valor
    filtros = {k: v for k, v in filtros.items() if v is not None}

    # Adiciona o codigo como um filtro se for diferente de 0
    if codigo != "0":
        filtros["cdDispositivo"] = codigo

    resultado = Selecionar_VwRelHistoricoDispositivoProduto(
        filtros=filtros, db_client=supabase_client
    )
    return resultado


@main.route("/VwRelDadosDispositivo/<codigo>")
def get_RelVwRelDadosDispositivo(codigo):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    filtros = {
        "dtRegistro": request.args.get("dtRegistro"),
    }

    # Remove filtros que nao tem valor
    filtros = {k: v for k, v in filtros.items() if v is not None}

    # Adiciona o codigo como um filtro se for diferente de 0
    if codigo != "0":
        filtros["cdDispositivo"] = codigo

    resultado = Selecionar_VwRelDadosDispositivo(
        filtros=filtros, db_client=supabase_client
    )
    return resultado


@main.route("/TbPosicaoAtual/<codigo>")
def get_TbPosicaoAtual(codigo):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    filtros = {"cdProduto": request.args.get("cdProduto")}

    # Remove filtros que nao tem valor
    filtros = {k: v for k, v in filtros.items() if v is not None}

    # Adiciona o codigo como um filtro se for diferente de 0
    if codigo != "0":
        filtros["cdDispositivo"] = codigo

    resultado = Selecionar_VwTbPosicaoAtual(filtros=filtros, db_client=supabase_client)
    return resultado


@main.route("/GroupedSensorData")
def get_GroupedSensorData():
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    cdDispositivo = request.args.get("cdDispositivo")
    dtRegistroComeco = request.args.get("dtRegistroComeco")
    dtRegistroFim = request.args.get("dtRegistroFim")

    if not cdDispositivo:
        return jsonify({"message": "Pelo menos um cdDispositivo é necessário"}), 400

    dispositivos = cdDispositivo.split(",")
    raw_result = Selecionar_GroupedSensorData(
        dispositivos, dtRegistroComeco, dtRegistroFim
    )

    # Transform the raw result into the desired JSON structure
    structured_result = {"cdDispositivos": {}}
    for row in raw_result:
        cd_dispositivo = row["cdDispositivo"]
        ds_tipo_sensor = row["dsTipoSensor"]
        media_leitura = row["mediaLeitura"]
        total_leitura = row["totalLeitura"]

        if cd_dispositivo not in structured_result["cdDispositivos"]:
            structured_result["cdDispositivos"][cd_dispositivo] = {}

        structured_result["cdDispositivos"][cd_dispositivo][ds_tipo_sensor] = {
            "mediaLeitura": media_leitura,
            "totalLeitura": total_leitura,
        }

    return jsonify(structured_result)


@main.route("/cliente/<cdCliente>/produtos")
def get_VwProdutoCompleto(cdCliente):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    filtros = {
        "cdCliente": cdCliente,
        "dsNome": request.args.get("dsNome"),
        "cdStatus": request.args.get("cdStatus"),
    }

    # Remove filtros que nao tem valor
    filtros = {k: v for k, v in filtros.items() if v is not None}

    resultado = Selecionar_VwProdutoCompleto(filtros=filtros, db_client=supabase_client)
    return jsonify(resultado)


# Usado para a pagina de lista de dispositivos
@main.route("/cliente/<cdCliente>/produto/<cdProduto>/dispositivos-resumo")
def get_ListaDispositivosResumo(cdCliente, cdProduto):
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"message": error}), 401

    # Convert path parameters to integers
    try:
        cdCliente = int(cdCliente)
        cdProduto = int(cdProduto)
    except ValueError:
        return jsonify({"message": "cdCliente and cdProduto must be valid integers"}), 400

    filtros = {
        "dt_registro_inicio": request.args.get("dt_registro_inicio"),
        "dt_registro_fim": request.args.get("dt_registro_fim"),
        "cd_status": request.args.get("cd_status"),
        "ds_uf": request.args.get("ds_uf"),
        "bl_area": request.args.get("bl_area"),
        "nr_bateria_min": request.args.get("nr_bateria_min"),
        "nr_bateria_max": request.args.get("nr_bateria_max"),
        "cd_cliente": cdCliente,
        "cd_produto": cdProduto,
    }

    # Remove filtros que nao tem valor
    filtros = {k: v for k, v in filtros.items() if v is not None}

    # Convert numeric filters
    if "nr_bateria_min" in filtros:
        try:
            filtros["nr_bateria_min"] = float(filtros["nr_bateria_min"])
        except ValueError:
            return jsonify({"message": "nr_bateria_min deve ser um número válido"}), 400

    if "nr_bateria_max" in filtros:
        try:
            filtros["nr_bateria_max"] = float(filtros["nr_bateria_max"])
        except ValueError:
            return jsonify({"message": "nr_bateria_max deve ser um número válido"}), 400

    # Convert boolean filter
    if "bl_area" in filtros:
        if filtros["bl_area"].lower() in ["true", "1", "yes"]:
            filtros["bl_area"] = True
        elif filtros["bl_area"].lower() in ["false", "0", "no"]:
            filtros["bl_area"] = False
        else:
            return jsonify({"message": "bl_area deve ser true/false, 1/0, ou yes/no"}), 400

    resultado = Selecionar_ListaDispositivosResumo(
        filtros=filtros, db_client=supabase_client
    )
    return jsonify(resultado)


@main.route("/v1/summary/abertura-porta", methods=["GET"])
def get_abertura_porta_summary():
    """
    Get door opening sensor summary data with hourly aggregation
    """
    # Get authenticated client
    supabase_client, error = get_authenticated_client(request=request)
    
    if error or supabase_client is None:
        return jsonify({"error": error, "error_code": "AUTHENTICATION_ERROR"}), 401
    
    try:
        # Get required parameters
        cd_produto = request.args.get('cdProduto')
        dt_registro_inicio = request.args.get('dt_registro_inicio')
        dt_registro_fim = request.args.get('dt_registro_fim')
        cd_cliente = request.args.get('cdCliente')
        aggregation = request.args.get('aggregation', 'hourly')  # Default to hourly
        
        # Validate required parameters
        if not cd_produto:
            return jsonify({
                "error": "cdProduto parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400
            
        if not dt_registro_inicio:
            return jsonify({
                "error": "dt_registro_inicio parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400
            
        if not dt_registro_fim:
            return jsonify({
                "error": "dt_registro_fim parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400
        
        # Validate date formats and range
        is_valid, error_message, error_code, parsed_dates = validate_date_range(
            dt_registro_inicio, dt_registro_fim
        )
        
        if not is_valid:
            return jsonify({
                "error": error_message,
                "error_code": error_code
            }), 400
        
        # Convert cd_produto to integer
        try:
            cd_produto = int(cd_produto)
        except ValueError:
            return jsonify({
                "error": "cdProduto must be a valid integer",
                "error_code": "INVALID_PARAMETER"
            }), 400
        
        # Convert cd_cliente to integer if provided
        if cd_cliente:
            try:
                cd_cliente = int(cd_cliente)
            except ValueError:
                return jsonify({
                    "error": "cdCliente must be a valid integer",
                    "error_code": "INVALID_PARAMETER"
                }), 400
        
        # Validate aggregation parameter
        if aggregation not in ['hourly', 'by_day_of_week']:
            return jsonify({
                "error": "aggregation must be 'hourly' or 'by_day_of_week'",
                "error_code": "INVALID_PARAMETER"
            }), 400
        
        # Get optional device filter (comma-separated list)
        cd_dispositivos_param = request.args.get('cdDispositivos')
        cd_dispositivos = None
        if cd_dispositivos_param:
            try:
                # Split by comma and convert to integers
                cd_dispositivos = [int(d.strip()) for d in cd_dispositivos_param.split(',') if d.strip()]
            except ValueError:
                return jsonify({
                    "error": "cdDispositivos must be a comma-separated list of valid integers",
                    "error_code": "INVALID_PARAMETER"
                }), 400
        
        # Call service function
        result = get_abertura_porta_aggregation(
            cd_produto=cd_produto,
            dt_inicio=dt_registro_inicio,
            dt_fim=dt_registro_fim,
            cd_dispositivos=cd_dispositivos if cd_dispositivos else None,
            cd_cliente=cd_cliente,
            aggregation_type=aggregation,
            db_client=supabase_client
        )
        
        # Build response
        response = {
            "metadata": {
                "last_read": result.get("last_read"),
                "aggregation_type": aggregation,
                "date_range": {
                    "start": dt_registro_inicio,
                    "end": dt_registro_fim
                }
            },
            "data": {
                aggregation: result.get(aggregation, {}),
                "total": result.get("total", 0),
                "record_count": result.get("record_count", 0)
            }
        }
        
        # Add the appropriate average field based on aggregation type
        if aggregation == 'hourly':
            response["data"]["average_hourly"] = result.get("average_hourly", 0)
        else:  # by_day_of_week
            response["data"]["average_per_day_of_week"] = result.get("average_per_day_of_week", 0)
        
        return jsonify(response)
        
    except Exception as e:
        print(f"Error in get_abertura_porta_summary: {e}")
        return jsonify({
            "error": "Internal server error",
            "error_code": "INTERNAL_ERROR",
            "details": str(e)
        }), 500


@main.route("/v1/summary/movimento-pessoas", methods=["GET"])
def get_movimento_pessoas_summary():
    """
    Get movimento-pessoas sensor summary data with hourly aggregation
    """
    # Get authenticated client
    supabase_client, error = get_authenticated_client(request=request)
    
    if error or supabase_client is None:
        return jsonify({"error": error, "error_code": "AUTHENTICATION_ERROR"}), 401
    
    try:
        # Get required parameters
        cd_produto = request.args.get('cdProduto')
        dt_registro_inicio = request.args.get('dt_registro_inicio')
        dt_registro_fim = request.args.get('dt_registro_fim')
        cd_cliente = request.args.get('cdCliente')
        aggregation = request.args.get('aggregation', 'hourly')  # Default to hourly
        
        # Validate required parameters
        if not cd_produto:
            return jsonify({
                "error": "cdProduto parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400
            
        if not dt_registro_inicio:
            return jsonify({
                "error": "dt_registro_inicio parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400
            
        if not dt_registro_fim:
            return jsonify({
                "error": "dt_registro_fim parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400
        
        # Validate date formats and range
        is_valid, error_message, error_code, parsed_dates = validate_date_range(
            dt_registro_inicio, dt_registro_fim
        )
        
        if not is_valid:
            return jsonify({
                "error": error_message,
                "error_code": error_code
            }), 400
        
        # Convert cd_produto to integer
        try:
            cd_produto = int(cd_produto)
        except ValueError:
            return jsonify({
                "error": "cdProduto must be a valid integer",
                "error_code": "INVALID_PARAMETER"
            }), 400
        
        # Convert cd_cliente to integer if provided
        if cd_cliente:
            try:
                cd_cliente = int(cd_cliente)
            except ValueError:
                return jsonify({
                    "error": "cdCliente must be a valid integer",
                    "error_code": "INVALID_PARAMETER"
                }), 400
        
        # Validate aggregation parameter
        if aggregation not in ['hourly', 'by_day_of_week']:
            return jsonify({
                "error": "aggregation must be 'hourly' or 'by_day_of_week'",
                "error_code": "INVALID_PARAMETER"
            }), 400
        
        # Get optional device filter (comma-separated list)
        cd_dispositivos_param = request.args.get('cdDispositivos')
        cd_dispositivos = None
        if cd_dispositivos_param:
            try:
                # Split by comma and convert to integers
                cd_dispositivos = [int(d.strip()) for d in cd_dispositivos_param.split(',') if d.strip()]
            except ValueError:
                return jsonify({
                    "error": "cdDispositivos must be a comma-separated list of valid integers",
                    "error_code": "INVALID_PARAMETER"
                }), 400
        
        # Call service function
        result = get_movimento_pessoas_aggregation(
            cd_produto=cd_produto,
            dt_inicio=dt_registro_inicio,
            dt_fim=dt_registro_fim,
            cd_dispositivos=cd_dispositivos if cd_dispositivos else None,
            cd_cliente=cd_cliente,
            aggregation_type=aggregation,
            db_client=supabase_client
        )
        
        # Build response
        response = {
            "metadata": {
                "last_read": result.get("last_read"),
                "aggregation_type": aggregation,
                "date_range": {
                    "start": dt_registro_inicio,
                    "end": dt_registro_fim
                }
            },
            "data": {
                aggregation: result.get(aggregation, {}),
                "total": result.get("total", 0),
                "record_count": result.get("record_count", 0)
            }
        }
        
        # Add the appropriate average field based on aggregation type
        if aggregation == 'hourly':
            response["data"]["average_hourly"] = result.get("average_hourly", 0)
        else:  # by_day_of_week
            response["data"]["average_per_day_of_week"] = result.get("average_per_day_of_week", 0)
        
        return jsonify(response)
        
    except Exception as e:
        print(f"Error in get_movimento_pessoas_summary: {e}")
        return jsonify({
            "error": "Internal server error",
            "error_code": "INTERNAL_ERROR",
            "details": str(e)
        }), 500


@main.route("/v1/summary/temperatura", methods=["GET"])
def get_temperatura_summary():
    """
    Get temperatura sensor summary data with daily or by_day_of_week aggregation
    """
    # Get authenticated client
    supabase_client, error = get_authenticated_client(request=request)
    
    if error or supabase_client is None:
        return jsonify({"error": error, "error_code": "AUTHENTICATION_ERROR"}), 401
    
    try:
        # Get required parameters
        cd_produto = request.args.get('cdProduto')
        dt_registro_inicio = request.args.get('dt_registro_inicio')
        dt_registro_fim = request.args.get('dt_registro_fim')
        cd_cliente = request.args.get('cdCliente')
        aggregation = request.args.get('aggregation', 'daily')  # Default to daily
        
        # Validate required parameters
        if not cd_produto:
            return jsonify({
                "error": "cdProduto parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400
            
        if not dt_registro_inicio:
            return jsonify({
                "error": "dt_registro_inicio parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400
            
        if not dt_registro_fim:
            return jsonify({
                "error": "dt_registro_fim parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400
        
        # Validate date formats and range
        is_valid, error_message, error_code, parsed_dates = validate_date_range(
            dt_registro_inicio, dt_registro_fim
        )
        
        if not is_valid:
            return jsonify({
                "error": error_message,
                "error_code": error_code
            }), 400
        
        # Convert cd_produto to integer
        try:
            cd_produto = int(cd_produto)
        except ValueError:
            return jsonify({
                "error": "cdProduto must be a valid integer",
                "error_code": "INVALID_PARAMETER"
            }), 400
        
        # Convert cd_cliente to integer if provided
        if cd_cliente:
            try:
                cd_cliente = int(cd_cliente)
            except ValueError:
                return jsonify({
                    "error": "cdCliente must be a valid integer",
                    "error_code": "INVALID_PARAMETER"
                }), 400
        
        # Validate aggregation parameter
        if aggregation not in ['daily', 'by_day_of_week']:
            return jsonify({
                "error": "aggregation must be 'daily' or 'by_day_of_week'",
                "error_code": "INVALID_PARAMETER"
            }), 400
        
        # Get optional device filter (comma-separated list)
        cd_dispositivos_param = request.args.get('cdDispositivos')
        cd_dispositivos = None
        if cd_dispositivos_param:
            try:
                # Split by comma and convert to integers
                cd_dispositivos = [int(d.strip()) for d in cd_dispositivos_param.split(',') if d.strip()]
            except ValueError:
                return jsonify({
                    "error": "cdDispositivos must be a comma-separated list of valid integers",
                    "error_code": "INVALID_PARAMETER"
                }), 400
        
        # Call service function
        result = get_temperatura_aggregation(
            cd_produto=cd_produto,
            dt_inicio=dt_registro_inicio,
            dt_fim=dt_registro_fim,
            cd_dispositivos=cd_dispositivos if cd_dispositivos else None,
            cd_cliente=cd_cliente,
            aggregation_type=aggregation,
            db_client=supabase_client
        )
        
        # Build response
        response = {
            "metadata": {
                "last_read": result.get("last_read"),
                "aggregation_type": aggregation,
                "date_range": {
                    "start": dt_registro_inicio,
                    "end": dt_registro_fim
                }
            },
            "data": {
                aggregation: result.get(aggregation, {}),
                "total": result.get("total", 0),
                "record_count": result.get("record_count", 0)
            }
        }
        
        # Add the appropriate average field based on aggregation type
        if aggregation == 'daily':
            response["data"]["average_daily"] = result.get("average_daily", 0)
        else:  # by_day_of_week
            response["data"]["average_per_day_of_week"] = result.get("average_per_day_of_week", 0)
        
        return jsonify(response)
        
    except Exception as e:
        print(f"Error in get_temperatura_summary: {e}")
        return jsonify({
            "error": "Internal server error",
            "error_code": "INTERNAL_ERROR",
            "details": str(e)
        }), 500


@main.route("/v1/summary/camera-categorias", methods=["GET"])
def get_camera_categorias_summary():
    """
    Get camera category sensor summary data (gender, age, emotion) aggregated by hour
    """
    # Get authenticated client
    supabase_client, error = get_authenticated_client(request=request)

    if error or supabase_client is None:
        return jsonify({"error": error, "error_code": "AUTHENTICATION_ERROR"}), 401

    try:
        # Get required parameters
        cd_produto = request.args.get('cdProduto')
        dt_registro_inicio = request.args.get('dt_registro_inicio')
        dt_registro_fim = request.args.get('dt_registro_fim')
        cd_cliente = request.args.get('cdCliente')

        # Validate required parameters
        if not cd_produto:
            return jsonify({
                "error": "cdProduto parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400

        if not dt_registro_inicio:
            return jsonify({
                "error": "dt_registro_inicio parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400

        if not dt_registro_fim:
            return jsonify({
                "error": "dt_registro_fim parameter is required",
                "error_code": "MISSING_PARAMETER"
            }), 400

        # Validate date formats and range
        is_valid, error_message, error_code, parsed_dates = validate_date_range(
            dt_registro_inicio, dt_registro_fim
        )

        if not is_valid:
            return jsonify({
                "error": error_message,
                "error_code": error_code
            }), 400

        # Convert cd_produto to integer
        try:
            cd_produto = int(cd_produto)
        except ValueError:
            return jsonify({
                "error": "cdProduto must be a valid integer",
                "error_code": "INVALID_PARAMETER"
            }), 400

        # Convert cd_cliente to integer if provided
        if cd_cliente:
            try:
                cd_cliente = int(cd_cliente)
            except ValueError:
                return jsonify({
                    "error": "cdCliente must be a valid integer",
                    "error_code": "INVALID_PARAMETER"
                }), 400

        # Get optional device filter (comma-separated list)
        cd_dispositivos_param = request.args.get('cdDispositivos')
        cd_dispositivos = None
        if cd_dispositivos_param:
            try:
                # Split by comma and convert to integers
                cd_dispositivos = [int(d.strip()) for d in cd_dispositivos_param.split(',') if d.strip()]
            except ValueError:
                return jsonify({
                    "error": "cdDispositivos must be a comma-separated list of valid integers",
                    "error_code": "INVALID_PARAMETER"
                }), 400

        # Call service function
        result = get_camera_categorias_aggregation(
            cd_produto=cd_produto,
            dt_inicio=dt_registro_inicio,
            dt_fim=dt_registro_fim,
            cd_dispositivos=cd_dispositivos if cd_dispositivos else None,
            cd_cliente=cd_cliente,
            db_client=supabase_client
        )

        return jsonify(result)

    except Exception as e:
        print(f"Error in get_camera_categorias_summary: {e}")
        return jsonify({
            "error": "Internal server error",
            "error_code": "INTERNAL_ERROR",
            "details": str(e)
        }), 500
