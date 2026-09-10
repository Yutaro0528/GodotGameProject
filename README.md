# GodotGameProject

Godot エンジンを使ったゲーム開発の試作プロジェクト。

設計・実装・レビュー・マージを **GitHub 上で完結**させ、ローカルは
**Godot エディタでの動作確認とアセット制作専用**にする運用を採る。

- 環境: Godot **4.7.2** / GDScript（静的型付け必須）/ 2D ピクセルアート
- テスト: gdUnit4 **v6.2.1**（`addons/gdUnit4/` にコミット済み）
- 規約の実体は [`CLAUDE.md`](CLAUDE.md)。**AI エージェントのモデル利用ルールもそこに記載**

## 責務分担

| 領域 | GitHub（Claude） | ローカル（人間） |
|---|---|---|
| GDScript | ◎ 主担当 | 必要時のみ |
| `.tscn`（シーン） | ◎ 編集可 | 複雑な構造の初回作成 |
| `.tres`（リソース） | ◎ 主担当 | 値の微調整 |
| スプライト・音源 | ✕ | ◎ 主担当 |
| `.import` 設定 | △ | ◎ |
| テスト | ◎ 実装＋CI 実行 | — |
| 動作確認・手触り調整 | ✕ | ◎ 主担当 |

## 日々の運用フロー

```
[GitHub]                                  [ローカル]

1. Issue 起票
2. @claude で実装依頼
3. Claude が PR を作成
   （.gd + .tscn + .tres + テスト）
4. lint → scene validation → tests
   ├─ 失敗 → PR コメントで @claude
   └─ 成功
5. Claude Review + 人間の一次レビュー
6. アセット依頼を確認 ──────────► 7. git pull
                                    8. スプライト等を配置
                                    9. F5 でプレイして確認
                                   10. コミット & push
   │◄──────────────────────────────┘
11. 手触りの調整を @claude に依頼
12. マージ
```

## ローカルのセットアップ

1. **Git LFS を有効にする**（画像・音声は LFS 管理。これを忘れるとポインタ
   ファイルしか落ちてこない）

   ```bash
   git lfs install
   git clone https://github.com/Yutaro0528/GodotGameProject
   ```

2. **Godot 4.7.2**（通常版。.NET 版は不要）を入手して `project.godot` を開く
3. 初回起動時に `Project → Project Settings → Plugins` で **gdUnit4** が
   有効になっていることを確認する

## CI

`.github/workflows/godot-tests.yml` が PR ごとに 2 段階で走る。

| ジョブ | 内容 |
|---|---|
| `lint` | import ウォームアップ → 全 `.gd` のパースチェック → **シーン / リソース検証** |
| `test` | gdUnit4 でテスト実行（`res://tests`） |

`lint` の **Validate scenes and resources** が、この運用の要になるガード。
Claude が `.tscn` をテキスト編集する以上、破損の自動検出がないと
「ローカルで開いた瞬間に壊れている PR」が積み上がる。

`tools/validate_scenes.gd` は実行時の `load()` / `instantiate()` に加えて、
テキストレベルで以下を検査する:

- `parent=` が実際に宣言済みのノードパスを指しているか
  （**Godot は不正な `parent=` を警告止まりにして instantiate に成功してしまう**ため、
  この検査が唯一の確実な検出手段）
- `ExtResource("...")` / `SubResource("...")` の参照先が宣言されているか
- `load_steps` が「ext_resource + sub_resource + 1」と一致しているか（警告）

### ローカルで CI と同じ検証を回す

```bash
bash tools/ci/install_godot.sh   # .tools/ に Godot を取得（gitignore 済み）

.tools/godot --headless --path . --import --quit
.tools/godot --headless --path . --script res://tools/validate_scenes.gd
GODOT_DISABLE_LEAK_CHECKS=1 .tools/godot --headless \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

## Claude まわりのセットアップ（リポジトリ管理者が一度だけ）

1. **Claude GitHub App の導入** — ローカルの Claude Code ターミナルで
   `/install-github-app` を実行する。手動の場合は
   <https://github.com/apps/claude> をリポジトリにインストールし、
   Contents / Issues / Pull requests の読み書きを許可する
2. **`ANTHROPIC_API_KEY`** をリポジトリシークレットに追加する
3. これで Issue や PR に `@claude` と書くと `.github/workflows/claude.yml` が起動し、
   PR が `opened` / `synchronize` されると `claude-review.yml` が自動レビューする

## リポジトリ構成

```
CLAUDE.md                    # 規約（モデル利用ルールを含む）
.claude/
  settings.json              # フック登録・権限
  hooks/check_plan_mode.py   # Plan モード未選択の警告
  agents/                    # godot-implementer(sonnet) / researcher(sonnet) / reviewer(opus)
  skills/                    # edit-scene / add-resource / handoff-to-local
                             # add-feature / read-test-log
.mcp.json                    # godot-docs MCP（Godot 公式ドキュメント検索）
.github/
  workflows/                 # godot-tests / claude / claude-review
  ISSUE_TEMPLATE/feature.yml
  pull_request_template.md
addons/gdUnit4/              # テストフレームワーク（v6.2.1 ピン留め）
scenes/                      # .tscn
scripts/                     # Node 派生（UI・シグナル・入力）
scripts/core/                # RefCounted 派生の純粋ロジック（テスト対象）
scripts/resources/           # Resource 派生のデータ定義
resources/                   # .tres 実体
art/                         # 画像・音声（LFS 管理）
tests/                       # gdUnit4 テスト
tools/                       # validate_scenes.gd / ci/install_godot.sh
```

## 言語方針

**GDScript のみ**を使う。C# は使わない。

再利用可能なアルゴリズムを C# の独立ライブラリに切り出す案も検討したが、
以下の理由で見送った。

- GDScript から呼べる C# クラスは **Godot クラスの継承が必須**なため、
  純粋なロジック層とは別にブリッジ層を書き続ける手間が発生する
- Claude Code の Web セッションからは **.NET SDK の配布元にネットワークが
  通らず**、C# のビルド・テストをローカルで検証できない
  （コンパイルエラーが PR を出すまで分からなくなる）
- Godot .NET 版バイナリと .NET SDK のセットアップで CI が伸びる

再利用性とテスト容易性は、`scripts/core/` に `RefCounted` 派生の純粋ロジックを
分離する規約で確保している（`CLAUDE.md` の「コード配置の規約」）。

## 第三者製スキルについて（未導入）

Godot 向けの公開 Claude スキル / プラグインがいくつかある。
**本リポジトリでは中身を検証していないため導入していない。**
入れる場合は内容を読んでから、以下の手順で追加する。

```bash
claude plugin marketplace add gamedev-skills/awesome-gamedev-agent-skills
claude plugin install godot@awesome-gamedev-agent-skills
```

他の選択肢: `thedivergentai/GD-Agentic-Skills`、`jame581/GodotPrompter`、
`vl4dt/godot-skills`、`Randroids-Dojo/Godot-Claude-Skills`、
`alexmeckes/godot-claude-skills`

注意点:

- 第三者製コードが環境に入る。**特にスクリプトを含むスキルは実行内容を確認すること**
- エンジン全部入りより Godot バンドルだけを入れるほうがコンテキストを節約できる
- 本リポジトリ固有の運用（`.tscn` 編集手順、ローカルへの引き継ぎ）は
  `.claude/skills/` の自作スキルが担当しており、公開スキルでは代替できない
