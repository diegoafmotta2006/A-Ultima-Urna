# Mudanças — 13/11/2026

Relato do que foi feito **agora** nesta atualização do **A Última Urna**.

## Problema relatado

> "Tem 3 personagens. Um deles está com a pose repetida e era para ter só dois.
> O azul se chama Bolsonaro, o outro é o Lula."

Depois de confirmar a preferência, ficou definido: **azul = LULA** e **faixa = BOLSONARO**
(é o que a arte mostra na tela: a pasta `azul` tem o personagem de cabelo branco e
terno azul; a pasta `faixa` tem o personagem com a faixa presidencial).

## O que estava errado

1. **Três personagens no elenco.** `scripts/game.gd` tinha `P1_ROSTER` com três
   entradas: `FAIXA`, `AZUL` e `PRESIDENTE`. O terceiro (`assets/characters/presidente`)
   só possuía **um** arquivo de arte (`idle.png`), então o código caía no `idle` para
   **todas** as poses — era ele que aparecia "com a pose repetida".
2. **Pose repetida também no Bolsonaro.** `assets/characters/faixa/special.png` era
   **cópia byte a byte** de `faixa/heavy.png` (mesmo SHA256 `F7B89CD104AB…`), ou seja,
   o golpe especial mostrava a arte do golpe forte.
3. **HUD desatualizado.** `scenes/hud.tscn` mostrava `P1: FAIXA`, `P1 - PLAYER 1` e
   `PLAYER 2`.

## O que foi alterado

| Arquivo | Mudança |
|---------|---------|
| `scripts/game.gd` | `P1_ROSTER` reduzido de 3 para **2** entradas: `BOLSONARO` (arte `faixa`, índice 0 = P1 inicial) e `LULA` (arte `azul`). Comentário explicando a relação pasta ↔ personagem. |
| `scenes/hud.tscn` | Textos padrão: botão `P1: BOLSONARO`, rótulo `P1 - BOLSONARO` e `P2 - LULA`. |
| `assets/characters/faixa/special.png` | **Nova pose de especial** gerada a partir da arte não usada `assets/characters/presidente/idle.png`, espelhada para olhar à direita como o resto do set, na mesma escala do conjunto (corpo ~645 px vs 652 px do `idle`), ancorada nos pés e com ruído pequeno removido. |
| `tools/make_faixa_special.py` | Script reexecutável que regenera a pose acima (usa PIL/numpy). |
| `README.md` | Nova seção **Personagens**, tabela de controles completa (agachar/especial/gamepad), estrutura de arquivos corrigida e link para este arquivo. |
| `MUDANCAS.md` | Este arquivo. |

Arquivos **não** alterados de propósito:

- `assets/characters/presidente/` e o perfil `presidente` em `data/characters.json`
  continuam no projeto (fora do elenco). São a fonte da pose do especial e podem virar
  um terceiro lutador no futuro.
- Nenhum `.import` foi criado à mão: o Godot gera o do PNG novo na primeira abertura.

## Verificações feitas

- **Elenco**: `scenes/main.tscn` tem apenas dois nós `Fighter` (P1 com arte `faixa`,
  P2 com arte `azul`) e `P1_ROSTER` tem duas entradas — trocar de personagem no botão
  só alterna entre BOLSONARO e LULA.
- **Sem poses duplicadas**: os 22 PNGs (11 poses × 2 lutadores) têm SHA256 todos
  distintos e nenhuma par de poses de mesmo conjunto chega a IoU 0,90 na silhueta.
- **Escala/ancoragem**: as poses do Bolsonaro têm alturas de corpo compatíveis e os
  pés alinhados na mesma linha de chão.
- **Sem erros de sintaxe novos**: as edições foram restritas a constantes/dicionários
  e a textos de cena (`.tscn`).

## Como desfazer / regenerar

```bash
# regenerar a pose de especial do Bolsonaro (Python 3 + pillow + numpy)
python tools/make_faixa_special.py
```

Para voltar a ter três personagens, basta recriar a terceira entrada em `P1_ROSTER`
(`scripts/game.gd`) e um rótulo no HUD — a arte da pasta `presidente` continua lá.

## Como testar

Abra o projeto no **Godot 4.7** (o engine reimporta o PNG novo automaticamente) e
rode `scenes/main.tscn` com **F5**. Confira:

1. P1 nasce como **BOLSONARO** e o botão superior esquerdo alterna para **LULA**;
2. os rótulos mostram `P1 - BOLSONARO` / `P2 - LULA`;
3. o **especial** (`H` no teclado) mostra uma pose diferente do golpe forte.
