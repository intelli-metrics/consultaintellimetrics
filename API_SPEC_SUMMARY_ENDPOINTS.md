# API Specification: Device Summary Endpoints

## Project Overview

This Flask application provides REST API endpoints for device sensor data aggregation and summary information. The application uses Supabase for authentication and database operations, with complex queries implemented via PostgreSQL RPC functions called through PostgREST.

### Architecture
- **Framework**: Flask
- **Authentication**: Supabase Auth
- **Database**: Supabase (PostgreSQL)
- **Database Access**: PostgREST with RPC for complex queries
- **API Version**: v2

### Project Structure Context
- Main Flask app: `app/` directory
- Routes: `app/routes.py` (existing v1 routes) and `app/routes_v2.py` (new v2 routes)
- Services: `app/services.py` (business logic)
- Database utilities: `db_utils/storage.py`
- Supabase migrations: `supabase/migrations/`
- Database schema: `supabase/schemas/prod.sql`

## Business Requirements

### Overview
The API provides summary data for device sensors across different sensor types, allowing clients to view aggregated sensor data for devices belonging to specific products. The data is used to populate dashboard cards showing various metrics like door openings, movement detection, and temperature readings.

### Sensor Types
- **Abertura de Porta** (Door Opening): ID 2
- **Camera de movimento** (Movement Detection): ID 5  
- **Temperatura** (Temperature): ID 4

### Complete Sensor Type Mapping
- **Distancia** (Distance): ID 1
- **Abertura de Porta** (Door Opening): ID 2
- **Peso** (Weight): ID 3
- **Temperatura** (Temperature): ID 4
- **Camera de movimento** (Movement Detection): ID 5

### Data Relationships
```
TbProduto → TbDispositivo → TbSensor → TbSensorRegistro
```

### Key Database Tables
- `TbProduto`: Products (cdProduto, dsNome, cdCliente)
- `TbDispositivo`: Devices (cdDispositivo, cdProduto, cdCliente)
- `TbSensor`: Sensors (cdSensor, cdDispositivo, cdTipoSensor)
- `TbSensorRegistro`: Sensor readings (cdDispositivo, cdSensor, nrValor, dtRegistro)
- `TbTipoSensor`: Sensor types (id, dsNome, dsUnidade)

### Database Schema Details
- Sensor readings are stored in `TbSensorRegistro` with numeric values (`nrValor`)
- Date filtering is done on `TbSensorRegistro.dtRegistro`
- Device filtering uses `TbDispositivo.cdDispositivo`
- Product filtering uses `TbDispositivo.cdProduto`

## API Endpoints Specification

### Base URL
```
GET /api/v2/summary/{sensor-type}
```

### Common Parameters
All endpoints accept the following parameters:
- `cdProduto` (required): Product ID to filter devices
- `dtRegistroInicio` (required): Start date for data range (ISO format)
- `dtRegistroFim` (required): End date for data range (ISO format)
- `cdDispositivos[]` (optional): Array of device IDs to filter by

### Endpoint 1: Door Opening Summary
```
GET /api/v2/summary/abertura-porta
```

**Additional Parameters:**
- `aggregation` (optional): "daily" | "hourly" (default: "daily")

**Response Structure:**
```json
{
  "metadata": {
    "last_read": "2025-01-25T13:42:00Z",
    "aggregation_type": "daily",
    "date_range": {
      "start": "2025-01-01T00:00:00Z",
      "end": "2025-01-05T23:59:59Z"
    }
  },
  "data": {
    "daily": {
      "segunda": 95000,
      "terca": 47000,
      "quarta": 48000,
      "quinta": 47000,
      "sexta": 105000,
      "sabado": 187000,
      "domingo": 155000
    },
    "total": 785000,
    "average_daily": 254
  }
}
```

### Endpoint 2: Movement Detection Summary
```
GET /api/v2/summary/movimento-pessoas
```

**Additional Parameters:**
- `aggregation` (optional): "daily" | "hourly" (default: "daily")

**Response Structure:** Same as abertura-porta endpoint

### Endpoint 3: Temperature Summary
```
GET /api/v2/summary/temperatura
```

**Response Structure:**
```json
{
  "metadata": {
    "last_read": "2025-01-25T13:42:00Z",
    "date_range": {
      "start": "2025-01-01T00:00:00Z",
      "end": "2025-01-05T23:59:59Z"
    }
  },
  "data": {
    "statistics": {
      "max_temperature": 12.0,
      "avg_temperature": -3.0,
      "min_temperature": -8.0
    },
    "limits": {
      "max_limit": 8.0,
      "min_limit": -8.0
    },
    "time_series": [
      {
        "timestamp": "2025-01-01T00:00:00Z",
        "temperature": -3.5
      }
    ]
  }
}
```

