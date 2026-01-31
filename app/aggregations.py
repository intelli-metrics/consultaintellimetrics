"""
Sensor aggregation functions for dispositivos resumo.

This module provides optimized functions to aggregate sensor data by device,
only querying for sensor types that actually exist on the devices.
"""

from typing import Dict, List, Any, Optional
from collections import defaultdict


def get_sensor_types_by_dispositivo(dispositivos_ids: List[int], db_client) -> Dict[int, List[int]]:
    """
    Query TbSensor to determine which cdTipoSensor each dispositivo has.
    
    Args:
        dispositivos_ids: List of device IDs to check
        db_client: Supabase client instance
        
    Returns:
        Dict mapping cdDispositivo to list of cdTipoSensor IDs:
        {
            cdDispositivo: [1, 3, 4],  # list of cdTipoSensor IDs this device has
            ...
        }
    """
    if not dispositivos_ids:
        return {}
    
    try:
        query = (
            db_client.table("TbSensor")
            .select("cdDispositivo", "cdTipoSensor")
            .in_("cdDispositivo", dispositivos_ids)
        )
        resultado = query.execute()
        print(f"DEBUG: Sensor query returned {len(resultado.data)} rows")
        
        # Group by dispositivo
        sensor_types_by_device = defaultdict(list)
        for row in resultado.data:
            cd_dispositivo = row["cdDispositivo"]
            cd_tipo_sensor = row["cdTipoSensor"]
            if cd_tipo_sensor not in sensor_types_by_device[cd_dispositivo]:
                sensor_types_by_device[cd_dispositivo].append(cd_tipo_sensor)
        
        return dict(sensor_types_by_device)
        
    except Exception as e:
        print(f"Error getting sensor types by dispositivo: {e}")
        return {}


def aggregate_simple_sensors(
    dispositivos_by_type: Dict[int, List[int]], 
    dt_inicio: Optional[str], 
    dt_fim: Optional[str], 
    db_client
) -> Dict[int, Dict[str, float]]:
    """
    Single query for sensor types 2, 4, 5 (porta, temp, pessoas).
    Only queries devices that have these sensor types.
    
    Args:
        dispositivos_by_type: Dict mapping sensor type to list of devices that have it
        dt_inicio: Start date filter (ISO format)
        dt_fim: End date filter (ISO format)
        db_client: Supabase client instance
    
    Returns:
        Dict mapping cdDispositivo to sensor aggregations:
        {
            cdDispositivo: {
                'nrPorta': X,      # SUM for type 2
                'nrTemp': Y,       # AVG for type 4
                'nrPessoas': Z     # SUM for type 5
            }
        }
    """
    # Get all devices that have sensor types 2, 4, or 5
    devices_with_simple_sensors = set()
    for sensor_type in [2, 4, 5]:
        if sensor_type in dispositivos_by_type:
            devices_with_simple_sensors.update(dispositivos_by_type[sensor_type])
    
    if not devices_with_simple_sensors:
        return {}
    
    try:
        # First, get the sensor IDs for the devices and sensor types we need
        sensor_query = (
            db_client.table("TbSensor")
            .select("cdSensor", "cdDispositivo", "cdTipoSensor")
            .in_("cdDispositivo", list(devices_with_simple_sensors))
            .in_("cdTipoSensor", [2, 4, 5])
        )
        sensor_result = sensor_query.execute()
        
        if not sensor_result.data:
            return {}
        
        # Extract sensor IDs for the query
        sensor_ids = [s["cdSensor"] for s in sensor_result.data]
        
        # Now query the sensor registros with the specific sensor IDs
        query = (
            db_client.table("TbSensorRegistro")
            .select("cdDispositivo", "nrValor", "dtRegistro", "cdSensor")
            .in_("cdSensor", sensor_ids)
        )
        
        # Apply date filters if provided
        if dt_inicio:
            query = query.gte("dtRegistro", dt_inicio)
        if dt_fim:
            query = query.lte("dtRegistro", dt_fim)
        
        resultado = query.execute()
        
        # Create mappings of sensor ID to sensor type and device for processing
        sensor_type_map = {s["cdSensor"]: s["cdTipoSensor"] for s in sensor_result.data}
        sensor_device_map = {s["cdSensor"]: s["cdDispositivo"] for s in sensor_result.data}

        # Process results and aggregate
        device_aggregations = defaultdict(lambda: {
            'nrPorta': 0.0,
            'nrTemp': 0.0,
            'nrPessoas': 0.0
        })
        
        # Group by device and sensor type for aggregation
        temp_readings = defaultdict(list)  # For averaging temperature
        
        for row in resultado.data:
            cd_sensor = row["cdSensor"]
            # Use cdDispositivo from TbSensor (authoritative) instead of TbSensorRegistro
            cd_dispositivo = sensor_device_map.get(cd_sensor)
            if cd_dispositivo is None:
                continue
            nr_valor = float(row["nrValor"]) if row["nrValor"] is not None else 0.0
            cd_tipo_sensor = sensor_type_map.get(cd_sensor)

            if cd_tipo_sensor == 2:  # Door sensor
                device_aggregations[cd_dispositivo]['nrPorta'] += nr_valor
            elif cd_tipo_sensor == 4:  # Temperature sensor
                temp_readings[cd_dispositivo].append(nr_valor)
            elif cd_tipo_sensor == 5:  # People sensor
                device_aggregations[cd_dispositivo]['nrPessoas'] += nr_valor
        
        # Calculate average temperature for each device
        for cd_dispositivo, readings in temp_readings.items():
            if readings:
                device_aggregations[cd_dispositivo]['nrTemp'] = sum(readings) / len(readings)
        
        return dict(device_aggregations)
        
    except Exception as e:
        print(f"Error aggregating simple sensors: {e}")
        return {}


