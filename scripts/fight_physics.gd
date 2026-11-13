class_name FightPhysics
extends RefCounted

## Camada de fisica compartilhada: Street Fighter vs SNK (MUGEN) + Tekken.
##
## ============================ FONTES MEDIDAS ============================
## Lado Street Fighter (extraido de "street-fighter-snk-en-win.rar"):
##   chars/02/ryu94.cns  [Velocity] walk.fwd=3, walk.back=-2, jump.neu=-7.5,
##                       jump.fwd=3.4, jump.back=-3.9, yaccel=.34,
##                       [Movement] stand.friction=.89
##   chars/20/ryusnk.cns [Velocity] walk.fwd=2.8, jump.neu=-11.0, yaccel=.72
##   HitDefs (ryu94.cns):
##     leve  -> ground.velocity=-5, ground.hittime=12f, ground.slidetime=11f,
##              air.velocity=(-2,-6), pausetime=14f, guard.hittime=19f,
##              ground.cornerpush.veloff=-10
##     forte -> ground.velocity=-9, ground.hittime=20f, ground.slidetime=21f,
##              pausetime=14f, guard.hittime=29f, cornerpush=-18
##     launcher (state 1300) -> ground.velocity=(-2.5,-7), yaccel=.51,
##              ground.hittime=20f, fall=1
##
## Lado Tekken (extraido de "tekken-1-5.apk" -> Assembly-CSharp.dll):
##   FighterStateEnum.eState = Idle, Grounded, WeakHitStun, StrongHitStun,
##     BlockStun, Juggled, Falling, Thrown, Rising
##   PlayerCharacter.m_wall_limit_size / getWallLimitSize()
##   libBattleCore.so: "damage_adjust_aircombo", "wall_distance",
##     "hitstop_speed_armor", "GetJuggleFrame"
##   -> modelo: launch, juggle com dano decrescente, wall splat, queda e
##      levantada (Rising) com invulnerabilidade.
##
## ============================ CONVERSAO =================================
## MUGEN roda a 60 Hz e seus personagens tem ~100 px de altura. O nosso
## lutador tem BODY_HEIGHT = 112 px, entao:
##   escala = 112 / 100 = 1.12
##   px/s   = px/quadro * 60 * 1.12 = px/quadro * 67.2
const MUGEN_TO_GODOT := 67.2
const FPS := 60.0

# ------------------------------------------------------------ movimento (SF)
const WALK_FWD := 3.0 * MUGEN_TO_GODOT          # 201.6 px/s
const WALK_BACK := 2.0 * MUGEN_TO_GODOT         # 134.4 px/s
const RUN_FWD := 9.0 * MUGEN_TO_GODOT           # 604.8 px/s (medido, nao usado ainda)
const JUMP_VY := -7.5 * MUGEN_TO_GODOT          # -504 px/s
const JUMP_FWD := 3.4 * MUGEN_TO_GODOT          # 228.5 px/s
const JUMP_BACK := -3.9 * MUGEN_TO_GODOT        # -262.1 px/s
const GRAVITY := 0.34 * FPS * FPS * 1.12        # 1370.9 px/s^2
const GROUND_FRICTION := 0.89                   # por quadro, medido em ryu94

# --------------------------------------------------------------- impacto (SF)
const CHIP_RATIO := 0.25                        # dano no bloqueio
const CORNER_MARGIN := 90.0                     # distancia da parede p/ corner push
const GUARD_PUSH := 5.0 * MUGEN_TO_GODOT        # empurrao base de bloqueio

# ----------------------------------------------------- juggle / parede (TK)
const JUGGLE_GRAVITY := 1500.0                  # gravidade no ar (mais flutuante que a do pulo)
const JUGGLE_LIFT_DECAY := 0.86                 # cada golpe seguinte sobe menos
const JUGGLE_DAMAGE_DECAY := 0.85               # damage_adjust_aircombo
const MAX_JUGGLE := 8.0
const WALL_SPLAT_SPEED := 380.0                 # velocidade minima p/ grudar na parede
const WALL_SLIDE := 260.0                       # descida durante o wall splat
const WALL_SPLAT_TIME := 0.55
const KNOCKDOWN_TIME := 0.80
const GETUP_TIME := 0.30
const GETUP_INVULN := 0.45
const AIR_DRAG := 0.0                           # Tekken mantem a inercia horizontal no ar

