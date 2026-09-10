---
name: add-feature
description: Issue から機能を実装して PR を出すまでの一連の手順。GitHub 中心開発の基本フローで、実装依頼を受けたときはこの順序で進める。
---

# Issue → 実装 → PR の手順

## 0. モデルの使い分け（CLAUDE.md の必須ルール）

- **あなた（司令塔）は Opus5。** 方針決定・分解・レビュー結果の判断を行う
- **実装と調査は Sonnet に委譲する。** `godot-implementer` / `godot-researcher`
  サブエージェントを使う。自分で書き始めない
- **レビューは Opus5。** `godot-reviewer` サブエージェントを使う
- セッションのモデルが **Fable5 の場合は、Opus5 の役割をすべて Fable5 に読み替える**
  （`godot-reviewer` を呼ぶときは `model` を `fable` で上書きする）
- 判断が難しい場合は自分で決めず、`AskUserQuestion` でユーザーに委ねる

## 1. 要件を確定させる

Issue の受け入れ条件を読み、曖昧な点を洗い出す。
**解釈の違いで成果物が変わる点だけ**ユーザーに確認する。
細かい判断は自分で決めて、決めた内容を PR 本文に書く。

必要なら `godot-researcher` に既存コードの調査を投げる。

## 2. コードの置き場所を決める

判断基準は「**シーンツリー無しでテストできるか**」。

- Yes → `scripts/core/`（`RefCounted` 派生の純粋ロジック）
- No  → `scripts/`（`Node` 派生。シグナル・UI・入力）

計算とノード操作が混ざっている要件は、**先に分ける**。
ここを曖昧にしたまま実装すると、テストが遅く壊れやすくなる。

## 3. テストを設計する

`scripts/core/` に置くロジックには必ずテストを書く。
先に「何が満たされたら完了か」をテストの形にしてから実装に入る。

- テスト対象は `RefCounted` 派生クラス。`Node` を経由しない
- 境界値（0、最大値、負の入力）を含める
- 既存の `tests/test_health.gd` の書き方に合わせる

## 4. 実装を委譲する

`godot-implementer` に渡す。渡すときに必ず含めること:

- 何を作るか（受け入れ条件）
- どこに置くか（`scripts/core/` か `scripts/` か）
- 書くべきテスト
- `.tscn` を触る場合はその旨（`edit-scene` スキルに従わせる）

## 5. 検証する

実装エージェントの報告を鵜呑みにせず、自分でも確認する。

```bash
bash tools/ci/install_godot.sh   # .tools/godot が無ければ
.tools/godot --headless --path . --import --quit
.tools/godot --headless --path . --script res://tools/validate_scenes.gd
GODOT_DISABLE_LEAK_CHECKS=1 .tools/godot --headless \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

## 6. レビューする

`godot-reviewer` に変更内容を渡す。指摘は原則すべて対応する。
対応しないと判断したものは、その理由を PR 本文に書く。

## 7. PR を出す

- **1 PR = 1 機能**。`project.godot`（autoload / input map）を触る変更は
  競合しやすいので、他の変更と混ぜず、先にマージする
- `handoff-to-local` スキルに従い「ローカル作業依頼」と「動作確認手順」を書く
- コミットメッセージは Conventional Commits（`feat:` / `fix:` / `chore:` ...）

## 8. CI が赤くなったら

`read-test-log` スキルに従って原因を切り分ける。
「たぶん flaky」で再実行に逃げないこと。