def aggregate_itens_sensors(
    dispositivos_by_type: Dict[int, List[int]], 
    dt_inicio: Optional[str], 
    dt_fim: Optional[str], 
    db_client
) -> Dict[int, float]:
    """
    Query for sensor types 1 and 3 (distance and weight) to calculate nrItens.
    Only queries devices that have these sensor types.
    
    Args:
        dispositivos_by_type: Dict mapping sensor type to list of devices that have it
        dt_inicio: Start date filter (ISO format)
        dt_fim: End date filter (ISO format)
        db_client: Supabase client instance
    
    Returns:
        Dict mapping cdDispositivo to total nrItens:
        {
            cdDispositivo: nrItens_total  # sum of peso + distancia calculations
        }
    """
    # Get all devices that have sensor types 1 or 3
    devices_with_item_sensors = set()
    for sensor_type in [1, 3]:
        if sensor_type in dispositivos_by_type:
            devices_with_item_sensors.update(dispositivos_by_type[sensor_type])
    
    if not devices_with_item_sensors:
        return {}
    
    try:
        # First, get the sensor IDs for the devices and sensor types we need
        sensor_query = (
            db_client.table("TbSensor")
            .select("cdSensor", "cdDispositivo", "cdTipoSensor")
            .in_("cdDispositivo", list(devices_with_item_sensors))
            .in_("cdTipoSensor", [1, 3])
        )
        sensor_result = sensor_query.execute()
        
        if not sensor_result.data:
            return {}
        
        # Extract sensor IDs for the query
        sensor_ids = [s["cdSensor"] for s in sensor_result.data]
        
        # Now query the sensor registros with the specific sensor IDs
        query = (
            db_client.table("TbSensorRegistro")
            .select("cdDispositivo", "nrValor", "dtRegistro", "cdSensor", "cdProdutoItem")
            .in_("cdSensor", sensor_ids)
        )
        
        # Apply date filters if provided
        if dt_inicio:
            query = query.gte("dtRegistro", dt_inicio)
        if dt_fim:
            query = query.lte("dtRegistro", dt_fim)
        
        resultado = query.execute()
        
        # Create mappings of sensor ID to sensor type and device for processing
        sensor_type_map = {s["cdSensor"]: s["cdTipoSensor"] for s in sensor_result.data}
        sensor_device_map = {s["cdSensor"]: s["cdDispositivo"] for s in sensor_result.data}

        # Get product item data for calculations
        produto_items = set()
        for row in resultado.data:
            if row["cdProdutoItem"]:
                produto_items.add(row["cdProdutoItem"])
        
        produto_item_data = {}
        if produto_items:
            produto_query = (
                db_client.table("TbProdutoItem")
                .select("cdProdutoItem", "nrPesoUnit", "nrAlt")
                .in_("cdProdutoItem", list(produto_items))
            )
            produto_result = produto_query.execute()
            produto_item_data = {
                item["cdProdutoItem"]: item 
                for item in produto_result.data
            }
        
        # Process results and calculate items
        device_items = defaultdict(list)  # Store all item calculations for averaging
        
        for row in resultado.data:
            cd_sensor = row["cdSensor"]
            # Use cdDispositivo from TbSensor (authoritative) instead of TbSensorRegistro
            cd_dispositivo = sensor_device_map.get(cd_sensor)
            if cd_dispositivo is None:
                continue
            nr_valor = float(row["nrValor"]) if row["nrValor"] is not None else 0.0
            cd_tipo_sensor = sensor_type_map.get(cd_sensor)
            cd_produto_item = row["cdProdutoItem"]

            # Get product item data
            produto_item = produto_item_data.get(cd_produto_item) if cd_produto_item else None

            if cd_tipo_sensor == 3:  # Weight sensor
                nr_peso_unit = float(produto_item["nrPesoUnit"]) if produto_item and produto_item["nrPesoUnit"] else 0.0
                if nr_peso_unit > 0:
                    items_calculated = nr_valor / nr_peso_unit
                    device_items[cd_dispositivo].append(items_calculated)
            elif cd_tipo_sensor == 1:  # Distance sensor
                nr_alt = float(produto_item["nrAlt"]) if produto_item and produto_item["nrAlt"] else 0.0
                if nr_alt > 0:
                    items_calculated = nr_valor / nr_alt
                    device_items[cd_dispositivo].append(items_calculated)
        
        # Calculate average items for each device and convert to integer
        device_nr_itens = {}
        for cd_dispositivo, calculations in device_items.items():
            if calculations:
                avg_items = sum(calculations) / len(calculations)
                device_nr_itens[cd_dispositivo] = int(round(avg_items))
            else:
                device_nr_itens[cd_dispositivo] = 0
        
        return device_nr_itens
        
    except Exception as e:
        print(f"Error aggregating items sensors: {e}")
        return {}


