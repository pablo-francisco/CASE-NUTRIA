# Dados: `nutria.db`

Banco SQLite com 22 tabelas, de jan/2024 a set/2026. Esquema completo em [`sql/01_schema.sql`](../sql/01_schema.sql).

O arquivo é **versionado de propósito** (~20 MB), para que os números dos notebooks sejam reproduzidos exatamente sem rodar a simulação. Para recriá-lo:

```bash
python -m nutria gerar          # mesma semente => mesmo banco
```

> Ele foi gerado com numpy 2.5 e pandas 3.0. Versões muito diferentes do numpy podem produzir sequências aleatórias diferentes e, portanto, números ligeiramente diferentes dos citados nos notebooks.

Abre em qualquer cliente SQLite (DBeaver, DB Browser for SQLite, extensão SQLite do VS Code). As views analíticas de [`sql/02_views.sql`](../sql/02_views.sql) já vêm gravadas no banco.

## Dicionário de dados

### Comercial / CRM

| Tabela | Grão | Colunas principais |
|---|---|---|
| `clientes` | cliente | `segmento` (Corporativo, Hospitalar, Industrial, Educacional), `data_cadastro` |
| `contratos` | termo de contrato | `data_inicio`, `data_fim`, `modelo_cobranca` (`por_refeicao` ou `minimo_garantido`), `volume_minimo_dia`, `preco_refeicao_base`, `reajuste_anual_pct` (aplicado em janeiro), `data_decisao_renovacao` (90 dias antes do fim), `status` (`vigente`, `renovado`, `nao_renovado`), `motivo_nao_renovacao` (o motivo **declarado**) |
| `unidades` | restaurante/cozinha dentro do cliente | `cliente_id`, `cidade_id`, `capacidade_refeicoes_dia`, `dias_operacao`, `data_encerramento` |
| `crm_interacoes` | anotação do gerente de contas | `data`, `tipo` (visita, reunião, reclamação, comercial), `descricao` (**texto livre**) |

### Operação e cardápio

| Tabela | Grão | Colunas principais |
|---|---|---|
| `producao_diaria` | unidade × dia | `refeicoes_planejadas` (= produzidas), `refeicoes_servidas`, `esgotou_opcao` (0/1), `sobra_limpa_kg` (produzido e não servido), `resto_ingesta_kg` (deixado no prato) |
| `cardapio_dia` | unidade × dia × opção (1 ou 2) | `prato_id` |
| `pesquisa_satisfacao` | resposta | `nota` (0–10), `categoria` (tema do comentário: sabor, tempo de fila, variedade...) |
| `pratos` | prato | `complexidade` (simples ou elaborado) |
| `insumos` | insumo | `categoria` (proteína, grãos, hortifrúti...) |
| `ficha_tecnica` | prato × insumo | `qtd_por_porcao` (kg) |

### Pessoas, suprimentos e financeiro

| Tabela | Grão | Colunas principais |
|---|---|---|
| `cargos` | cargo | `salario_base` (jan/2024) |
| `funcionarios` | vínculo de trabalho | `unidade_id`, `cargo_id`, `data_admissao`, `data_desligamento`, `motivo_desligamento` (`pedido_demissao`, `dispensa_sem_justa_causa`, `encerramento_contrato`) |
| `folha_mensal` | unidade × mês | `headcount_medio`, `custo_total` (salários + encargos) |
| `fornecedores` | fornecedor | `tipo` (distribuidor ou varejo local), `regiao_id` |
| `pedidos_compra` | pedido | `tipo_pedido` (`programado` ou `emergencial`), datas de pedido, entrega prevista e real |
| `itens_pedido` | item do pedido | `insumo_id`, `quantidade`, `preco_unitario` |
| `faturas` | contrato × mês | `refeicoes_faturadas`, `preco_unitario`, `valor_total` |

### Dados externos

| Tabela | Grão | Colunas principais |
|---|---|---|
| `acessos_predio` | unidade corporativa × dia | `pessoas_no_predio` (catraca do cliente) |
| `clima_diario` | cidade × dia | `chuva_mm`, `temp_max_c` |
| `feriados` | data | `nome` |
| `regioes`, `cidades` | | geografia |

## Views analíticas (`sql/02_views.sql`)

| View | O que entrega |
|---|---|
| `vw_unidade` | unidade com cliente, segmento, cidade e região |
| `vw_operacao_mes` | produção mensal por unidade |
| `vw_receita_unidade_mes` | fatura do contrato rateada entre as unidades do cliente pela proporção de refeições servidas |
| `vw_insumos_unidade_mes` | custo de compras por unidade e mês (programado e emergencial) |
| `vw_dre_unidade_mes` | DRE simplificada: receita − insumos − folha = margem de contribuição |
