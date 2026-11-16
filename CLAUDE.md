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
├── index.html              ← o sistema (cópia fiel de "01 Sistema/compras-isv.html")
├── CNAME                   ← (a criar no deploy) compras.institutosaovicente.com.br
├── docs/
│   ├── documentacao-tecnica.md
│   ├── LEIA-ME-pacote.md   ← leia-me original do pacote de entrega
│   ├── manuais/            ← Manual do Solicitante e do Assistente v3.1 (docx/pdf)
│   ├── exemplos/           ← cotação, mapa (xlsx) e pedido de compra (pdf)
│   └── referencias/        ← telas, esboço do Kanban, versão retirada (link do fornecedor)
├── libs/                   ← bibliotecas nas versões exatas (hoje não usadas: a página usa CDN)
├── dados/                  ← GITIGNORED: banco exportado, anexos reais, lista de usuários
└── _entrega-original/      ← GITIGNORED: zip e arquivos como chegaram da desenvolvedora
```

---

## Estado atual e decisões

- **Fase 1 (atual): só publicar** em `https://compras.institutosaovicente.com.br/`. **Não alterar** frontend, backend nem lógica até nova decisão.
- **Limitação conhecida:** fora do claude.ai, `window.claude` não existe. A página abre a interface e mostra o aviso "Abra esta página no claude.ai...", sem login, banco nem envio. O sistema em uso continua sendo o do claude.ai até a migração.
- **Migração (futuro):** substituir `db`, `user`, `downloads`, `sample`, `assets` (seção 3 e 7 da documentação técnica). Fazer nova exportação de dados no dia da virada.

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
