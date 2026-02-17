# Database & Backend Refactor Plan

## Current State Assessment

### Scale Target
- Thousands of devices sending data every ~15 minutes
- At 1,000 devices: **96,000 position records/day**, **96,000+ sensor readings/day**
- At 5,000 devices: **480,000 position records/day**, **480,000+ sensor readings/day**
- After 1 year at 1,000 devices: **~35M rows** in TbPosicao, **~35M+ rows** in TbSensorRegistro

### Critical Problems Found

The system has a well-designed entity model (Client > Destinatario > Dispositivo > Sensor) but the **time-series data layer** (TbPosicao and TbSensorRegistro) has no scalability strategy. The main issues are:

1. **Zero indexes on the two highest-volume tables** (TbPosicao and TbSensorRegistro)
2. **No table partitioning** for time-series data that grows unboundedly
3. **Heavy views with correlated subqueries** (VwRelHistoricoDispositivoProduto does 4 subqueries per row)
4. **RLS policies call functions on every row** (e.g., `get_clientes_user_by_dispositivo()` is re-evaluated per row)
5. **Client-side aggregation** - Python/pandas processes up to 100k rows that should be aggregated in PostgreSQL
6. **N+1 query patterns** - aggregation functions make 8+ sequential DB calls
7. **Lat/Long stored as VARCHAR** instead of numeric types, preventing spatial operations

---

## Phase 1: Critical Indexes (Immediate, Zero Downtime)

This is the single highest-impact change. Currently, every query on TbPosicao and TbSensorRegistro does a **sequential scan** because there are no secondary indexes.

### Migration: Add indexes to TbPosicao

```sql
-- Most queries filter by device + order by date
CREATE INDEX CONCURRENTLY idx_tbposicao_dispositivo_dtregistro
    ON "TbPosicao" ("cdDispositivo", "dtRegistro" DESC);

-- The VwTbPosicaoAtual view does MAX(cdPosicao) GROUP BY cdDispositivo
-- This index makes "get latest position per device" an index-only scan
CREATE INDEX CONCURRENTLY idx_tbposicao_dispositivo_cdposicao
    ON "TbPosicao" ("cdDispositivo", "cdPosicao" DESC);

-- Queries filter by cdEndereco for address joins
CREATE INDEX CONCURRENTLY idx_tbposicao_cdendereco
    ON "TbPosicao" ("cdEndereco");

-- Date range scans (used by all historical queries)
CREATE INDEX CONCURRENTLY idx_tbposicao_dtregistro
    ON "TbPosicao" ("dtRegistro" DESC);
```

### Migration: Add indexes to TbSensorRegistro

```sql
-- Primary access pattern: get readings by sensor within date range
CREATE INDEX CONCURRENTLY idx_tbsensorregistro_sensor_dtregistro
    ON "TbSensorRegistro" ("cdSensor", "dtRegistro" DESC);

-- Join pattern: readings by position (used in get_historico_paginado)
CREATE INDEX CONCURRENTLY idx_tbsensorregistro_posicao_dispositivo
    ON "TbSensorRegistro" ("cdPosicao", "cdDispositivo");

-- Date range queries across all sensors
CREATE INDEX CONCURRENTLY idx_tbsensorregistro_dtregistro
    ON "TbSensorRegistro" ("dtRegistro" DESC);
```

### Migration: Add index to TbSensor

```sql
-- Aggregation queries filter by device + sensor type
CREATE INDEX CONCURRENTLY idx_tbsensor_dispositivo_tiposensor
    ON "TbSensor" ("cdDispositivo", "cdTipoSensor");
```

**Why:** `CREATE INDEX CONCURRENTLY` doesn't lock the table, so this is safe on production. These indexes alone should reduce query times by 10-100x on the most common access patterns.

---

## Phase 2: Replace Expensive Views

### 2a. Replace VwTbPosicaoAtual

**Current problem:** Uses a subquery with `GROUP BY cdDispositivo` + `MAX(cdPosicao)` across the entire TbPosicao table. As the table grows, this becomes a full table scan every time.

**Proposed solution:** Create a materialized approach using a `TbPosicaoAtual` table that stores only the latest position per device, updated on insert via trigger.

