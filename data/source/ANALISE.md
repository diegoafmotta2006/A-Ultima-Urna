# Tekken mobile — o que o REA encontrou

Análise feita abrindo os artefatos do pacote com o REA (MCP). Tudo aqui é
observação de artefato, com a evidência correspondente.

## Identidade do alvo

| Item | Valor |
|---|---|
| Pacote | `eu.bandainamcoent.tekkenmobile` v1.5 (versionCode 498080) |
| Formato | XAPK = APK 39,9 MB + OBB 157,8 MB |
| Engine | Unity **2017.4.1f1**, backend **Mono** (não IL2CPP) |
| `Assembly-CSharp.dll` | 4.203.008 bytes, SHA-256 `915b93e4faf85da12165e5b7cc2b1ff98907ca543ab721c1e27c3763377361d7`, MVID `360142c8-e11d-4946-8070-b3952b26d657` |
| Metadados | v2.0.50727, 5142 tipos, 28.940 métodos, 21.143 campos, cobertura completa |
| Evidência REA | `ev_5a0f8ce7eda3d48c64b729d26153b2228f393adcc2dd622aad84d504294ce33d` (artefato) · `ev_f8c702807c826faa2b66662d603473283a41284020319bbacf844a0ad06fb0b0` (membros) |

## O achado principal: onde a física realmente está

O combate **não é C#**. O C# é só a ponte. O motor de luta é uma biblioteca
nativa `lib/armeabi-v7a/libBattleCore.so` (1.459.928 bytes), chamada por
`BattleCoreMain` / `BCInterfaceUnity` via exports `BattleCoreEngineTick`,
`BattleCoreEngineCreate`, `BattleCorePlayerInterface_*`.

E os dados de personagem (movimento, golpes, frames) **não estão no pacote**.
O arquivo de configuração do app (`assets/bin/Data/f9bbc86a6387b4d4a947a90cd386ba0b`,
um TextAsset "BNSFightApplicationInfoService") declara:

```json
"awsS3Bucket": "contents.truefighting.bnsv.ca",
"preloadBundlesInclude": ["bnsv/","common/","bnsi/stage/","bnsi/character/","bnsi/mothead"]
```

Ou seja: os bundles `bnsi/character/` e `bnsi/mothead` — onde ficam os
parâmetros e as animações/motions de cada lutador — são **baixados de um CDN**
na primeira execução. Varri os 2002 arquivos do OBB e os 4 do APK procurando os
campos de dados (`InputFrame`, `mothead`, `BaseParam`): só aparecem dentro de
`Assembly-CSharp.dll` e `libBattleCore.so` (como nomes de campo/símbolo), nunca
como dados. O jogo foi encerrado em 2019, então esse CDN não é mais uma fonte
confiável.

**Conclusão:** não existe "tabela de física do Tekken" dentro desse pacote. O
que existe é o *motor* e o *esquema dos parâmetros* — e isso eu extraí.

## O esquema do motor (extraído de `libBattleCore.so`)

Chaves de parâmetro encontradas como strings do binário nativo:

`air_combo_limit`, `armor_damage_rate`, `damage_adjust_aircombo`,
`damage_adjust_card_1..4`, `hitstop_frame_armor`, `hitstop_speed_armor`,
`wall_distance`, `player_distance_limit`, `player_start_position`,
`interval_frame`, `effect_frame`, `event_speed_after_ko`,
`event_speed_exclusive_self`, `camera_param`, `buff_table`, `mothead_table`,
`mothead_script`, `card_point_per_attack`,
`card_point_per_damage`, `card_point_per_time`.

Funções exportadas que revelam o modelo de simulação:

```
BattleCoreEngineTick / SetFrameRate / SetGameSpeed / SetResolution
BattleCorePlayerInterface_GetJuggleFrame / GetRecoveryFrame
BattleCorePlayerInterface_GetWallDistance / GetWallLimitSize
BattleCorePlayerInterface_GetPlayerDistanceLimit
BattleCorePlayerInterface_GetMotheadName / GetMotheadNameList
BattleCoreEngine::flipPosition / recordPosition / restorePosition
subfunc_CreateMotheadFromTable_
GetCurrentSpeed / SetSpeedRate / ChangeMotionSpeed / ChangeSpeed
```

