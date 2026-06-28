# Bestiário — A Torre da Vingança

Lista inicial de mobs e bosses para referência de **design/arte**. Organizada pelas 5 zonas
temáticas da torre (10 andares cada) + o trono do Rei. Cada zona termina num **Great Boss**
(andares 10/20/30/40/50) já presente no jogo; o **Rei** fecha no andar 51.

Ranks (de `balance.json`): `MINION` (fraco, em grupo) · `NORMAL` (padrão) · `ELITE` (raro,
forte) · `BOSS` (guardião de andar) · `GREAT_BOSS` (marco) · `KING` (final).

Os `id` sugeridos servem também de checklist para os JSON em `data/enemies` / `data/bosses`.
Tamanhos de referência (base 640×360): normais **32×32**, elites 32–48, bosses **64×64**,
great bosses/Rei **96–128**.

---

## Zona 1 — O Ossário (andares 1–10)
*Tema: mortos-vivos, criptas, necromancia. Paleta: ossos, cinza, verde-necrótico.*

- **Esqueleto Guerreiro** — `enm_skeleton` — NORMAL — *morto-vivo*
  Esqueleto humano amarelado e lascado, com armadura de couro apodrecido e elmo enferrujado.
  Empunha uma espada curta cega e um escudo de madeira rachado. Movimentos secos e
  desengonçados; olhos com brasa azul-pálida nas órbitas vazias. É o inimigo-base do jogo.

- **Servo Tumular** — `enm_bone_minion` — MINION — *morto-vivo*
  Esqueleto pequeno e incompleto (falta um braço ou parte das costelas), sem armadura.
  Ataca com as próprias garras ósseas ou um fêmur usado como porrete. Aparece em enxames,
  desmoronando num montinho de ossos ao morrer.

- **Necromante Acólito** — `enm_necromancer` — NORMAL — *humano (mago)*
  Humano magro de túnica negra esfarrapada com capuz fundo que esconde o rosto; mãos
  esqueléticas seguram um cajado com um crânio acoplado e brasa verde. Mantém distância e
  conjura projéteis necróticos; pode reerguer um "Servo Tumular" caído.

- **Carniçal Esfomeado** — `enm_ghoul` — NORMAL — *morto-vivo (besta)*
  Criatura curvada e nua de pele acinzentada esticada sobre os ossos, garras longas e
  mandíbula deslocada cheia de dentes. Sem equipamento — ataca com garras e mordida; rápido
  e agressivo, corre de quatro em surtos.

- **Cavaleiro da Cripta** — `enm_crypt_knight` — ELITE — *morto-vivo (cavaleiro)*
  Esqueleto alto envolto em armadura de placas escura e corroída, capa em farrapos. Empunha
  uma espada longa espectral (lâmina com aura azul-fria) e por vezes um escudo torre. Postura
  marcial, golpes pesados e lentos. Mini-chefe da zona.

- **★ Colosso de Ossos** — `gbs_bone_colossus` — GREAT_BOSS (andar 10) — *amálgama de ossos*
  Gigante montado com centenas de ossos e crânios fundidos numa só massa humanoide; costelas
  formam uma "jaula" no peito onde pulsa uma luz verde (o núcleo necromântico). Braços enormes
  terminam em punhos de ossos cravados. Na fase de fúria (50% HP) os ossos se reorganizam,
  ele cresce e ganha espinhos. Sem armas — usa o próprio corpo (esmagar, ondas de osso).

---

## Zona 2 — O Pântano Pestilento (andares 11–20)
*Tema: doença, podridão, esgotos e pântanos. Paleta: verde-pus, marrom, roxo doentio.*

- **Zumbi Inchado** — `enm_bloated_zombie` — NORMAL — *morto-vivo*
  Cadáver inchado de gás, pele esverdeada estourando em bolhas; barriga translúcida deixando
  ver vísceras. Lento, cambaleante; ao morrer explode numa nuvem tóxica. Sem armas.

- **Rato da Peste** — `enm_plague_rat` — MINION — *besta*
  Rato do tamanho de um cão, pelo sarnento e caído, olhos leitosos, cauda pelada com pústulas.
  Anda em matilha e morde. Pequeno e rápido.

- **Cultista da Peste** — `enm_plague_cultist` — NORMAL — *humano (fanático)*
  Humano de manto de aniagem com máscara de bico de médico-da-peste (couro e vidro embaçado).
  Carrega um turíbulo (incensário) que solta fumaça verde e arremessa frascos de veneno.

