# A Última Urna — Documento do Projeto

> **Resumo:** protótipo jogável de jogo de luta 2D, feito em **Godot 4.7.2 (GDScript)**,
> com um único código-fonte que gera **duas versões**: navegador (Web/HTML5) e Android.
> Hoje já tem partida local (2 jogadores ou vs CPU), rounds, golpes, dano, bloqueio,
> controles de toque e build Web funcionando.
>
> **Status:** Milestone 0 (protótipo jogável) concluído e validado.
> **Data deste documento:** 2026-11-05

---

## 1. O que é o projeto

**A Última Urna** é um jogo de luta 2D 1v1, no estilo clássico de arcade (ex.: Street
Fighter / KOF), focado em:

- Dois personagens frente a frente numa arena plana.
- Golpes com **frame data** (startup → active → recovery), alcance, dano e hitstun.
- Bloqueio, knockback e rounds (melhor de 3).
- Começo **local** (2 jogadores no mesmo aparelho/gamepad ou contra a CPU).
- Distribuição em **duas plataformas com o mesmo código**:
  1. **Navegador de desktop** (Web/HTML5).
  2. **App Android** (APK/AAB instalável).

O nome definitivo do jogo é **A Última Urna** (o nome de trabalho antigo, "FightLab 2D",
ainda aparece em alguns trechos históricos deste documento e em nomes de arquivos).

---

## 2. Onde queremos chegar (visão e roadmap)

### Visão de produto
Um jogo de luta 2D enxuto e responsivo, com arte própria, que roda no navegador e
como app Android, começando local e evoluindo (se fizer sentido) para online.

### Roadmap por fases

| Fase | Objetivo | Estado |
|------|----------|--------|
| **M0 — Protótipo jogável** | Arena, 2 lutadores, golpes, dano, rounds, input, build Web | **Concluído** |
| **M1 — Identidade visual e áudio** | Trocar polígonos por sprites animados, cenário, efeitos, sons | Em andamento |
| **M2 — Profundidade de gameplay** | Especiais por comando, agachar, bloqueio alto/baixo, agarrão, combo, barra de especial | Pendente |
| **M3 — Conteúdo** | 2+ personagens selecionáveis, seleção de personagem, telas de menu/resultado | Pendente |
| **M4 — Polimento mobile** | Controles de toque melhores, PAUSE, performance, APK assinado, ícone/splash | Pendente |
| **M5 — Online (opcional)** | Multiplayer com rollback netcode | Futuro / fora do escopo atual |

> Decisão registrada: **multiplayer online NÃO entra agora**. Primeiro local.
> Rollback netcode é um projeto à parte e muito mais complexo.

---

## 3. O que já está construído (M0)

- Arena estática 1280×720 com chão e paredes (colisão física).
- Dois lutadores controláveis, com máquina de estados.
- Física com gravidade, pulo e movimentação, travada a **60 Hz**.
- Dois tipos de golpe: **leve** e **forte**, cada um com startup/active/recovery,
  hitbox própria, dano, knockback e hitstun.
- **Feedback de impacto**: hitstop nos dois lutadores, flash no corpo (branco no acerto,
  azul no bloqueio) e faísca no ponto de contato.
- **Hitbox/hurtbox** por cálculo de retângulos (AABB) por frame.
- **Bloqueio** segurando a direção contrária ao oponente.
- Sistema de **rounds melhor de 3**, placar e reset de round.
- **HUD**: barras de vida (P1/P2), placar de rounds e mensagem central (round/vencedor).
- **Input unificado**: teclado, gamepad e botões de toque.
- **Botões de toque** para Android/móvel (controlam o P1).
- **Toggle de CPU** no HUD (IA simples para o P2).
- **Export Web (HTML5)** funcionando e testado.
- Projeto validado: importa sem erros, roda 400 frames sem erro, e um teste funcional
  confirmou dano de golpe leve (vida 100 → 94).
- Este documento + `README.md` + `.gitignore` + preset de export Web.

---

## 4. Stack técnica e por quê

| Item | Escolha | Motivo |
|------|---------|--------|
| Engine | **Godot 4.7.2** | Exporta Web + Android do mesmo projeto; ótimo 2D; gratuito/open source |
| Linguagem | **GDScript** | Nativa da engine, rápida de iterar; sem necessidade de C# |
| Renderer | **GL Compatibility** | Máxima compatibilidade com navegador e Android antigo |
| Física | **60 Hz fixo** | Base para frame data consistente |
| Resolução | **1280×720** (`canvas_items`, aspect `keep`) | Escala bem em telas variadas |
| Input | `InputBridge` (autoload) | Unifica teclado + gamepad + toque num só ponto |
| Build Web | Export template oficial `web_nothreads_release.zip` | Sem threads = hospedagem simples |
| Build Android | Export template oficial (via editor) | APK/AAB |

