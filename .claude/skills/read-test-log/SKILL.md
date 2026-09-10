---
name: read-test-log
description: godot-tests ワークフローや gdUnit4 の出力を読んで失敗の原因を切り分ける。CI が赤くなったとき、テストが落ちたときに使う。
---

# テスト結果の読み方と切り分け

## まずジョブを特定する

`godot-tests` は 2 段階。**どこで落ちたかで原因の範囲が決まる。**

| 落ちた場所 | 意味 | 見るべきもの |
|---|---|---|
| `lint` / Import project | プロジェクトが読み込めない | `project.godot` の構文、参照先の欠落 |
| `lint` / Check GDScript | パースエラー | エラーメッセージのファイル:行 |
| `lint` / Validate scenes | **シーン / リソースの破損** | 下記「validate_scenes の読み方」 |
| `test` | テストの失敗 | gdUnit4 のレポート |

## validate_scenes の読み方

`[FAIL]` 行がそのまま原因を指している。

- `node "X" has parent="Y" which is not a declared node path`
  → `parent=` の指定ミス。ノード「型」を書いていないか、
    親より先に子を書いていないか、消したノードを指していないかを確認。
    `edit-scene` スキルの「よくある失敗」を見直すこと
- `ExtResource("X") references an id that is not declared`
  → ext_resource の宣言を消したか、id を数字だけで参照している
- `load() failed` / `instantiate() failed`
  → 上の 2 つが根本原因なことが多い。先にそちらを直す
- `[warn] load_steps=N but expected M`
  → 動作には影響しないが差分が汚れるので直す

## gdUnit4 の結果の読み方

`Statistics: N test cases | E errors | F failures | ...` の行を見る。

- **`failures` があればテストの失敗。** アサーションのメッセージが
  期待値と実際値を出しているので、そこから追う
- **`orphans` はメモリリークの警告。** テストの失敗ではないが、
  `RefCounted` でなく `Node` を作って `free()` し忘れている可能性がある

## 「テストは通っているのに CI が赤い」場合

まず gdUnit4 の出力に `Exit code: 0` と
`The tests was successfully with exit code: 0` があるか確認する。
**あれば失敗しているのはテストではなく、その後のレポート公開処理。**

- `##[error]HttpError: Resource not accessible by integration`
  → gdUnit4-action が内部で使う `dorny/test-reporter` が
    チェックランを作れていない。ジョブに `checks: write` 権限が要る。
    `godot-tests.yml` の `test` ジョブの `permissions` を確認すること
    （フォークからの PR では権限が付与されないため、その場合は
    Action の `publish-report: false` を検討する）

次に、Godot 終了時の RID/ObjectDB リーク警告による非ゼロ終了を疑う。
ワークフローには `GODOT_DISABLE_LEAK_CHECKS: "1"` を設定済み。
それでも起きる場合は、テストが `Node` を生成して解放していないことを疑う。

## 「class_name が見つからない」場合

`--import` のウォームアップが走っていない。`.godot/` はコミットしていないため、
import を飛ばすと `class_name` が未登録になりブートストラップが落ちる。
ローカルで再現するときも先に import すること。

## flaky と判断する前に

**「たぶん flaky」で再実行に逃げない。** 再実行してよいのは:

- テスト本体が始まる前に落ちた場合（checkout / セットアップ / ランナー消失）
- 同じコミットで以前は通っていた場合

それ以外は実際の失敗として原因を追うこと。
テストをスキップ・無効化して緑にするのは禁止。

## ローカルでの再現

```bash
bash tools/ci/install_godot.sh
.tools/godot --headless --path . --import --quit
.tools/godot --headless --path . --script res://tools/validate_scenes.gd
GODOT_DISABLE_LEAK_CHECKS=1 .tools/godot --headless \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

`--ignoreHeadlessMode` が要るのは、gdUnit4 が「ヘッドレスでは InputEvent が
届かない」と警告して終了するため。UI 入力を伴わないテストでは問題ない。
CI では gdUnit4-action が面倒を見るのでこのフラグは不要。
