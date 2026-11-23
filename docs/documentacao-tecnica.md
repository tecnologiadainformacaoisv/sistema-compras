# Compras ISV · Documentação técnica

Sistema de solicitações de compras do **Instituto São Vicente (ISV)**: do pedido da unidade até a prestação de contas da nota fiscal.

- **Arquivo:** `Compras ISV - sistema (pagina).html` (página única: HTML + CSS + JavaScript, cerca de 3.200 linhas).
- **Versão:** publicada em 12/11/2026.
- **Ambiente atual:** hospedado como página (artifact) do **claude.ai**. Login, banco de dados, downloads e leitura de documentos com IA vêm do ambiente do claude.ai (seção 3).
- **Público:** equipe de desenvolvimento que vai manter ou migrar o sistema.

---

## 1. Visão geral

| Perfil | Quem é | O que vê |
|---|---|---|
| **Solicitante** | Diretores, coordenadores e supervisores das unidades; coordenação farmacêutica | Abas **Nova solicitação** e **Minhas solicitações** (só os próprios pedidos) |
| **Assistente de Suprimentos** | Equipe de compras (marcada na aba Equipe) | Também o **Painel de Suprimentos**: todos os pedidos, fornecedores, cotação, mapa, pedido de compra, recebimento |
| **Gestão** | Gerência de Suprimentos e Logística (marcada na aba Equipe) | O mesmo que o assistente, mais **homologação do mapa** e **relatório para a Controladoria** |
| **Dona da página** | Coordenação de Suprimentos (dona do artifact) | Tudo, mais a aba **Equipe de Suprimentos** e o cadastro de **tetos mensais** |

### Fluxo do pedido

```
Recebida → Em análise → (Devolvida para correção) → Aprovada → Em cotação → Comprada
        → Recebido com pendência de item  ou  Prestação de contas do pedido OK
        (Cancelada a qualquer momento)
```

| Chave interna | Rótulo na tela | Quem muda |
|---|---|---|
| `recebida` | Recebida | automático ao enviar |
| `analise` | Em análise | Suprimentos |
| `devolvida` | Devolvida para correção | Suprimentos (motivo obrigatório) |
| `aprovada` | Aprovada | Suprimentos |
| `cotacao` | Em cotação | automático ao registrar o envio ao fornecedor, ou Suprimentos |
| `comprada` | Comprada | Suprimentos (exige escolha salva no mapa se a categoria tem teto) |
| `pendencia` | Recebido com pendência de item | automático pela conferência |
| `entregue` | Prestação de contas do pedido OK | automático pela conferência + notas fiscais |
| `cancelada` | Cancelada | Suprimentos |

> As chaves `entregue` e `pendencia` foram mantidas para não migrar dados antigos; só os rótulos mudaram.

---

## 2. Módulos e regras de negócio

### 2.1 Nova solicitação (solicitante)
- **Identificação:** primeiro o **município** (Orós, Lavras da Mangabeira, ISV). Em Orós e Lavras, o nome sai de uma lista fixa (`SOLICITANTES`); no ISV é digitado. A unidade é filtrada pelo município (`UNIDADES_ISV`). No ISV os setores são RH, ADM, PDC/FIN/CONTR., MKT e TI (`SETORES_ISV`); nos demais, `SETORES`.
- **Tipo** (`TIPOS`) e prazo em **dias úteis** (`PRAZO_DU`): Emergencial 2; Mensal, Quinzenal e Semanal 5; Cotação para compra futura sem prazo. Contam só seg–sex, sem os feriados nacionais fixos (`FERIADOS`).
- **Categoria** (`CATS`). *Medicamento e MMH* só com o setor *Farmácia*.
- **Justificativa da necessidade = ofício em PDF, obrigatório em todas as solicitações** (até 5 MB). Não há campo de texto. O campo `justificativa` (texto) só existe em pedidos antigos e é exibido quando houver.
- **Planilha padrão obrigatória** (.xlsx/.xls/.csv, até 5 MB), lida com SheetJS. Colunas ITEM, PRODUTO, UNID, QUANT, MARCA/OBSERVAÇÃO. Rejeita quantidade zerada, negativa ou em texto e linhas em branco no meio da lista.
- **Protocolo:** `SC-AAAAMMDD-XXXX` (4 caracteres aleatórios).
- **Correção:** pedido devolvido pode ser reaberto no formulário e reenviado (`reenviadoEm`); o prazo recomeça.

