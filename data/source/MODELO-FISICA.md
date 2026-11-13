# Modelo de física do SF SNK (M.U.G.E.N 1.0)

Este é o modelo que produz a "sensação" do jogo. Os números de cada personagem
estão em `fisica_personagens.csv` / `.json`.

## 1. Unidades e eixos

| Grandeza | Unidade |
|---|---|
| Distância | pixel (px) |
| Tempo | *tick* = 1/60 s (o jogo roda a 60 Hz) |
| Velocidade | px/tick |
| Aceleração | px/tick² |

Eixos: **+x para a direita** e **+y para baixo** (é coordenada de tela, não de
matemática). Por isso salto é `y` **negativo** (`jump.neu = 0,-11` = subir 11
px/tick), e a gravidade é positiva (puxa pra baixo).

Conversão para o seu engine (metros/segundo): escolha a escala pelo tamanho do
personagem. No M.U.G.E.N, `height = 100` ≈ altura de um lutador (~1,80 m),
logo:

```
1 px            = 0.018 m
1 px/tick       = 1.08 m/s
1 px/tick²      = 64.8 m/s²
```

Exemplo (Sakura: walk 2,4 / yaccel 0,64 / jump -11):
andar = 2,59 m/s · gravidade = 41,5 m/s² · impulso de salto = 11,88 m/s.

## 2. Modos de física (`physics = S / C / A / N`)

O estado (state) define qual física o jogo aplica automaticamente todo tick:

- **`S` (em pé, no chão):** aplica atrito em `vel.x`; a velocidade é zerada
  quando `|vel.x|` cai abaixo de `stand.friction.threshold`.
- **`C` (agachado):** igual ao `S`, mas com `crouch.friction` (mais atrito, ou
  seja, freia mais rápido).
- **`A` (no ar):** `vel.y += yaccel` a cada tick; **sem atrito em x** (o
  deslocamento horizontal do salto é constante). Quando `pos.y >= 0`, cai
  imediatamente no estado de aterrissagem (state 52), que zera `vel.y`,
  fixa `pos.y = 0` e trava o controle por 3 ticks.
- **`N` (nenhuma):** o estado controla tudo na mão (usado em golpes aéreos,
  projéteis, etc.).

Ordem por tick (o que reproduz o comportamento real):

```
1. executa os controllers do estado (muda vel, pos, anim...)
2. aplica física automática:  atrito (S/C)  ou  vel.y += yaccel (A)
3. pos += vel
4. resolve colisão com o oponente (push boxes) e com as bordas da tela
5. se physics = A e pos.y >= 0  ->  estado de pouso
6. avança a animação, decrementa timers (hitstun etc.), lê input
```

## 3. Atrito

O modelo é multiplicativo (exponencial), não linear:

```
vel.x *= friction        // friction = stand.friction (ex.: 0.85) ou crouch.friction
se |vel.x| < threshold:  vel.x = 0
```

`friction` perto de 1 = desliza muito; perto de 0 = para na hora. O
`threshold` (padrão do engine ≈ 0,05 px/tick) evita que sobre um resto
infinito de velocidade.

## 4. Salto

O salto é um impulso instantâneo em `vel.y`, e a trajetória sai da integração
de Euler com gravidade constante. Para o arco perfeito (sem colisão), vale:

```
altura do ápice   h = v² / (2 * yaccel)          [px]
tempo até o ápice t = v / yaccel                 [ticks]
tempo total no ar T = 2 * v / yaccel             [ticks]
```

Essas três colunas já estão calculadas no CSV (`alto_apice_px`,
`tempo_apice_ticks`, `tempo_ar_ticks`). Elas são o jeito mais rápido de
comparar personagens: no jogo real, Sakura fica 34 ticks no ar (0,57 s),
Dhalsim só 27 ticks, enquanto Akuma passa de 42.

Cada personagem tem 4 variações de salto (`jump.neu`, `jump.fwd`, `jump.back`,
`runjump.*` para salto correndo, e `airjump.*` para pulo duplo). Note que
`jump.fwd/back` **não é** `jump.neu` com x diferente: o y costuma ser menor
(mais baixo) para o salto diagonal ter a mesma duração aproximada.

