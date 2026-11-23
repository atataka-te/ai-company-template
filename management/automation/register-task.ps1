# 会社のスキルを、Windows のタスクスケジューラに定期実行として登録する(同じ名前で再実行すると上書き)。
# 例: 毎月の全社レビューを、毎週日曜 10:00 に試す(スキルの中で「その月にまだなら実行」と判断させる)
#   powershell -ExecutionPolicy Bypass -File register-task.ps1 -Skill company-review -Weekly Sunday -At 10:00
# 例: 平日 7:30 に毎日のスキルを動かす
#   powershell -ExecutionPolicy Bypass -File register-task.ps1 -Skill my-daily-skill -Weekdays -At 07:30
# 登録先: タスクスケジューラの \ai-company\<Skill>。サインインしている間だけ動く(パスワードは保存しない)。
# 消すとき: Unregister-ScheduledTask -TaskPath '\ai-company\' -TaskName <Skill>
param(
    [Parameter(Mandatory = $true)][string]$Skill,
    [string]$At = '10:00',
    [string]$Weekly,          # 曜日(Sunday など)。指定すると毎週その曜日
    [switch]$Weekdays,        # 平日(月〜金)の毎日
    [switch]$WakeToRun        # スリープ中なら PC を起こして実行する
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run-skill.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$runner`" -Skill $Skill"

if ($Weekly) {
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Weekly -At $At
} elseif ($Weekdays) {
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday, Tuesday, Wednesday, Thursday, Friday -At $At
} else {
    $trigger = New-ScheduledTaskTrigger -Daily -At $At
}

# 時刻に PC が切れていたら、起動後に実行する。失敗したら 15 分後に 2 回まで再試行する
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 15) `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -WakeToRun:$WakeToRun
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskPath '\ai-company\' -TaskName $Skill -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-Output "登録しました: \ai-company\$Skill"
Write-Output "試しに今すぐ動かす: Start-ScheduledTask -TaskPath '\ai-company\' -TaskName $Skill"
Write-Output "ログ: $env:LOCALAPPDATA\ai-company\logs"
