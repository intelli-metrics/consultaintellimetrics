-- The previous migration created a new function overload instead of replacing
-- the original, because the parameter list changed. Drop the old signature
-- so only the new one (with p_cd_dispositivos) remains.

DROP FUNCTION IF EXISTS get_historico_paginado(INTEGER, INTEGER, TIMESTAMP, TIMESTAMP, INTEGER, INTEGER);
