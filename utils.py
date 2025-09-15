from datetime import datetime, timedelta

import pytz
from geopy.distance import geodesic
from geopy.geocoders import Nominatim

from constantes import campos_tabelas


def valida_campo(field, value, field_type, required):
    """
    Valida o valor de um campo com base no tipo e se é obrigatório.

    Parâmetros:
    - field (str): Nome do campo.
    - value (any): Valor do campo.
    - field_type (str): Tipo do campo.
    - required (bool): Se o campo é obrigatório.

    Retorna:
    - bool: True se o campo for válido, False caso contrário.
    - str: Mensagem de erro, se houver.
    """
    # Handle empty strings for text and timestamp fields
    if field_type in ("text", "character varying", "timestamp"):
        if value == "":
            if required:
                return False, f"Campo {field} é necessário."
            # se o campo é vazio e não necessário, retornar True
            return True, None

    # Validate the type
    if (field_type == "integer" or field_type == "bigint") and not isinstance(
        value, int
    ):
        return False, f"Campo {field} deve ser do tipo inteiro."
    elif field_type in ("text", "character varying", "uuid") and not isinstance(
        value, str
    ):
        return False, f"Campo {field} deve ser do tipo texto."
    elif field_type == "boolean" and not isinstance(value, bool):
        return False, f"Campo {field} deve ser do tipo boolean."
    elif field_type in ("double precision", "real") and (
        not isinstance(value, float) and not isinstance(value, int)
    ):
        return False, f"Campo {field} deve ser do tipo número com precisão dupla."
    elif field_type in ("timestamp", "timestamp with time zone") and not isinstance(
        value, str
    ):
        return False, f"Campo {field} deve ser do tipo timestamp."

    return True, None


def valida_e_constroi_insert(table, payload, ignorar_fields=None):
    """
    Valida e constrói o dicionário de dados para inserção em uma tabela com base no payload fornecido.

    Parâmetros:
    - table (str): Nome da tabela onde os dados serão inseridos.
    - payload (dict): Dicionário contendo os dados para inserção.
    - ignorar_fields (list): Opcional. Lista de fields para ignorar validação

    Retorna:
    - dict: Dicionário com os dados validados e prontos para inserção.
    - str: Mensagem de erro, se houver.
    """
    if table not in campos_tabelas:
        return None, f"Tabela {table} não é suportada."

    fields = campos_tabelas[table]
    data = {}

    for field, attributes in fields.items():
        if ignorar_fields and len(ignorar_fields) and field in ignorar_fields:
            continue
        
        required = attributes["required"]
        field_type = attributes["type"]

        if required and field not in payload:
            return None, f"Campo {field} é necessário."

        if field in payload:
            value = payload[field]

            # Validate the field
            is_valid, error_message = valida_campo(field, value, field_type, required)
            if not is_valid:
                return None, error_message

            data[field] = value

    return data, None


def valida_e_constroi_update(table, payload):
    """
    Valida e constrói o dicionário de dados para atualização em uma tabela com base no payload fornecido.

    Parâmetros:
    - table (str): Nome da tabela onde os dados serão atualizados.
    - payload (dict): Dicionário contendo os dados para atualização.

    Retorna:
    - dict: Dicionário com os dados validados e prontos para atualização.
    - str: Mensagem de erro, se houver.
    """
    if table not in campos_tabelas:
        return None, f"Tabela {table} não é suportada."

    fields = campos_tabelas[table]
    data = {}

    for field, attributes in fields.items():
        required = attributes["required"]
        field_type = attributes["type"]

        if field in payload:
            value = payload[field]

            # Validate the field
            is_valid, error_message = valida_campo(field, value, field_type, required)
            if not is_valid:
                return None, error_message

            data[field] = value

    if not data:
        return None, "Nenhum campo válido para atualizar."

    return data, None


def calcular_distancia(lat1, lon1, lat2, lon2):
    geolocator = Nominatim(user_agent="my_app")
    distancia = geodesic((lat1, lon1), (lat2, lon2)).kilometers
    return distancia



def convert_sao_paulo_date_to_utc_range(date_str: str):
    """
    Converts a date string in the format YYYYMMDD from São Paulo timezone
    to a UTC datetime range (start and end of the day).

    Args:
        date_str (str): Date in the format YYYYMMDD representing the date in São Paulo timezone.

    Returns:
        tuple: A tuple containing two strings:
            - start_of_day_utc (str): Start of the day in UTC (YYYY-MM-DD HH:MM:SS).
            - end_of_day_utc (str): End of the day in UTC (YYYY-MM-DD HH:MM:SS).
    """
    # São Paulo timezone
    saopaulo_tz = pytz.timezone('America/Sao_Paulo')

    # Convert string to a datetime object
    date_obj = datetime.strptime(date_str, '%Y%m%d')

    # Define start and end of the day in São Paulo timezone
    start_of_day = saopaulo_tz.localize(datetime(date_obj.year, date_obj.month, date_obj.day, 0, 0, 0))
    end_of_day = saopaulo_tz.localize(datetime(date_obj.year, date_obj.month, date_obj.day, 23, 59, 59))

    # Convert to UTC
    start_of_day_utc = start_of_day.astimezone(pytz.utc)
    end_of_day_utc = end_of_day.astimezone(pytz.utc)

    # Return as formatted strings
    return (start_of_day_utc.strftime('%Y-%m-%d %H:%M:%S'),
            end_of_day_utc.strftime('%Y-%m-%d %H:%M:%S'))


def validate_date_range(start_date_str, end_date_str):
    """
    Validates date format and range for API parameters.
    
    Args:
        start_date_str (str): Start date in ISO 8601 format
        end_date_str (str): End date in ISO 8601 format
    
    Returns:
        tuple: (is_valid, error_message, error_code, parsed_dates)
        - is_valid (bool): True if dates are valid
        - error_message (str): Error message if invalid, None if valid
        - error_code (str): Error code if invalid, None if valid
        - parsed_dates (tuple): (start_dt, end_dt) if valid, (None, None) if invalid
    """
    try:
        # Try to parse the dates to validate format
        start_dt = datetime.fromisoformat(start_date_str.replace('Z', '+00:00'))
        end_dt = datetime.fromisoformat(end_date_str.replace('Z', '+00:00'))
        
        # Validate date range
        if start_dt >= end_dt:
            return False, "dtRegistroInicio must be before dtRegistroFim", "INVALID_DATE_RANGE", (None, None)
        
        return True, None, None, (start_dt, end_dt)
        
    except ValueError as e:
        return False, "Invalid date format. Expected ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)", "INVALID_DATE_FORMAT", (None, None)
    except Exception as e:
        return False, "Error parsing date range", "DATE_PARSING_ERROR", (None, None)
