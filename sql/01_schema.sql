-- =====================================================================
-- NUTRIA Refeições Coletivas (empresa fictícia) — modelo de dados
-- Banco relacional de um operador de refeições coletivas / facilities
-- (restaurantes corporativos, hospitais, indústrias e escolas).
-- Dialeto: SQLite 3 (compatível com PostgreSQL com ajustes mínimos de tipos)
-- =====================================================================
PRAGMA foreign_keys = ON;

-- ---------- Dimensões geográficas ----------
CREATE TABLE regioes (
    regiao_id      INTEGER PRIMARY KEY,
    nome           TEXT NOT NULL UNIQUE
);

CREATE TABLE cidades (
    cidade_id      INTEGER PRIMARY KEY,
    nome           TEXT NOT NULL,
    uf             TEXT NOT NULL,
    regiao_id      INTEGER NOT NULL REFERENCES regioes(regiao_id)
);

-- ---------- Clientes, contratos e unidades (CRM / comercial) ----------
CREATE TABLE clientes (
    cliente_id     INTEGER PRIMARY KEY,
    razao_social   TEXT NOT NULL,
    segmento       TEXT NOT NULL CHECK (segmento IN ('Corporativo','Hospitalar','Industrial','Educacional')),
    data_cadastro  TEXT NOT NULL
);

CREATE TABLE contratos (
    contrato_id           INTEGER PRIMARY KEY,
    cliente_id            INTEGER NOT NULL REFERENCES clientes(cliente_id),
    data_inicio           TEXT NOT NULL,
    data_fim              TEXT NOT NULL,
    modelo_cobranca       TEXT NOT NULL CHECK (modelo_cobranca IN ('por_refeicao','minimo_garantido')),
    volume_minimo_dia     INTEGER,               -- só p/ minimo_garantido
    preco_refeicao_base   REAL NOT NULL,         -- R$ por refeição no início do contrato
    reajuste_anual_pct    REAL NOT NULL,         -- aplicado todo janeiro
    data_decisao_renovacao TEXT,                 -- data em que o cliente decidiu renovar ou não
    status                TEXT NOT NULL CHECK (status IN ('vigente','renovado','nao_renovado')),
    motivo_nao_renovacao  TEXT                   -- motivo DECLARADO pelo cliente
);

CREATE TABLE unidades (
    unidade_id               INTEGER PRIMARY KEY,
    cliente_id               INTEGER NOT NULL REFERENCES clientes(cliente_id),
    nome                     TEXT NOT NULL,
    cidade_id                INTEGER NOT NULL REFERENCES cidades(cidade_id),
    capacidade_refeicoes_dia INTEGER NOT NULL,
    dias_operacao            TEXT NOT NULL,     -- 'seg-sex' | 'seg-sab' | 'todos'
    data_inauguracao         TEXT NOT NULL,
    data_encerramento        TEXT
);

CREATE TABLE crm_interacoes (
    interacao_id   INTEGER PRIMARY KEY,
    cliente_id     INTEGER NOT NULL REFERENCES clientes(cliente_id),
    data           TEXT NOT NULL,
    tipo           TEXT NOT NULL,     -- visita, reuniao, reclamacao, elogio, comercial
    descricao      TEXT NOT NULL      -- texto livre digitado pelo gerente de contas
);

-- ---------- Pessoas (RH / folha) ----------
CREATE TABLE cargos (
    cargo_id       INTEGER PRIMARY KEY,
    nome           TEXT NOT NULL UNIQUE,
    salario_base   REAL NOT NULL        -- R$/mês em jan/2024
);

CREATE TABLE funcionarios (
    funcionario_id      INTEGER PRIMARY KEY,
    unidade_id          INTEGER NOT NULL REFERENCES unidades(unidade_id),
    cargo_id            INTEGER NOT NULL REFERENCES cargos(cargo_id),
    data_admissao       TEXT NOT NULL,
    data_desligamento   TEXT,
    motivo_desligamento TEXT CHECK (motivo_desligamento IN
        ('pedido_demissao','dispensa_sem_justa_causa','encerramento_contrato'))
);

CREATE TABLE folha_mensal (
    unidade_id       INTEGER NOT NULL REFERENCES unidades(unidade_id),
    competencia      TEXT NOT NULL,     -- primeiro dia do mês
    headcount_medio  REAL NOT NULL,
    custo_total      REAL NOT NULL,     -- salários + encargos
    PRIMARY KEY (unidade_id, competencia)
);

-- ---------- Cardápio / engenharia de menu ----------
CREATE TABLE insumos (
    insumo_id       INTEGER PRIMARY KEY,
    nome            TEXT NOT NULL,
    categoria       TEXT NOT NULL CHECK (categoria IN ('proteina','graos','hortifruti','laticinios','mercearia')),
    unidade_medida  TEXT NOT NULL
);

CREATE TABLE pratos (
    prato_id        INTEGER PRIMARY KEY,
    nome            TEXT NOT NULL,
    complexidade    TEXT NOT NULL CHECK (complexidade IN ('simples','elaborado'))
);

