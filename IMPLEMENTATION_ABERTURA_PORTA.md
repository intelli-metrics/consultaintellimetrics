# Implementation Plan: Abertura de Porta Endpoint

## Overview
Building the `/api/v1/summary/abertura-porta` endpoint for door opening sensor data aggregation.

**Sensor Type**: Abertura de Porta (ID: 2)
**Endpoint**: `GET /api/v1/summary/abertura-porta`

## Sprint 1: MVP - Bare Minimum Working Endpoint

### Goal
Create a working endpoint that returns hourly aggregation data for door opening sensors.

### Required Parameters (MVP)
- `cdProduto` (required): Product ID
- `dtRegistroInicio` (required): Start date (ISO format)
- `dtRegistroFim` (required): End date (ISO format)

### MVP Response Structure
```json
{
  "metadata": {
    "last_read": "2025-01-25T13:42:00Z",
    "aggregation_type": "hourly",
    "date_range": {
      "start": "2025-01-01T00:00:00Z",
      "end": "2025-01-05T23:59:59Z"
    }
  },
  "data": {
    "hourly": {
      "00": 1200,
      "01": 800,
      "02": 600,
      // ... hours 03-23
    },
    "total": 785000,
    "average_hourly": 32708
  }
}
```

## Implementation Steps

### Step 1: Create RPC Function in Supabase
**File**: `supabase/migrations/[timestamp]_add_abertura_porta_hourly_aggregation.sql`

```sql
-- Create RPC function for hourly door opening aggregation
CREATE OR REPLACE FUNCTION get_abertura_porta_hourly_aggregation(
    p_cd_produto INTEGER,
    p_dt_inicio TIMESTAMP WITH TIME ZONE,
    p_dt_fim TIMESTAMP WITH TIME ZONE,
    p_cd_dispositivos INTEGER[] DEFAULT NULL
)
RETURNS TABLE (
    hour_of_day INTEGER,
    total_value BIGINT,
    record_count BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXTRACT(HOUR FROM sr.dtRegistro)::INTEGER as hour_of_day,
        SUM(sr.nrValor)::BIGINT as total_value,
        COUNT(*)::BIGINT as record_count
    FROM "TbSensorRegistro" sr
    INNER JOIN "TbSensor" s ON sr.cdSensor = s.cdSensor
    INNER JOIN "TbDispositivo" d ON s.cdDispositivo = d.cdDispositivo
    WHERE s.cdTipoSensor = 2  -- Abertura de Porta
        AND d.cdProduto = p_cd_produto
        AND sr.dtRegistro >= p_dt_inicio
        AND sr.dtRegistro <= p_dt_fim
        AND (p_cd_dispositivos IS NULL OR d.cdDispositivo = ANY(p_cd_dispositivos))
    GROUP BY EXTRACT(HOUR FROM sr.dtRegistro)
    ORDER BY hour_of_day;
END;
$$;
```

### Step 2: Create Service Method
**File**: `app/services.py`

Add method to existing service class or create new `SensorSummaryService`:

```python
def get_abertura_porta_hourly_aggregation(self, cd_produto, dt_inicio, dt_fim, cd_dispositivos=None):
    """
    Get hourly aggregation for door opening sensors
    
    Args:
        cd_produto (int): Product ID
        dt_inicio (str): Start date in ISO format
        dt_fim (str): End date in ISO format
        cd_dispositivos (list, optional): List of device IDs to filter
    
    Returns:
        dict: Aggregated data with hourly breakdown
    """
    # Implementation details in next step
    pass
```

### Step 3: Create Route Endpoint
**File**: `app/routes.py` (add to existing file)

```python
from flask import request, jsonify
from app.services import SensorSummaryService

@app.route('/api/v1/summary/abertura-porta', methods=['GET'])
def get_abertura_porta_summary():
    """
    Get door opening sensor summary data
    """
    # Parameter validation and service call
    pass
```

### Step 4: Integration
**File**: `app/routes.py` (follow existing patterns)

- Add the new route to the existing routes file
- Follow existing authentication and error handling patterns
- Use existing service instantiation patterns

## Sprint 2: Enhanced Features

### Goal
Add daily aggregation option and device filtering.

### Additional Parameters
- `aggregation` (optional): "by_day_of_week" | "hourly" (default: "hourly")
- `cdDispositivos` (optional): Comma-separated list of device IDs