### 2.2 Painel de Suprimentos
- **Contadores** clicáveis (filtros): Todas, Emergenciais abertas, Fora do prazo, Mapa aguardando homologação, Divergência no recebimento, e um por situação.
- **Saldo das contas:** um gráfico de pizza (CSS `conic-gradient`) por município, ISV sempre presente. Fatias = valor usado por categoria; cinza = saldo livre. Teto de município prevalece sobre o de unidade da mesma categoria (não soma os dois).
- **Visão Quadro (Kanban) ou Lista**, preferência em `localStorage` (`isv-painel-vista`). Arrastar o cartão muda a situação; Devolvida e Cancelada pedem o motivo.
- **Fornecedores cadastrados** e **Saldo dos tetos do mês**: blocos recolhíveis (`<details>`). O estado do saldo fica em `localStorage` (`isv-saldo-aberto`).
- **Relatório para a Controladoria** (só Gestão).
- **Avisos** de pedidos novos enquanto a página está aberta.

### 2.3 Fornecedores
- Cadastro com nome, **CNPJ** (dígitos verificadores + duplicidade), WhatsApp e/ou e-mail, contato e categorias atendidas.
- **Cadastro sumário** (Regulamento, Art. 21), campos em `CAD_CAMPOS`: nome fantasia, pagamento, endereço, bairro, CEP, cidade, UF, banco, agência, conta, PIX.
- **Preenchimento automático:**
  - **Buscar dados**: `GET https://brasilapi.com.br/api/cnpj/v1/{cnpj}`. Pode ser bloqueado no ambiente atual; nesse caso a página mostra o link da Receita.
  - **Cartão CNPJ (PDF)**: lido com pdf.js pela posição dos rótulos; se falhar (PDF escaneado), lê com o Claude (`sample`). O PDF é guardado no cadastro.
- **Certidões (CND)** em `CERTS`: Federal (180 dias), Trabalhista (180), FGTS (30), Estadual SEFAZ-CE (180), Municipal (60).
  - **Regra mensal:** a certidão precisa ser **emitida no mesmo mês** do cadastro ou da atualização; mês anterior é recusado, mesmo válida.
  - Municipal aceita só `MUNICIPIOS_CND`: Fortaleza, Orós, Lavras da Mangabeira, Maracanaú, Eusébio, Icó, Pindoretama.
  - Leitura do PDF extrai emissão, validade, situação e CNPJ, incluindo os formatos "EMITIDA VIA INTERNET EM dd/mm/aaaa" e "Fortaleza, dd de mês de aaaa".
  - Níveis (`certStatus`): 0 ok · 1 vence em até 7 dias · 2 atualizar (regra mensal) · 3 pendente ou CNPJ diferente · 4 vencida · 5 positiva.
  - **Bloqueio:** sem certidões em dia, o **pedido de compra** não é gerado.
- **Fornecedor impedido** (Art. 5º): motivo de `MOTIVOS_IMPED` + relatório (mín. 30 caracteres). Bloqueia envio de cotação, escolha no mapa e pedido de compra.
- **Carta de exclusividade** (Art. 15 e 16): PDF, válida por 6 meses a partir da emissão.

### 2.4 Cotação (envio ao fornecedor)
- No pedido: escolher o fornecedor → **baixar a planilha de cotação** (ExcelJS, padrão visual do ISV) → **abrir WhatsApp** (`wa.me`) ou **Gmail** (`mail.google.com/...view=cm`) com a mensagem pronta. O fornecedor devolve a planilha preenchida pelo mesmo canal.
- Registrar o envio muda a situação para **Em cotação**.
- **Cotações vigentes (60 dias, `VALIDADE_COTACAO_DIAS`):** preços de outros pedidos ainda válidos são sugeridos e podem ser reaproveitados (índice `data/suprimentos/precos`).

### 2.5 Mapa de cotação
- **Respostas** de fornecedor por três caminhos:
  - (A) nossa planilha preenchida, lida automaticamente e recusada se estiver incompleta;
  - (B) orçamento livre (PDF/imagem) lido com o Claude;
  - (C) digitação.