Leitura: o jogo se comporta como um lutador **2.5D** — posição de combate
essencialmente em X (o eixo de profundidade é visual; `flipPosition` vira o
personagem), `wall_distance` como limite de arena, e movimento definido por
**mothead** (script de motion por golpe) com velocidade modulada por
`GetCurrentSpeed`/`SetSpeedRate`. Não é um corpo rígido com gravidade/impulso
como no SF SNK: é animação dirigida + tabela de frames.
`GetJuggleFrame` e `GetRecoveryFrame` são os "frames de juggle" e de
recuperação, contados em **frames**, não em segundos.

## O modelo de estado (extraído do C#, confiável)

`BandaiNamco.Common.FighterStateEnum.eState`:

```
None, Idle, Grounded, WeakHitStun, StrongHitStun, BlockStun,
Juggled, Falling, Thrown, Rising
```

`FighterActionEnum.eAction`:

```
None, Card1..Card5, MoveLeft, MoveRight, Charge, Block, BasicAttack,
LongRangeAttack, RageArt, LauncherWaza, StrikeWaza, GuardBreakWaza,
StunWaza, ThrowWaza, SpecialWaza
```

E os nomes de motion associados às ações (string literals do assembly):

```
MoveLeft  -> "Swipe_step_backward"     MoveRight -> "Swipe_step_forward"
Block     -> "guard_start_LeftPanel"   Charge    -> "Hold_dash_attack"
BasicAttack -> "attack_short_combo"    Card1..5  -> "skill_"
```

Isso é o suficiente para reconstruir a máquina de estados de um jogo de luta
3D estilo Tekken. Está implementado em `FighterStateMachine.cs` nesta pasta.

## Valores numéricos que o pacote entrega

Poucos, mas reais (campos default declarados no código):

| Parâmetro | Valor | Origem |
|---|---|---|
| `StageLength` (comprimento da arena) | 31,6 | `FighterCloneTuningAsset` |
| `MaxDistBtwnFighters` | 5,0 | idem |
| `MinOpponentStateFrameDiscrepancyAbort` | 38 frames | idem |
| `minRating` / `maxRating` (clonagem de IA) | -10 / +10 | `ChainStatistics` |

O resto (velocidades, gravidade de juggle, hitstun, dano) **não está aqui**.

## Se ainda quiser os números do Tekken

Três caminhos, em ordem de custo:

1. **Rodar o jogo e medir** — instalar em um Android/emulador, gravar a tela a
   60 fps e medir frames de hitstun, distância de dash, altura de juggle. Dá
   números reais e é o único caminho que ainda funciona com o servidor fora do ar.
2. **Baixar os bundles do CDN** — `contents.truefighting.bnsv.ca` (S3) servia
   `bnsi/character/` e `bnsi/mothead`. Exige a metadata de versão do app e
   provavelmente já não responde; é serviço de terceiros e não é algo que eu
   deva tentar puxar por conta própria.
3. **Instrumentar o `libBattleCore.so`** — com Frida no Android, ler
   `GetCurrentSpeed`, `GetJuggleFrame` e os campos de `BattleCorePlayerInterface`
   em tempo real. Precisa de um aparelho rodando o jogo (não roda mais online,
   mas o modo offline/tutorial pode iniciar).

Se você tiver um APK de outra build que já venha com os bundles embutidos (alguns
XAPKs de terceiros trazem OBB maior), me passa que eu abro com o REA do mesmo
jeito — aí sim dá para extrair os motheads.

## O que fazer com o que já saiu daqui

- `FighterStateMachine.cs` — máquina de estados pronta (Idle → HitStun →
  Juggled → Falling → Rising), com hitstop, `juggleFrame`, `recoveryFrame`,
  limite de parede e dash. Os *nomes* dos estados e das ações são do jogo; os
  valores são seus para calibrar.
- `ENGINE-BATTLECORE.md` — o detalhamento técnico e a lista completa de chaves.
- Para a parte numérica, use `01-sf-snk-mugen/` como referência de escala
  (tempo de ar, distância de salto, atrito) e ajuste no seu engine.
