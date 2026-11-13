# BattleCore — referência técnica extraída do binário

Tudo abaixo saiu do artefato (strings e exports de
`lib/armeabi-v7a/libBattleCore.so`, 1.459.928 bytes, e dos metadados de
`Assembly-CSharp.dll`). É a lista de "o que existe" — os valores desses
parâmetros vêm dos bundles `bnsi/character/` e `bnsi/mothead`, que **não** estão
no pacote (ver `ANALISE.md`).

## Divisão de responsabilidades

```
Unity (C#, Assembly-CSharp.dll)
  └─ BattleCoreMain / BCInterfaceUnity  ── P/Invoke ──┐
                                                      │
libBattleCore.so (C++ nativo)                         │
  ├─ BattleCore::Engine          (tick, frame rate, resolução, posições)
  ├─ BattleCore::PlayerInterface (vida, flags, distâncias, mothead)
  ├─ mothead (motion por golpe)  ← bundles bnsi/mothead (CDN)
  └─ GameParam / BaseParam       ← bundles bnsi/character (CDN)
```

O C# **não** simula luta: ele registra eventos, lê o estado e desenha. A
simulação é `BattleCoreEngineTick`, chamado a uma taxa fixa
(`BattleCoreEngineSetFrameRate`, `setGameSpeed`).

## Chaves de parâmetro nativas

Controle de combate / juggle:

```
air_combo_limit          hitstop_frame_armor      hitstop_speed_armor
armor_damage_rate        damage_adjust_aircombo   damage_adjust_card_1..4
wall_distance            player_distance_limit    player_start_position
interval_frame           effect_frame             buff_table
```

Velocidade / tempo:

```
event_speed_after_ko     event_speed_exclusive_self
GetCurrentSpeed          SetSpeedRate   ChangeMotionSpeed   ChangeSpeed
```

Economia de cartas (sistema de "waza cards"):

```
card_point_per_attack    card_point_per_damage    card_point_per_time
```

Animação / motion:

```
mothead_table            mothead_script           camera_param
subfunc_CreateMotheadFromTable_   GetMotheadName   GetMotheadNameList
```

## API exportada (o que dá para ler em runtime)

Engine:

```
BattleCoreEngineCreate / Delete / Tick / IsExist / IsSequenceEnd
BattleCoreEngineSetFrameRate / SetGameSpeed / SetResolution / SetGameMode
BattleCoreEngineGetTickTime / GetUsedMemorySize / GetMyPlayerNo / GetCameraInfo
BattleCoreEngineLockSharedMemory / UnlockSharedMemory / SendEvent
BattleCoreEngine::flipPosition / recordPosition / restorePosition
BattleCoreEngine::overrideWallThrowShiftLength
```

Jogador:

```
GetLife / GetLifeMax / GetLifeExtra        GetWinRoundCount / Max
GetPosition (implícito em GetCharacterTransform / CharacterMatrix)
GetJuggleFrame / GetRecoveryFrame          GetEnemyDistance
GetWallDistance / GetWallLimitSize         GetPlayerDistanceLimit
GetFlagArray                               GetMotheadName / List
GetWazaCardArray / Info / Num / Type       GetComboNum / GetChainNum
GetSpecialAttackPoint / Max                IsRage
GetDamageArray                             GetCharacterTransform / Matrix
GetHitObjectInfo / SetHitObjectInfo        IsCurrentAttackObjectNear
```

`GetFlagArray` é a fonte dos estados: `FighterState.GetStateFromFlags` mapeia
índices de flag para `eState` (Idle=20, Grounded=3, WeakHitStun=8,
StrongHitStun=9, Juggled=10, BlockStun=11, Thrown=12, Falling=1).

## Eventos (nomes exatos do motor)

Combate: `evt_hit`, `evt_guard`, `evt_damage`, `evt_guard_loop_start/end`,
`evt_guard_se`, `evt_hit_light/fire/water/earth/lightning/darkness`,
`evt_downef_reserve_light/heavy` (+`_opp`), `evt_effect_down_light/heavy`,
`evt_wallthrowshift_start/back`, `evt_override_wallthrow_shift_6`,
`evt_battle_flipposition`, `evt_battle_recordposition`,
`evt_battle_restoreposition`, `evt_battle_recordstartposition`,
`evt_battle_unlinkthrow`.

Round / fluxo: `gamesys_battle_start`, `gamesys_battle_next_round`,
`gamesys_battle_reset`, `gamesys_ko`, `gamesys_ko_ef`, `gamesys_win`,
`gamesys_timeup`, `gamesys_load_character_start/finish`,
`gamesys_load_next_chara`, `gamesys_instance_chara`, `gamesys_uninstance_chara`,
`gamesys_use_card`, `gamesys_setup_stage_effect`,
`gamesys_battle_change_player_name`, `gamesys_battle_bgm_start/end`.

Áudio/voz: `evt_kiai_voice`, `evt_sound_voice_attack1/2`, `evt_sound_voice_cry`,
`evt_sound_voice_damage1/2`, `evt_sound_voice_dead`, `evt_sound_voice_ko`,
`evt_cry_voice` (+`_opp`, `_noface`).

Câmera: `evt_cam_shakecam`, `evt_cam_forcegamecam`,
`evt_cam_stopcamera_gameengine`, `evt_cameraanim_start/end`,
`evt_cam_shakecam_attnrate`, `evt_cam_shakecam_ignorespeed`.

Modelo/efeito: `evt_model_visible/invisible`,
`evt_model_stabilize_swingbone(_shift)`, `evt_eff_starburst_start/end`,
`evt_eff_draw_trace`, `evt_eff_clear_trace`, `evt_skinny_start/stop/minmax`,
`evt_setmodelflag_*` (asa, mrx, yos, cla...).

Nomes de personagem aparecem no binário (`DevilJin_Wing_Speed`,
`evt_setmodelflag_yos_katana_l/r`) — são ganchos específicos de personagem, não
tabelas de física.

## Ações → motion (string literals do C#)

```
MoveLeft    -> Swipe_step_backward      MoveRight   -> Swipe_step_forward
Block       -> guard_start_LeftPanel    Charge      -> Hold_dash_attack
BasicAttack -> attack_short_combo       Card1..Card5 -> skill_
```

## O que isso significa para o seu jogo

Se você quer um lutador estilo Tekken, o que vale copiar daqui é a
**arquitetura**, não os números:

1. **Tick fixo** e `gameSpeed` como multiplicador global (o engine nativo faz
   isso; é o que garante consistência de frame data).
2. **Estados** exatamente como `eState` (o `FighterStateMachine.cs` implementa).
3. **Motion por golpe** (mothead): cada ataque é um script de keyframes com
   eventos em frames (`evt_hit` no frame N). Isso é o oposto de física
   contínua — e é o que dá o "feel" de Tekken.
4. **Limites de arena** (`wall_distance`, `player_distance_limit`) e câmera em
   trilho, sem colisão física real.
5. **Flags** em vez de `if` espalhado: um `GetFlagArray` com um mapa
   flag → estado é fácil de debugar e de sincronizar em rede.
