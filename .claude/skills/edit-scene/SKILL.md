---
name: edit-scene
description: .tscn ファイルを安全に編集する。ノードの追加・削除・プロパティ変更・シーン新規作成を行う際は必ずこの手順に従う。
---

# .tscn 編集手順

`.tscn` は INI 風のテキストなので Claude が直接編集できる。この運用の価値の
大半はそこにあるが、壊し方も決まっている。以下を必ず踏むこと。

## 事前確認

1. 対象の `.tscn` を**全文読む**（部分読みは禁止）
2. `[gd_scene]` 行の `load_steps` と `format` を控える
3. 既存の `uid=` と `id=` をすべて列挙する

## ノード追加

1. 追加位置の親ノード名を確認する
2. 新しい `[node name="..." type="..." parent="親のパス"]` を、
   ツリー順（**親が必ず先**）を崩さない位置に挿入する
   - ルート直下なら `parent="."`
   - 孫なら `parent="Player/Sprite2D"` のようにルートからの相対パス
   - `parent=` に書くのはノード「**名**」であってノード「型」ではない
3. 新しい ext_resource が必要なら:
   - `id` は `<連番>_<ランダム英数5文字>` 形式（例: `3_k2m9x`）
   - 既存 id と重複しないこと
   - `uid=` は書かない（Godot がインポート時に補完する）
4. `load_steps` を「ext_resource 数 + sub_resource 数 + 1」に更新する

## ノード削除

1. 削除対象を `parent=` に指定している子ノードをすべて洗い出す
2. 子ノードごと削除するか、親を付け替えるかを決める
3. そのノードだけが参照していた ext_resource / sub_resource も削除する
4. `load_steps` を更新する

## 絶対禁止

- 既存の `uid://` の書き換え
- `format=` の変更
- `.import` ファイルの編集

## 完了後（省略しない）

必ずローカルで検証する。`.tools/godot` が無ければ
`bash tools/ci/install_godot.sh` で取得すること。

```bash
.tools/godot --headless --path . --import --quit
.tools/godot --headless --path . --script res://tools/validate_scenes.gd
```

`validate_scenes.gd` は実行時の load/instantiate に加えて、
`parent=` の解決先・`ExtResource` の参照先・`load_steps` をテキストレベルで
検査する。**`parent=` の破損は Godot だと警告止まりで instantiate が成功して
しまうため、この検査を通すことが唯一の確実な確認手段。**

ローカルで Godot を用意できない環境では、PR を出して `godot-tests` の
`lint` ジョブ（Validate scenes and resources ステップ）の結果を待つこと。

## よくある失敗

- `parent=` にノード「型」を書いてしまう（正しくはノード「名」）
- 親より先に子ノードを書いてしまう
- `ExtResource("3")` のように id を数字だけで参照する
  （宣言した id 文字列の全体が必要）
- ノードを消したのに、そのノードだけが使っていた ext_resource が残る
