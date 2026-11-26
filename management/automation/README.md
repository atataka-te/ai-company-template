# 定期実行(Windows のタスクスケジューラ)

Claude のアプリを開いていなくても、決まった時刻に会社のスキルを無人で動かす仕組み。

| ファイル | 役割 |
|---|---|
| `register-task.ps1` | スキルをタスクスケジューラに登録する(`\ai-company\<スキル名>`) |
| `run-skill.ps1` | タスクスケジューラから呼ばれ、スキルの本文を `claude -p` に渡して実行し、ログを残す |
| `headless-permissions.json` | 無人の回に許すツール・コマンドと、禁止するものの一覧 |

## 使い方

0. 先に一度、このフォルダで Claude Code を普通に開き、「このフォルダを信頼する」の確認に答えておく。答えていないフォルダでは、無人の回で `.claude/settings.json` の許可の設定が無視される(作者の環境で確認)。
1. 動かしたいスキルを作る(`/create-skill`)。無人で動くので、スキルの中に「無人の定期実行のときは質問せず、〜する」と書いておく。
2. PowerShell で登録する(例: 全社レビューを毎週日曜 10:00 に試す)。
   ```powershell
   powershell -ExecutionPolicy Bypass -File management\automation\register-task.ps1 -Skill company-review -Weekly Sunday -At 10:00
   ```
3. 今すぐ試す: `Start-ScheduledTask -TaskPath '\ai-company\' -TaskName company-review`
4. 結果は `%LOCALAPPDATA%\ai-company\logs\` に残る。次の会話の開始時に、フックが直近2日分の結果(`exit=`)を CEO に渡す。

## 決まり

- 無人の回の権限は `headless-permissions.json` で絞っている。Web で読んだ文に指示が仕込まれていても、PC 上の何でも実行されることがないようにするため。
  - 許可: このフォルダのファイルの読み書き、読むだけのコマンド(cat・head・tail・ls・grep・sed -n・find など)、git の記録(status・log・diff・show・add・commit)、Web 検索・Web の読み込み
  - 禁止: `git push`・`git config`・curl・wget・rm、`.py`・`.ps1`・`.sh` などのプログラムと `.claude/settings*.json`・フック・このフォルダの書き換え、`secrets/`・`~/.ssh` などの読み込み
  - スキルで新しいコマンドを使うときは、許可の一覧に足す(足さないと、無人の回では拒否されて飛ばされる)
  - 残る穴: Web の読み込みは送り先を絞っていない(調べものに要るため)。Windows では Claude Code のサンドボックスが使えないため、コマンドの文字で判定している
- push はしない(次の会話の開始時のフックがまとめて送る)。
- 登録・変更・削除は「定期実行の変更」なので、オーナーの承認を取ってから行う(rules/04・company-review の「実行してよい範囲」)。
- 登録したら `/owner-log` で記録し、tasks.md の「毎日・毎週の定常業務」に載せる(lessons.md: 会社の外で作った仕組みも記録に残す)。
- 使った分だけ Claude の利用枠を消費する。回数を増やしすぎない。
