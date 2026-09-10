---
name: add-resource
description: カスタム Resource クラスと .tres ファイルをセットで作成・編集する。ゲームのパラメータやデータ定義を追加するときに使う。
---

# カスタム Resource の追加手順

値の調整をローカルのインスペクタでも Claude のテキスト編集でも行えるように、
データはスクリプトのハードコードではなく `Resource` + `.tres` に逃がす。

参考実装: `scripts/resources/enemy_stats.gd` と `resources/enemies/slime.tres`

## 1. Resource クラスを作る

`scripts/resources/<name>.gd`:

```gdscript
class_name EnemyStats
extends Resource

## 1 行で何のデータかを書く。

@export var display_name: String = ""
@export_range(1, 9999) var max_hp: int = 1
```

- `class_name` は**必須**（`.tres` の `script_class` とテストから参照するため）
- すべての `@export` に型注釈を付ける
- 数値には `@export_range` で妥当な範囲を付ける（ローカルでの調整を安全にする）
- 実行時オブジェクトの組み立てメソッド（例: `create_health()`）を持たせると、
  呼び出し側が `Resource` の中身を知らずに済む

## 2. `.tres` を書く

`resources/<category>/<name>.tres`:

```ini
[gd_resource type="Resource" script_class="EnemyStats" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/enemy_stats.gd" id="1_a3k9m"]

[resource]
script = ExtResource("1_a3k9m")
display_name = "Slime"
max_hp = 12
```

- `load_steps` = ext_resource 数 + sub_resource 数 + 1
- `id` は `<連番>_<ランダム英数5文字>` 形式
- `script_class` はクラス名と一致させる
- `uid=` は書かない（Godot が補完する）
- **既存ファイルを編集する場合、既存の `uid://` は絶対に書き換えない**

## 3. 検証する

```bash
.tools/godot --headless --path . --import --quit
.tools/godot --headless --path . --script res://tools/validate_scenes.gd
```

`resources/` 配下の `.tres` は `validate_scenes.gd` の検査対象に入っている。

## 4. テストを足す

`Resource` に計算ロジックを持たせた場合は `tests/` にテストを書く。
`load("res://resources/...")` で読んで検証すれば、`.tres` の値の妥当性も
同時に守れる（`tests/test_health.gd` の `test_enemy_stats_builds_health` を参照）。