# =============================== GOLPES ==================================
## Tempos em segundos (60 Hz). Os valores de hitstop foram reduzidos em
## relacao ao pausetime bruto do MUGEN (14 quadros = 0.233 s) para o
## prototipo nao ficar "travado"; a origem medida esta em cada comentario.
## box/offset usam a origem nos pes (y=0 na base), igual ao fighter.tscn.
const ATTACKS := {
	"light": {
		"startup": 0.050,
		"active": 0.067,
		"recovery": 0.133,
		"damage": 6,
		"box": Vector2(64, 34),
		"offset": Vector2(42, -62),
		"knock": Vector2(5.0 * MUGEN_TO_GODOT, 0.0),        # ground.velocity -5
		"hitstun": 12.0 / FPS,                              # ground.hittime 12f
		"hitstop": 0.10,                                    # pausetime 14f ajustado
		"blockstun": 19.0 / FPS,                            # guard.hittime 19f
		"guard_knock": 5.0 * MUGEN_TO_GODOT * 0.6,
		"air_knock": Vector2(2.0 * MUGEN_TO_GODOT, -6.0 * MUGEN_TO_GODOT),
		"air_hitstun": 30.0 / FPS,
		"corner_push": 10.0 * MUGEN_TO_GODOT,
		"launcher": false,
		"juggle_cost": 3,
	},
	"heavy": {
		"startup": 0.133,
		"active": 0.083,
		"recovery": 0.283,
		"damage": 14,
		"box": Vector2(100, 46),
		"offset": Vector2(64, -66),
		"knock": Vector2(9.0 * MUGEN_TO_GODOT, 0.0),        # ground.velocity -9
		"hitstun": 20.0 / FPS,                              # ground.hittime 20f
		"hitstop": 0.16,                                    # pausetime 14f ajustado
		"blockstun": 29.0 / FPS,                            # guard.hittime 29f
		"guard_knock": 9.0 * MUGEN_TO_GODOT * 0.6,
		"air_knock": Vector2(2.0 * MUGEN_TO_GODOT, -6.0 * MUGEN_TO_GODOT),
		"air_hitstun": 40.0 / FPS,
		"corner_push": 18.0 * MUGEN_TO_GODOT,
		"launcher": false,
		"juggle_cost": 4,
	},
	"launcher": {
		"startup": 0.117,
		"active": 0.100,
		"recovery": 0.317,
		"damage": 11,
		"box": Vector2(74, 64),
		"offset": Vector2(46, -92),
		"knock": Vector2(2.5 * MUGEN_TO_GODOT, -7.0 * MUGEN_TO_GODOT),
		"hitstun": 20.0 / FPS,
		"hitstop": 0.14,
		"blockstun": 27.0 / FPS,
		"guard_knock": 9.0 * MUGEN_TO_GODOT * 0.6,
		"air_knock": Vector2(2.5 * MUGEN_TO_GODOT, -7.0 * MUGEN_TO_GODOT),
		"air_hitstun": 45.0 / FPS,
		"corner_push": 18.0 * MUGEN_TO_GODOT,
		"launcher": true,
		"juggle_cost": 7,
	},
	"crouch_light": {
		"startup": 0.045,
		"active": 0.060,
		"recovery": 0.115,
		"damage": 5,
		"box": Vector2(58, 26),
		"offset": Vector2(38, -34),                          # golpe baixo (agachado)
		"knock": Vector2(4.0 * MUGEN_TO_GODOT, 0.0),
		"hitstun": 11.0 / FPS,
		"hitstop": 0.08,
		"blockstun": 17.0 / FPS,
		"guard_knock": 4.0 * MUGEN_TO_GODOT * 0.6,
		"air_knock": Vector2(2.0 * MUGEN_TO_GODOT, -6.0 * MUGEN_TO_GODOT),
		"air_hitstun": 28.0 / FPS,
		"corner_push": 8.0 * MUGEN_TO_GODOT,
		"launcher": false,
		"juggle_cost": 2,
	},
	"air_light": {
		"startup": 0.050,
		"active": 0.100,
		"recovery": 0.160,
		"damage": 7,
		"box": Vector2(66, 40),
		"offset": Vector2(40, -70),
		"knock": Vector2(5.0 * MUGEN_TO_GODOT, 0.0),
		"hitstun": 14.0 / FPS,
		"hitstop": 0.10,
		"blockstun": 18.0 / FPS,
		"guard_knock": 5.0 * MUGEN_TO_GODOT * 0.6,
		"air_knock": Vector2(2.0 * MUGEN_TO_GODOT, -6.0 * MUGEN_TO_GODOT),
		"air_hitstun": 30.0 / FPS,
		"corner_push": 10.0 * MUGEN_TO_GODOT,
		"launcher": false,
		"juggle_cost": 3,
	},
	"air_heavy": {
		"startup": 0.105,
		"active": 0.120,
		"recovery": 0.250,
		"damage": 13,
		"box": Vector2(96, 56),
		"offset": Vector2(58, -72),
		"knock": Vector2(8.0 * MUGEN_TO_GODOT, 0.0),
		"hitstun": 18.0 / FPS,
		"hitstop": 0.15,
		"blockstun": 25.0 / FPS,
		"guard_knock": 8.0 * MUGEN_TO_GODOT * 0.6,
		"air_knock": Vector2(2.5 * MUGEN_TO_GODOT, -6.5 * MUGEN_TO_GODOT),
		"air_hitstun": 38.0 / FPS,
		"corner_push": 16.0 * MUGEN_TO_GODOT,
		"launcher": false,
		"juggle_cost": 4,
	},
	"special": {
		"startup": 0.220,
		"active": 0.050,
		"recovery": 0.380,
		"damage": 18,
		"box": Vector2(1, 1),                                # hitbox nao usada: projetil
		"offset": Vector2(46, -66),
		"knock": Vector2(8.0 * MUGEN_TO_GODOT, 0.0),
		"hitstun": 20.0 / FPS,
		"hitstop": 0.16,
		"blockstun": 26.0 / FPS,
		"guard_knock": 8.0 * MUGEN_TO_GODOT * 0.6,
		"air_knock": Vector2(3.0 * MUGEN_TO_GODOT, -7.0 * MUGEN_TO_GODOT),
		"air_hitstun": 45.0 / FPS,
		"corner_push": 18.0 * MUGEN_TO_GODOT,
		"launcher": false,
		"juggle_cost": 5,
		"invuln": 0.18,                                      # invulneravel no startup
		"projectile": true,
		"projectile_speed": 620.0,
		"projectile_radius": 22.0,
		"projectile_lifetime": 1.6,
		"projectile_color": Color(0.45, 0.82, 1.0),
	},
}
