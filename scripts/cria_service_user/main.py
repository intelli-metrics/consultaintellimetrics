# helper script to create service user
import os
import secrets
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_KEY")
supabase_api = create_client(url, key)

# Create service user
user_response = supabase_api.auth.admin.create_user(
    {
        "email": "inova-service-client@intellimetrics.tec.br",
        "password": os.getenv("SERVICE_USER_PASSWORD"),
        "email_confirm": True,
    }
)

if user_response.user:
    # Generate API key
    api_key = secrets.token_urlsafe(32)

    # Insert API key record
    supabase_api.table("TbApiKeys").insert(
        {
            "cdUsuario": user_response.user.id,
            "dsKey": api_key,
            "cdClientes": [37],  # Can only access client 37
            "dsNome": "API Key para Inova + Trade",
            "dsPermissoes": ["read"],
        }
    ).execute()

    print(f"Created service user: {user_response.user.email}")
    print(f"API Key: {api_key}")