- **Proposta em papel timbrado** (PDF/imagem) **obrigatória em qualquer valor** (Art. 11, §2º).
- Exigidos: prazo de entrega, validade, pagamento e frete.
- **Escolha:** menor preço por item, tudo de um fornecedor, ou manual por item.
- **Empate:** desempate automático por menor prazo, depois frete CIF, depois quem respondeu primeiro. As condições aparecem no mapa.
- **Acima do menor preço:** critério obrigatório; opções prontas em `MOTIVOS_ACIMA`, ou texto livre.
- **Divisão de quantidade** de um item entre fornecedores.
- **Teto mensal:** ao salvar a escolha, o total sai do saldo do mês da categoria (município e/ou unidade). **Sem saldo, bloqueia**; só a dona libera exceção, com justificativa.
- **Homologação** pela Gerência de Suprimentos e Logística (Art. 8º, II). Não bloqueia o pedido de compra. Se a escolha muda depois de homologada, volta para pendente.
- Exporta o **mapa em Excel** (abas MAPA e COMPARATIVO).

### 2.6 Pedido de compra
- Um por fornecedor vencedor, numerado `{protocolo}-PC01`, `-PC02`…, **só em PDF** (jsPDF + autotable).
- Envio por WhatsApp ou Gmail, com registro de envio.
- Bloqueado se o fornecedor estiver impedido ou com certidões irregulares.

### 2.7 Recebimento e prestação de contas
- Suprimentos **libera a lista de recebimento**: itens agrupados por fornecedor, sem preços.
- A **unidade confere na página**, por fornecedor: data, quem recebeu, quantidade recebida, Conferido Sim/Não e observação.
- **Nota fiscal atestada (PDF) por fornecedor**, com o número da NF.
- **Situação automática** (`statusPorConferencia`):
  - todos os itens conferidos **e** NF de todos os fornecedores → **Prestação de contas do pedido OK** (mesmo com divergência de quantidade);
  - divergência e ainda falta NF → **Recebido com pendência de item**;
  - sem divergência e sem NF → continua em **Comprada**.
  - A conferência salva mesmo sem NF. Anexar a última NF reavalia a situação.
- **Itens faltantes → nova solicitação automática** (`gerarSolicitacaoFaltantes`):
  - faltante = pedido − recebido (quando recebido é menor); item "Não" sem quantidade = nada recebido;
  - cria um pedido no nome do mesmo solicitante, com `origem: {pid, protocolo, motivo}` e `automatica: true`;
  - a conferência guarda `complemento: {id, protocolo, em}` para não duplicar;
  - enquanto a nova estiver **Recebida**, ela é atualizada se a conferência mudar;
  - divergência que não é de quantidade (marca errada, avaria com quantidade completa) **não** gera.

### 2.8 Processo completo e Controladoria
- **Processo completo (PDF):** resumo (solicitação, mapa, critérios, homologação, pedidos de compra, regularidade, recebimento, histórico) + anexos juntados com pdf-lib (ofício, propostas timbradas, CNDs e cartão CNPJ dos vencedores, carta de exclusividade, NFs).
- **Relatório para a Controladoria (só Gestão):** por período e **um PDF por unidade**. Folha de rosto com protocolo `CTRL-AAAA-NNNN`, lista dos processos com nº da NF, valor e páginas, campos de assinatura, seguidos dos processos.

---

## 3. Dependências do ambiente claude.ai (o que precisa ser substituído numa migração)

A página roda dentro do claude.ai e obtém as capacidades por `window.claude.use(nome)`. Fora dele, `window.claude` não existe e a página mostra só a interface com um aviso.

| Capacidade | Uso na página | Substituto numa migração |
|---|---|---|
| `db` | Banco de documentos (estilo Firestore): `db.doc(path).get/set/delete`, `db.collection(path).get/onSnapshot/doc()/limit()` | Firestore, Supabase, PostgreSQL + API etc. |
| `user` | `id()`, `name()`, `canEdit()`, `can("data.write")`, `isOwner()` | Autenticação própria (SSO/e-mail) + papéis |
| `downloads` | `downloads.save({filename, data})` para Excel e PDF | Download comum pelo navegador (`Blob` + `<a download>`) |
| `sample` | Leitura de orçamentos, certidões e cartão CNPJ com o Claude (`sample.json`, imagens) | API da Anthropic no servidor, ou OCR |
| `assets` | Só anexos antigos (`/_blob/<id>`) | Armazenamento de arquivos (S3, Storage) |