```sql
-- New table: stores only the latest position per device
CREATE TABLE "TbPosicaoAtual" (
    "cdDispositivo" integer PRIMARY KEY
        REFERENCES "TbDispositivo"("cdDispositivo"),
    "cdPosicao" integer NOT NULL
        REFERENCES "TbPosicao"("cdPosicao"),
    "nrBat" double precision,
    "blArea" boolean,
    "nrDistancia" real,
    "dtRegistro" timestamp,
    "cdDestinatario" integer,
    "cdEndereco" integer
);

-- Trigger: automatically update on new position insert
CREATE OR REPLACE FUNCTION fn_update_posicao_atual()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO "TbPosicaoAtual" (
        "cdDispositivo", "cdPosicao", "nrBat", "blArea",
        "nrDistancia", "dtRegistro", "cdDestinatario", "cdEndereco"
    ) VALUES (
        NEW."cdDispositivo", NEW."cdPosicao", NEW."nrBat", NEW."blArea",
        NEW."nrDistancia", NEW."dtRegistro", NEW."cdDestinatario", NEW."cdEndereco"
    )
    ON CONFLICT ("cdDispositivo") DO UPDATE SET
        "cdPosicao" = EXCLUDED."cdPosicao",
        "nrBat" = EXCLUDED."nrBat",
        "blArea" = EXCLUDED."blArea",
        "nrDistancia" = EXCLUDED."nrDistancia",
        "dtRegistro" = EXCLUDED."dtRegistro",
        "cdDestinatario" = EXCLUDED."cdDestinatario",
        "cdEndereco" = EXCLUDED."cdEndereco";
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_posicao_atual
    AFTER INSERT ON "TbPosicao"
    FOR EACH ROW EXECUTE FUNCTION fn_update_posicao_atual();

-- Rewrite the view to use the new table (backwards-compatible)
CREATE OR REPLACE VIEW "VwTbPosicaoAtual" WITH (security_invoker='true') AS
SELECT
    pa."cdPosicao",
    pa."dtRegistro",
    pa."cdDispositivo",
    e."dsLogradouro", e."nrNumero", e."dsComplemento",
    e."dsBairro", e."dsCep", e."dsCidade", e."dsUF",
    e."dsLat", e."dsLong",
    pa."nrBat",
    pa."blArea",
    d."cdStatus",
    d."cdProduto",
    pd."dsNome" AS "dsNomeProduto",
    pd."nrCodigo"
FROM "TbPosicaoAtual" pa
JOIN "TbDispositivo" d ON d."cdDispositivo" = pa."cdDispositivo"
JOIN "TbEndereco" e ON e."cdEndereco" = pa."cdEndereco"
LEFT JOIN "TbProduto" pd ON pd."cdProduto" = d."cdProduto";

-- Backfill existing data
INSERT INTO "TbPosicaoAtual"
SELECT DISTINCT ON ("cdDispositivo")
    "cdDispositivo", "cdPosicao", "nrBat", "blArea",
    "nrDistancia", "dtRegistro", "cdDestinatario", "cdEndereco"
FROM "TbPosicao"
ORDER BY "cdDispositivo", "cdPosicao" DESC;
```

**Impact:** "Get current position" goes from O(n) full table scan to O(1) primary key lookup. At 35M rows, this is the difference between seconds and milliseconds.

### 2b. Replace VwRelHistoricoDispositivoProduto

**Current problem:** This view has **4 correlated subqueries** that each scan TbSensorRegistro per row. At scale, this is n * 4 scans.

**Proposed solution:** Already partially addressed by `get_historico_paginado` (the latest migration). The plan is to:
1. Deprecate the view entirely
2. Migrate all remaining usages to the `get_historico_paginado` RPC function
3. Eventually drop the view

Affected code in `services.py`:
- `Selecionar_VwRelHistoricoDispositivoProduto()` (line 381) - used by `Selecionar_HistoricoPaginaDispositivo()`
- `get_camera_categorias_aggregation()` (line 1500) - queries this view with 100k limit

### 2c. Replace VwProdutosFora

**Current problem:** Uses a subquery `SELECT MAX(dtRegistro) FROM TbPosicao GROUP BY cdDispositivo` which is a full table scan.

