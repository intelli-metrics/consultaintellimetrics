alter table "public"."TbEndereco" enable row level security;

create policy "somente api pode fazer mudanças"
on "public"."TbEndereco"
as permissive
for all
to service_role
using (true);


create policy "todos podem ver"
on "public"."TbEndereco"
as permissive
for select
to anon
using (true);