### 3.1 Regras de acesso ao banco (configuradas na publicação)

Níveis: `view` < `interact` (contribuidor) < `admin` (editor) < `owner`. `{self}` = id do próprio usuário.

| Caminho | Leitura | Escrita |
|---|---|---|
| `pedidos` | admin | admin |
| `pedidos/{self}` | interact | interact |
| `status` | admin | admin |
| `status/{self}` | interact | admin |
| `data/suprimentos` | admin | admin |
| `config` | view | owner |
| `pessoas` | admin | admin |

**Papéis na prática:** o perfil "Suprimentos" na interface vem de `config/equipe` (listas `assistentes` e `gestores` com ids de usuário), não só do nível de acesso. Gestão = dona ou `gestores`.

### 3.2 Arquivos
Arquivos (planilha, ofício, NF, CND, proposta, cartão CNPJ, carta) são gravados como **base64 dividido em partes de 180.000 caracteres**, em documentos `.../partes/<n>`. O documento principal guarda `{nome, tipo, tamanho, partes, base}`. Numa migração, prefira um storage de arquivos e guarde só a URL.

---

## 4. Modelo de dados

```
pedidos/<uid>                                   marcador {atualizadoEm} (Suprimentos lista os uids por aqui)
pedidos/<uid>/lista/<pid>                       solicitação
pedidos/<uid>/arquivos/<tipo>-<pid>/partes/<n>  planilha / ofício (base64 em partes)
pedidos/<uid>/arquivos/nf-<pid>-<n>/partes/<i>  nota fiscal
pedidos/<uid>/conferencia/<pid>                 conferência do recebimento
pedidos/<uid>/notas/<pid>                       notas fiscais por fornecedor
status/<uid>/lista/<pid>                        situação visível ao solicitante
config/equipe                                   {assistentes:[uid], gestores:[uid]}
config/tetos                                    {itens:[{id, cat, nivel:"mun"|"uni", alvo, valor}]}
pessoas/<uid>                                   {primeiroAcesso, ultimoAcesso}
data/suprimentos/andamento/<pid>                cópia da situação para o painel
data/suprimentos/fornecedores/<fid>             fornecedor
data/suprimentos/certidoes/<fid>-<tipo>/partes/<n>  PDFs (CND, exclusividade, cartão CNPJ)
data/suprimentos/cotacoes/<pid>                 decisão do mapa
data/suprimentos/cotacoes/<pid>/respostas/<rid> resposta de fornecedor
data/suprimentos/cotacoes/<pid>/anexos/<rid>/partes/<n>  proposta timbrada
data/suprimentos/precos/<pid>__<rid>            índice de preços (cotações vigentes)
data/suprimentos/gastos/<pid>                   valor descontado do teto
data/suprimentos/homologacoes/<pid>             homologação do mapa
data/suprimentos/autorizacoes/<pid>             pedidos de compra emitidos
data/suprimentos/protocolos/<id>                protocolos enviados à Controladoria
```

### Principais documentos

**Solicitação** `pedidos/<uid>/lista/<pid>`
```js
{ protocolo, nome, unidade, municipio, setor, tipo, categoria,
  itens: [{aba, linha, descricao, unidade, quantidade, obs}], cabecalhos, totalItens, planilhaLida,
  planilha: {nome, tipo, tamanho, partes} | null, oficio: {...} | null, anexos: [],
  criadoEm, atualizadoEm, prazoEm, criadoPor, reenviadoEm?,
  justificativa?,                      // só pedidos antigos (texto)
  origem?: {pid, protocolo, motivo}, automatica?: true   // gerada por itens faltantes
}
```