**Por que não Unity/Phaser/etc.:** Godot dá o melhor equilíbrio entre 2D, export
Web e Android nativo sem trocar de código, e o resultado roda bem em aparelho modesto.

**Não há dependências externas/plugins.** Só Godot padrão + GDScript.

---

## 5. Estrutura de arquivos

```
projeto/
├─ project.godot          # config da engine (viewport, física, autoload, renderer)
├─ export_presets.cfg     # preset de export "Web"
├─ README.md              # como rodar/exportar (guia rápido)
├─ PROJECT.md             # ESTE documento (visão completa + handoff)
├─ .gitignore             # ignora .godot/ e builds
├─ icon.svg               # (a adicionar) ícone do projeto
├─ scenes/
│  ├─ main.tscn           # arena + chão/paredes + P1/P2 + HUD
│  ├─ fighter.tscn        # lutador: colisão + corpo em polígonos
│  └─ hud.tscn            # barras, placar, botão CPU, botões de toque
├─ scripts/
│  ├─ game.gd             # regras da partida: rounds, placar, reset, separação
│  ├─ fighter.gd          # máquina de estados, física, ataques, hit/hurtbox, IA
│  ├─ hud.gd              # atualização do HUD + input dos botões de toque
│  └─ input_bridge.gd     # autoload: teclado + gamepad + toque
├─ build/
│  └─ web/                # build Web exportado (index.html, .wasm, .pck...)
└─ .godot/                # cache da engine (NÃO versionar)
```

> `build/` é gerado e está no `.gitignore`; para o GitHub você normalmente **não
> commita** o build, só o código-fonte.

---

## 6. Arquitetura e como funciona

### 6.1 Cena principal (`scenes/main.tscn`)
- **Background**: dois `Polygon2D` (céu e chão).
- **Floor / WallLeft / WallRight**: `StaticBody2D` com colisão (camada 1).
- **P1 / P2**: instâncias de `fighter.tscn`, com `player_id` (1/2) e `body_color`
  sobrescritos na instância.
- **HUD**: instância de `hud.tscn` (CanvasLayer).

### 6.2 Lutador (`scripts/fighter.gd`, `class_name Fighter`)
Máquina de estados (`enum State`):

```
IDLE → WALK → JUMP → ATTACK → HIT → KO
```

Regras principais:
- `_physics_process(delta)` lê input, aplica gravidade, resolve o estado e chama
  `move_and_slide()`.
- **Ataque**: `_start_attack("light"/"heavy")` copia os dados de `ATTACKS`,
  `_advance_attack()` percorre startup→active→recovery, e durante o *active* chama
  `_try_hit()`.
- **Hitbox**: `_attack_rect()` (retângulo do golpe, espelhado por `facing`).
- **Hurtbox**: `hurt_rect()` (retângulo do corpo).
- **Acerto**: `_attack_rect().intersects(opponent.hurt_rect())` → `opponent.receive_hit(...)`.
- **Bloqueio**: `_is_blocking()` = no chão, segurando direção oposta ao oponente,
  e sem estar atacando. Reduz dano/knockback/hitstun.
- **Facing**: `update_facing()` (não muda durante ATTACK/HIT/KO), espelha o corpo
  com `_body.scale.x = facing`.
- **IA** (`_ai_input`): aproxima se longe, recua se perto, ataca com cooldown.

### 6.3 Dados de golpe (`ATTACKS` em `fighter.gd`)
Cada golpe é um `Dictionary`:

| Campo | Significado |
|-------|-------------|
| `startup` | Tempo antes de acertar (segundos a 60 Hz) |
| `active` | Janela em que a hitbox pode acertar |
| `recovery` | Tempo de recuperação (não pode agir) |
| `damage` | Dano |
| `box` | Tamanho da hitbox (`Vector2`) |
| `offset` | Deslocamento da hitbox em relação ao corpo (espelhado por `facing`) |
| `knock` | Knockback (`x` é aplicado na direção do `facing`) |
| `hitstun` | Tempo que o atingido fica travado |
| `hitstop` | Tempo que **os dois** ficam congelados no acerto (leve 0.05 s, forte 0.10 s) |