- **Aberração da Lama** — `enm_swamp_horror` — ELITE — *limo/ooze*
  Massa gelatinosa verde-amarronzada semitransparente com detritos, ossos e armas enferrujadas
  suspensos dentro. Estende pseudópodes para golpear; divide-se em pedaços menores ao tomar
  dano pesado. Sem equipamento próprio (o "lixo" interno é decorativo).

- **★ Guardião da Peste** — `gbs_plague_warden` — GREAT_BOSS (andar 20) — *humanoide corrompido*
  Figura alta e curvada em túnica encharcada, máscara de bico enorme e enferrujada; do corpo
  brotam tumores e cogumelos luminescentes. Numa das mãos, um lampião que exala esporos; na
  outra, uma foice de coveiro. Na fúria (50%), a máscara racha e libera nuvens de esporos
  mais densas; invoca esporos vivos.

---

## Zona 3 — A Forja Infernal (andares 21–30)
*Tema: fogo, demônios, salões de lava e ferro. Paleta: laranja, vermelho, preto-carvão.*

- **Imp Brasa** — `enm_ember_imp` — MINION — *demônio*
  Pequeno demônio vermelho-alaranjado com chifres curtos, asas membranosas e cauda em ponta
  de lança; rastro de brasas. Voa em grupo e cospe fagulhas. Sem equipamento.

- **Salamandra de Lava** — `enm_lava_salamander` — NORMAL — *besta elemental*
  Lagarto grande de pele rachada como rocha vulcânica, fendas brilhando lava entre as escamas.
  Investe e dá rabadas; deixa poças de fogo. Sem armas.

- **Cão Infernal** — `enm_hellhound` — NORMAL — *besta demoníaca*
  Mastim esquelético-musculoso de pelo carbonizado, juba de chamas e olhos brancos brilhantes;
  babo de brasa. Rápido, ataca em investidas e mordida flamejante.

- **Cavaleiro da Forja** — `enm_forge_knight` — ELITE — *humanoide (demônio armado)*
  Demônio robusto em armadura de ferro negro incandescente nas juntas, chifres recurvados.
  Empunha um malho/martelo de guerra em brasa que solta fagulhas a cada golpe no chão.

- **★ Tirano das Chamas** — `gbs_flame_tyrant` — GREAT_BOSS (andar 30) — *senhor demoníaco (caster)*
  Demônio alto e imperioso de pele de obsidiana com veios de magma, coroa de chifres e um
  manto de fogo vivo nas costas. Conjura com as mãos (bolas de fogo, meteoros) e empunha um
  cetro de ferro coroado por uma chama. Na fúria (50%), o manto explode em chamas e ele
  flutua sobre o chão derretido.

---

## Zona 4 — O Sepulcro Gélido (andares 31–40)
*Tema: gelo, mortos congelados, assombrações. Paleta: azul-claro, branco, ciano.*

- **Servo Congelado** — `enm_frozen_thrall` — NORMAL — *morto-vivo gélido*
  Cadáver azulado encrustado em gelo, lascas de gelo crescendo do corpo; movimentos rígidos e
  estalando. Restos de armadura presos no gelo. Soco/garra congelante.

- **Lobo de Gelo** — `enm_ice_wolf` — MINION — *besta*
  Lobo de pelagem branco-azulada com cristais de gelo na juba e hálito de vapor frio; olhos
  azul-elétrico. Caça em alcateia, ágil.

- **Assombração Gélida** — `enm_frost_wraith` — NORMAL — *espectro*
  Espírito translúcido azul-ciano sem pernas (calda de névoa), rosto cavernoso e gritante;
  mãos espectrais que congelam ao toque. Flutua e atravessa parcialmente; arremessa lanças
  de gelo.

- **Golem de Gelo** — `enm_frost_golem` — ELITE — *constructo elemental*
  Coloso feito de blocos de gelo e pedra glacial, núcleo azul brilhante visível no peito;
  punhos enormes. Lento, mas devastador; cria estacas de gelo no solo. Sem armas (corpo).

- **★ Espectro Gélido** — `gbs_frost_revenant` — GREAT_BOSS (andar 40) — *senhor espectral (controlador)*
  Aparição majestosa de um antigo rei-cavaleiro morto no frio: armadura ornamentada coberta de
  geada, capa esfarrapada de gelo, coroa quebrada flutuando sobre um elmo de onde escapa névoa
  azul. Empunha uma espada longa espectral coberta de cristais. Controla o campo: aura de
  lentidão, nova de gelo. Na fúria (50%), o ambiente congela e ele invoca a nevasca.