### Enhanced Response Structure
```json
{
  "metadata": {
    "last_read": "2025-01-25T13:42:00Z",
    "aggregation_type": "by_day_of_week",
    "date_range": {
      "start": "2025-01-01T00:00:00Z",
      "end": "2025-01-05T23:59:59Z"
    }
  },
  "data": {
    "by_day_of_week": {
      "monday": 95000,
      "tuesday": 47000,
      "wednesday": 48000,
      "thursday": 47000,
      "friday": 105000,
      "saturday": 187000,
      "sunday": 155000
    },
    "total": 785000,
    "average_per_day_of_week": 112143
  }
}
```

## Sprint 3: Error Handling & Validation

### Goal
Add comprehensive error handling and parameter validation.

### Error Scenarios to Handle
- Invalid date formats
- Missing required parameters
- Invalid product ID
- No data found for date range
- Database connection errors

### Error Response Format
```json
{
  "error": "Invalid date format",
  "error_code": "INVALID_DATE_FORMAT",
  "details": {
    "field": "dtRegistroInicio",
    "expected_format": "ISO 8601 (YYYY-MM-DDTHH:MM:SSZ)"
  }
}
```

## Sprint 4: Testing & Optimization

### Goal
Test with realistic data and optimize performance.

### Test Scenarios
- Single device, single day
- Multiple devices, week range
- Large date range (month)
- Edge cases (no data, invalid parameters)

### Performance Considerations
- Query execution time
- Memory usage
- Database connection pooling
- Response time optimization

## Database Schema Reference

### Key Tables
- `TbSensorRegistro`: Sensor readings (cdDispositivo, cdSensor, nrValor, dtRegistro)
- `TbSensor`: Sensor definitions (cdSensor, cdDispositivo, cdTipoSensor)
- `TbDispositivo`: Device definitions (cdDispositivo, cdProduto, cdCliente)
- `TbTipoSensor`: Sensor types (id, dsNome, dsUnidade)

### Sensor Type Mapping
- **Abertura de Porta**: ID 2

## Development Notes

### PostgreSQL Functions
- Use `SECURITY DEFINER` for RPC functions
- Implement proper parameter validation in SQL
- Use prepared statements for security

### Flask Implementation
- Use Blueprint for v2 routes
- Implement proper error handling
- Add request logging for debugging
- Use consistent response format

### Testing Strategy
- Unit tests for service methods
- Integration tests for endpoints
- Database query performance testing
- Error scenario testing

## Next Steps After MVP
1. Implement daily aggregation RPC function
2. Add device filtering logic
3. Implement comprehensive error handling
4. Add response validation
5. Performance testing and optimization
6. Documentation and examples

---

## TODO List - Implementation Tasks

### Sprint 1: MVP Implementation
- [x] **Create Supabase Migration File**
  - [x] Create new migration file with timestamp
  - [x] Add RPC function `get_abertura_porta_hourly_aggregation`
  - [x] Test function with sample data
  - [x] Apply migration to database

- [x] **Service Layer Implementation**
  - [x] Read existing `app/services.py` to understand current structure
  - [x] Add `SensorSummaryService` class or extend existing service
  - [x] Implement `get_abertura_porta_hourly_aggregation` method
  - [x] Add database connection logic using existing patterns
  - [x] Add parameter validation (dates, product ID)

- [x] **Route Implementation**
  - [x] Read existing `app/routes.py` to understand current structure
  - [x] Add new endpoint to existing routes file
  - [x] Implement `/api/v1/summary/abertura-porta` endpoint
  - [x] Add parameter parsing and validation
  - [x] Add basic error handling
  - [x] Follow existing route patterns and conventions

- [x] **Integration & Testing**
  - [x] Test endpoint with sample data
  - [x] Verify response format matches specification
  - [x] Test with different date ranges
  - [x] Test error scenarios (invalid dates, missing params)

### Sprint 2: Enhanced Features
- [x] **Daily Aggregation**
  - [x] Create RPC function for daily aggregation with different GROUP BY clause
  - [x] Change query from `EXTRACT(HOUR FROM sr.dtRegistro)` to `EXTRACT(DOW FROM sr.dtRegistro)`
  - [x] Add day-of-week mapping (0=sunday, 1=monday, 2=tuesday, etc.)
  - [x] Map numeric DOW to English day names (monday, tuesday, wednesday, thursday, friday, saturday, sunday)
  - [x] Update service method to handle aggregation parameter and call appropriate RPC function
  - [x] Update endpoint to accept `aggregation` parameter ("by_day_of_week" | "hourly")

- [x] **Device Filtering**
  - [x] Update RPC function to accept device array parameter
  - [x] Add device validation logic
  - [x] Update service method for device filtering
  - [x] Update endpoint to accept `cdDispositivos` parameter (comma-separated list)