**Proposed solution:** Rewrite using `TbPosicaoAtual`:
```sql
CREATE OR REPLACE VIEW "VwProdutosFora" AS
SELECT pd."cdProduto", COUNT(pa."cdDispositivo") AS dispositivo_count
FROM "TbPosicaoAtual" pa
JOIN "TbDispositivo" d ON d."cdDispositivo" = pa."cdDispositivo"
JOIN "TbProduto" pd ON pd."cdProduto" = d."cdProduto"
WHERE pa."blArea" = false
GROUP BY pd."cdProduto";
```

---

## Phase 3: Table Partitioning for Time-Series Data

At the projected scale, TbPosicao and TbSensorRegistro will have tens of millions of rows within months. Partitioning ensures queries only scan relevant data.

### 3a. Partition TbPosicao by month

```sql
-- Convert to partitioned table (requires data migration)
CREATE TABLE "TbPosicao_partitioned" (
    "cdPosicao" integer NOT NULL DEFAULT nextval('"TbPosicao_cdPosicao_seq"'),
    "nrBat" double precision,
    "nrSeq" integer,
    "cdDispositivo" integer REFERENCES "TbDispositivo"("cdDispositivo"),
    "blArea" boolean,
    "nrDistancia" real,
    "dtRegistro" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "cdDestinatario" integer,
    "cdEndereco" integer,
    PRIMARY KEY ("cdPosicao", "dtRegistro")
) PARTITION BY RANGE ("dtRegistro");

-- Create partitions per month (automate with pg_partman or cron)
CREATE TABLE "TbPosicao_2025_01" PARTITION OF "TbPosicao_partitioned"
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
-- ... etc
```

**Trade-off:** Partitioning changes the primary key to include the partition column (`dtRegistro`). This means foreign keys from TbSensorRegistro need adjustment. This is the most complex migration and should be done with careful planning.

**Alternative (simpler):** If Supabase's managed Postgres doesn't support `pg_partman`, implement **archive partitioning** instead - periodically move old data (>3 months) to an archive table and keep the main table small:

```sql
-- Archive table (same schema, no FK constraints for performance)
CREATE TABLE "TbPosicao_archive" (LIKE "TbPosicao" INCLUDING ALL);

-- Monthly cron job to archive old data
INSERT INTO "TbPosicao_archive"
SELECT * FROM "TbPosicao" WHERE "dtRegistro" < NOW() - INTERVAL '3 months';

DELETE FROM "TbPosicao" WHERE "dtRegistro" < NOW() - INTERVAL '3 months';
```

### 3b. Partition or archive TbSensorRegistro

Same approach as TbPosicao. The sensor readings table will grow the fastest and most of it is only needed for historical analysis, not real-time queries.

---

## Phase 4: Move Aggregation Logic to Database

### 4a. New RPC: Temperature aggregation

Currently `get_temperatura_aggregation()` in services.py makes 3 sequential queries then aggregates in Python. Replace with a single RPC:

```sql
CREATE OR REPLACE FUNCTION get_temperatura_aggregation(
    p_cd_produto INTEGER,
    p_dt_inicio TIMESTAMP,
    p_dt_fim TIMESTAMP,
    p_cd_dispositivos INTEGER[] DEFAULT NULL,
    p_cd_cliente INTEGER DEFAULT NULL,
    p_aggregation_type TEXT DEFAULT 'hourly'  -- 'hourly' | 'day_of_week'
) RETURNS JSON
LANGUAGE plpgsql SECURITY INVOKER AS $$
-- Aggregate temperature readings by hour or day-of-week
-- Returns JSON array with labels and datasets per device
-- Replaces 3 Python queries + pandas processing
$$;
```

### 4b. New RPC: Camera categories aggregation

Currently `get_camera_categorias_aggregation()` loads 100k rows from VwRelHistoricoDispositivoProduto then aggregates in Python. Replace with RPC:

```sql
CREATE OR REPLACE FUNCTION get_camera_categorias_aggregation(
    p_cd_produto INTEGER,
    p_dt_inicio TIMESTAMP,
    p_dt_fim TIMESTAMP,
    p_cd_dispositivos INTEGER[] DEFAULT NULL,
    p_cd_cliente INTEGER DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql SECURITY INVOKER AS $$
-- Aggregate camera category sensors (types 9-17) by device
-- Returns JSON with gender, age, emotion breakdowns
-- Replaces: 3 queries + 100k row Python processing
$$;
```

### 4c. Replace Python aggregation in aggregate_all_sensors()

