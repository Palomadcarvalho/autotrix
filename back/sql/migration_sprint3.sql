-- Migration Sprint 3 — autenticação de clientes
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS senha_hash VARCHAR(255);
CREATE INDEX IF NOT EXISTS idx_clientes_email ON clientes(email);