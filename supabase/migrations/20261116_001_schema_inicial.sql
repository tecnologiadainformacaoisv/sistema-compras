-- Compras ISV · schema inicial (projeto Supabase cmvhbcmolvolxoperdin)
--
-- O sistema foi escrito para o banco de documentos do claude.ai (caminhos estilo Firestore).
-- Para não mexer na lógica, o banco guarda os documentos numa tabela só (`docs`), indexada pelo
-- caminho original (ex.: pedidos/<uid>/lista/<pid>). As regras de acesso (RLS) reproduzem a tabela
-- da seção 3.1 da documentação técnica, com dois ajustes necessários (marcados com [AJUSTE]).
--
-- Níveis: view(1) < interact(2) < admin(3) < owner(4)
--   interact = solicitante · admin = assistente/gestão (definido na aba Equipe) · owner = dona

-- ---------------------------------------------------------------- tabelas
create table public.docs (
  path          text primary key check (path ~ '^[^/]+(/[^/]+)+$'),
  parent        text generated always as (regexp_replace(path, '/[^/]*$', '')) stored,
  id            text generated always as (regexp_replace(path, '^.*/', '')) stored,
  dados         jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid default auth.uid()
);
create index docs_parent_idx on public.docs (parent);

create table public.perfis (
  id        uuid primary key references auth.users(id) on delete cascade,
  email     text not null,
  nome      text not null default '',
  nivel     text not null default 'interact' check (nivel in ('view','interact','admin','owner')),
  criado_em timestamptz not null default now()
);

-- Quem pode criar conta: e-mails @institutosaovicente.com.br ou listados aqui.
create table public.convites (
  email     text primary key check (email = lower(email)),
  nivel     text not null default 'interact' check (nivel in ('view','interact','admin','owner')),
  criado_em timestamptz not null default now()
);
insert into public.convites (email, nivel) values ('gerente.compras@institutosaovicente.com.br', 'owner');

alter table public.docs     enable row level security;
alter table public.perfis   enable row level security;
alter table public.convites enable row level security;   -- sem policies: só o servidor acessa

revoke all on public.docs, public.perfis, public.convites from anon;
revoke all on public.convites from authenticated;

-- ---------------------------------------------------------------- funções
create or replace function public.nivel_num(p_user uuid default auth.uid())
returns int language sql stable security definer set search_path = public as $$
  select coalesce((select case nivel when 'view' then 1 when 'interact' then 2
                                     when 'admin' then 3 when 'owner' then 4 end
                   from public.perfis where id = p_user), 0)
$$;

create or replace function public.pode_acessar(p_path text, p_escrita boolean)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  s  text[] := string_to_array(p_path, '/');
  n  int    := public.nivel_num();
  eu text   := auth.uid()::text;
begin
  if n = 0 or eu is null then return false; end if;
  case s[1]
    when 'pedidos' then                       -- pedidos: admin · pedidos/{self}: interact
      return n >= case when s[2] = eu then 2 else 3 end;
    when 'status' then                        -- status: admin · status/{self}: leitura interact
      -- [AJUSTE] escrita em status/{self} liberada ao solicitante: a conferência do recebimento
      -- muda a situação pelo navegador dele (documentação, seção 7, item 3).
      return n >= case when s[2] = eu then 2 else 3 end;
    when 'data' then                          -- data/suprimentos: admin
      if s[2] = 'suprimentos' then
        if n >= 3 then return true; end if;
        -- [AJUSTE] o solicitante grava a situação (andamento) só do próprio pedido.
        return p_escrita and n >= 2 and s[3] = 'andamento' and array_length(s, 1) = 4
               and exists (select 1 from public.docs d where d.path = 'pedidos/' || eu || '/lista/' || s[4]);
      end if;
      return false;
    when 'config' then                        -- config: leitura view · escrita owner
      return n >= case when p_escrita then 4 else 1 end;
    when 'pessoas' then                       -- pessoas: admin
      -- [AJUSTE] cada pessoa registra o próprio acesso, senão não apareceria na aba Equipe.
      return n >= case when s[2] = eu and array_length(s, 1) = 2 then 2 else 3 end;
    else
      return false;
  end case;
end $$;

create or replace function public.definir_meu_nome(p_nome text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if length(trim(coalesce(p_nome, ''))) < 3 then raise exception 'Informe seu nome completo'; end if;
  update public.perfis set nome = trim(p_nome) where id = auth.uid();
end $$;

revoke all on function public.definir_meu_nome(text) from public, anon;
grant execute on function public.definir_meu_nome(text) to authenticated;
revoke all on function public.nivel_num(uuid), public.pode_acessar(text, boolean) from public, anon;
grant execute on function public.nivel_num(uuid), public.pode_acessar(text, boolean) to authenticated;

-- ---------------------------------------------------------------- policies
create policy docs_select on public.docs for select to authenticated using (public.pode_acessar(path, false));
create policy docs_insert on public.docs for insert to authenticated with check (public.pode_acessar(path, true));
create policy docs_update on public.docs for update to authenticated
  using (public.pode_acessar(path, true)) with check (public.pode_acessar(path, true));
create policy docs_delete on public.docs for delete to authenticated using (public.pode_acessar(path, true));

create policy perfis_select on public.perfis for select to authenticated
  using (id = auth.uid() or public.nivel_num() >= 4);

-- ---------------------------------------------------------------- novos usuários
create or replace function public.checar_novo_usuario()
returns trigger language plpgsql security definer set search_path = public, auth as $$
begin
  if not (exists (select 1 from public.convites where email = lower(coalesce(new.email, '')))
          or lower(coalesce(new.email, '')) like '%@institutosaovicente.com.br') then
    raise exception 'E-mail sem acesso ao sistema de compras';
  end if;
  return new;
end $$;

create or replace function public.criar_perfil()
returns trigger language plpgsql security definer set search_path = public, auth as $$
begin
  insert into public.perfis (id, email, nivel)
  values (new.id, lower(new.email),
          coalesce((select c.nivel from public.convites c where c.email = lower(new.email)), 'interact'))
  on conflict (id) do nothing;
  return new;
end $$;

create trigger trg_checar_novo_usuario before insert on auth.users
  for each row execute function public.checar_novo_usuario();
create trigger trg_criar_perfil after insert on auth.users
  for each row execute function public.criar_perfil();

-- ---------------------------------------------------------------- aba Equipe → nível de acesso
-- Quando a dona salva config/equipe, quem está nas listas vira "admin"; quem saiu volta a "interact".
create or replace function public.sincronizar_equipe()
returns trigger language plpgsql security definer set search_path = public as $$
declare ids text[];
begin
  ids := array(select jsonb_array_elements_text(coalesce(new.dados->'assistentes', '[]'::jsonb)))
      || array(select jsonb_array_elements_text(coalesce(new.dados->'gestores',    '[]'::jsonb)));
  update public.perfis set nivel = 'admin'    where id::text = any(ids) and nivel in ('view','interact');
  update public.perfis set nivel = 'interact' where nivel = 'admin' and not (id::text = any(ids));
  return new;
end $$;

create trigger trg_sincronizar_equipe after insert or update on public.docs
  for each row when (new.path = 'config/equipe') execute function public.sincronizar_equipe();

-- ---------------------------------------------------------------- tempo real
alter publication supabase_realtime add table public.docs;
