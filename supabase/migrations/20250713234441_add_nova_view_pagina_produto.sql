CREATE OR REPLACE VIEW "public"."VwProdutoCompleto" WITH ("security_invoker"='true') AS
SELECT 
    p."cdProduto",
    p."dsNome" AS "dsNomeProduto",
    p."cdStatus" AS "cdStatusProduto",
    p."dtRegistro" AS "dtRegistroProduto",
    p."cdCliente",
    
    -- Image information (first image for each product)
    img."dsCaminho" AS "dsCaminhoImagem",
    img."cdCodigo" AS "cdCodigoImagem",
    img."nrImagem" AS "nrImagem",
    
    -- Sensor types as comma-separated list (using subquery to avoid multiplication)
    (SELECT STRING_AGG(DISTINCT ts2."dsNome", ', ' ORDER BY ts2."dsNome")
     FROM "public"."TbDispositivo" d2
     LEFT JOIN "public"."TbSensor" s2 ON d2."cdDispositivo" = s2."cdDispositivo"
     LEFT JOIN "public"."TbTipoSensor" ts2 ON s2."cdTipoSensor" = ts2."id"
     WHERE d2."cdProduto" = p."cdProduto") AS "dsTiposSensores",
    
    -- Device counts by status
    COUNT(CASE WHEN d."cdStatus" = 'ativo' THEN 1 END) AS "nrDispositivosAtivos",
    COUNT(CASE WHEN d."cdStatus" = 'inativo' THEN 1 END) AS "nrDispositivosInativos", 
    COUNT(CASE WHEN d."cdStatus" = 'suspenso' THEN 1 END) AS "nrDispositivosSuspensos",
    COUNT(CASE WHEN d."cdStatus" = 'bloqueado' THEN 1 END) AS "nrDispositivosBloqueados",
    COUNT(CASE WHEN d."cdStatus" = 'encerrado' THEN 1 END) AS "nrDispositivosEncerrados",
    COUNT(CASE WHEN d."cdStatus" = 'estoque' THEN 1 END) AS "nrDispositivosEstoque",
    COUNT(CASE WHEN d."cdStatus" IS NULL THEN 1 END) AS "nrDispositivosSemStatus",
    
    -- Total device count
    COUNT(d."cdDispositivo") AS "nrTotalDispositivos"
    
FROM "public"."TbProduto" p
LEFT JOIN "public"."TbImagens" img ON p."cdProduto" = img."cdProduto" 
    AND img."nrImagem" = (
        SELECT MIN(img2."nrImagem") 
        FROM "public"."TbImagens" img2 
        WHERE img2."cdProduto" = p."cdProduto"
    )
JOIN "public"."TbDispositivo" d ON p."cdProduto" = d."cdProduto"

GROUP BY 
    p."cdProduto",
    p."dsNome",
    p."cdStatus",
    p."dtRegistro",
    p."cdCliente",
    img."dsCaminho",
    img."cdCodigo", 
    img."nrImagem"

ORDER BY p."dsNome";