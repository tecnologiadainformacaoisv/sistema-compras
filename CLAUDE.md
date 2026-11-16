# Compras ISV — ISV

> Arquivo de contexto para Claude Code. Leia este arquivo inteiro antes de qualquer tarefa.

---

## Visão geral do projeto

Sistema de solicitações de compras do Instituto São Vicente: do pedido da unidade até a prestação de contas da nota fiscal (cotação, mapa, homologação, pedido de compra, recebimento, relatório para a Controladoria).

Desenvolvido fora do setor e publicado como página (artifact) no claude.ai. **Assumido pelo setor de desenvolvimento em 2026-11-16.**

**Stack:** página única `index.html` (HTML + CSS + JS, cerca de 3.200 linhas, sem build). Bibliotecas via CDN (cópia local em `libs/`). Login, banco, downloads e leitura com IA vêm do runtime do claude.ai (`window.claude.use(...)`).

**Documentação completa:** `docs/documentacao-tecnica.md` (regras, perfis, modelo de dados, pontos de migração).

---

## Ecossistema (ISV / Desenvolvimento)

Este projeto faz parte da pasta `Desenvolvimento/`, que reúne os sistemas do
**Instituto São Vicente (ISV)**. Padrões compartilhados ficam em:

- **Comandos e agentes:** `~/.claude/` — `/atualizar`, `/encerrar`, agente `revisor`.
- **Assets/estilos/componentes comuns:** `../shared/`
- **UX/UI:** `../_ux-design/` — agente `ux-revisor` + skill `frontend-design`.
- **Referência de comandos:** `../COMANDOS-CLAUDE.md`
- **Publicar em subdomínio:** `../DOMINIO-GITHUB-PAGES.md`

> ⚠️ **NÃO ler nem indexar as pastas dos outros projetos** (`projeto-*`, `pessoal-*`)
> a menos que explicitamente solicitado.

---

## Estrutura

```
/
├── index.html              ← o sistema (original + 2 tags script + textos sem claude.ai)
├── js/supabase-adapter.js  ← substitui window.claude (login, banco, downloads)
├── supabase/migrations/    ← SQL aplicado no projeto Compras ISV (em ordem)
├── CNAME                   ← compras.institutosaovicente.com.br (GitHub Pages, publicado em 2026-11-16)
├── docs/
│   ├── documentacao-tecnica.md
│   ├── LEIA-ME-pacote.md   ← leia-me original do pacote de entrega
│   ├── manuais/            ← Manual do Solicitante e do Assistente v3.1 (docx/pdf)
│   ├── exemplos/           ← cotação, mapa (xlsx) e pedido de compra (pdf)
│   └── referencias/        ← telas, esboço do Kanban, versão retirada (link do fornecedor)
├── libs/                   ← supabase.min.js (usada) + demais bibliotecas do pacote (a página ainda usa CDN para elas)
├── dados/                  ← GITIGNORED: banco exportado, anexos reais, lista de usuários
└── _entrega-original/      ← GITIGNORED: zip e arquivos como chegaram da desenvolvedora
```

---

## Estado atual e decisões

- **Fase 1 (2026-11-16): publicado** em `https://compras.institutosaovicente.com.br/` (GitHub Pages).
- **Fase 2 (2026-11-16): rodando fora do claude.ai.** A lógica do `index.html` **não foi alterada**. Foi adicionada uma camada de compatibilidade, `js/supabase-adapter.js`, que implementa `window.claude.use(...)` em cima do Supabase:
  - `db` → tabela `docs` (documentos por caminho, igual ao banco original) + RLS + tempo real
  - `user` → tabela `perfis` (nome, e-mail, nível) · login por **link no e-mail, sem senha**
  - `downloads` → download comum · `sample` e `assets` → `null` (leitura com IA desligada; o fluxo segue por planilha e digitação)
  - `index.html` só ganhou 2 tags `<script>` e textos que citavam o claude.ai. O original está em `_entrega-original/`.
- **Supabase:** projeto `cmvhbcmolvolxoperdin` (org ISV Summit, sa-east-1). Migrations versionadas em `supabase/migrations/`. **Nunca tocar** no projeto `fgsxqiywncarflpbxxgm` (pesquisa de satisfação dos tablets, em produção), que está na mesma organização.
- **Acesso:** só e-mails `@institutosaovicente.com.br` ou listados em `public.convites`. Níveis: `interact` (solicitante, padrão), `admin` (assistente/gestão: a aba Equipe promove e rebaixa sozinha), `owner` (dona). `gerente.compras@institutosaovicente.com.br` entra como `owner`.
- **Ajustes de permissão em relação à documentação (seção 3.1):** o solicitante grava `status/{self}` e o `andamento` do próprio pedido (a conferência muda a situação pelo navegador dele); cada pessoa grava o próprio `pessoas/{self}`. Detalhes em `supabase/migrations/`.
- **Configuração no painel do Supabase (não versionável):** Authentication > URL Configuration (Site URL e Redirect URL = `https://compras.institutosaovicente.com.br`) e Authentication > Emails > SMTP (e-mail de envio do Titan). Sem SMTP próprio, o Supabase só entrega e-mails para membros da organização e com limite baixo.
- **Pendências:** nova exportação de dados no dia da virada (importar `banco-completo.json` exige mapear os ids antigos para os novos usuários); anexos continuam em base64 dentro do banco (migrar para Storage se o volume crescer); leitura com IA exigiria função no servidor + chave da API.

---

## Padrões de desenvolvimento

- Versionamento: **Semantic Versioning**; `MAJOR` = 0 em pré-produção.
- Commits no padrão **Conventional Commits** (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
- **LGPD:** `dados/` tem nomes, CNPJs, certidões e notas fiscais reais. Nunca versionar nem publicar. O repositório no GitHub é público.

---

## Contexto organizacional

- **Organização:** Instituto São Vicente (ISV)
- **Responsável de TI:** Henrique (TI — ISV)
- **Dona do sistema (claude.ai):** Coordenação de Suprimentos
- **Municípios:** Orós, Lavras da Mangabeira e ISV (sede)
