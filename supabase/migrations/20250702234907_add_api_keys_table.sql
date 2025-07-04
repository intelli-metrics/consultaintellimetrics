CREATE TABLE "TbApiKeys" (
    "cdApiKey" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "cdUsuario" UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    "dsKey" TEXT NOT NULL UNIQUE,
    "dsNome" TEXT,
    -- Nome legível para a chave API
    "cdClientes" INTEGER [],
    -- Array de IDs de clientes permitidos, NULL significa todos os clientes
    "blAtiva" BOOLEAN NOT NULL DEFAULT true,
    "dtRegistro" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "dtExpiracao" TIMESTAMP WITH TIME ZONE,
    "dsPermissoes" TEXT [] DEFAULT ARRAY ['read']
    -- ex: ['read', 'write', 'delete']
);