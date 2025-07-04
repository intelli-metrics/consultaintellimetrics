import os
from datetime import datetime

import jwt
from supabase.client import ClientOptions

from supabase import Client, create_client

url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_KEY")
supabase_api: Client = create_client(url, key)


def verify_token(token):
    try:
        decoded_token = jwt.decode(token, options={"verify_signature": False})
        return decoded_token
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def get_supabase_client_from_request(request):
    auth_header = request.headers.get("Authorization", None)
    if auth_header is None or not auth_header.startswith("Bearer "):
        return None, "Não autorizado"

    token = auth_header.split("Bearer ")[1]
    user_info = verify_token(token)
    if user_info is None:
        return None, "Token inválido"

    user_id = user_info.get("sub")
    if not user_id:
        return None, "ID do usuário não encontrado no token"

    headers = {"Authorization": f"Bearer {token}"}
    supabase_client: Client = create_client(
        url, key, options=ClientOptions(headers=headers)
    )
    return supabase_client, None


def get_supabase_client_from_api_key(request, required_client_id=None):
    """
    Autentica clientes externos usando chaves API
    """
    api_key = request.headers.get("X-API-Key")
    if not api_key:
        return None, "X-API-Key header necessário"

    try:
        # Buscar informações da chave API
        response = (
            supabase_api.table("TbApiKeys")
            .select(
                "cdApiKey, cdUsuario, cdClientes, blAtiva, dtExpiracao, dsPermissoes"
            )
            .eq("dsKey", api_key)
            .eq("blAtiva", True)
            .execute()
        )

        if not response.data:
            return None, "Chave API inválida ou inativa"

        key_info = response.data[0]

        # Verificar se a chave expirou
        if key_info.get("dtExpiracao"):
            expiry = datetime.fromisoformat(
                key_info["dtExpiracao"].replace("Z", "+00:00")
            )
            if datetime.now(expiry.tzinfo) > expiry:
                return None, "Chave API expirada"

        # Verificar acesso ao cliente específico
        if required_client_id and key_info["cdClientes"]:
            if int(required_client_id) not in key_info["cdClientes"]:
                return None, "Acesso negado para este cliente"

        # Buscar email do usuário na tabela auth.users
        user_response = supabase_api.auth.admin.get_user_by_id(key_info["cdUsuario"])

        if not user_response.user:
            return None, "Usuário não encontrado"

        user_email = user_response.user.email

        # Fazer login com o usuário de serviço
        service_password = os.getenv("SERVICE_USER_PASSWORD")
        if not service_password:
            return None, "Configuração do servidor incorreta"

        user_client = create_client(url, key)
        auth_response = user_client.auth.sign_in_with_password(
            {"email": user_email, "password": service_password}
        )

        if not auth_response.user:
            return None, "Erro de autenticação do usuário de serviço"

        return user_client, None

    except Exception as e:
        print(f"Erro ao validar chave API: {e}")
        return None, "Erro interno do servidor"


def get_authenticated_client(request, required_client_id=None):
    """
    Função unificada que lida com autenticação por token Supabase ou chave API
    """
    # Verificar se é chave API primeiro
    if request.headers.get("X-API-Key"):
        return get_supabase_client_from_api_key(request, required_client_id)

    # Caso contrário, usar autenticação por token Supabase
    return get_supabase_client_from_request(request)
