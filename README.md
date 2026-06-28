# A Torre da Vingança (Tower of Vengeance)

Roguelike de ação 2D retrô, com permadeath significativo, builds aleatórias por **Augments** e um
sistema **Nemesis** (Fantasma): onde você morre, deixa um eco que o boss daquele andar invoca na sua
próxima run.

**Stack:** Godot 4 + GDScript.

## Documentação

- **[`TDV_Arquitetura.md`](TDV_Arquitetura.md)** — GDD + arquitetura de software (documento canônico).
- **[`CLAUDE.md`](CLAUDE.md)** — guia para sessões de implementação assistida.

## Status

Pré-implementação. Nenhum código ainda — apenas os documentos de planejamento acima.

Próximos passos seguem o roadmap de 5 fases em `TDV_Arquitetura.md` §2.4, começando pela Fase 1
(estrutura de pastas, `BalanceConfig`, `EventBus`, `RNGService`, máquina de estados, loaders de JSON).

## Princípios de arquitetura (não-negociáveis)

1. **Data-driven** — armas, inimigos, augments, andares e constantes de tuning em JSON sob `data/`.
2. **Core puro** — lógica de jogo em `src/core/` sem dependências de render; 100% testável.
3. **RNG determinístico** — todo sorteio passa por um `RNGService` semeado (mesma seed → mesma run).
4. **Eventos sobre acoplamento** — sistemas conversam via `EventBus`; a UI escuta o Core, nunca o contrário.
