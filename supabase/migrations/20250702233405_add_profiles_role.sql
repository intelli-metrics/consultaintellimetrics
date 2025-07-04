create type "public"."role" as enum ('default', 'admin', 'service');

alter table "public"."profiles" add column "role" role default 'default'::role;


