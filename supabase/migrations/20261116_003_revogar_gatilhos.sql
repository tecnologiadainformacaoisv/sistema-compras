-- Funções de gatilho não devem ser chamáveis pela API (/rest/v1/rpc/...). O gatilho continua
-- funcionando: a permissão EXECUTE é checada na criação do gatilho, não a cada disparo.
revoke all on function public.checar_novo_usuario() from public, anon, authenticated;
revoke all on function public.criar_perfil()        from public, anon, authenticated;
revoke all on function public.sincronizar_equipe()  from public, anon, authenticated;
