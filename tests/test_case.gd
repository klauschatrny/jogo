## Classe base de testes (mini-framework sem dependências). Cada suíte estende esta classe
## e define métodos test_*(). Os asserts acumulam falhas em _errors; o test_runner reporta.
class_name TestCase
extends RefCounted

var _errors: Array[String] = []

func _reset() -> void:
	_errors = []

func assert_true(condition: bool, msg := "") -> void:
	if not condition:
		_errors.append("esperava true. %s" % msg)

func assert_false(condition: bool, msg := "") -> void:
	if condition:
		_errors.append("esperava false. %s" % msg)

func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if actual != expected:
		_errors.append("esperado <%s>, obtido <%s>. %s" % [expected, actual, msg])

func assert_null(value: Variant, msg := "") -> void:
	if value != null:
		_errors.append("esperava null, obtido <%s>. %s" % [value, msg])

func assert_almost(actual: float, expected: float, eps := 0.0001, msg := "") -> void:
	if abs(actual - expected) > eps:
		_errors.append("esperado ~<%f>, obtido <%f>. %s" % [expected, actual, msg])
