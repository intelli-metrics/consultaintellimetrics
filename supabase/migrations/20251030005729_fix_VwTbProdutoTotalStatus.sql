CREATE OR REPLACE VIEW public."VwTbProdutoTotalStatus" AS
SELECT
  "VwTbProdutoTipo"."cdProduto",
  "VwTbProdutoTipo"."dsNome",
  "VwTbProdutoTipo"."dsDescricao",
  "VwTbProdutoTipo"."nrCodigo",
  "VwTbProdutoTipo"."nrLarg",
  "VwTbProdutoTipo"."nrComp",
  "VwTbProdutoTipo"."nrAlt",
  "VwTbProdutoTipo"."StatusDispositivo",
  COUNT("VwTbProdutoTipo"."StatusDispositivo") AS "nrQtde",
  c."nrQtde" AS "QtdeTotal",
  "VwTbProdutoTipo"."cdCliente"
FROM
  "VwTbProdutoTipo"
  LEFT JOIN "VwTbProdutoTotal" c ON "VwTbProdutoTipo"."cdProduto" = c."cdProduto"
GROUP BY
  c."nrQtde",
  "VwTbProdutoTipo"."StatusDispositivo",
  "VwTbProdutoTipo"."cdProduto",
  "VwTbProdutoTipo"."dsNome",
  "VwTbProdutoTipo"."dsDescricao",
  "VwTbProdutoTipo"."nrCodigo",
  "VwTbProdutoTipo"."nrLarg",
  "VwTbProdutoTipo"."nrComp",
  "VwTbProdutoTipo"."nrAlt",
  "VwTbProdutoTipo"."cdCliente";