## 5. Andar, correr, agachar

- Andar: a velocidade é simplesmente setada para `walk.fwd` / `walk.back`
  enquanto a direção está pressionada — sem aceleração. Ou seja, o
  personagem atinge a velocidade máxima instantaneamente.
- Correr: `run.fwd` / `run.back` são pares (x,y); `run.back` costuma ter `y`
  negativo porque o recuo é um pequeno pulinho pra trás.
- No agachar, o estado multiplica `vel.x` por ~0,75 no primeiro tick e usa o
  atrito de agachado — é o "freio" ao agachar em movimento.

## 6. Empurrão e paredes (o detalhe que quase todo mundo esquece)

- Cada personagem tem uma *push box*: `ground.front`, `ground.back` (no chão) e
  `air.front`, `air.back` (no ar), além de `height`.
- Dois corpos não podem se sobrepor: se as caixas se cruzam, os dois são
  separados meio a meio (cada um recua metade da penetração).
- **Corner push:** se um está encostado na borda da tela e é empurrado, ele não
  pode recuar — então o **atacante** recua a diferença. Isso vale mesmo com
  `velset = 0`.
- A borda da tela é o limite do *stage*, não uma parede física; personagens
  ficam presos nela e o empurrão vira pressão de canto.

## 7. Receber golpe (hitstun / knockdown / juggle)

Isso não está nos `[Movement]`, mas define 90% do feeling de luta:

- Cada `HitDef` traz `pausetime`, `ground.hittime` (ticks de hitstun no chão),
  `air.hittime`, `ground.velocity`, `air.velocity`, `airguard.velocity`,
  `yaccel` próprio do golpe e `fall` (queda/knockdown).
- No ar, o `yaccel` **do golpe** substitui o do personagem (`GetHitVar(yaccel)`),
  e a recuperação aérea usa `velocity.air.gethit.airrecover.*`.
- `airjuggle` é o orçamento de "juggle": cada golpe aéreo gasta uma quantidade;
  quando zera, o oponente não pode mais ser reacertado no ar.
- Queda/knockdown usa `fall.defence_up` (defesa sobe 50 por golpe recebido
  caído) e `liedown.time` (ticks no chão antes de levantar).
- Pós-aterrissagem dura ~3 ticks de controle travado (state 52), e levantar do
  chão tem invencibilidade nos últimos ~10 ticks (`liedown.time`).

## 8. Números de referência (variação entre os 25 personagens)

| Parâmetro | Faixa encontrada |
|---|---|
| `yaccel` (gravidade) | 0,34 (Ryu) a 0,80 (Vega/Balrog) |
| `jump.neu.y` | -5,9 (Dhalsim) a -13,1 (Balrog) |
| `walk.fwd` | 2,0 (Dhalsim) a 4,1 (Akuma) |
| `stand.friction` | 0,80 a 0,89 |
| `airjuggle` | 3 (M.Bison) a 20 (Fei-Long) |
| `height` (colisão) | 50 a 100 |

Repare que gravidade e impulso andam **juntos**: quem tem `yaccel` alto também
tem salto mais forte. O que muda de verdade entre eles é a **duração do arco**
(e a velocidade horizontal). Use a coluna `tempo_ar_ticks` como alvo ao portar:
se o seu engine der 0,5 s de ar, está no padrão do jogo.

## 9. Portando para 2D/3D no seu engine

- **2D (o mais fiel):** use `FighterPhysics.cs` como está — x/y, física por
  estado, atrito multiplicativo, pouso em `y = 0`.
- **3D:** mantenha o modelo e troque só o eixo: `y` → `z` (gravidade) e o
  `vel.x` do salto vira velocidade no plano XZ. O `vel.x` constante no ar é o
  que dá o salto "de fliperama"; se colocar atrito no ar, o salto vira
  "realista" e perde a identidade do jogo.
- **Escala:** multiplique os valores por `sua_altura_de_personagem / 100`. Se
  seu lutador tem 1,8 m, pode usar `1 px = 0,018 m` e o resto segue igual.
- **60 Hz fixo:** rode a simulação em passo fixo de 1/60 s (accumulator). Se
  rodar a física por `deltaTime` variável, o arco do salto muda com o FPS.
