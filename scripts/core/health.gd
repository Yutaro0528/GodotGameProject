class_name Health
extends RefCounted

## HP を管理する純粋ロジック。
##
## シーンツリー・シグナル・Godot の入出力に依存しないため、
## gdUnit4 から `Health.new(...)` で直接生成してテストできる。
## Node に依存する振る舞い（シグナル送出や演出）は
## `scripts/` 側の Node がこのクラスをラップして行うこと。

var _max: int
var _current: int


func _init(max_hp: int) -> void:
	assert(max_hp > 0, "max_hp must be positive")
	_max = max_hp
	_current = max_hp


func get_max() -> int:
	return _max


func get_current() -> int:
	return _current


func is_alive() -> bool:
	return _current > 0


## ダメージを適用し、実際に減った量を返す。
## 負の amount は受け付けない（回復は heal() を使う）。
func take_damage(amount: int) -> int:
	assert(amount >= 0, "damage must not be negative")
	var before: int = _current
	_current = maxi(_current - amount, 0)
	return before - _current


## 回復を適用し、実際に回復した量を返す。
## 死亡状態からの復帰はここでは行わない（呼び出し側の責務）。
func heal(amount: int) -> int:
	assert(amount >= 0, "heal must not be negative")
	var before: int = _current
	_current = mini(_current + amount, _max)
	return _current - before


## 0.0〜1.0 の残量比率。UI のバー表示などに使う。
func get_ratio() -> float:
	return float(_current) / float(_max)
