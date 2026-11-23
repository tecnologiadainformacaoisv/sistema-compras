/* Compras ISV · camada de compatibilidade com o Supabase
 *
 * O sistema (index.html) foi escrito para o ambiente do claude.ai e pede suas capacidades por
 * window.claude.use("db" | "user" | "downloads" | "sample" | "assets"). Este arquivo entrega a mesma
 * interface em cima do Supabase, sem mexer na lógica do sistema:
 *   db        → tabela `docs` (documentos por caminho) com regras de acesso (RLS) e tempo real
 *   user      → perfil do usuário logado (tabela `perfis`)
 *   downloads → download comum pelo navegador
 *   sample    → null (leitura com IA desligada; o sistema segue por planilha e digitação)
 *   assets    → null (só existia para anexos antigos do claude.ai)
 * Login: link enviado por e-mail, sem senha.
 */
(function (root) {
  "use strict";

  var CFG = {
    url: "https://cmvhbcmolvolxoperdin.supabase.co",
    // Chave pública (anon). Segura no navegador: quem protege os dados são as regras de acesso (RLS).
    key: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtdmhiY21vbHZvbHhvcGVyZGluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4NDQ1OTEsImV4cCI6MjExMDQyMDU5MX0.P8Vyrwl5odnMMR723X3vRn-gnzL4Lg9Lqs1Z3aElo8g"
  };

  /* ------------------------------------------------------------------ camada de dados */
  function criarDb(sb, getUid, opcoes) {
    var pollMs = (opcoes && opcoes.pollMs) || 20000;
    var ouvintes = new Set();
    var ALFA = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    function novoId() {
      var b = root.crypto.getRandomValues(new Uint8Array(20)), s = "";
      for (var i = 0; i < b.length; i++) s += ALFA[b[i] % 62];
      return s;
    }
    function idDe(p) { return p.slice(p.lastIndexOf("/") + 1); }
    function paiDe(p) { return p.slice(0, p.lastIndexOf("/")); }
    function erro(e) { var x = new Error((e && e.message) || "Erro"); x.code = e && (e.code || e.status); return x; }
    function snapDoc(path, dados) {
      return { id: idDe(path), exists: dados != null, data: function () { return dados == null ? undefined : dados; } };
    }
    function avisar(path) { ouvintes.forEach(function (f) { try { f(path); } catch (e) { /* ignora */ } }); }

    async function lerDoc(path) {
      var r = await sb.from("docs").select("dados").eq("path", path).maybeSingle();
      if (r.error) throw erro(r.error);
      return snapDoc(path, r.data ? r.data.dados : null);
    }
    async function lerColecao(path) {
      var docs = [];
      for (var de = 0; ; de += 1000) {            // o servidor devolve no máximo 1000 linhas por vez
        var r = await sb.from("docs").select("path,dados").eq("parent", path).order("path").range(de, de + 999);
        if (r.error) throw erro(r.error);
        r.data.forEach(function (x) { docs.push(snapDoc(x.path, x.dados)); });
        if (r.data.length < 1000) break;
      }
      return docs;
    }
    async function gravar(path, obj) {
      var dados = JSON.parse(JSON.stringify(obj == null ? {} : obj));   // descarta undefined, como o banco original
      var linha = { path: path, dados: dados, atualizado_em: new Date().toISOString() };
      var uid = getUid(); if (uid) linha.atualizado_por = uid;
      var r = await sb.from("docs").upsert(linha, { onConflict: "path" });
      if (r.error) throw erro(r.error);
      avisar(path);
    }
    async function apagar(path) {
      var r = await sb.from("docs").delete().eq("path", path);
      if (r.error) throw erro(r.error);
      avisar(path);
    }

    // Assinatura: busca ao assinar, de novo a cada mudança (tempo real do Supabase + gravações locais)
    // e a cada `pollMs` como rede de segurança (o tempo real não avisa exclusões nem perdas de conexão).
    function assinar(o) {
      var vivo = true, ocupado = false, repetir = false, primeira = true, espera = null, canal = null, ultima = null;
      async function rodar() {
        if (!vivo) return;
        if (ocupado) { repetir = true; return; }
        ocupado = true;
        var res, falhou = null;
        try { res = await o.busca(); } catch (e) { falhou = e; }
        ocupado = false;
        if (vivo) {
          if (falhou) { if (primeira && o.onErro) { primeira = false; o.onErro(falhou); } }
          else {
            primeira = false;
            var chave = o.chave(res);                  // só avisa quando algo mudou de verdade
            if (chave !== ultima) { ultima = chave; o.entrega(res); }
          }
        }
        if (repetir) { repetir = false; rodar(); }
      }
      function agendar() { clearTimeout(espera); espera = setTimeout(rodar, 150); }
      function ouvinte(p) { if (o.casa(p)) agendar(); }
      ouvintes.add(ouvinte);
      try {
        canal = sb.channel("c" + novoId())
          .on("postgres_changes", { event: "*", schema: "public", table: "docs", filter: o.filtro }, agendar)
          .subscribe();
      } catch (e) { /* sem tempo real: o intervalo cobre */ }
      var timer = setInterval(function () { if (typeof document === "undefined" || !document.hidden) rodar(); }, pollMs);
      rodar();
      return function () {
        vivo = false; ouvintes.delete(ouvinte); clearInterval(timer); clearTimeout(espera);
        if (canal) { try { sb.removeChannel(canal); } catch (e) { /* ignora */ } }
      };
    }

    function montarSnap(docs, anterior) {
      return {
        docs: docs, size: docs.length, empty: docs.length === 0,
        forEach: function (f) { docs.forEach(f); },
        docChanges: function () {
          var mudancas = [], atual = {};
          docs.forEach(function (d) {
            var j = JSON.stringify(d.data()); atual[d.id] = j;
            if (!anterior) mudancas.push({ type: "added", doc: d });
            else if (!(d.id in anterior)) mudancas.push({ type: "added", doc: d });
            else if (anterior[d.id] !== j) mudancas.push({ type: "modified", doc: d });
          });
          if (anterior) Object.keys(anterior).forEach(function (id) {
            if (!(id in atual)) mudancas.push({ type: "removed", doc: snapDoc(id, null) });
          });
          return mudancas;
        }
      };
    }
    function mapaJson(docs) { var m = {}; docs.forEach(function (d) { m[d.id] = JSON.stringify(d.data()); }); return m; }

    function doc(path) {
      return {
        id: idDe(path), path: path,
        get: function () { return lerDoc(path); },
        set: function (obj) { return gravar(path, obj); },
        delete: function () { return apagar(path); },
        onSnapshot: function (cb, eb) {
          return assinar({ busca: function () { return lerDoc(path); }, casa: function (p) { return p === path; },
                           chave: function (d) { return JSON.stringify([d.exists, d.data()]); },
                           filtro: "path=eq." + path, entrega: cb, onErro: eb });
        }
      };
    }
    function collection(path) {
      return {
        get: async function () { return montarSnap(await lerColecao(path), null); },
        doc: function (id) { return doc(path + "/" + (id || novoId())); },
        onSnapshot: function (cb, eb) {
          var anterior = null;
          return assinar({
            busca: function () { return lerColecao(path); },
            casa: function (p) { return paiDe(p) === path; },
            chave: function (docs) { return JSON.stringify(mapaJson(docs)); },
            filtro: "parent=eq." + path,
            entrega: function (docs) { var s = montarSnap(docs, anterior); anterior = mapaJson(docs); cb(s); },
            onErro: eb
          });
        }
      };
    }
    return { doc: doc, collection: collection };
  }

  function criarDownloads(doc) {
    var TIPOS = { xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", pdf: "application/pdf", csv: "text/csv;charset=utf-8" };
    return {
      save: async function (o) {
        var ext = (o.filename.split(".").pop() || "").toLowerCase();
        var url = URL.createObjectURL(new Blob([o.data], { type: TIPOS[ext] || "application/octet-stream" }));
        var a = doc.createElement("a"); a.href = url; a.download = o.filename;
        doc.body.appendChild(a); a.click(); a.remove();
        setTimeout(function () { URL.revokeObjectURL(url); }, 30000);
      }
    };
  }

  root.ISVCompras = { criarDb: criarDb };
  if (typeof module !== "undefined" && module.exports) module.exports = { criarDb: criarDb };
  if (!(root.document && root.supabase)) return;      // fora do navegador (testes): só a camada de dados

  /* ------------------------------------------------------------------ navegador: login e sessão */
  var D = root.document;
  var sb = root.supabase.createClient(CFG.url, CFG.key, {
    auth: { flowType: "implicit", persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
  var perfil = null, seguindo = false, resolverPronto;
  var pronto = new Promise(function (r) { resolverPronto = r; });
  var db = criarDb(sb, function () { return perfil && perfil.id; });
  var NIVEL = { view: 1, interact: 2, admin: 3, owner: 4 };

  var user = {
    id: function () { return perfil.id; },
    name: function () { return perfil.nome; },
    canEdit: function () { return NIVEL[perfil.nivel] >= 3; },
    can: function (p) { return p === "data.write" ? NIVEL[perfil.nivel] >= 2 : false; },
    isOwner: function () { return perfil.nivel === "owner"; },
    profiles: async function (ids) {
      var r = await sb.from("perfis").select("id,nome,email,nivel").in("id", ids), m = {};
      (r.data || []).forEach(function (p) { m[p.id] = { name: p.nome, email: p.email, owner: p.nivel === "owner" }; });
      return m;
    }
  };

  root.claude = {
    use: async function (nome) {
      if (nome === "downloads") return criarDownloads(D);
      if (nome === "db" || nome === "user") { await pronto; return nome === "db" ? db : user; }
      return null;                                   // sample e assets: indisponíveis fora do claude.ai
    }
  };

  // ---- tela de entrada (usa as cores da própria página)
  var css = D.createElement("style");
  css.textContent =
    "#isv-login{position:fixed;inset:0;z-index:9999;background:var(--bg,#F5F7FA);display:flex;align-items:center;justify-content:center;padding:16px;overflow:auto}" +
    "#isv-login .card{background:var(--surface,#fff);border:1px solid var(--line,#DCE2EB);border-top:4px solid var(--green,#3E9B4F);border-radius:10px;padding:28px;width:100%;max-width:420px;display:flex;flex-direction:column;gap:14px;color:var(--ink,#16233A)}" +
    "#isv-login .marca{font-family:var(--f-display,Georgia,serif);font-weight:600;font-size:1.15rem;color:var(--ink,#16233A)}" +
    "#isv-login[hidden]{display:none}" +
    "#isv-login h2{margin:0}#isv-login p{margin:0;color:var(--muted,#5B6880)}" +
    "#isv-login form{display:flex;flex-direction:column;gap:12px}" +
    "#isv-login .erro{color:var(--bad,#B3261E);font-size:.9rem;min-height:1.2em}" +
    "#isv-login .linha{display:flex;gap:8px;flex-wrap:wrap}";
  D.head.appendChild(css);

  var overlay = D.createElement("div");
  overlay.id = "isv-login"; overlay.setAttribute("role", "dialog"); overlay.setAttribute("aria-modal", "true");
  overlay.innerHTML = '<div class="card" id="isv-card"></div>';
  D.body.appendChild(overlay);
  var card = overlay.querySelector("#isv-card");

  function esc(s) { return String(s).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  function tela(html) { card.innerHTML = '<div class="marca">Instituto São Vicente</div>' + html; overlay.hidden = false; D.documentElement.style.overflow = "hidden"; }
  function fecharTela() { overlay.hidden = true; D.documentElement.style.overflow = ""; }

  function telaEmail(aviso, emailInicial) {
    tela('<h2>Entrar no sistema de compras</h2>' +
      '<p>Digite seu e-mail institucional. Enviaremos um link de acesso, sem senha.</p>' +
      '<form id="isv-f"><label class="f">E-mail<input type="email" id="isv-email" required autocomplete="email" inputmode="email" placeholder="nome@institutosaovicente.com.br" value="' + esc(emailInicial || "") + '"></label>' +
      '<div class="erro" id="isv-erro" role="alert">' + esc(aviso || "") + '</div>' +
      '<button class="btn primary" id="isv-ok" type="submit">Enviar link de acesso</button></form>');
    var f = card.querySelector("#isv-f"), campo = card.querySelector("#isv-email");
    campo.focus();
    f.onsubmit = async function (ev) {
      ev.preventDefault();
      var email = campo.value.trim().toLowerCase(), btn = card.querySelector("#isv-ok"), er = card.querySelector("#isv-erro");
      btn.disabled = true; btn.textContent = "Enviando…"; er.textContent = "";
      var r = await sb.auth.signInWithOtp({ email: email, options: { emailRedirectTo: root.location.origin + root.location.pathname } });
      if (r.error) {
        var m = r.error.message || "";
        er.textContent = /database error|sem acesso/i.test(m) ? "Este e-mail não tem acesso. Use seu e-mail @institutosaovicente.com.br ou peça a liberação ao setor de TI."
          : /rate limit|too many|seconds/i.test(m) ? "Muitos pedidos de link em pouco tempo. Aguarde alguns minutos e tente de novo."
          : "Não foi possível enviar o link. Confira o e-mail e tente de novo.";
        btn.disabled = false; btn.textContent = "Enviar link de acesso"; return;
      }
      telaEnviado(email);
    };
  }
  function telaEnviado(email) {
    tela('<h2>Verifique seu e-mail</h2>' +
      '<p>Enviamos um link de acesso para <b>' + esc(email) + '</b>. Abra o e-mail neste aparelho e clique no link. Pode levar alguns minutos; olhe também a caixa de spam.</p>' +
      '<div class="linha"><button class="btn" id="isv-outro" type="button">Usar outro e-mail</button></div>');
    card.querySelector("#isv-outro").onclick = function () { telaEmail("", email); };
  }
  function telaNome() {
    return new Promise(function (resolve) {
      tela('<h2>Como você se chama?</h2><p>Informe seu nome completo. Ele aparece nas solicitações e no histórico do sistema.</p>' +
        '<form id="isv-f"><label class="f">Nome completo<input type="text" id="isv-nome" required minlength="3" autocomplete="name"></label>' +
        '<div class="erro" id="isv-erro" role="alert"></div><button class="btn primary" id="isv-ok" type="submit">Continuar</button></form>');
      var campo = card.querySelector("#isv-nome"); campo.focus();
      card.querySelector("#isv-f").onsubmit = async function (ev) {
        ev.preventDefault();
        var nome = campo.value.trim().replace(/\s+/g, " "), btn = card.querySelector("#isv-ok"), er = card.querySelector("#isv-erro");
        if (nome.split(" ").length < 2) { er.textContent = "Informe nome e sobrenome."; return; }
        btn.disabled = true;
        var r = await sb.rpc("definir_meu_nome", { p_nome: nome });
        if (r.error) { er.textContent = "Não foi possível salvar. Tente de novo."; btn.disabled = false; return; }
        resolve(nome);
      };
    });
  }
  function telaFalha(msg) {
    tela('<h2>Não foi possível entrar</h2><p>' + esc(msg) + '</p><div class="linha"><button class="btn primary" id="isv-t" type="button">Tentar de novo</button></div>');
    card.querySelector("#isv-t").onclick = function () { root.location.replace(root.location.pathname); };
  }

  async function carregarPerfil(uid) {
    for (var i = 0; i < 4; i++) {
      var r = await sb.from("perfis").select("id,email,nome,nivel").eq("id", uid).maybeSingle();
      if (r.data) return r.data;
      await new Promise(function (ok) { setTimeout(ok, 500); });
    }
    throw new Error("Seu usuário ainda não tem perfil no sistema. Fale com o setor de TI.");
  }
  function instalarSaida() {
    var marca = D.querySelector("header .brand");
    if (!marca || D.getElementById("isv-user")) return;
    var s = D.createElement("span");
    s.id = "isv-user"; s.style.cssText = "margin-left:auto;display:flex;align-items:center;gap:8px;font-size:.9rem;opacity:1";
    s.innerHTML = esc(perfil.nome) + ' <button class="btn ghost" type="button" style="color:var(--navy-ink);border:1px solid rgba(255,255,255,.4)">Sair</button>';
    s.querySelector("button").onclick = async function () { await sb.auth.signOut(); root.location.replace(root.location.pathname); };
    marca.appendChild(s);
  }
  async function seguir(sessao) {
    if (seguindo) return; seguindo = true;
    try {
      perfil = await carregarPerfil(sessao.user.id);
      if (!perfil.nome) perfil.nome = await telaNome();
      fecharTela(); instalarSaida(); resolverPronto();
    } catch (e) { seguindo = false; telaFalha(e.message || "Erro desconhecido."); }
  }

  // link expirado ou já usado: o Supabase devolve o erro no endereço
  var aviso = "";
  try {
    var p = new URLSearchParams((root.location.hash || "").replace(/^#/, "") || root.location.search);
    if (p.get("error_code") === "otp_expired") aviso = "Este link expirou ou já foi usado. Peça um novo.";
    else if (p.get("error")) aviso = "Não foi possível validar o link. Peça um novo.";
  } catch (e) { /* ignora */ }

  tela("<p>Carregando…</p>");
  sb.auth.onAuthStateChange(function (evento, sessao) {
    // sem await aqui dentro (o Supabase trava); a continuação roda fora do callback
    if (evento === "SIGNED_OUT") return;
    if (sessao && (evento === "INITIAL_SESSION" || evento === "SIGNED_IN")) setTimeout(function () { seguir(sessao); }, 0);
    else if (evento === "INITIAL_SESSION" && !sessao) setTimeout(function () { telaEmail(aviso); }, 0);
  });
})(typeof window !== "undefined" ? window : globalThis);
