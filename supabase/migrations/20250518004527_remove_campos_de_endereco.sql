alter table "public"."TbPosicao" drop column "dsBairro";
alter table "public"."TbPosicao" drop column "dsCep";
alter table "public"."TbPosicao" drop column "dsCidade";
alter table "public"."TbPosicao" drop column "dsEndereco";
alter table "public"."TbPosicao" drop column "dsLat";
alter table "public"."TbPosicao" drop column "dsLong";
alter table "public"."TbPosicao" drop column "dsNum";
alter table "public"."TbPosicao" drop column "dsPais";
alter table "public"."TbPosicao" drop column "dsUF";

alter table "public"."TbDestinatario" add constraint "TbDestinatario_cdEndereco_fkey" FOREIGN KEY ("cdEndereco") REFERENCES "TbEndereco"("cdEndereco");

alter table "public"."TbDestinatario" drop column "dsLogradouro";
alter table "public"."TbDestinatario" drop column "nrNumero";
alter table "public"."TbDestinatario" drop column "dsComplemente";
alter table "public"."TbDestinatario" drop column "dsBairro";
alter table "public"."TbDestinatario" drop column "dsCep";
alter table "public"."TbDestinatario" drop column "dsCidade";
alter table "public"."TbDestinatario" drop column "dsUF";
alter table "public"."TbDestinatario" drop column "dsLat";
alter table "public"."TbDestinatario" drop column "dsLong";
