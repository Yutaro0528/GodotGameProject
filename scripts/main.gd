class_name Main
extends Node2D

## 起動シーンのルート。
##
## Node 依存の処理（シグナル接続・UI 更新）だけをここに書き、
## 計算そのものは `scripts/core/` の RefCounted 派生に置くこと。

## 表示に使う敵の定義。ノードパスをハードコードせず @export で注入する。
@export var enemy_stats: EnemyStats

@onready var _status_label: Label = $StatusLabel

var _health: Health


func _ready() -> void:
	if enemy_stats == null:
		enemy_stats = load("res://resources/enemies/slime.tres") as EnemyStats
	_health = enemy_stats.create_health()
	_refresh_label()


func _refresh_label() -> void:
	_status_label.text = "%s  HP %d/%d" % [
		enemy_stats.display_name,
		_health.get_current(),
		_health.get_max(),
	]