### 6.4 Partida (`scripts/game.gd`)
- `ROUNDS_TO_WIN = 2` (melhor de 3).
- Conecta sinais: `health_changed`, `defeated`, `hud.cpu_toggled`.
- `_reset_positions()` reposiciona e restaura vida.
- `_on_defeated()` dá o round ao adversário, mostra mensagem, espera e reinicia o round
  ou a partida.
- `_separate_bodies()` evita sobreposição dos corpos (empurra ambos).
- `_process()` chama `update_facing()` de cada lutador todo frame.

### 6.5 HUD (`scripts/hud.gd`)
- `set_health(player, current, max)`, `update_round_wins(p1,p2)`, `show_message(text)`.
- Botões de toque ligados via `_bind_hold(button, action)` → `InputBridge.set_virtual`.
- Botão **CPU: OFF/ON** emite `cpu_toggled`.
- Botões de toque aparecem só se `DisplayServer.is_touchscreen_available()`.

### 6.6 Input (`scripts/input_bridge.gd`, autoload `InputBridge`)
- `held(player, action)` combina: estado virtual (toque) → gamepad → teclado.
- `set_virtual(player, action, pressed)` usado pelos botões de toque.
- **Edge detection** (acabou de pressionar) fica no `fighter.gd` (variáveis `_prev_*`).
- Teclas: definidas em `KEYS` (P1: A/D/W/F/G, P2: setas + K/L).

---

## 7. Controles

| Ação | Player 1 | Player 2 | Gamepad |
|------|----------|----------|---------|
| Mover | `A` / `D` | `←` / `→` | Analógico esq. / DPad |
| Pular | `W` | `↑` | `A` |
| Golpe leve | `F` | `K` | `X` |
| Golpe forte | `G` | `L` | `Y` |
| Bloqueio | segurar direção contrária ao oponente | idem | idem |

- **Toque (Android/móvel):** `<` `>` `JUMP` `LIGHT` `HEAVY` (controlam P1).
- **CPU:** botão `CPU: ON` no HUD liga a IA no P2.

---

## 8. Como rodar e reexportar

### Abrir no editor
Importe a pasta no Godot 4.7.x e rode com F5. Cena principal: `scenes/main.tscn`.

### Rodar a versão Web localmente
```bash
cd build/web && python3 -m http.server 8000 --bind 0.0.0.0
# abra http://localhost:8000 no navegador
```

### Reexportar a versão Web (headless)
```bash
cd /root/projeto/projeto
/tmp/opencode/godot/Godot_v4.7.2-stable_linux.arm64 \
  --headless --path . --export-release "Web" build/web/index.html
```

> **Atenção (ambiente):** o binário do Godot usado no desenvolvimento ficava em
> `/tmp/opencode/godot/` (temporário). Se não existir mais, baixe novamente:
> `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.arm64.zip`
>
> Os **export templates** 4.7.2 ficam em:
> `~/.local/share/godot/export_templates/4.7.2.stable/`
> (baixados de `Godot_v4.7.2-stable_export_templates.tpz`, ~1,28 GB).

---

## 9. Exportar para Android (fazer num PC)

Este ambiente é **Termux/Android aarch64 (proot Debian)** — montar APK aqui é inviável
porque as build-tools do Android SDK são x86_64. Faça num PC:

1. JDK 17+ e Android SDK (Android Studio ou command-line tools).
2. Godot 4.7.x + Export Templates 4.7.2.
3. **Editor → Configurações do Editor → Exportar → Android**: preencher
   `Android SDK Path`, `Java SDK Path` e `Debug Keystore`.
4. **Projeto → Exportar → Adicionar → Android**: definir `Package Name`
   (ex.: `com.diegoafmotta.ultimaurna`), escolher APK (teste) ou AAB (Play Store).
5. Instalar: `adb install -r build/android/a-ultima-urna.apk`.

Detalhes completos no `README.md`.

---

## 10. Limitações atuais / dívida técnica

- Arte usa sprites PNG estáticos por pose (faixa/azul); falta animação/spritesheet e
  cenário. Os polígonos permanecem como fallback quando `art_set` está vazio.
- Sem áudio (o impacto tem hitstop, flash e faísca, mas nenhum som).
- Hitbox/hurtbox por **AABB manual** (não `Area2D`); funciona, mas o ideal é migrar
  para `Area2D` + `CollisionShape2D` quando entrar arte/mais golpes.
- Sem golpes especiais por comando, sem agachar, sem bloqueio alto/baixo, sem agarrão.
- IA simples (não defensiva, sem leitura de distância fina).
- 2 jogadores no mesmo celular é ruim sem gamepad; toque controla só o P1.
- `build/` não é versionado (correto), mas o Web exige servidor HTTP (não abre via `file://`).
- Sem menu inicial/tela de seleção/pause.

