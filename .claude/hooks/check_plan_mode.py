#!/usr/bin/env python3
"""Plan モード未選択を検出して Claude に警告させる UserPromptSubmit フック。

CLAUDE.md の「AI エージェントモデル利用ルール」の以下を実装する:

    モード選択で Plan モードが選択されていない場合は警告を出して、
    そのまま進めても良いか確認する

仕組み:
  UserPromptSubmit フックの入力 JSON には permission_mode が入る。
  これが "plan" 以外なら additionalContext を返し、Claude 自身に
  「警告して確認してから着手せよ」と指示する。decision は使わないので
  プロンプトがブロックされることはない。

警告の頻度について:
  ルールの文面は「毎プロンプト警告」とも読めるが、既定では
  1 セッション 1 モードにつき 1 回だけ警告する（モードが変われば再警告）。
  毎回警告すると短い質問のたびに確認が挟まって実用に耐えないため。
  毎回警告に戻したい場合は下の WARN_EVERY_PROMPT を True にすること。
"""

import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path

# True にすると、Plan モードでない限り毎プロンプト警告する（ルール文面どおりの挙動）
WARN_EVERY_PROMPT = False

WARNING = """\
[プロジェクト規約 / モード確認]

現在のパーミッションモードは "{mode}" で、Plan モードではありません。

CLAUDE.md の「AI エージェントモデル利用ルール」により、この状態で作業を
始める前にユーザーへ警告し、確認を取る必要があります。次を必ず行ってください:

1. Plan モードが選択されていないことをユーザーに伝える
2. AskUserQuestion で「このまま進めてよいか」「Plan モードに切り替えるか」を確認する
3. ユーザーの回答を得てから実際の作業に着手する

ユーザーが「そのまま進めてよい」と答えた場合、このセッションではこの確認を
繰り返す必要はありません。調査・質問への回答だけで完結する依頼であれば、
その旨を添えて確認を省略してもかまいません。
"""


def marker_path(session_id: str, mode: str) -> Path:
    """セッション ID とモードの組ごとに 1 つのマーカーファイルを決める。"""
    key = hashlib.sha256(f"{session_id}:{mode}".encode()).hexdigest()[:16]
    base = Path(os.environ.get("TMPDIR", tempfile.gettempdir()))
    return base / f"claude-plan-mode-warned-{key}"


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        # 入力が壊れていてもプロンプト処理は止めない
        return 0

    mode = payload.get("permission_mode")

    # permission_mode が来ないイベントもある。判断できないときは黙る。
    if not mode or mode == "plan":
        return 0

    if not WARN_EVERY_PROMPT:
        marker = marker_path(str(payload.get("session_id", "")), mode)
        if marker.exists():
            return 0
        try:
            marker.touch()
        except OSError:
            # マーカーを置けない環境では警告を出す側に倒す
            pass

    json.dump(
        {
            "additionalContext": WARNING.format(mode=mode),
            "hookSpecificOutput": {"hookEventName": "UserPromptSubmit"},
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
