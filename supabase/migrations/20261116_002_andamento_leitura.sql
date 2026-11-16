-- O upsert (INSERT ... ON CONFLICT DO UPDATE) exige permissão de LEITURA na linha existente.
-- Sem isto, o solicitante não conseguiria regravar o andamento do próprio pedido (conferência
-- do recebimento) depois que o Suprimentos já criou esse documento.
create or replace function public.pode_acessar(p_path text, p_escrita boolean)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  s  text[] := string_to_array(p_path, '/');
  n  int    := public.nivel_num();
  eu text   := auth.uid()::text;
begin
  if n = 0 or eu is null then return false; end if;
  case s[1]
    when 'pedidos' then
      return n >= case when s[2] = eu then 2 else 3 end;
    when 'status' then
      return n >= case when s[2] = eu then 2 else 3 end;
    when 'data' then
      if s[2] = 'suprimentos' then
        if n >= 3 then return true; end if;
        -- [AJUSTE] solicitante lê e grava a situação (andamento) só do próprio pedido.
        return n >= 2 and s[3] = 'andamento' and array_length(s, 1) = 4
               and exists (select 1 from public.docs d where d.path = 'pedidos/' || eu || '/lista/' || s[4]);
      end if;
      return false;
    when 'config' then
      return n >= case when p_escrita then 4 else 1 end;
    when 'pessoas' then
      return n >= case when s[2] = eu and array_length(s, 1) = 2 then 2 else 3 end;
    else
      return false;
  end case;
end $$;
