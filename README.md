# Compras ISV

Sistema de solicitações de compras do Instituto São Vicente (ISV).

- **Endereço:** https://compras.institutosaovicente.com.br/
- **Repositório:** `tecnologiadainformacaoisv/sistema-compras` (GitHub Pages, branch `master`)
- **Backend:** Supabase (login por link no e-mail, banco e tempo real)
- **Documentação técnica:** [docs/documentacao-tecnica.md](docs/documentacao-tecnica.md)
- **Manuais de uso:** [docs/manuais/](docs/manuais/)

O sistema nasceu como página do claude.ai. Para rodar aqui, `js/supabase-adapter.js` entrega ao `index.html` as mesmas capacidades que o claude.ai fornecia, sem alterar a lógica. O SQL do banco está em `supabase/migrations/`.

Acesso: e-mails `@institutosaovicente.com.br` (ou liberados na tabela `convites`).

Mantido pelo setor de Desenvolvimento do ISV.
