revoke delete on table "public"."TbLeituraCameraInventario" from "anon";

revoke insert on table "public"."TbLeituraCameraInventario" from "anon";

revoke references on table "public"."TbLeituraCameraInventario" from "anon";

revoke select on table "public"."TbLeituraCameraInventario" from "anon";

revoke trigger on table "public"."TbLeituraCameraInventario" from "anon";

revoke truncate on table "public"."TbLeituraCameraInventario" from "anon";

revoke update on table "public"."TbLeituraCameraInventario" from "anon";

revoke delete on table "public"."TbLeituraCameraInventario" from "authenticated";

revoke insert on table "public"."TbLeituraCameraInventario" from "authenticated";

revoke references on table "public"."TbLeituraCameraInventario" from "authenticated";

revoke select on table "public"."TbLeituraCameraInventario" from "authenticated";

revoke trigger on table "public"."TbLeituraCameraInventario" from "authenticated";

revoke truncate on table "public"."TbLeituraCameraInventario" from "authenticated";

revoke update on table "public"."TbLeituraCameraInventario" from "authenticated";

revoke delete on table "public"."TbLeituraCameraInventario" from "service_role";

revoke insert on table "public"."TbLeituraCameraInventario" from "service_role";

revoke references on table "public"."TbLeituraCameraInventario" from "service_role";

revoke select on table "public"."TbLeituraCameraInventario" from "service_role";

revoke trigger on table "public"."TbLeituraCameraInventario" from "service_role";

revoke truncate on table "public"."TbLeituraCameraInventario" from "service_role";

revoke update on table "public"."TbLeituraCameraInventario" from "service_role";

alter table "public"."TbLeituraCameraInventario" drop constraint "TbLeituraCameraInventario_pkey";

drop index if exists "public"."TbLeituraCameraInventario_pkey";

drop table "public"."TbLeituraCameraInventario";