def aggregate_all_sensors(
    dispositivos_ids: List[int], 
    dt_inicio: Optional[str], 
    dt_fim: Optional[str], 
    db_client
) -> Dict[int, Dict[str, Any]]:
    """
    Orchestrator function that:
    1. Gets sensor type mapping for all devices
    2. Groups devices by sensor type
    3. Calls aggregate_simple_sensors (if any devices have types 2,4,5)
    4. Calls aggregate_itens_sensors (if any devices have types 1,3)
    5. Merges results and returns complete aggregation dict
    
    Args:
        dispositivos_ids: List of device IDs to aggregate
        dt_inicio: Start date filter (ISO format)
        dt_fim: End date filter (ISO format)
        db_client: Supabase client instance
    
    Returns:
        Dict mapping cdDispositivo to all sensor aggregations:
        {
            cdDispositivo: {
                'nrPorta': 0,
                'nrPessoas': 0, 
                'nrTemp': 0,
                'nrItens': 0
            }
        }
        All devices get all 4 fields, defaulting to 0 if sensor type not present.
    """
    if not dispositivos_ids:
        return {}
    
    # Step 1: Get sensor types for each device
    print(f"DEBUG: Getting sensor types for {len(dispositivos_ids)} devices: {dispositivos_ids}")
    sensor_types_by_device = get_sensor_types_by_dispositivo(dispositivos_ids, db_client)
    print(f"DEBUG: Sensor types by device: {sensor_types_by_device}")
    
    # Step 2: Group devices by sensor type
    dispositivos_by_type = defaultdict(list)
    for cd_dispositivo, sensor_types in sensor_types_by_device.items():
        for sensor_type in sensor_types:
            dispositivos_by_type[sensor_type].append(cd_dispositivo)
    
    # Step 3: Initialize result with all devices having default values
    result = {}
    for cd_dispositivo in dispositivos_ids:
        result[cd_dispositivo] = {
            'nrPorta': 0,
            'nrPessoas': 0,
            'nrTemp': 0,
            'nrItens': 0
        }
    
    # Step 4: Get simple sensor aggregations (types 2, 4, 5)
    simple_sensors = aggregate_simple_sensors(dispositivos_by_type, dt_inicio, dt_fim, db_client)
    for cd_dispositivo, aggregations in simple_sensors.items():
        result[cd_dispositivo].update(aggregations)
    
    # Step 5: Get items sensor aggregations (types 1, 3)
    items_sensors = aggregate_itens_sensors(dispositivos_by_type, dt_inicio, dt_fim, db_client)
    for cd_dispositivo, nr_itens in items_sensors.items():
        result[cd_dispositivo]['nrItens'] = nr_itens
    
    return result