The `aggregate_all_sensors()` function in `aggregations.py` makes 8 sequential queries. Replace with a single RPC that returns all aggregations in one call:

```sql
CREATE OR REPLACE FUNCTION get_device_aggregations(
    p_dispositivos INTEGER[],
    p_dt_inicio TIMESTAMP,
    p_dt_fim TIMESTAMP
) RETURNS JSON
LANGUAGE plpgsql SECURITY INVOKER AS $$
-- Single query that returns all sensor aggregations per device:
-- - Door openings (SUM)
-- - Temperature (AVG)
-- - People count (SUM)
-- - Item count (calculated from weight/distance + product specs)
-- - All camera categories (SUM)
-- Replaces: 8 Python queries + in-memory aggregation
$$;
```

**Impact:** Reduces 8 network round-trips to 1. At 50ms latency per query, that's 350ms saved per API call. At scale with concurrent users, this reduces database connection pressure significantly.

---

## Phase 5: RLS Policy Optimization

### Problem

Every RLS policy calls `get_clientes_user_by_dispositivo()` or `get_clientes_user()` which executes a query against the `profiles` table for **every single row** being evaluated. At 1000 rows, that's 1000 sub-queries.

### Solution: Use session variables

```sql
-- Set client IDs once per request as a session variable
-- (done in the Flask middleware before making queries)
SET LOCAL app.current_client_ids = '{1,2,3}';

-- Then RLS policies use the cached variable instead of re-querying
CREATE POLICY "device_access" ON "TbDispositivo"
    TO authenticated
    USING (
        "cdCliente" = ANY(
            string_to_array(current_setting('app.current_client_ids', true), ',')::integer[]
        )
    );
```

**Backend change:** In `db_utils/__init__.py`, after authenticating the user, execute a `SET LOCAL` to store their client IDs for the duration of the request.

**Trade-off:** This requires the backend to be trusted to set the correct variable. Since RLS is already bypassed for `service` role users, this is an acceptable trust model. The alternative is to keep the function calls but add proper caching (e.g., `STABLE` + `statement_cache_mode`).

**Simpler alternative:** Mark `get_clientes_user()` and related functions as `STABLE` (already done) and ensure PostgreSQL's plan caching kicks in. Test with `EXPLAIN ANALYZE` to verify the function is only called once per statement rather than per row.

---

## Phase 6: Data Type Fixes

### 6a. Lat/Long as numeric types

Currently `dsLat` and `dsLong` are `character varying(45)`. This prevents:
- Proper distance calculations in SQL
- Use of PostGIS spatial indexes
- Numeric comparisons and range queries

```sql
ALTER TABLE "TbEndereco"
    ALTER COLUMN "dsLat" TYPE double precision USING "dsLat"::double precision,
    ALTER COLUMN "dsLong" TYPE double precision USING "dsLong"::double precision;

-- Update the index
DROP INDEX "TbEndereco_lat_long_idx";
CREATE INDEX idx_tbendereco_lat_long ON "TbEndereco" ("dsLat", "dsLong");
```

**Backend change:** Remove any string-to-float conversions in Python that currently compensate for this.

### 6b. Consider PostGIS extension

If geofencing (the `is_dentro_area` logic) is a core feature, enabling PostGIS allows:
- Native `ST_DWithin()` for radius checks instead of Python geopy calculations
- Spatial indexes for fast geographic lookups
- Database-level "devices outside area" queries

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

-- Add a geometry column to TbEndereco
ALTER TABLE "TbEndereco" ADD COLUMN geom geometry(Point, 4326);
UPDATE "TbEndereco" SET geom = ST_SetSRID(ST_MakePoint("dsLong"::float, "dsLat"::float), 4326);
CREATE INDEX idx_tbendereco_geom ON "TbEndereco" USING gist(geom);
```

**Note:** Supabase supports PostGIS natively.

---

## Phase 7: Data Ingestion Optimization

### Current problem
Each device sends data every 15 minutes. The current ingestion path is:
1. API receives position + sensor readings
2. `Inserir_TbPosicao()` - inserts one row
3. `Inserir_TbSensorRegistro()` - inserts one row per sensor
4. `is_dentro_area()` - makes a separate query to check geofence

At 1,000 devices, this is 96,000 insert operations/day with additional geofence checks.

### Solution: Batch insert RPC

```sql
CREATE OR REPLACE FUNCTION insert_device_reading(
    p_cd_dispositivo INTEGER,
    p_nr_bat DOUBLE PRECISION,
    p_nr_seq INTEGER,
    p_dt_registro TIMESTAMP,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_sensor_readings JSONB  -- [{cdSensor, nrValor, cdProdutoItem}, ...]
) RETURNS JSON
LANGUAGE plpgsql AS $$
DECLARE
    v_cd_posicao INTEGER;
    v_cd_endereco INTEGER;
    v_bl_area BOOLEAN;
    v_nr_distancia REAL;