## Error Handling

### Common Error Responses
- `400 Bad Request`: Invalid parameters (invalid date format, missing required fields)
- `401 Unauthorized`: Authentication required
- `404 Not Found`: Product or devices not found
- `500 Internal Server Error`: Server error or database connection issues

### Error Response Format
```json
{
  "error": "Error message description",
  "error_code": "ERROR_CODE",
  "details": {
    "field": "Additional error details if applicable"
  }
}
```

## Implementation TODO

### 1. Database Analysis & Query Planning
- [ ] Analyze existing data to understand typical record volumes
- [ ] Create efficient SQL queries for each sensor type aggregation
- [ ] Design indexes if needed for `TbSensorRegistro` (cdDispositivo, dtRegistro, cdSensor)
- [ ] Plan date/time aggregation functions for PostgreSQL (daily vs hourly grouping)
- [ ] Map sensor type IDs to endpoint names (Abertura de Porta = id 2, Camera de movimento = id 5, Temperatura = id 4)

### Implementation Order for AI Agent
1. **Start with database queries** - Create RPC functions in Supabase for each sensor type
2. **Implement base service class** - Create shared logic for date/device filtering
3. **Build endpoints one by one** - Start with temperatura (simplest), then abertura-porta, then movimento-pessoas
4. **Add validation and error handling** - Implement parameter validation and proper error responses
5. **Test and optimize** - Test with realistic data and optimize queries if needed

### 2. Endpoint Structure Design
- [ ] Define response schema for each endpoint (abertura-porta, movimento-pessoas, temperatura)
- [ ] Plan error handling structure for partial failures
- [ ] Design metadata structure (last read timestamps, aggregation type, etc.)
- [ ] Define query parameter validation rules for each endpoint
- [ ] Plan consistent error response format across all endpoints

### 3. Implementation Tasks
- [ ] Create base service class for sensor data aggregation with shared logic
- [ ] Implement `/api/v2/summary/abertura-porta` endpoint with daily/hourly aggregation
- [ ] Implement `/api/v2/summary/movimento-pessoas` endpoint with daily/hourly aggregation  
- [ ] Implement `/api/v2/summary/temperatura` endpoint (no aggregation options)
- [ ] Add parameter validation and error handling for each endpoint
- [ ] Add response formatting and metadata generation for each endpoint
- [ ] Implement shared date range and device filtering logic

### 4. Query Implementation Details
- [ ] Create SQL queries for daily aggregation (group by day of week)
- [ ] Create SQL queries for hourly aggregation (group by hour of day)
- [ ] Create SQL queries for temperatura (min/max/avg with time series)
- [ ] Implement proper JOIN logic between TbSensorRegistro, TbSensor, TbDispositivo, TbTipoSensor
- [ ] Add proper WHERE clauses for date range and device filtering

### 5. Testing & Optimization
- [ ] Create test data scenarios for each sensor type
- [ ] Performance testing with realistic data volumes (100 devices × 3 sensors)
- [ ] Query optimization if needed
- [ ] Error scenario testing (invalid dates, empty device lists, etc.)
- [ ] Test aggregation logic for daily vs hourly grouping

### 6. Documentation
- [ ] API endpoint documentation for each endpoint
- [ ] Response schema documentation
- [ ] Example requests/responses for each endpoint
- [ ] Parameter validation rules documentation

### 7. Code Organization
- [ ] Create separate service classes for each sensor type if needed
- [ ] Implement shared utilities for date/time aggregation
- [ ] Create consistent response formatters
- [ ] Set up proper logging for debugging

## Technical Considerations

### Database Performance
- Expected data volume: 100 devices × 3 sensors × 48 readings/day = ~14,400 records/day
- Complex aggregations should be implemented as PostgreSQL RPC functions
- Consider materialized views for frequently accessed aggregations

### Authentication & Authorization
- All endpoints require valid Supabase authentication
- Implement proper RLS (Row Level Security) policies
- Validate user access to requested products and devices

### Caching Strategy
- Consider caching aggregated results for frequently requested date ranges
- Implement cache invalidation when new sensor data is added

### Development Guidelines for AI Agent
- **RPC Functions**: Create PostgreSQL functions in `supabase/migrations/` for complex aggregations
- **Service Layer**: Add business logic to `app/services.py`
- **Route Layer**: Add endpoints to `app/routes.py`
- **Error Handling**: Use consistent error response format across all endpoints
- **Validation**: Validate all input parameters before database queries
- **Testing**: Test each endpoint with various parameter combinations
- **Documentation**: Update this spec as implementation progresses

## Future Enhancements
- Real-time data updates via WebSockets
- Additional aggregation types (weekly, monthly)
- Export functionality for aggregated data
- Historical data comparison features 