---

## Zona 5 — O Santuário das Sombras (andares 41–50)
*Tema: trevas, assassinos, vazio, guardiões alados. Paleta: preto-arroxeado, magenta, prata.*

- **Lâmina das Sombras** — `enm_shadow_blade` — NORMAL — *humanoide (assassino)*
  Vulto humanoide de contorno indefinido, "feito" de fumaça negra com dois olhos magenta e
  uma máscara prateada lisa. Empunha duas adagas curvas que deixam rastro escuro; teleporta
  curtas distâncias e ataca pelas costas.

- **Sombra Rastejante** — `enm_creeping_shade` — MINION — *vazio*
  Mancha de escuridão viva que desliza pelo chão como uma poça, erguendo-se em garras quando
  perto. Quase sem forma; magenta fraco no "núcleo". Enxame.

- **Cultista do Vazio** — `enm_void_cultist` — NORMAL — *humano (mago sombrio)*
  Humano encapuzado de manto negro com bordados prateados de símbolos; rosto coberto por uma
  máscara-espelho. Conjura projéteis de energia escura e abre breves fendas que sugam. Cajado
  rúnico em obsidiana.

- **Gárgula Sentinela** — `enm_gargoyle` — ELITE — *constructo alado*
  Estátua viva de pedra escura: corpo musculoso, asas de morcego, chifres e garras de pedra,
  olhos magenta. Fica imóvel como estátua e desperta investindo do ar (mergulho). Sem armas
  (garras/asas).

- **★ Carrasco das Sombras** — `gbs_shadow_executioner` — GREAT_BOSS (andar 50) — *ceifador (assassino)*
  Figura alta e esguia envolta num manto negro vivo que se desfaz em fumaça nas pontas; capuz
  vazio com dois pontos de luz magenta e uma coleira de correntes. Empunha uma **grande
  espada-foice (executioner sword)** prateada que brilha frio. Some e reaparece (shadow step),
  golpes em sequência (blade flurry) e um golpe de execução nos HP baixos. Três fases.

---

## Andares comuns — Guardiões recorrentes
Nos andares **sem** great boss, fecha o andar um **Guardião** (rank BOSS). Hoje há um único
modelo; o ideal é uma **variante por zona** (mesma silhueta, "roupagem" do tema):

- **Guardião da Torre** — `bss_guardian` — BOSS — *constructo guardião*
  Sentinela imponente de armadura pesada e ancestral (placas escuras com runas), elmo fechado
  sem rosto visível — só uma fenda luminosa. Empunha um grande martelo/maça e um escudo torre.
  Lento e resistente; golpe sísmico no chão (ground slam). Recolore por zona: ossos (Z1),
  enferrujado/musgo (Z2), em brasa (Z3), gélido (Z4), sombrio (Z5).

---

## Andar 51 — O Trono

- **★ O Rei da Torre** — `king_tyrant` — KING — *rei tirano (boss final)*
  O alvo da vingança. Rei humano outrora poderoso, agora corrompido pela própria torre: pele
  pálida com veios negros, olhos sem pupila brilhando dourado, manto real esfarrapado e uma
  coroa pesada e tortuosa cravada na carne. Armadura de placas dourada-escurecida, ornamentada.
  Empunha uma **espada larga real** e um cetro/orbe que canaliza magia (decreto real, nova da
  coroa, julgamento). Invoca guardas, escala em **três fases**, ficando mais sombrio e
  imponente a cada uma. Tamanho 96–128.

---

## Especial — O Eco (Nemesis)

- **Eco** — `ECHO` (rank ELITE, gerado em runtime) — *fantasma do próprio jogador*
  Não tem arte fixa: é a **silhueta do jogador** renderizada como um espectro translúcido em
  **ciano** (a cor do fantasma na paleta). Quando houver sprite do jogador, o Eco reusa o mesmo
  sprite com tonalização ciano/transparência e talvez um leve "rastro". Aparência = jogador +
  efeito fantasmagórico; arma = a do jogador no momento da morte.

---

### Resumo de produção (prioridade sugerida)
1. **Jogador** (define a densidade de pixel e o pipeline).
2. **Zona 1 completa** (Esqueleto, Servo, Necromante, Carniçal, Cavaleiro da Cripta, Colosso) —
   fecha a primeira "fatia jogável bonita".
3. **Guardião** recorrente (1 silhueta, 5 recolorações).
4. Zonas 2→5 na ordem dos andares.
5. **Rei** por último (o capricho final).
