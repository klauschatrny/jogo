# Fair Despair

Soulslike de ação 2D retrô, side-scroller. Stamina limita cada golpe e cada esquiva, os chefes têm
padrões que só se aprendem morrendo, e a morte não encerra nada: você levanta na última fogueira e
volta para tentar de novo.

**Stack:** Godot 4 + GDScript.

## Documentação

- **[`CLAUDE.md`](CLAUDE.md)** — estado real do projeto e guia de implementação. **Manda.**
- **[`TDV_Arquitetura.md`](TDV_Arquitetura.md)** — GDD + arquitetura originais. Ainda descrevem um
  *roguelike* (o nome antigo era "A Torre da Vingança"): a arquitetura segue valendo, o gênero não.
  Onde os dois divergem, vale o `CLAUDE.md`.

## Status

Jogável. Vila de tutorial → sala do Necromante → arena do Ogro, com fogueiras, augments e
armadilhas de cenário. A conversão de roguelike para soulslike está em curso: as fogueiras já
existem; faltam as almas caídas no corpo e os upgrades escolhidos no lugar das cartas aleatórias.

```bash
godot --headless --script res://tests/test_runner.gd   # suíte de testes (sai 0 se passar)
```

## Princípios de arquitetura (não-negociáveis)

1. **Data-driven** — armas, inimigos, augments, andares e constantes de tuning em JSON sob `data/`.
2. **Core puro** — lógica de jogo em `src/core/` sem dependências de render; 100% testável.
3. **RNG determinístico** — todo sorteio passa por um `RNGService` semeado (mesma seed → mesma run).
4. **Eventos sobre acoplamento** — sistemas conversam via `EventBus`; a UI escuta o Core, nunca o contrário.