---

## 11. Próximos passos priorizados

**M1 — Arte e áudio**
1. Criar spritesheet (idle/walk/jump/attack/hit/KO) e usar `AnimatedSprite2D`.
2. Trocar o corpo de polígonos por `AnimatedSprite2D` dentro de `fighter.tscn`,
   mantendo `hurt_rect()` compatível.
3. Adicionar sons (golpe, acerto, bloqueio, KO) com `AudioStreamPlayer`.
4. Cenário/parallax e efeitos de impacto.

**M2 — Gameplay**
5. Golpes especiais com input por comando (ex.: ↓↘→ + golpe) — detectar sequência de
   direções com buffer de input.
6. Agachar e bloqueio alto/baixo; ajustar `hurt_rect()` por postura.
7. Cancelamento/combo e barra de especial.

**M3 — Conteúdo/UI**
8. Tela de menu, seleção de personagem e resultado.
9. Segundo personagem (novos valores em `ATTACKS` e cores/arte).

**M4 — Mobile**
10. Botões de toque melhores (zona morta, tamanho, ambos jogadores opcional).
11. Pause e ajuste de performance.
12. Gerar APK assinado num PC; ícone e splash.

---

## 12. Convenções e invariantes (não quebrar)

- Lógica de combate roda em **`_physics_process`** a 60 Hz — não mover para `_process`.
- **Facing**: não alterar durante ATTACK/HIT/KO.
- Hitbox é espelhada por `facing`; `knock.x` é aplicado na direção do `facing`.
- Todo input passa por **`InputBridge.held()`**; detecção de borda fica no lutador.
- Sinais existentes (`health_changed`, `defeated`, `cpu_toggled`) — manter contrato.
- `MAX_HEALTH = 100` e `ROUNDS_TO_WIN = 2` centralizados; não espalhar números mágicos.
- Sem comentários óbvios no código; nomes em inglês, mensagens de UI em português.

---

## 13. Notas para a próxima IA (handoff)

- **Ambiente do desenvolvimento:** Termux/Android + proot Debian (aarch64). Godot
  arm64 rodou via `--headless`. Download do Android SDK/buils x86_64 não funciona aqui.
- **O que foi validado:** import sem erro, execução headless por 400 frames sem erro,
  e teste de combate confirmando dano (100 → 94). Build Web exportado e servido com
  `python3 -m http.server`.
- **Como reproduzir a validação:** rode o binário do Godot com
  `--headless --path . --import` e depois `--headless --path . --quit-after 400`.
- **Build Web atual:** `build/web/` com `index.html`, `index.js`, `index.wasm` (~40 MB),
  `index.pck` e worklets de áudio.
- **Onde mexer primeiro:** `scripts/fighter.gd` (gameplay) e `scenes/fighter.tscn`
  (visual). `scripts/game.gd` para regras de partida. `scenes/hud.tscn` para UI.
- **Cuidado:** o autoload `InputBridge` é referenciado globalmente; ele precisa estar
  em `[autoload]` no `project.godot`.
- **Ao adicionar sprite:** mantenha a origem do `Fighter` nos **pés** (y=0 na base),
  pois `hurt_rect()`, o chão (y=600) e o espelhamento dependem disso.
- **Ao adicionar golpe:** adicione entrada em `ATTACKS` e deixe `damage/box/offset/
  knock/hitstun` coerentes; o fluxo já trata startup/active/recovery.

---

## 14. GitHub e licença

- **Commitar:** `project.godot`, `export_presets.cfg`, `scenes/`, `scripts/`,
  `README.md`, `PROJECT.md`, `.gitignore`.
- **Não commitar:** `.godot/`, `build/`, export templates, `*.apk`, `*.aab`.
- **Licença:** MIT (permissiva) — ver `LICENSE`.
- Repositório: `https://github.com/diegoafmotta2006/A-Ultima-Urna`.

---

## 15. Glossário

- **Frame data**: números de frames de cada fase de um golpe.
- **Startup**: quadros até o golpe ficar ativo.
- **Active**: quadros em que a hitbox pode acertar.
- **Recovery**: quadros após o golpe, sem poder agir.
- **Hitbox**: área que causa dano.
- **Hurtbox**: área que recebe dano.
- **Hitstun**: travamento do atingido após levar golpe.
- **Knockback**: empurrão ao levar golpe.
- **Facing**: direção para onde o lutador está virado.
- **Rollback netcode**: técnica de sincronização para multiplayer online (futuro).
