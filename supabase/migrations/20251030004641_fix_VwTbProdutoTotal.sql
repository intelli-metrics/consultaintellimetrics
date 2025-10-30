CREATE OR REPLACE VIEW public."VwTbProdutoTotal" AS
SELECT
  "VwTbProdutoTipo"."dsNome",
  "VwTbProdutoTipo"."cdProduto",
  "VwTbProdutoTipo"."dsDescricao",
  "VwTbProdutoTipo"."nrCodigo",
  "VwTbProdutoTipo"."nrLarg",
  "VwTbProdutoTipo"."nrComp",
  "VwTbProdutoTipo"."nrAlt",
  COUNT("VwTbProdutoTipo"."cdProduto") AS "nrQtde",
  "VwTbProdutoTipo"."cdCliente"
FROM
  "VwTbProdutoTipo"
GROUP BY
  "VwTbProdutoTipo"."cdProduto",
  "VwTbProdutoTipo"."dsNome",
  "VwTbProdutoTipo"."dsDescricao",
  "VwTbProdutoTipo"."nrCodigo",
  "VwTbProdutoTipo"."nrLarg",
  "VwTbProdutoTipo"."nrComp",
  "VwTbProdutoTipo"."nrAlt",
  "VwTbProdutoTipo"."cdCliente";