CREATE TABLE ficha_tecnica (
    prato_id        INTEGER NOT NULL REFERENCES pratos(prato_id),
    insumo_id       INTEGER NOT NULL REFERENCES insumos(insumo_id),
    qtd_por_porcao  REAL NOT NULL,      -- em kg (ou un. de medida do insumo)
    PRIMARY KEY (prato_id, insumo_id)
);

CREATE TABLE cardapio_dia (
    unidade_id      INTEGER NOT NULL REFERENCES unidades(unidade_id),
    data            TEXT NOT NULL,
    opcao           INTEGER NOT NULL CHECK (opcao IN (1,2)),
    prato_id        INTEGER NOT NULL REFERENCES pratos(prato_id),
    PRIMARY KEY (unidade_id, data, opcao)
);

-- ---------- Operação diária ----------
CREATE TABLE producao_diaria (
    unidade_id            INTEGER NOT NULL REFERENCES unidades(unidade_id),
    data                  TEXT NOT NULL,
    refeicoes_planejadas  INTEGER NOT NULL,   -- = produzidas (saída do sistema de planejamento)
    refeicoes_servidas    INTEGER NOT NULL,
    esgotou_opcao         INTEGER NOT NULL CHECK (esgotou_opcao IN (0,1)),
    sobra_limpa_kg        REAL NOT NULL,      -- comida produzida e não servida
    resto_ingesta_kg      REAL NOT NULL,      -- comida deixada no prato
    PRIMARY KEY (unidade_id, data)
);

-- Catraca do prédio do cliente (dado compartilhado pelos clientes corporativos)
CREATE TABLE acessos_predio (
    unidade_id        INTEGER NOT NULL REFERENCES unidades(unidade_id),
    data              TEXT NOT NULL,
    pessoas_no_predio INTEGER NOT NULL,
    PRIMARY KEY (unidade_id, data)
);

CREATE TABLE pesquisa_satisfacao (
    resposta_id     INTEGER PRIMARY KEY,
    unidade_id      INTEGER NOT NULL REFERENCES unidades(unidade_id),
    data            TEXT NOT NULL,
    nota            INTEGER NOT NULL CHECK (nota BETWEEN 0 AND 10),
    categoria       TEXT NOT NULL       -- tema principal do comentário
);

-- ---------- Suprimentos ----------
CREATE TABLE fornecedores (
    fornecedor_id   INTEGER PRIMARY KEY,
    nome            TEXT NOT NULL,
    tipo            TEXT NOT NULL CHECK (tipo IN ('distribuidor','varejo_local')),
    regiao_id       INTEGER NOT NULL REFERENCES regioes(regiao_id)
);

CREATE TABLE pedidos_compra (
    pedido_id              INTEGER PRIMARY KEY,
    unidade_id             INTEGER NOT NULL REFERENCES unidades(unidade_id),
    fornecedor_id          INTEGER NOT NULL REFERENCES fornecedores(fornecedor_id),
    tipo_pedido            TEXT NOT NULL CHECK (tipo_pedido IN ('programado','emergencial')),
    data_pedido            TEXT NOT NULL,
    data_entrega_prevista  TEXT NOT NULL,
    data_entrega_real      TEXT NOT NULL
);

CREATE TABLE itens_pedido (
    item_id         INTEGER PRIMARY KEY,
    pedido_id       INTEGER NOT NULL REFERENCES pedidos_compra(pedido_id),
    insumo_id       INTEGER NOT NULL REFERENCES insumos(insumo_id),
    quantidade      REAL NOT NULL,
    preco_unitario  REAL NOT NULL
);

-- ---------- Financeiro ----------
CREATE TABLE faturas (
    fatura_id            INTEGER PRIMARY KEY,
    contrato_id          INTEGER NOT NULL REFERENCES contratos(contrato_id),
    competencia          TEXT NOT NULL,
    refeicoes_faturadas  INTEGER NOT NULL,
    preco_unitario       REAL NOT NULL,
    valor_total          REAL NOT NULL
);

-- ---------- Dados externos ----------
CREATE TABLE clima_diario (
    cidade_id   INTEGER NOT NULL REFERENCES cidades(cidade_id),
    data        TEXT NOT NULL,
    chuva_mm    REAL NOT NULL,
    temp_max_c  REAL NOT NULL,
    PRIMARY KEY (cidade_id, data)
);

CREATE TABLE feriados (
    data   TEXT PRIMARY KEY,
    nome   TEXT NOT NULL
);

-- ---------- Índices ----------
CREATE INDEX ix_unid_cliente      ON unidades(cliente_id);
CREATE INDEX ix_contr_cliente     ON contratos(cliente_id);
CREATE INDEX ix_func_unidade      ON funcionarios(unidade_id);
CREATE INDEX ix_pesq_unid_data    ON pesquisa_satisfacao(unidade_id, data);
CREATE INDEX ix_ped_unid_data     ON pedidos_compra(unidade_id, data_entrega_prevista);
CREATE INDEX ix_ped_forn          ON pedidos_compra(fornecedor_id);
CREATE INDEX ix_item_pedido       ON itens_pedido(pedido_id);
CREATE INDEX ix_fat_contrato      ON faturas(contrato_id, competencia);
CREATE INDEX ix_crm_cliente       ON crm_interacoes(cliente_id, data);
