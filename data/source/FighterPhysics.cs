// FighterPhysics.cs
// Motor de referencia da fisica do SF SNK (M.U.G.E.N 1.0), reescrito do zero.
// Sem dependencia de engine: funciona em Unity, MonoGame, Godot (C#), console, etc.
//
// Uso:
//   var p = new FighterPhysics();
//   p.Constants = FighterPhysics.ConstantsFromJson("fisica_personagens.json", "Sakura");
//   p.SetWalk(+1);                 // segurou para a frente
//   p.Jump(JumpKind.Forward);      // pulou para a frente
//   p.Tick();                      // chame 60x por segundo, em passo FIXO
//
// Escala: os valores sao px/tick. Para metros, use p.PixelsToMeters ou
// multiplique as velocidades por 1.08 (px/tick -> m/s) assumindo 100 px = 1,80 m.

using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MugenPhysics
{
    public enum PhysicsMode { None, Stand, Crouch, Air }
    public enum JumpKind { Neutral, Forward, Back, RunForward, RunBack, AirNeutral, AirForward, AirBack }

    public class MugenConstants
    {
        // Nomes iguais as chaves de fisica_personagens.json
        [JsonPropertyName("displayname")] public string DisplayName { get; set; } = "";
        [JsonPropertyName("height")] public float Height { get; set; } = 100f;

        [JsonPropertyName("walk_fwd")] public float WalkFwd { get; set; } = 3f;
        [JsonPropertyName("walk_back")] public float WalkBack { get; set; } = -3f;

        [JsonPropertyName("run_fwd_x")] public float RunFwdX { get; set; } = 4.8f;
        [JsonPropertyName("run_fwd_y")] public float RunFwdY { get; set; } = 0f;
        [JsonPropertyName("run_back_x")] public float RunBackX { get; set; } = -4.8f;
        [JsonPropertyName("run_back_y")] public float RunBackY { get; set; } = -5f;

        [JsonPropertyName("jump_neu_x")] public float JumpNeuX { get; set; } = 0f;
        [JsonPropertyName("jump_neu_y")] public float JumpNeuY { get; set; } = -11f;
        [JsonPropertyName("jump_fwd_x")] public float JumpFwdX { get; set; } = 3f;
        [JsonPropertyName("jump_fwd_y")] public float JumpFwdY { get; set; } = -10.6f;
        [JsonPropertyName("jump_back_x")] public float JumpBackX { get; set; } = -3f;
        [JsonPropertyName("jump_back_y")] public float JumpBackY { get; set; } = -10.6f;
        [JsonPropertyName("runjump_fwd_x")] public float RunJumpFwdX { get; set; } = 6f;
        [JsonPropertyName("runjump_fwd_y")] public float RunJumpFwdY { get; set; } = -12.5f;
        [JsonPropertyName("runjump_back_x")] public float RunJumpBackX { get; set; } = -6f;
        [JsonPropertyName("runjump_back_y")] public float RunJumpBackY { get; set; } = -4f;
        [JsonPropertyName("airjump_neu_y")] public float AirJumpNeuY { get; set; } = -8f;
        [JsonPropertyName("airjump_fwd_x")] public float AirJumpFwdX { get; set; } = 3f;
        [JsonPropertyName("airjump_fwd_y")] public float AirJumpFwdY { get; set; } = -7f;
        [JsonPropertyName("airjump_back_x")] public float AirJumpBackX { get; set; } = -3f;
        [JsonPropertyName("airjump_back_y")] public float AirJumpBackY { get; set; } = -7f;
        [JsonPropertyName("airjump_num")] public float AirJumpNum { get; set; } = 0f;

        [JsonPropertyName("yaccel")] public float YAccel { get; set; } = 0.44f;
        [JsonPropertyName("stand_friction")] public float StandFriction { get; set; } = 0.85f;
        [JsonPropertyName("crouch_friction")] public float CrouchFriction { get; set; } = 0.82f;

        [JsonPropertyName("ground_back")] public float GroundBack { get; set; } = 16f;
        [JsonPropertyName("ground_front")] public float GroundFront { get; set; } = 20f;
        [JsonPropertyName("air_back")] public float AirBack { get; set; } = 16f;
        [JsonPropertyName("air_front")] public float AirFront { get; set; } = 20f;

        [JsonPropertyName("airjuggle")] public float AirJuggle { get; set; } = 15f;
        [JsonPropertyName("liedown_time")] public float LieDownTime { get; set; } = 60f;
        [JsonPropertyName("fall_defence_up")] public float FallDefenceUp { get; set; } = 50f;

        // Constantes do engine/estado (nao vem do personagem)
        public float FrictionThreshold = 0.05f;
        public float TicksPerSecond = 60f;
    }

    public class FighterPhysics
    {
        public MugenConstants Constants = new MugenConstants();

        public float X, Y;          // Y negativo = acima do chao (igual M.U.G.E.N)
        public float VelX, VelY;
        public int Facing = 1;      // +1 direita, -1 esquerda
        public PhysicsMode Mode = PhysicsMode.Stand;

        public bool OnGround => Mode != PhysicsMode.Air && Y >= 0f;
        public bool InHitstun => HitstunTicks > 0;
        public int HitstunTicks;
        public int AirJumpsLeft;

        public float HitYAccel;     // yaccel do golpe; 0 = usa o do personagem
        public float CurrentYAccel => HitYAccel > 0f ? HitYAccel : Constants.YAccel;

        public event Action Landed; // dispara no pouso (para trocar animacao/estado)

        // ---- comandos -------------------------------------------------------

        public void SetWalk(int dir)
        {
            if (Mode == PhysicsMode.Air || InHitstun) return;
            VelX = dir > 0 ? Constants.WalkFwd * Facing : Constants.WalkBack * Facing;
        }

        public void Crouch()
        {
            if (Mode == PhysicsMode.Air || InHitstun) return;
            VelX *= 0.75f;                       // "freio" do agachar
            Mode = PhysicsMode.Crouch;
        }

        public void Stand() { if (Mode != PhysicsMode.Air) Mode = PhysicsMode.Stand; }

        public void Jump(JumpKind kind)
        {
            if (Mode == PhysicsMode.Air) return;

            float vx, vy;
            switch (kind)
            {
                case JumpKind.Forward:    vx = Constants.JumpFwdX;    vy = Constants.JumpFwdY;    break;
                case JumpKind.Back:       vx = Constants.JumpBackX;   vy = Constants.JumpBackY;   break;
                case JumpKind.RunForward: vx = Constants.RunJumpFwdX; vy = Constants.RunJumpFwdY; break;
                case JumpKind.RunBack:    vx = Constants.RunJumpBackX;vy = Constants.RunJumpBackY;break;
                default:                  vx = Constants.JumpNeuX;    vy = Constants.JumpNeuY;    break;
            }
            VelX = vx * Facing;
            VelY = vy;
            Y = -0.001f;                          // sai do chao
            Mode = PhysicsMode.Air;
            AirJumpsLeft = (int)Constants.AirJumpNum;
        }

        public void AirJump(JumpKind kind)
        {
            if (Mode != PhysicsMode.Air || AirJumpsLeft <= 0) return;
            AirJumpsLeft--;
            switch (kind)
            {
                case JumpKind.AirForward: VelX = Constants.AirJumpFwdX * Facing; VelY = Constants.AirJumpFwdY; break;
                case JumpKind.AirBack:    VelX = Constants.AirJumpBackX * Facing; VelY = Constants.AirJumpBackY; break;
                default:                  VelY = Constants.AirJumpNeuY; break;
            }
        }

        /// <summary>Recebe um golpe. hittime em ticks; yaccel do golpe (0 = usa o do personagem).</summary>
        public void ApplyHit(float vx, float vy, int hittime, float hitYAccel = 0f)
        {
            VelX = vx;
            VelY = vy;
            HitstunTicks = hittime;
            HitYAccel = hitYAccel;
            if (vy < 0f || Y < 0f) { Mode = PhysicsMode.Air; Y = Math.Min(Y, -0.001f); }
            // knockdown: se o golpe manda cair (vy positivo grande), o estado de queda
            // deve ser tratado pelo jogo; aqui so mantemos a fisica do ar.
        }

        // ---- simulacao ------------------------------------------------------

        /// <summary>Um passo de fisica. Chame 60x por segundo em passo fixo.</summary>
        public void Tick()
        {
            if (HitstunTicks > 0) HitstunTicks--;

            switch (Mode)
            {
                case PhysicsMode.Air:
                    VelY += CurrentYAccel;                 // gravidade (Y+ = para baixo)
                    break;

                case PhysicsMode.Stand:
                case PhysicsMode.Crouch:
                    float friction = Mode == PhysicsMode.Stand
                        ? Constants.StandFriction
                        : Constants.CrouchFriction;
                    VelX *= friction;
                    if (Math.Abs(VelX) < Constants.FrictionThreshold) VelX = 0f;
                    break;
            }

            X += VelX;
            Y += VelY;

            if (Mode == PhysicsMode.Air && Y >= 0f)
            {
                Y = 0f;
                VelY = 0f;
                Mode = PhysicsMode.Stand;
                HitYAccel = 0f;
                OnLand();                              // equivale ao state 52
            }
        }

        private void OnLand()
        {
            Landed?.Invoke();
        }

        // ---- colisao entre corpos -------------------------------------------

        public float FrontEdge => X + (Facing > 0 ? Constants.GroundFront : Constants.GroundBack);
        public float BackEdge  => X - (Facing > 0 ? Constants.GroundBack  : Constants.GroundFront);

        /// <summary>
        /// Separa dois corpos sobrepostos (push box) e resolve o corner push.
        /// Chame depois de mover todo mundo, uma vez por par.
        /// </summary>
        public static void Push(FighterPhysics a, FighterPhysics b, float stageMinX, float stageMaxX)
        {
            float gap = b.X - a.X;
            float overlap = (a.Constants.GroundFront + b.Constants.GroundFront) - Math.Abs(gap);
            if (overlap <= 0f || Math.Sign(gap) == 0) return;

            float dir = gap >= 0f ? 1f : -1f;
            float half = overlap * 0.5f;

            float ax = a.X - dir * half;
            float bx = b.X + dir * half;

            bool aBlocked = ax < stageMinX || ax > stageMaxX;
            bool bBlocked = bx < stageMinX || bx > stageMaxX;

            if (aBlocked && !bBlocked) { b.X += dir * overlap; ax = a.X; }       // corner push
            else if (bBlocked && !aBlocked) { a.X -= dir * overlap; bx = b.X; }
            else { a.X = ax; b.X = bx; }

            a.X = Clamp(a.X, stageMinX, stageMaxX);
            b.X = Clamp(b.X, stageMinX, stageMaxX);
        }

        private static float Clamp(float v, float lo, float hi) => v < lo ? lo : (v > hi ? hi : v);

        // ---- utilidades -----------------------------------------------------

        /// <summary>Altura do apice do salto em px (v^2 / 2a).</summary>
        public static float ApexHeight(float jumpVelY, float yaccel) =>
            (jumpVelY * jumpVelY) / (2f * yaccel);

        /// <summary>Duracao total do salto em ticks (2v/a).</summary>
        public static float AirTimeTicks(float jumpVelY, float yaccel) =>
            (2f * Math.Abs(jumpVelY)) / yaccel;

        public const float MetersPerPixel = 0.018f;      // 100 px = 1,80 m
        public const float PxPerTickToMetersPerSecond = 1.08f;   // 60 Hz * 0.018

        public static MugenConstants ConstantsFromJson(string json, string displayName)
        {
            // Na Unity: troque System.Text.Json por Newtonsoft (JsonConvert) ou
            // carregue o JSON com JsonUtility (nesse caso, remova os atributos
            // [JsonPropertyName]). A logica de fisica nao depende disso.
            var list = JsonSerializer.Deserialize<List<MugenConstants>>(json);
            foreach (var c in list)
                if (string.Equals(c.DisplayName, displayName, StringComparison.OrdinalIgnoreCase))
                    return c;
            throw new KeyNotFoundException($"Personagem '{displayName}' nao encontrado no JSON.");
        }
    }
}