BEGIN
    -- 1. Upsert address (find or create by lat/long)
    -- 2. Calculate geofence (is_dentro_area) in SQL
    -- 3. Insert TbPosicao
    -- 4. Insert all TbSensorRegistro rows in one batch
    -- 5. Update TbPosicaoAtual (or let trigger handle it)
    -- All in ONE database transaction, ONE network round-trip
    RETURN json_build_object('cdPosicao', v_cd_posicao, 'blArea', v_bl_area);
END;
$$;
```

**Impact:** Replaces 3-5 separate API calls per device reading with 1 RPC call. Reduces network latency and ensures atomicity.

---

## Phase 8: Backend Code Cleanup

After the database changes, the Python backend simplifies significantly:

### Remove/simplify in services.py:
- `Selecionar_HistoricoPaginaDispositivo()` (lines 424-632) - 200+ lines of pandas processing replaced by `get_historico_paginado` RPC
- `get_temperatura_aggregation()` (lines 1199-1406) - replaced by RPC
- `get_camera_categorias_aggregation()` (lines 1413-1624) - replaced by RPC
- `is_dentro_area()` / geofence Python logic - moved to database

### Remove/simplify in aggregations.py:
- `aggregate_all_sensors()` and sub-functions (entire file) - replaced by `get_device_aggregations` RPC

### Estimated code reduction: ~1,000 lines from services.py and ~450 lines from aggregations.py

---

## Implementation Priority & Ordering

| Phase | Risk | Impact | Dependency |
|-------|------|--------|------------|
| **Phase 1: Indexes** | None (CONCURRENTLY) | Very High | None |
| **Phase 2a: TbPosicaoAtual** | Low | Very High | None |
| **Phase 2b-c: View rewrites** | Low | High | Phase 2a |
| **Phase 4: Aggregation RPCs** | Medium | High | Phase 1 |
| **Phase 6a: Lat/Long types** | Medium | Medium | None |
| **Phase 8: Backend cleanup** | Medium | High | Phases 2, 4 |
| **Phase 5: RLS optimization** | Medium | Medium | None |
| **Phase 7: Batch ingestion** | Medium | High | Phase 2a |
| **Phase 3: Partitioning** | High | High | Phases 1, 2 |
| **Phase 6b: PostGIS** | Medium | Medium | Phase 6a |

**Recommended order:** Phase 1 -> 2a -> 2b/2c -> 4 -> 8 -> 7 -> 6a -> 5 -> 3 -> 6b

---

## What Does NOT Need to Change

- **Entity model** (TbCliente, TbDestinatario, TbDispositivo, TbProduto, TbSensor, TbTipoSensor) - well designed, proper normalization, correct relationships
- **Auth model** (profiles, TbApiKeys, JWT + API key dual auth) - solid, no changes needed
- **Inventario schema** - separate concern, not in the hot path
- **V2 route structure** - good pattern, should continue migrating v1 routes to v2
- **RLS concept** - correct approach, just needs performance optimization
- **Supabase as platform** - good choice, supports all proposed changes

---

## Projected Impact at 1,000 Devices

| Metric | Current | After Refactor |
|--------|---------|----------------|
| "Get current positions" query | ~2-5s (full table scan) | ~5-20ms (direct lookup) |
| "Device history page" query | ~3-10s (view + pandas) | ~50-200ms (RPC with pagination) |
| Aggregation API calls | 8 DB round-trips | 1 DB round-trip |
| Data ingestion per device | 3-5 API calls | 1 RPC call |
| TbPosicao query (by device+date) | Sequential scan | Index seek |
| TbSensorRegistro query (by sensor+date) | Sequential scan | Index seek |
| RLS overhead per query | N function calls per row | 1 variable lookup |
