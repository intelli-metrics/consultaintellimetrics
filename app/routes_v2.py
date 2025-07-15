from flask import Blueprint, jsonify, request

from db_utils import get_authenticated_client
from .services import Selecionar_VwTbProdutoTotalStatus

v2 = Blueprint("v2", __name__)


@v2.route("/TbProdutoTotalStatus/<codigo>")
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