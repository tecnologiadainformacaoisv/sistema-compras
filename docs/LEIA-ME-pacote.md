# Compras ISV · Pacote para o setor de desenvolvimento

Pacote de passagem do sistema de solicitações de compras do Instituto São Vicente (ISV) para a equipe de desenvolvimento, que vai assumir a produção.
Exportado em **16/11/2026**, a partir da versão publicada no claude.ai em 12/11/2026.

## O que tem em cada pasta

| Pasta | Conteúdo |
|---|---|
| `01 Sistema` | `compras-isv.html`: código completo da página (HTML + CSS + JavaScript, arquivo único). `documentacao-tecnica.md`: regras de negócio, perfis, situações, modelo de dados, dependências e cuidados para a migração. **Comece por ela.** |
| `02 Dados` | Exportação completa do banco: `banco-completo.json` (todos os documentos, indexados pelo caminho no banco), `dados-do-sistema.xlsx` (as mesmas informações em abas legíveis: solicitações, itens, histórico, fornecedores, certidões, respostas de cotação, decisões do mapa, pedidos de compra, homologações, conferência, notas fiscais, tetos e gastos) e `anexos/` (todos os arquivos enviados, já remontados: planilhas, ofícios, notas fiscais, certidões, cartões CNPJ e propostas timbradas). `anexos/indice-anexos.json` liga cada arquivo ao caminho original no banco. |
| `03 Usuarios` | `lista-de-usuarios (preencher).xlsx`: os usuários que já acessaram o sistema, com o ID interno, o papel atual, os nomes e unidades usados nas solicitações e as datas de acesso. **As colunas em laranja (nome, e-mail, unidade/setor e papel no novo sistema) precisam ser preenchidas pela coordenação**, porque o claude.ai não fornece e-mails. |
| `04 Manuais` | Manual do Solicitante e Manual do Assistente, versão 3.1, em Word e PDF. Descrevem o uso de cada tela, do jeito que o sistema funciona hoje. |
| `05 Exemplos` | Exemplos dos arquivos que o sistema gera: planilha de cotação, mapa de cotação (Excel) e pedido de compra em PDF (exemplo do modelo antigo, quando ainda se chamava "Autorização de compra"). |
| `06 Referencias` | Telas do sistema (capturas com dados de teste); o esboço do quadro Kanban feito antes da implementação; e a versão com "link de resposta do fornecedor", que foi testada e **retirada** (fica só como referência, caso queiram retomar a ideia). |
| `07 Bibliotecas` | Cópia local das bibliotecas usadas, nas versões exatas: SheetJS 0.18.5, ExcelJS 4.4.0, jsPDF 2.5.1, jspdf-autotable 3.8.2, pdf-lib 1.17.1 e pdf.js 3.11.174. Hoje elas são carregadas de CDNs públicas. |

Os vídeos de apresentação do sistema foram entregues separadamente, por causa do tamanho.

## Pontos de atenção

1. **O sistema hoje depende do claude.ai** para login, banco de dados em tempo real, downloads e leitura de documentos com IA. Numa hospedagem própria, essas quatro partes precisam ser substituídas (detalhes na seção 3 da documentação técnica).
2. **Os dados continuam entrando no claude.ai** até a virada. Planejem uma nova exportação no dia da migração.
3. **Leitura com IA (opcional):** para manter a leitura automática de orçamentos, certidões e cartão CNPJ, é preciso uma chave da API da Anthropic, usada só no servidor. Sem ela, o sistema funciona por planilha e digitação.
4. **Dados pessoais:** o pacote contém nomes, CNPJs, certidões e notas fiscais reais. Guardem e compartilhem com o mesmo cuidado do sistema.
5. **Papéis dos usuários:** os IDs da exportação são internos do claude.ai e só servem para ligar os registros entre si. No novo sistema, use a lista de usuários preenchida pela coordenação.
