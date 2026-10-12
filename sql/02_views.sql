-- =====================================================================
-- Camada analítica: views reutilizadas pelos três cases
-- =====================================================================
DROP VIEW IF EXISTS vw_unidade;
CREATE VIEW vw_unidade AS
SELECT u.unidade_id, u.nome, u.capacidade_refeicoes_dia, u.cliente_id, cl.razao_social,
       cl.segmento, ci.nome AS cidade, ci.uf, r.nome AS regiao, u.data_encerramento
FROM unidades u
JOIN clientes cl USING (cliente_id)
JOIN cidades  ci USING (cidade_id)
JOIN regioes  r  ON r.regiao_id = ci.regiao_id;

-- Operação mensal por unidade
DROP VIEW IF EXISTS vw_operacao_mes;
CREATE VIEW vw_operacao_mes AS
SELECT unidade_id,
       substr(data, 1, 7) || '-01'      AS competencia,
       COUNT(*)                         AS dias_operacao,
       SUM(refeicoes_planejadas)        AS planejadas,
       SUM(refeicoes_servidas)          AS servidas,
       SUM(esgotou_opcao)               AS dias_esgotou,
       SUM(sobra_limpa_kg)              AS sobra_kg,
       SUM(resto_ingesta_kg)            AS resto_kg
FROM producao_diaria
GROUP BY 1, 2;

-- Receita: a fatura é por contrato (cliente); rateio por unidade proporcional às refeições servidas
DROP VIEW IF EXISTS vw_receita_unidade_mes;
CREATE VIEW vw_receita_unidade_mes AS
WITH serv_cli AS (
    SELECT u.cliente_id, o.competencia, SUM(o.servidas) AS serv_cli
    FROM vw_operacao_mes o JOIN unidades u USING (unidade_id)
    GROUP BY 1, 2
)
SELECT o.unidade_id, o.competencia,
       f.valor_total * 1.0 * o.servidas / NULLIF(s.serv_cli, 0) AS receita
FROM vw_operacao_mes o
JOIN unidades  u ON u.unidade_id = o.unidade_id
JOIN serv_cli  s ON s.cliente_id = u.cliente_id AND s.competencia = o.competencia
JOIN contratos c ON c.cliente_id = u.cliente_id
JOIN faturas   f ON f.contrato_id = c.contrato_id AND f.competencia = o.competencia;

-- Custo de insumos por unidade/mês, separando compra programada x emergencial
DROP VIEW IF EXISTS vw_insumos_unidade_mes;
CREATE VIEW vw_insumos_unidade_mes AS
SELECT p.unidade_id,
       substr(p.data_entrega_prevista, 1, 7) || '-01'                                   AS competencia,
       SUM(i.quantidade * i.preco_unitario)                                              AS custo_insumos,
       SUM(CASE WHEN p.tipo_pedido = 'emergencial' THEN i.quantidade * i.preco_unitario END) AS custo_emergencial
FROM pedidos_compra p
JOIN itens_pedido i USING (pedido_id)
GROUP BY 1, 2;

-- DRE simplificada (margem de contribuição) por unidade/mês
DROP VIEW IF EXISTS vw_dre_unidade_mes;
CREATE VIEW vw_dre_unidade_mes AS
SELECT v.*, o.competencia, o.dias_operacao, o.planejadas, o.servidas, o.dias_esgotou, o.sobra_kg, o.resto_kg,
       r.receita,
       COALESCE(ins.custo_insumos, 0)     AS custo_insumos,
       COALESCE(ins.custo_emergencial, 0) AS custo_emergencial,
       COALESCE(fm.custo_total, 0)        AS custo_folha,
       fm.headcount_medio,
       r.receita - COALESCE(ins.custo_insumos, 0) - COALESCE(fm.custo_total, 0) AS margem_contribuicao
FROM vw_operacao_mes o
JOIN vw_unidade v USING (unidade_id)
JOIN vw_receita_unidade_mes r USING (unidade_id, competencia)
LEFT JOIN vw_insumos_unidade_mes ins USING (unidade_id, competencia)
LEFT JOIN folha_mensal fm USING (unidade_id, competencia);
