from flask import Blueprint, jsonify, request

from db_utils import get_authenticated_client
from .services import Selecionar_VwTbPosicaoAtualV2

v2 = Blueprint("v2", __name__)


@v2.route("/TbPosicaoAtual", methods=["GET"])
def get_TbPosicaoAtual_v2():
    """
    Get current device positions (v2 endpoint).
    
    Query Parameters:
        cdProduto (required): Product ID to filter by
        cdDispositivos (optional): Comma-separated list of device IDs to filter by
        
    Returns:
        JSON array of position records
        
    Example:
        GET /v2/TbPosicaoAtual?cdProduto=123
        GET /v2/TbPosicaoAtual?cdProduto=123&cdDispositivos=1,2,3
    """
    # Authenticate request
    supabase_client, error = get_authenticated_client(request=request)
    
    if error or supabase_client is None:
        return jsonify({"message": error}), 401
    
    # Get required parameter
    cd_produto = request.args.get("cdProduto")
    if not cd_produto:
        return jsonify({
            "error": "cdProduto parameter is required",
            "error_code": "MISSING_PARAMETER"
        }), 400
    
    # Validate cdProduto is a valid integer
    try:
        int(cd_produto)
    except ValueError:
        return jsonify({
            "error": "cdProduto must be a valid integer",
            "error_code": "INVALID_PARAMETER"
        }), 400
    
    # Get optional device filter (comma-separated list)
    cd_dispositivos_param = request.args.get("cdDispositivos")
    cd_dispositivos = None
    if cd_dispositivos_param:
        try:
            # Split by comma and convert to integers
            cd_dispositivos = [int(d.strip()) for d in cd_dispositivos_param.split(',') if d.strip()]
            if not cd_dispositivos:
                cd_dispositivos = None
        except ValueError:
            return jsonify({
                "error": "cdDispositivos must be a comma-separated list of valid integers",
                "error_code": "INVALID_PARAMETER"
            }), 400
    
    # Call service function
    try:
        resultado = Selecionar_VwTbPosicaoAtualV2(
            cd_produto=cd_produto,
            cd_dispositivos=cd_dispositivos,
            db_client=supabase_client
        )
        return jsonify(resultado)
    except Exception as e:
        return jsonify({
            "error": "An error occurred while fetching position data",
            "error_code": "INTERNAL_ERROR",
            "details": str(e)
        }), 500
