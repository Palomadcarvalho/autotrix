
CREATE TYPE status_agendamento AS ENUM (
    'pendente',
    'negociacao',
    'confirmado',
    'em_andamento',
    'concluido',
    'cancelado'
);

CREATE TABLE IF NOT EXISTS clientes (
    id         SERIAL PRIMARY KEY,
    nome       VARCHAR(150) NOT NULL,
    email      VARCHAR(255) NOT NULL UNIQUE,
    telefone   VARCHAR(20)  NOT NULL,
    criado_em  TIMESTAMPTZ  DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS veiculos (
    id         SERIAL PRIMARY KEY,
    cliente_id INTEGER      NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    marca      VARCHAR(80)  NOT NULL,
    modelo     VARCHAR(80)  NOT NULL,
    ano        SMALLINT     NOT NULL,
    placa      VARCHAR(10)  NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS servicos (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(150) NOT NULL,
    descricao   TEXT,
    duracao_min SMALLINT     NOT NULL,
    preco       NUMERIC(10,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS disponibilidades (
    id          SERIAL PRIMARY KEY,
    data        DATE         NOT NULL,
    hora_inicio TIME         NOT NULL,
    hora_fim    TIME         NOT NULL,
    vagas       SMALLINT     NOT NULL DEFAULT 1,
    criado_em   TIMESTAMPTZ  DEFAULT NOW(),
    CONSTRAINT vagas_positivas CHECK (vagas > 0),
    CONSTRAINT horario_valido  CHECK (hora_fim > hora_inicio)
);

CREATE TABLE IF NOT EXISTS agendamentos (
    id                    SERIAL PRIMARY KEY,
    cliente_id            INTEGER           NOT NULL REFERENCES clientes(id),
    veiculo_id            INTEGER           NOT NULL REFERENCES veiculos(id),
    servico_id            INTEGER           NOT NULL REFERENCES servicos(id),
    data_hora             TIMESTAMPTZ       NOT NULL,
    data_hora_sugerida    TIMESTAMPTZ,
    status                status_agendamento NOT NULL DEFAULT 'pendente',
    observacoes           TEXT,
    criado_em             TIMESTAMPTZ       DEFAULT NOW()
);

CREATE INDEX idx_agendamentos_status     ON agendamentos(status);
CREATE INDEX idx_agendamentos_cliente    ON agendamentos(cliente_id);
CREATE INDEX idx_agendamentos_data_hora  ON agendamentos(data_hora);
CREATE INDEX idx_disponibilidades_data   ON disponibilidades(data);

INSERT INTO servicos (nome, descricao, duracao_min, preco) VALUES
    ('Revisão 10.000 km',   'Troca de óleo, filtro de ar e óleo, verificação geral',   90,  350.00),
    ('Alinhamento e balanceamento', 'Alinhamento de direção e balanceamento dos 4 pneus', 60,  120.00),
    ('Troca de pastilhas de freio', 'Substituição das pastilhas dianteiras e traseiras',  45,  280.00),
    ('Diagnóstico eletrônico',      'Leitura de falhas via scanner automotivo',            30,   80.00),
    ('Troca de correia dentada',    'Substituição da correia e tensores',                 120,  520.00);
