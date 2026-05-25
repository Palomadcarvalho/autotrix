-- ============================================================
-- Autotrix — Migration Sprint 2
-- Tabela de log de eventos processados pelo MOM consumer
-- ============================================================

CREATE TABLE IF NOT EXISTS eventos_log (
    id              SERIAL PRIMARY KEY,
    evento          VARCHAR(100)  NOT NULL,   -- routing key do evento
    fila            VARCHAR(100)  NOT NULL,   -- fila de origem
    agendamento_id  INTEGER,                  -- referência opcional
    cliente_id      INTEGER,                  -- referência opcional
    payload         JSONB         NOT NULL,   -- conteúdo completo da mensagem
    processado_em   TIMESTAMPTZ   DEFAULT NOW()
);

-- Índices para consulta rápida por evento e agendamento
CREATE INDEX IF NOT EXISTS idx_eventos_log_evento        ON eventos_log(evento);
CREATE INDEX IF NOT EXISTS idx_eventos_log_agendamento   ON eventos_log(agendamento_id);
CREATE INDEX IF NOT EXISTS idx_eventos_log_processado_em ON eventos_log(processado_em DESC);

-- View útil para demonstração — mostra os últimos eventos processados
CREATE OR REPLACE VIEW v_eventos_recentes AS
SELECT
    el.id,
    el.evento,
    el.fila,
    el.agendamento_id,
    el.processado_em,
    el.payload -> 'dados' AS dados
FROM eventos_log el
ORDER BY el.processado_em DESC
LIMIT 50;