**Situação** `status/<uid>/lista/<pid>` e `data/suprimentos/andamento/<pid>` (mesmo conteúdo)
```js
{ status, ultimaNota, em, uid, responsavel,
  historico: [{status, nota, em, por, porNome}],        // até 60
  envios: [{fornecedor, fid, canal, em, porNome}],      // envios para cotação
  recebimento?: {em, porNome, semFornecedor,
                 grupos: [{fornecedor, prazoEntrega, itens: [{n, descricao, unidade, quantidade, obs, marca}]}]} }
```

**Fornecedor** `data/suprimentos/fornecedores/<fid>`
```js
{ nome, cnpj, whatsapp, email, contato, categorias: [],
  cadastro: {fantasia, pagamento, endereco, bairro, cep, cidade, uf, banco, agencia, conta, pix},
  certidoes: { <tipo>: {emissao, validade, situacao, validadeEstimada, cnpjConfere, municipio?,
                        arquivo: {nome, tamanho, partes}, conferidoEm, porNome, origem} },
  impedimento: {motivo, relatorio, em, porNome} | null, impedimentosAnteriores: [],
  exclusividade: {emissao, objeto, arquivo, porNome, em} | null,
  cartaoCnpj: {nome, tamanho, partes, em, porNome} }
```

**Resposta de fornecedor** `data/suprimentos/cotacoes/<pid>/respostas/<rid>`
```js
{ fornecedor, fid, origem: "planilha"|"claude"|"manual"|"reaproveitada", arquivoNome,
  precos: [n|null], marcas: [], obsItens: [],      // alinhados aos itens do pedido
  prazoEntrega, validade, pagamento, frete, obs, nItens, cotadoEm,
  anexo: {nome, tipo, tamanho, partes, base} | null, em, porNome }
```

**Decisão do mapa** `data/suprimentos/cotacoes/<pid>`
```js
{ vencedores: [rid|null],          // por item
  divisoes: { <índice do item>: { <rid>: quantidade } },   // item dividido entre fornecedores
  motivos: [texto], total, em, porNome }
```

**Conferência** `pedidos/<uid>/conferencia/<pid>`
```js
{ itens: { "<n>": {qtd, ok: "S"|"N"|"", obs} },
  entregas: { "<fornecedor>": {data, por} },
  complemento?: {id, protocolo, em},   // solicitação gerada com os faltantes
  atualizadoEm, porNome }
```

**Notas fiscais** `pedidos/<uid>/notas/<pid>`
```js
{ porFornecedor: { "<fornecedor>": {numero, nome, tipo, tamanho, partes, base, em, porNome} }, atualizadoEm }
```

**Gasto (teto)** `data/suprimentos/gastos/<pid>`
```js
{ pid, protocolo, categoria, municipio, unidade, total, mes: "AAAA-MM", em, porNome,
  excecao: {just, porNome, em, total} | null }
```

**Homologação** `data/suprimentos/homologacoes/<pid>`
```js
{ status: "pendente"|"homologado"|"devolvido", assinatura, total, enviadoEm, enviadoPor,
  em, porNome, obs, historico: [{acao, em, porNome}] }
```

**Pedidos de compra** `data/suprimentos/autorizacoes/<pid>`
```js
{ porRid: { <rid>: {numero, fornecedor, total, itens, envios: [{canal, em, porNome}]} } }
```

**Protocolo da Controladoria** `data/suprimentos/protocolos/<id>`
```js
{ numero, de, ate, filtro, destino, obs, processos: [protocolo], total, em, porNome }
```

---

## 5. Bibliotecas externas (CDN)

| Biblioteca | Versão | Uso |
|---|---|---|
| SheetJS (xlsx) | 0.18.5 | Ler planilhas (solicitação, cotação) e CSV |
| ExcelJS | 4.4.0 | Gerar planilha de cotação, mapa e lista de recebimento no padrão visual do ISV |
| jsPDF + jspdf-autotable | 2.5.1 / 3.8.2 | Pedido de compra, processo completo, relatório da Controladoria |
| pdf-lib | 1.17.1 | Juntar anexos PDF ao processo |
| pdf.js (pdfjs-dist) | 3.11.174 | Ler texto de certidões e do cartão CNPJ |

Carregadas de `cdnjs.cloudflare.com`, com reserva em `cdn.jsdelivr.net`. SheetJS vem no `<script>` inicial; as demais são carregadas sob demanda.

