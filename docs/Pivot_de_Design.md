# Projeto - Pivot de Design

## Objetivo

Este projeto não será mais um Soulslike tradicional focado em exploração de mapas.

O projeto será pivotado para um **Action Roguelite** com combate inspirado em Soulslikes, onde o foco principal é a qualidade dos combates, bosses memoráveis e progressão estratégica entre batalhas.

Toda decisão de design e implementação deve reforçar essa direção.

---

# Nova Visão

O jogador enfrenta uma sequência de desafios dentro de uma estrutura única (torre, coliseu ou outra arena temática), avançando combate após combate.

A exploração deixa de ser o foco.

O combate passa a ser a experiência principal.

Cada encontro deve ser interessante por si só.

---

# Pilares do Projeto

## 1. Combate Profundo

O combate deve continuar sendo inspirado em Soulslikes.

Características desejadas:

- gerenciamento de stamina
- esquivas com iFrames
- parry (quando aplicável)
- leitura dos ataques inimigos
- animações com peso
- posicionamento importante
- punição por erros
- recompensa por habilidade

Não transformar o combate em um Hack'n Slash.

---

## 2. Progressão em Runs

Uma run consiste em uma sequência de combates.

Exemplo:

Combate

↓

Escolha recompensa

↓

Evento

↓

Combate

↓

Mini Boss

↓

Upgrade

↓

Boss

↓

Nova arena

Durante uma run o jogador fica progressivamente mais forte.

Ao morrer, parte da progressão é perdida, mas existe meta progressão permanente.

---

## 3. Rejogabilidade

Cada tentativa deve ser diferente.

A variedade vem através de:

- escolhas de upgrades
- ordem dos encontros
- eventos
- modificadores
- builds diferentes
- armas diferentes

O jogador nunca deve sentir que todas as runs são iguais.

---

## 4. Bosses

Bosses são o ponto alto do jogo.

Cada boss deve possuir:

- identidade visual forte
- padrões únicos
- mecânicas próprias
- recompensa significativa

Poucos bosses excelentes são melhores do que muitos bosses genéricos.

---

## Estrutura Geral

Uma run será composta por diversos nós.

Exemplo:

Combat
Elite Combat
Boss
Merchant
Blacksmith
Treasure
Rest
Random Event

Cada nó representa uma sala.

Não existem mapas grandes para exploração.

---

## Progressão Permanente

Mesmo após morrer o jogador mantém progresso.

Possíveis elementos permanentes:

- novas armas
- novos personagens
- novos augments
- novas bênçãos
- melhorias da base
- novos inimigos
- novas regiões

Sempre deve existir sensação de progresso.

---

## Progressão Temporária

Durante a run o jogador monta sua build.

Exemplos:

- aumento de atributos
- novas habilidades
- modificadores
- efeitos elementais
- melhorias de stamina
- melhorias de esquiva
- melhorias de parry

A build da run deve surgir das escolhas feitas pelo jogador.

---

# Sistema de Augments

Após determinados combates o jogador escolhe uma recompensa.

Exemplo:

Escolha entre 3 opções.

Exemplos de augments:

- +15% dano
- +20% stamina
- ataques aplicam sangramento
- crítico recupera vida
- executar inimigos recupera stamina

Os augments devem incentivar diferentes estilos de jogo.

---

# Atributos

Os atributos continuam existindo.

Exemplo:

Vitalidade

Força

Destreza

Resistência

Arcano

Eles podem ser melhorados durante a run ou através da meta progressão.

---

# Filosofia de Desenvolvimento

Sempre priorizar:

1. Melhor combate
2. Melhor feedback visual
3. Melhor IA
4. Melhor variedade de builds
5. Melhor variedade de inimigos

Antes de adicionar:

- mapas maiores
- exploração
- diálogos longos
- quests
- colecionáveis

Pergunta obrigatória:

"Isto melhora a experiência principal de combate?"

Se a resposta for não, reavaliar.

---

# Escopo

Sempre preferir:

Menos conteúdo

Mais qualidade.

Exemplos:

10 inimigos excelentes

é melhor que

40 inimigos parecidos.

8 armas extremamente diferentes

é melhor que

30 armas quase iguais.

10 bosses memoráveis

é melhor que

40 bosses simples.

---

# Diretrizes Técnicas

Sempre desenvolver sistemas modulares.

Evitar código específico para um único inimigo.

Preferir componentes reutilizáveis.

Todo sistema deve permitir expansão futura.

Exemplos:

Status Effects

Augments

Loot

IA

Skills

Buffs

Debuffs

Drops

Eventos

Todos devem ser independentes.

---

# Diretrizes para IA de Desenvolvimento

Ao sugerir novas funcionalidades, priorizar sempre:

- aumentar profundidade do combate
- aumentar variedade das runs
- melhorar a tomada de decisão do jogador
- reduzir repetição
- reutilizar sistemas existentes
- evitar aumento desnecessário do escopo

Evitar sugerir sistemas grandes de exploração ou mundo aberto.

Sempre considerar o custo de implementação versus impacto na experiência.

---

# Identidade do Projeto

O jogo deve ser reconhecido como:

"Um Action Roguelite focado em combates técnicos inspirados em Soulslikes."

Não como:

"Um Soulslike simplificado."

Todo novo sistema deve reforçar essa identidade.