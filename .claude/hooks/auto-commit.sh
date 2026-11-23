#!/usr/bin/env bash
# 会話の終了時と開始時に呼ばれ、未コミットの変更をコミットし、未 push のコミットを push する。
# 開始時にも呼ぶのは、前回の終了時に動かなかった(異常終了など)分を拾うため。失敗しても Claude の動作は止めない。

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  files=$(git diff --cached --name-only | head -n 5 | tr '\n' ' ')
  count=$(git diff --cached --name-only | wc -l | tr -d ' ')
  git commit -q \
    -m "自動保存: ${count}件のファイルを更新 (${files% })" \
    -m "Co-Authored-By: Claude <noreply@anthropic.com>" || exit 0
fi

# リモート(origin)がなければ push しない
git remote get-url origin >/dev/null 2>&1 || exit 0
if [ -n "$(git log '@{u}..HEAD' --oneline 2>/dev/null)" ] || ! git rev-parse '@{u}' >/dev/null 2>&1; then
  # 失敗したら、最初に失敗した日時を残す(開始時のフックが CEO に渡す)。成功したら消す
  flag="$(git rev-parse --git-dir)/push-failed-since"
  if GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git push -q -u origin HEAD >/dev/null 2>&1; then
    rm -f "$flag"
  else
    [ -f "$flag" ] || date '+%Y-%m-%d %H:%M' > "$flag"
    echo "auto-commit: push に失敗しました。次回に再試行します。" >&2
  fi
fi
exit 0
