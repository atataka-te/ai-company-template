#!/usr/bin/env bash
# 会話の開始時に会社の現状を CEO に渡す。ここで出力した内容が会話の前提になる。

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0

# 日付の計算(Windows の Git Bash・Linux は GNU date、Mac は BSD date)
days_ago() { date -d "$1 days ago" +%Y-%m-%d 2>/dev/null || date -v-"$1"d +%Y-%m-%d; }

echo "# 会社の現状(会話の開始時に自動読み込み)"
echo "今日の日付: $(date +%Y-%m-%d)"
echo

# リモートへの送信の状態。止まっていても誰も気づかないことがあるため、毎回確かめて渡す
if git remote get-url origin >/dev/null 2>&1; then
  echo "## リモートへの送信の状態"
  export GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never
  if command -v timeout >/dev/null 2>&1; then lsr() { timeout 8 git ls-remote --exit-code origin HEAD; }; else lsr() { git ls-remote --exit-code origin HEAD; }; fi
  if lsr >/dev/null 2>&1; then
    echo "- 接続: OK"
  else
    echo "- ⚠ 接続: 失敗(ネットワークか認証の問題)。オーナーに伝える"
  fi
  flag="$(git rev-parse --git-dir 2>/dev/null)/push-failed-since"
  [ -f "$flag" ] && echo "- ⚠ push の失敗が続いている: $(cat "$flag") から"
  n=$(git rev-list --count '@{u}..HEAD' 2>/dev/null)
  [ "${n:-0}" -gt 0 ] && echo "- ⚠ 未送信のコミット: ${n} 件"
  echo
fi

# 定期実行の結果(management/automation の仕組みが書くログ)。オーナーに聞かれる前に CEO から報告するため
logdir="${LOCALAPPDATA:-$HOME/.local/share}/ai-company/logs"
if [ -d "$logdir" ]; then
  echo "## 定期実行の結果(直近2日のログ: $logdir)"
  echo "(communications に報告の記録がない回は、オーナーに聞かれる前に要点を先に報告する)"
  for f in "$logdir"/"$(days_ago 1)"_* "$logdir"/"$(date +%Y-%m-%d)"_*; do
    [ -f "$f" ] || continue
    res=$(grep -a -o -E 'exit=[0-9]+' "$f" | tail -n 1)
    [ -n "$res" ] || res="結果なし"
    mark=""; [ "$res" = "exit=0" ] || mark="⚠ "
    echo "- ${mark}$(basename "$f" .log): ${res}"
  done
  echo
fi

echo "## management/vision.md"
cat management/vision.md 2>/dev/null
echo

echo "## management/tasks.md"
cat management/tasks.md 2>/dev/null
echo

# 直近2日分の記録から、各節の見出しと宿題を渡す(1日のやり取りが多くても前半の宿題が漏れないように)
recent=$(ls communications/*.md 2>/dev/null | sort | tail -n 2)
[ -n "$recent" ] && echo "(宿題には済んだものも含まれる。今の状況は上の tasks.md を正とする)" && echo
for f in $recent; do
  echo "## $f の見出しと宿題"
  awk '
    /^## /                   { print; inhw = 0; next }
    /^- \*\*宿題\*\*/         { print; inhw = 1; next }
    inhw && /^[[:space:]]+-/ { print; next }
    { inhw = 0 }
  ' "$f"
  echo
done

# 最新の節は全文を渡す
latest=$(echo "$recent" | tail -n 1)
if [ -n "$latest" ]; then
  echo "## 直近のオーナーとのやり取り ($latest の最後の節)"
  awk '/^## /{ buf = "" } { buf = buf $0 "\n" } END { printf "%s", buf }' "$latest"
fi
exit 0
