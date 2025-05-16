revoke delete on table "public"."TbUsuario" from "anon";

revoke insert on table "public"."TbUsuario" from "anon";

revoke references on table "public"."TbUsuario" from "anon";

revoke select on table "public"."TbUsuario" from "anon";

revoke trigger on table "public"."TbUsuario" from "anon";

revoke truncate on table "public"."TbUsuario" from "anon";

revoke update on table "public"."TbUsuario" from "anon";

revoke delete on table "public"."TbUsuario" from "authenticated";

revoke insert on table "public"."TbUsuario" from "authenticated";

revoke references on table "public"."TbUsuario" from "authenticated";

revoke select on table "public"."TbUsuario" from "authenticated";

revoke trigger on table "public"."TbUsuario" from "authenticated";

revoke truncate on table "public"."TbUsuario" from "authenticated";

revoke update on table "public"."TbUsuario" from "authenticated";

revoke delete on table "public"."TbUsuario" from "service_role";

revoke insert on table "public"."TbUsuario" from "service_role";

revoke references on table "public"."TbUsuario" from "service_role";

revoke select on table "public"."TbUsuario" from "service_role";

revoke trigger on table "public"."TbUsuario" from "service_role";

revoke truncate on table "public"."TbUsuario" from "service_role";

revoke update on table "public"."TbUsuario" from "service_role";

alter table "public"."TbUsuario" drop constraint "TbUsuario_pkey";

drop index if exists "public"."TbUsuario_pkey";

drop table "public"."TbUsuario";

drop sequence if exists "public"."TbUsuario_cdUsuario_seq";
