-- Link de cotação para o fornecedor (sem login).
-- O visitante anônimo NÃO ganha acesso a nenhuma tabela: ele só chama as três funções abaixo,
-- que conferem o código (32 hex, aleatório) e o prazo, e leem/gravam apenas o que é daquele link.
-- O link é um documento data/suprimentos/links/<código>, criado pela equipe (RLS: admin).

-- ---------------------------------------------------------------- interna (não chamável pela API)
create or replace function public.cot_link(p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare l jsonb; f jsonb; h jsonb; st jsonb;
begin
  if p_token is null or p_token !~ '^[a-f0-9]{32}$' then raise exception 'Link inválido.'; end if;
  select dados into l from public.docs where path = 'data/suprimentos/links/' || p_token;
  if l is null then raise exception 'Link inválido.'; end if;
  if coalesce(l->>'status','') = 'encerrado' then raise exception 'Este link foi encerrado pelo Setor de Suprimentos.'; end if;
  if (l->>'expiraEm')::timestamptz < now() then raise exception 'O prazo deste link terminou. Fale com o Setor de Suprimentos.'; end if;
  select dados into f from public.docs where path = 'data/suprimentos/fornecedores/' || (l->>'fid');
  if f is null or jsonb_typeof(f->'impedimento') = 'object' then raise exception 'Este link não está disponível. Fale com o Setor de Suprimentos.'; end if;
  select dados into h from public.docs where path = 'data/suprimentos/homologacoes/' || (l->>'pid');
  select dados into st from public.docs where path = 'data/suprimentos/andamento/' || (l->>'pid');
  if coalesce(h->>'status','') in ('pendente','homologado')
     or coalesce(st->>'status','') in ('cancelada','comprada','pendencia','entregue') then
    raise exception 'Esta cotação já foi encerrada.';
  end if;
  if not exists (select 1 from public.docs where path = 'pedidos/' || (l->>'uid') || '/lista/' || (l->>'pid')) then
    raise exception 'Esta cotação não está mais disponível.';
  end if;
  return l;
end $$;

-- ---------------------------------------------------------------- abrir
create or replace function public.cot_abrir(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare l jsonb := public.cot_link(p_token); r jsonb;
begin
  select dados into r from public.docs
   where path = 'data/suprimentos/cotacoes/' || (l->>'pid') || '/respostas/link-' || (l->>'fid');
  return jsonb_build_object(
    'protocolo', l->'protocolo', 'fornecedor', l->'fornecedor', 'categoria', l->'categoria',
    'municipio', l->'municipio', 'tipo', l->'tipo', 'itens', l->'itens', 'expiraEm', l->'expiraEm',
    'resposta', case when r is null then null else jsonb_build_object(
        'precos', r->'precos', 'marcas', r->'marcas', 'prazoEntrega', r->'prazoEntrega', 'validade', r->'validade',
        'pagamento', r->'pagamento', 'frete', r->'frete', 'obs', r->'obs', 'anexoNome', r->'anexo'->'nome',
        'enviadoEm', r->'em') end);
end $$;

-- ---------------------------------------------------------------- anexo (PDF em partes base64)
create or replace function public.cot_anexo(p_token text, p_envio text, p_parte int, p_b64 text)
returns void language plpgsql security definer set search_path = public as $$
declare l jsonb := public.cot_link(p_token); raiz text; caminho text;
begin
  if p_envio is null or p_envio !~ '^[a-f0-9]{16}$' then raise exception 'Envio inválido.'; end if;
  if p_parte is null or p_parte < 0 or p_parte > 79 then raise exception 'Arquivo muito grande (máx. 10 MB).'; end if;
  if p_b64 is null or length(p_b64) = 0 or length(p_b64) > 180000 or p_b64 !~ '^[A-Za-z0-9+/]+={0,2}$' then
    raise exception 'Arquivo inválido.';
  end if;
  raiz := 'data/suprimentos/cotacoes/' || (l->>'pid') || '/anexos/link-' || (l->>'fid') || '-';
  caminho := raiz || p_envio || '/partes/' || p_parte;
  -- limite de abuso: cerca de 5 envios de 10 MB por link
  if (select count(*) from public.docs where starts_with(path, raiz)) >= 400 then
    raise exception 'Limite de envios atingido. Fale com o Setor de Suprimentos.';
  end if;
  insert into public.docs (path, dados) values (caminho, jsonb_build_object('b64', p_b64))
  on conflict (path) do update set dados = excluded.dados, atualizado_em = now();
end $$;

-- ---------------------------------------------------------------- enviar / reenviar
create or replace function public.cot_enviar(p_token text, p_resposta jsonb)
returns text language plpgsql security definer set search_path = public as $$
declare
  l jsonb := public.cot_link(p_token);
  n int; i int; v jsonb; precos jsonb := '[]'; marcas jsonb := '[]'; obsitens jsonb := '[]'; algum boolean := false;
  ant jsonb; anexo jsonb; a jsonb; base text; partes int; achadas int; inicio text; agora text; caminho text;
  k text;
begin
  n := jsonb_array_length(l->'itens');
  if jsonb_typeof(p_resposta->'precos') <> 'array' or jsonb_array_length(p_resposta->'precos') <> n then
    raise exception 'Preços incompletos. Recarregue a página.';
  end if;
  for i in 0..n-1 loop
    v := p_resposta->'precos'->i;
    if jsonb_typeof(v) = 'number' then
      if (v#>>'{}')::numeric <= 0 or (v#>>'{}')::numeric >= 1000000000 then raise exception 'Valor inválido no item %.', i+1; end if;
      precos := precos || jsonb_build_array(round((v#>>'{}')::numeric, 4)); algum := true;
    else
      precos := precos || '[null]'::jsonb;
    end if;
    marcas := marcas || jsonb_build_array(left(coalesce(p_resposta->'marcas'->>i, ''), 200));
    obsitens := obsitens || '[""]'::jsonb;
  end loop;
  if not algum then raise exception 'Preencha o valor de pelo menos um item.'; end if;
  foreach k in array array['prazoEntrega','validade','pagamento','frete'] loop
    if length(trim(coalesce(p_resposta->>k, ''))) = 0 then raise exception 'Preencha prazo de entrega, validade, pagamento e frete.'; end if;
  end loop;

  caminho := 'data/suprimentos/cotacoes/' || (l->>'pid') || '/respostas/link-' || (l->>'fid');
  select dados into ant from public.docs where path = caminho;

  a := p_resposta->'anexo';
  if jsonb_typeof(a) = 'object' then
    if coalesce(a->>'envio','') !~ '^[a-f0-9]{16}$' or coalesce(a->>'partes','') !~ '^[0-9]{1,2}$' then raise exception 'Anexo inválido.'; end if;
    partes := (a->>'partes')::int;
    base := 'data/suprimentos/cotacoes/' || (l->>'pid') || '/anexos/link-' || (l->>'fid') || '-' || (a->>'envio');
    select count(*) into achadas from public.docs
     where path in (select base || '/partes/' || g from generate_series(0, partes-1) g);
    if partes < 1 or achadas <> partes then raise exception 'O PDF não chegou completo. Anexe novamente.'; end if;
    select dados->>'b64' into inicio from public.docs where path = base || '/partes/0';
    if left(inicio, 6) <> 'JVBERi' then raise exception 'A proposta precisa ser um arquivo PDF.'; end if;
    anexo := jsonb_build_object('nome', left(coalesce(a->>'nome','proposta.pdf'), 150), 'tipo', 'application/pdf',
             'tamanho', case when coalesce(a->>'tamanho','') ~ '^[0-9]{1,9}$' then (a->>'tamanho')::int else 0 end,
             'partes', partes, 'base', base);
  else
    anexo := ant->'anexo';
  end if;
  if anexo is null or jsonb_typeof(anexo) <> 'object' then
    raise exception 'Anexe a proposta em papel timbrado e assinada (PDF).';
  end if;

  agora := to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  insert into public.docs (path, dados) values (caminho, jsonb_build_object(
      'fornecedor', l->>'fornecedor', 'fid', l->>'fid', 'origem', 'link', 'arquivoNome', '',
      'precos', precos, 'marcas', marcas, 'obsItens', obsitens,
      'prazoEntrega', left(p_resposta->>'prazoEntrega', 200), 'validade', left(p_resposta->>'validade', 200),
      'pagamento', left(p_resposta->>'pagamento', 200), 'frete', left(p_resposta->>'frete', 200),
      'obs', left(coalesce(p_resposta->>'obs',''), 1000), 'nItens', n,
      'cotadoEm', agora, 'em', agora, 'anexo', anexo, 'porNome', 'Fornecedor (link)'))
  on conflict (path) do update set dados = excluded.dados, atualizado_em = now(), atualizado_por = null;

  update public.docs set dados = dados || jsonb_build_object('respondidoEm', agora), atualizado_em = now()
   where path = 'data/suprimentos/links/' || p_token;
  return agora;
end $$;

-- ---------------------------------------------------------------- permissões
revoke all on function public.cot_link(text) from public, anon, authenticated;
revoke all on function public.cot_abrir(text), public.cot_anexo(text, text, int, text), public.cot_enviar(text, jsonb) from public;
grant execute on function public.cot_abrir(text), public.cot_anexo(text, text, int, text), public.cot_enviar(text, jsonb) to anon, authenticated;
