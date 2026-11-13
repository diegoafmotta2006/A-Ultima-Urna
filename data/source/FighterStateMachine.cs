// FighterStateMachine.cs
// Maquina de estados de um lutador 3D estilo Tekken, construida a partir do
// modelo extraido do Tekken mobile (BattleCore):
//   - estados e acoes: FighterStateEnum / FighterActionEnum (nomes reais do jogo)
//   - hitstop, juggle frame, recovery frame, wall distance, arena de 31.6
//   - movimento por "motion" de golpe (keyframes), nao por corpo rigido
//
// Os VALORES de tuning sao seus: o pacote do Tekken nao traz os numeros
// (ver ANALISE.md). Os nomes, o fluxo e a estrutura vieram do binario.

using System;
using System.Collections.Generic;

namespace TekkenLike
{
    public enum FighterState
    {
        None = -1,
        Idle,
        Grounded,
        WeakHitStun,
        StrongHitStun,
        BlockStun,
        Juggled,
        Falling,
        Thrown,
        Rising,
        NumStates
    }

    public enum FighterAction
    {
        None = -1,
        Card1, Card2, Card3, Card4, Card5,
        MoveLeft, MoveRight,
        Charge, Block,
        BasicAttack, LongRangeAttack,
        RageArt, LauncherWaza, StrikeWaza,
        GuardBreakWaza, StunWaza, ThrowWaza, SpecialWaza,
        NumActions
    }

    /// <summary>Frame data de um golpe (o "mothead" do Tekken em forma de dados).</summary>
    public class MoveData
    {
        public string MotionName = "attack_short_combo";
        public int StartupFrames = 12;
        public int ActiveFrames = 3;
        public int RecoveryFrames = 14;

        public float Damage = 20f;
        public float HitStopFrames = 6f;         // congela os dois no impacto
        public float HitStunFrames = 18f;        // WeakHitStun
        public float BlockStunFrames = 12f;
        public float PushbackOnHit = 0.25f;      // metros
        public float PushbackOnBlock = 0.18f;

        public bool IsLauncher;                  // manda pro ar (Juggled)
        public float LaunchVelocity = 3.2f;      // m/s vertical
        public float LaunchForward = 1.4f;       // m/s no eixo X
        public float AirHitStunFrames = 30f;
    }

    public class FighterStateMachine
    {
        // --- valores observados no pacote ---
        public const float StageLength = 31.6f;             // FighterCloneTuningAsset
        public const float MaxDistanceBetweenFighters = 5f; // idem
        public const float WallDistance = StageLength * 0.5f;

        // --- tuning seu (nao vem do jogo) ---
        public float WalkSpeed = 2.6f;         // m/s
        public float DashSpeed = 7.0f;         // m/s
        public float DashDuration = 0.28f;     // s
        public float BackdashSpeed = 5.5f;
        public float BackdashDuration = 0.22f;
        public float Gravity = 18f;            // m/s^2 (juggle; arcade = alta)
        public float JuggleGravityMultiplier = 1.15f;  // aumenta a cada hit aereo
        public float JuggleLimit = 5f;         // "air_combo_limit"
        public float HitStopScale = 1f;        // "hitstop_speed_armor" etc.

        public float X, Y, Z;                  // Y = altura
        public float VelX, VelY;
        public int Facing = 1;

        public FighterState State = FighterState.Idle;
        public FighterAction Action = FighterAction.None;

        public int StateFrame;                 // frames dentro do estado atual
        public float HitStopLeft;              // frames de congelamento
        public float JuggleCount;              // hits aereos ja aplicados
        public float Health = 1000f;

        public MoveData CurrentMove;
        private int _moveFrame;
        private bool _hitRegistered;

        public event Action<MoveData, bool> OnHit;   // (golpe, foi bloqueado)

        public bool IsBusy =>
            Action != FighterAction.None ||
            State == FighterState.WeakHitStun || State == FighterState.StrongHitStun ||
            State == FighterState.BlockStun || State == FighterState.Thrown;

        public bool IsAirborne => State == FighterState.Juggled || State == FighterState.Falling;

        // ---- entrada ---------------------------------------------------------

        public void Press(FighterAction action, MoveData move = null)
        {
            if (IsBusy || HitStopLeft > 0f) return;

            switch (action)
            {
                case FighterAction.MoveLeft:
                case FighterAction.MoveRight:
                    Action = action;                       // "Swipe_step_forward/backward"
                    StateFrame = 0;
                    break;

                case FighterAction.Block:
                    Action = FighterAction.Block;          // "guard_start_LeftPanel"
                    StateFrame = 0;
                    break;

                default:
                    if (move == null) return;
                    CurrentMove = move;
                    Action = action;
                    _moveFrame = 0;
                    _hitRegistered = false;
                    StateFrame = 0;
                    break;
            }
        }

        public void Release()
        {
            if (Action == FighterAction.MoveLeft || Action == FighterAction.MoveRight ||
                Action == FighterAction.Block)
                Action = FighterAction.None;
        }

        // ---- simulacao (passo fixo de 1/60 s) --------------------------------

