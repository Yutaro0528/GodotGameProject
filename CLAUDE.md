# プロジェクト規約

## AI エージェントモデル利用ルール（最優先・必須）

以下はユーザーが定めたルール。原文のまま掲載する。**他のどの記述よりも優先する。**

```
AIエージェントモデル利用ルール
- 司令塔は Opus5 を使用する
- レビューは Opus5 を使用する
- 実装や調査は Sonnet を使用する
- 利用の判断が難しい場合はユーザーに判断を委ねる
- もし選択されたモデルが Fable5 だった場合は Opus5 の部分を Fable5 に差し替える
- モード選択で Plan モードが選択されていない場合は警告を出して、そのまま進めても良いか確認する
```

### 運用への落とし込み

| ルール | このリポジトリでの実装 |
|---|---|
| 司令塔は Opus5 | メインセッションが司令塔。`.github/workflows/claude.yml` は `--model claude-opus-5` で起動する |
| レビューは Opus5 | `godot-reviewer` サブエージェント（`model: opus`）に委譲する。`.github/workflows/claude-review.yml` も `--model claude-opus-5` |
| 実装や調査は Sonnet | `godot-implementer` / `godot-researcher` サブエージェント（`model: sonnet`）に委譲する。**司令塔が自分でコードを書き始めない** |
| 判断が難しい場合はユーザーに委ねる | `AskUserQuestion` で確認する。解釈の違いで成果物が変わる論点だけを聞き、細かい判断は自分で決めて記録する |
| Fable5 のときは Opus5 を Fable5 に差し替え | セッションのモデルが Fable 5.1 なら、司令塔とレビューの役割を Fable5 が担う。`godot-reviewer` を呼ぶときは Agent ツールの `model` を `"fable"` で上書きする（frontmatter の `opus` より呼び出し時の指定が優先される） |
| Plan モード未選択なら警告して確認 | `.claude/hooks/check_plan_mode.py`（UserPromptSubmit フック）が検出して警告文を注入する。指示に従い、着手前に `AskUserQuestion` で確認すること |

Plan モードの警告は既定で**1 セッション 1 モードにつき 1 回**（モードが変われば再警告）。
毎プロンプト警告に戻したい場合は `.claude/hooks/check_plan_mode.py` の
`WARN_EVERY_PROMPT` を `True` にする。

## 環境

- Godot 4.7.2 / GDScript（**静的型付けを必須とする**）
- 2D、ピクセルアート、テクスチャフィルタは Nearest
- テスト: gdUnit4 v6.2.1（`res://tests/`、`addons/gdUnit4/` にコミット済み）
- C# は使わない（GDScript のみ。理由は README の「言語方針」を参照）

## 開発運用

あなたは GitHub Actions 上、またはローカル Godot エディタの無い環境で動作しており、
Godot エディタの GUI は使えません。ただし `.tscn` / `.tres` はテキストなので
**直接編集して構いません**。

### できること

- `.gd` の作成・編集
- `.tscn` のノード追加・プロパティ変更・シーン新規作成
- `.tres`（カスタム Resource）の作成・編集
- `project.godot` の autoload / input map の追記

### できないこと（PR 本文の「ローカル作業依頼」に書くこと）

- 画像・音声ファイルの作成
- `.import` の再生成が必要な操作
- 実際にプレイしての手触り確認

## コード配置の規約

判断基準は「**シーンツリー無しでテストできるか**」。

| 置き場所 | 何を書くか |
|---|---|
| `scripts/core/` | `RefCounted` 派生の純粋ロジック（アルゴリズム、状態機械、戦闘計算、データ変換）。`Node` / シーンツリー / シグナル / `res://` の入出力に触れない。乱数は `RandomNumberGenerator` を注入して決定性を保つ |
| `scripts/` | `Node` 派生。`_ready` / `_process`、シグナル接続、UI（`Control`）、入力処理、Godot API 呼び出し |
| `scripts/resources/` + `resources/` | `Resource` 派生のデータ定義と `.tres` 実体 |

計算とノード操作が混ざった要件は、実装前に分ける。
`tests/` のテストは原則 `scripts/core/` を対象にする（`Node` 依存のテストは遅く壊れやすい）。

参考実装: `scripts/core/health.gd`（純粋ロジック）と `scripts/main.gd`（それを使う Node）

## GDScript 規約

- すべての変数・引数・戻り値に型注釈を付ける（`var hp: int = 10`）
- `@onready` を使い、`get_node()` の直呼びは避ける
- ノードパスのハードコードを避け、`@export var target: Node2D` で注入する
- シグナルは `signal damaged(amount: int)` のように型付きで宣言する
- `class_name` は必ず付ける（テストから参照するため）

## .tscn 編集ルール

**`.tscn` を触るときは必ず `edit-scene` スキルの手順に従うこと。**

- 既存の `uid://` は絶対に書き換えない
- 新規 ext_resource の id は `<連番>_<ランダム5文字>` 形式にする
- `load_steps` は ext_resource + sub_resource の総数 + 1 に合わせる
  （ずれても Godot は復旧するが、差分が汚れる）
- ノードを消すときは、そのノードを参照する `parent=` も併せて処理する
- `parent=` に書くのはノード「名」であってノード「型」ではない

## 完了の定義

1. `godot-tests` ワークフローがグリーン（`lint` と `test` の両方）
2. `--check-only` でパースエラーがゼロ
3. 追加・変更したロジックに対応するテストがある
4. PR 本文に「ローカル作業依頼」と「動作確認手順」が記載されている

### プッシュ前の自己検証（CI を待たない）

このリポジトリでは Claude 自身がローカルで検証できる。**CI に投げる前に必ず回すこと。**

```bash
bash tools/ci/install_godot.sh   # .tools/godot が無ければ（初回のみ）

.tools/godot --headless --path . --import --quit
.tools/godot --headless --path . --script res://tools/validate_scenes.gd
GODOT_DISABLE_LEAK_CHECKS=1 .tools/godot --headless \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

- `--import` は省略不可。`.godot/` をコミットしていないため、飛ばすと
  `class_name` が未登録になりテストのブートストラップが落ちる
- `--ignoreHeadlessMode` は gdUnit4 のヘッドレス警告を抑えるため。
  CI では gdUnit4-action が面倒を見るので不要

## その他の運用ルール

- **1 PR = 1 機能。** `project.godot`（autoload / input map）を触る PR は
  競合しやすいので他の変更と混ぜず、先にマージする
- コミットメッセージは Conventional Commits（`feat:` / `fix:` / `chore:` / `docs:`）
- テストをスキップ・無効化して CI を緑にするのは禁止
- Godot の API は変化が速い。クラス名やメソッドシグネチャに自信がないときは
  記憶で書かず、`godot-docs` MCP サーバ（`godot_docs_search` /
  `godot_docs_get_class` / `godot_docs_get_page`）で確認する
