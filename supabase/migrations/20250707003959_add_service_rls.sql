ALTER POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbDestinatario" TO "authenticated" USING (
  (
    (
      (
        SELECT profiles.role
        FROM profiles
        WHERE (profiles.id = auth.uid())
      ) = 'service'::role
    )
    OR (
      "cdCliente" = ANY (
        ARRAY(
          SELECT get_clientes_user(auth.uid()) AS get_clientes_user
        )
      )
    )
  )
);
ALTER POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbDispositivo" TO "authenticated" USING (
  (
    (
      (
        SELECT profiles.role
        FROM profiles
        WHERE (profiles.id = auth.uid())
      ) = 'service'::role
    )
    OR (
      "cdCliente" = ANY (
        ARRAY(
          SELECT get_clientes_user(auth.uid()) AS get_clientes_user
        )
      )
    )
  )
);
ALTER POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbPosicao" TO "authenticated" USING (
  (
    (
      (
        SELECT profiles.role
        FROM profiles
        WHERE (profiles.id = auth.uid())
      ) = 'service'::role
    )
    OR (
      "cdDispositivo" = ANY (
        ARRAY(
          SELECT get_clientes_user_by_dispositivo(auth.uid()) AS get_clientes_user_by_dispositivo
        )
      )
    )
  )
);
ALTER POLICY "Somente usuarios com acesso ao cliente" ON "public"."TbProduto" TO "authenticated" USING (
  (
    (
      (
        SELECT profiles.role
        FROM profiles
        WHERE (profiles.id = auth.uid())
      ) = 'service'::role
    )
    OR (
      "cdCliente" = ANY (
        ARRAY(
          SELECT get_clientes_user(auth.uid()) AS get_clientes_user
        )
      )
    )
  )
);