**Serviços externos chamados pelo navegador:** BrasilAPI (CNPJ), links de emissão de certidões (Receita, TST, Caixa, SEFAZ-CE, Prefeitura de Fortaleza), `wa.me` e Gmail.

---

## 6. Estrutura do código

Tudo em uma IIFE no final do HTML. Blocos marcados com `// ---------- nome ----------`:

| Bloco | Funções principais |
|---|---|
| Constantes | `TIPOS`, `PRAZO_DU`, `UNIDADES_ISV`, `SOLICITANTES`, `MUNICIPIOS`, `SETORES*`, `CATS`, `STATUS`, `ORDER` |
| Abas e formulário | `setTab`, `resetForm`, `lerPlanilha`, envio do formulário |
| Listas, quadro e detalhe | `render`, `listTable`, `cardHtml`, `COLUNAS`, `renderDrawer` |
| Equipe | `renderEquipe` (só dona) |
| Fornecedores e envio | `renderForn`, `blocoEnvio`, `msgPadrao`, `registrarEnvio`, `buscarCnpj`, `lerCartaoItens` |
| Impedido e exclusividade | `renderImp`, `exclusivoCard` |
| Certidões | `CERTS`, `certStatus`, `certResumo`, `lerCertidaoTexto`, `certBloqueio` |
| Cotações vigentes | `indexarResposta`, `vigentesDoPedido`, `trazerVigentes` |
| Tetos e saldo | `checarSaldo`, `usoTeto`, `saldoPorMunicipio`, `renderSaldoKpis`, `renderTetos` |
| Pedido de compra | `gruposVencedores`, `montarAutorizacaoPdf`, `registrarAutorizacao` |
| Homologação | `marcarHomologacaoPendente`, `blocoHomologacao` |
| Nota fiscal | `carregarNotas`, `linhaNF`, `ligarNotas`, `gruposSemNF` |
| Processo e Controladoria | `montarProcessoPdf`, `gerarRelatorioControladoria` |
| Mapa de cotação | `analiseCot`, `renderMapa`, `salvarResposta`, `lerNossaPlanilha`, `lerComClaude`, `salvarDecisao` |
| Planilhas ISV | `montarCotacaoXlsx`, `montarMapaXlsx` |
| Faltantes | `faltantesDe`, `gerarSolicitacaoFaltantes` |
| Recebimento | `liberarRecebimento`, `blocoRecebimento`, `ligarConferencia`, `statusPorConferencia` |
| Boot | `window.claude.use(...)`, `aplicarPapel`, assinaturas `onSnapshot` |

---

## 7. Observações para a migração

1. **Tempo real:** o painel depende de `onSnapshot` (pedidos, andamento, fornecedores, gastos, homologações, preços). O substituto precisa de assinaturas em tempo real ou polling.
2. **Situação duplicada:** a situação é gravada em `status/<uid>/lista/<pid>` (lida pelo solicitante) **e** em `data/suprimentos/andamento/<pid>` (lida pelo painel). Num banco relacional, vira uma tabela só, com permissão por linha.
3. **Permissões:** hoje o solicitante grava a própria conferência, as NFs e a solicitação automática de faltantes. A mudança de situação disparada pela conferência também é gravada pelo navegador do solicitante. Num backend próprio, mova essas regras (`statusPorConferencia`, `gerarSolicitacaoFaltantes`) para o servidor.
4. **IA:** a leitura com o Claude (`sample`) é opcional: sem ela, o fluxo funciona por planilha e digitação. A chave de API nunca deve ir para o navegador.
5. **Fuso e datas:** datas ISO em UTC; prazos calculados no navegador com feriados nacionais fixos (sem feriados móveis nem municipais).
6. **Dados atuais:** exportados em 16/11/2026 na pasta `02 Dados` deste pacote (`banco-completo.json`, `dados-do-sistema.xlsx` e `anexos/`). Depois dessa data, novos registros continuam entrando no banco do claude.ai até a virada para o novo sistema: combine uma nova exportação no dia da migração.
7. **Documentação de uso:** `Manual do Solicitante - Compras ISV.docx` e `Manual do Assistente - Compras ISV.docx` (versão 3.1).
