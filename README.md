# A Última Urna

Protótipo jogável de jogo de luta 2D feito em **Godot 4.7**, pensado para três alvos
a partir de **um único código**:

- **PC (Windows/Linux)**: export nativo — melhor desempenho, recomendado para jogar.
- **Web**: export HTML5 (roda no navegador, bom para demo/vitrine).
- **Android**: export APK/AAB nativo.

Os três presets de exportação já vêm configurados em `export_presets.cfg`.

Estado atual: partida local (2 jogadores no teclado/gamepad ou vs CPU), com barras de
vida, rounds (melhor de 3), bloqueio, golpes leve/forte, hitstun, knockback, feedback de
impacto (hitstop, flash e faísca) e botões de toque para Android. A arte ainda é feita
com polígonos (placeholders) para o projeto rodar sem assets.

## Requisitos

- Godot **4.7.x** (testado com 4.7.2).
- Para exportar: os **Export Templates** da mesma versão (Editor > Gerenciar Templates de Exportação).
- Para Android: JDK 17+, Android SDK (platform-tools, build-tools, uma plataforma android) e um keystore.

## Como rodar

Abra o Godot, clique em **Import**, selecione a pasta deste projeto (`project.godot`)
e rode com **F5**. Cena principal: `scenes/main.tscn`.

## Controles

| Ação        | Player 1        | Player 2        |
|-------------|-----------------|-----------------|
| Mover       | `A` / `D`       | `←` / `→`       |
| Pular       | `W`             | `↑`             |
| Golpe leve  | `F`             | `K`             |
| Golpe forte | `G`             | `L`             |

- **Bloqueio**: segure a direção oposta ao oponente (para trás) enquanto está no chão.
- **Gamepad**: P1 = controle 0, P2 = controle 1. Analógico/DPad move, `A` pula,
  `X` leve, `Y` forte.
- **CPU**: botão `CPU: OFF/ON` no canto superior esquerdo liga a IA no P2.
- **Toque (Android/móvel)**: os botões aparecem automaticamente quando há touchscreen;
  controlam o P1.

## Estrutura

```
project.godot            configuração (viewport 1280x720, física 60 Hz, autoload)
scenes/
  main.tscn              arena + chão/paredes + jogadores + HUD
  fighter.tscn           lutador (corpo, colisão, polígonos)
  hud.tscn               barras de vida, placar, CPU, botões de toque
scripts/
  game.gd                rounds, placar, posicionamento, separação de corpos
  fighter.gd             máquina de estados, física, ataques, hitboxes/hurtbox, IA
  hud.gd                 atualização de HUD e input dos botões de toque
  input_bridge.gd        input unificado: teclado + gamepad + toque
```

## Ajustar o jogo de luta

Os dados de golpe ficam em `scripts/fighter.gd` na constante `ATTACKS`:

```gdscript
const ATTACKS := {
    "light": { "startup": 0.055, "active": 0.070, "recovery": 0.130,
               "damage": 6, "box": Vector2(64, 34), "offset": Vector2(42, -62),
               "knock": Vector2(170, -60), "hitstun": 0.22, "hitstop": 0.05 },
    # ...
}
```

- `startup` / `active` / `recovery` são janelas em segundos a 60 Hz (1 frame ≈ 0.0167 s).
- `hitstop` congela os **dois** lutadores no acerto (leve 0.05 s ≈ 3 frames, forte 0.10 s ≈ 6 frames).
- `box` + `offset` definem a hitbox do golpe (em relação ao corpo, espelhada pelo `facing`).
- A hurtbox é `Fighter.hurt_rect()`. Para hitboxes por golpe, prefira trocar por `Area2D`
  com `CollisionShape2D` quando entrar a arte final.
- Para virar frame data "de verdade", converta para contagem de frames e trave a lógica
  em `_physics_process` (já roda a 60 Hz).

## Exportar para PC (Windows / Linux)

Recomendado para jogar de verdade: roda nativo, sem Wasm nem download de engine pelo navegador.

1. Instale os **Export Templates** de 4.7.x (**Editor > Gerenciar Templates de Exportação**).
2. Os presets **Windows Desktop** e **Linux** já estão prontos no projeto.
3. **Projeto > Exportar**, escolha o preset e clique em **Exportar Projeto**:
   - Windows: `build/windows/A Ultima Urna.exe`
   - Linux: `build/linux/a-ultima-urna.x86_64`
4. O `.pck` é embutido no executável (`embed_pck=true`), então cada build é **um único arquivo**.

Para gerar sem abrir a interface (depois de instalar os templates):

```bash
godot --headless --export-release "Windows Desktop" "build/windows/A Ultima Urna.exe"
godot --headless --export-release "Linux" "build/linux/a-ultima-urna.x86_64"
```

## Exportar para Web (navegador)

1. Instale os Export Templates: **Editor > Gerenciar Templates de Exportação** (baixar/instalar).
2. **Projeto > Exportar > Adicionar > Web**.
3. Deixe **Thread Support** desligado no começo (mais simples de hospedar).
4. **Exportar Projeto** para, por exemplo, `build/web/index.html`.
5. Sirva por HTTP (não abra `file://`):

   ```bash
   python3 -m http.server 8000 --directory build/web
   # abra http://localhost:8000
   ```

6. Para publicar: itch.io, GitHub Pages ou Netlify (suba a pasta `build/web`).

## Exportar para Android (APK)

Faça na sua máquina com Android SDK/JDK instalados (este ambiente não tem o SDK).

1. Instale o **JDK 17+** e o **Android SDK** (via Android Studio ou command-line tools).
2. Configure em **Editor > Configurações do Editor > Exportar > Android**:
   - `Android SDK Path`
   - `Java SDK Path` (JDK 17)
   - `Debug Keystore` (o Godot gera um keystore de debug se você preencher os campos)
3. Instale os **Export Templates** da versão 4.7.2.
4. O preset **Android** já está no projeto. Confira:
   - **Package Name** `com.diegoafmotta.ultimaurna`.
   - **APK** para testar rápido (ou AAB para publicar na Play Store).
5. Exporte e instale:

   ```bash
   adb install -r build/android/a-ultima-urna.apk
   ```

Observações:
- Na primeira execução o Android pede permissão de instalação de fontes desconhecidas.
- Para publicar na Play Store, gere um **AAB** assinado com keystore de release e
  versione `version/code` e `version/name` no preset.
- O projeto usa renderer **GL Compatibility**, escolhido por compatibilidade com
  aparelhos antigos e com a web.

## Limitações atuais / próximos passos

- Arte placeholder (polígonos) — trocar por `AnimatedSprite2D`/`Sprite2D` com spritesheet.
- Sem áudio ainda.
- Sem golpes especiais por comando (motion inputs como ↓↘→ + golpe).
- Sem multiplayer online (o plano combinado era local primeiro; netcode com rollback
  entra depois, e é bem mais complexo).
- Para 2 jogadores no mesmo celular, o ideal é gamepad Bluetooth; os botões de toque
  atuais controlam só o P1.

## Licença

Distribuído sob a licença **MIT** — veja [`LICENSE`](LICENSE).
