## Cria inimigos/bosses a partir do JSON. Os stats são os que o arquivo declara — ponto.
##
## Já houve aqui uma curva geométrica por andar (GROWTH^(f-1)) mais um multiplicador de rank:
## herança do roguelike, onde o mesmo esqueleto reaparecia 50 vezes e só a matemática o mantinha
## relevante. Num soulslike não existe "o esqueleto do andar 12" — existe o esqueleto DAQUELA
## área, com os números que o designer escolheu para ele ali. Um inimigo mais duro é uma
## ENTRADA NOVA em data/enemies/, não o mesmo bicho multiplicado.
##
## Consequência prática: para deixar algo mais forte, edite o JSON dele (ou crie uma variante com
## outro id e use-a nos níveis que a pedirem). Não existe mais botão global de dificuldade — e é
## de propósito, porque é justamente o botão global que impede afinar um encontro específico.
class_name EnemyFactory
extends RefCounted

static func build(base_dict: Dictionary) -> Enemy:
	return Enemy.from_dict(base_dict)

static func build_boss(base_dict: Dictionary) -> Boss:
	return Boss.from_dict(base_dict)
