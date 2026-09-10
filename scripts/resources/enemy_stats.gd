class_name EnemyStats
extends Resource

## 敵 1 種類ぶんのパラメータ定義。
##
## 実体は `resources/enemies/*.tres` に置き、値の調整はローカルの
## インスペクタでも Claude によるテキスト編集でも行える。
## `add-resource` スキルの手順に従って追加すること。

@export var display_name: String = ""
@export_range(1, 9999) var max_hp: int = 1
@export_range(0, 999) var attack: int = 0
@export_range(0.0, 1000.0, 0.1) var move_speed: float = 0.0


## この定義から実行時用の Health を組み立てる。
func create_health() -> Health:
	return Health.new(max_hp)