        public void Tick(float dt, float opponentX)
        {
            Facing = opponentX >= X ? 1 : -1;

            // hitstop congela tudo, menos contadores
            if (HitStopLeft > 0f)
            {
                HitStopLeft -= dt * 60f * HitStopScale;
                return;
            }

            StateFrame++;

            switch (State)
            {
                case FighterState.Juggled:
                case FighterState.Falling:
                    TickAir(dt);
                    break;

                case FighterState.Grounded:
                case FighterState.WeakHitStun:
                case FighterState.StrongHitStun:
                case FighterState.BlockStun:
                case FighterState.Rising:
                    // preso no chao: so o pushback anda
                    X += VelX * dt;
                    VelX *= 0.90f;
                    if (StateFrame > StunDurationFrames) ToIdle();
                    break;

                default:
                    TickNeutral(dt);
                    break;
            }

            // chao
            if (Y <= 0f && IsAirborne)
            {
                Y = 0f; VelY = 0f;
                State = FighterState.Falling;
                if (StateFrame > 6) State = FighterState.Rising;   // knockdown -> levantar
                StateFrame = 0;
            }

            X = Clamp(X, -WallDistance, WallDistance);
        }

        private float StunDurationFrames = 18f;

        private void TickNeutral(float dt)
        {
            switch (Action)
            {
                case FighterAction.MoveRight:
                    X += Facing * WalkSpeed * dt;                  // andar para frente
                    break;

                case FighterAction.MoveLeft:
                    X -= Facing * WalkSpeed * dt;                  // andar para tras
                    break;

                case FighterAction.Block:
                    break;

                default:
                    if (CurrentMove != null)
                        TickMove(dt);
                    break;
            }
        }

        private void TickMove(float dt)
        {
            _moveFrame++;
            var m = CurrentMove;

            if (_moveFrame == m.StartupFrames)
                X += Facing * 0.10f;                        // pequeno avanco do golpe

            // janela ativa: o "evt_hit" do motor
            if (!_hitRegistered && _moveFrame >= m.StartupFrames &&
                _moveFrame < m.StartupFrames + m.ActiveFrames)
            {
                // quem chama decide se acertou; aqui registramos a tentativa
                OnHit?.Invoke(m, false);
                _hitRegistered = true;
            }

            if (_moveFrame >= m.StartupFrames + m.ActiveFrames + m.RecoveryFrames)
            {
                CurrentMove = null;
                Action = FighterAction.None;
            }
        }

        private void TickAir(float dt)
        {
            float g = Gravity * (1f + (JuggleGravityMultiplier - 1f) * JuggleCount);
            VelY -= g * dt;
            Y += VelY * dt;
            X += VelX * dt;
        }

        // ---- receber golpe ---------------------------------------------------

        /// <summary>Aplica um golpe recebido. Retorna o dano efetivo.</summary>
        public float Receive(MoveData m, bool blocked)
        {
            HitStopLeft = m.HitStopFrames;

            if (blocked)
            {
                State = FighterState.BlockStun;
                StunDurationFrames = m.BlockStunFrames;
                VelX = -Facing * m.PushbackOnBlock * 60f;
                StateFrame = 0;
                return 0f;
            }

            float damage = m.Damage * (IsAirborne ? 0.8f : 1f);
            Health = Math.Max(0f, Health - damage);

            if (m.IsLauncher || IsAirborne)
            {
                if (JuggleCount >= JuggleLimit)          // air_combo_limit
                    return damage;

                State = FighterState.Juggled;
                JuggleCount++;
                VelY = m.LaunchVelocity;
                VelX = Facing * m.LaunchForward;
                Y = Math.Max(Y, 0.01f);
            }
            else
            {
                State = m.HitStunFrames >= 24f ? FighterState.StrongHitStun : FighterState.WeakHitStun;
                StunDurationFrames = m.HitStunFrames;
                VelX = -Facing * m.PushbackOnHit * 60f;
            }

            StateFrame = 0;
            Action = FighterAction.None;
            CurrentMove = null;
            return damage;
        }

        public void ToIdle()
        {
            if (IsAirborne) return;
            State = FighterState.Idle;
            StateFrame = 0;
            JuggleCount = 0;
            VelX = 0f;
        }

        // ---- utilidades ------------------------------------------------------

        /// <summary>Separa dois lutadores (pushbox) respeitando as paredes.</summary>
        public static void Push(FighterStateMachine a, FighterStateMachine b, float pushbox = 0.55f)
        {
            float gap = b.X - a.X;
            float overlap = pushbox - Math.Abs(gap);
            if (overlap <= 0f) return;
            float dir = gap >= 0f ? 1f : -1f;
            a.X -= dir * overlap * 0.5f;
            b.X += dir * overlap * 0.5f;
            a.X = Clamp(a.X, -WallDistance, WallDistance);
            b.X = Clamp(b.X, -WallDistance, WallDistance);
        }

        private static float Clamp(float v, float lo, float hi) => v < lo ? lo : (v > hi ? hi : v);

        // Catalogo de exemplo: acrescente os moves de cada personagem.
        public static readonly Dictionary<FighterAction, MoveData> DefaultMoves = new Dictionary<FighterAction, MoveData>
        {
            { FighterAction.BasicAttack, new MoveData { MotionName = "attack_short_combo", StartupFrames = 10, ActiveFrames = 3, RecoveryFrames = 12, Damage = 18f } },
            { FighterAction.LauncherWaza, new MoveData { MotionName = "skill_launcher", StartupFrames = 16, ActiveFrames = 2, RecoveryFrames = 22, Damage = 26f, IsLauncher = true } },
            { FighterAction.StrikeWaza, new MoveData { MotionName = "skill_strike", StartupFrames = 14, ActiveFrames = 3, RecoveryFrames = 18, Damage = 30f } },
            { FighterAction.RageArt, new MoveData { MotionName = "skill_rageart", StartupFrames = 22, ActiveFrames = 4, RecoveryFrames = 30, Damage = 60f, IsLauncher = true, HitStopFrames = 10f } },
        };
    }
}
