# 定期実行ランチャー(Windows のタスクスケジューラから呼ばれる)
# 会社のスキル(.claude/skills/<Skill>/SKILL.md)の本文を claude -p に渡して、無人で実行し、ログを残す。
# ログ: %LOCALAPPDATA%\ai-company\logs\YYYY-MM-DD_HHmm_<Skill>.log(会話の開始時のフックが CEO に渡す)
param(
    [Parameter(Mandatory = $true)]
    [string]$Skill
)

$ErrorActionPreference = 'Stop'
# 会社のフォルダ = このスクリプトの2つ上
$companyDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$skillFile = Join-Path $companyDir ".claude\skills\$Skill\SKILL.md"

# claude の場所(PATH になければ、標準のインストール先)
$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) { $claude = Join-Path $env:USERPROFILE '.local\bin\claude.exe' }

$logDir = Join-Path $env:LOCALAPPDATA 'ai-company\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("{0}_{1}.log" -f (Get-Date -Format 'yyyy-MM-dd_HHmm'), $Skill)
function Write-Log($text) { Add-Content -LiteralPath $log -Value "[$(Get-Date -Format s)] $text" -Encoding utf8 }

if (-not (Test-Path -LiteralPath $skillFile)) { Write-Log "スキルが見つからない: $skillFile"; Write-Log 'exit=2'; exit 2 }
if (-not (Test-Path -LiteralPath $claude)) { Write-Log "claude が見つからない: $claude"; Write-Log 'exit=2'; exit 2 }

# 実行中にスリープしないようにする
Add-Type -Namespace AiCompany -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
[AiCompany.Power]::SetThreadExecutionState([uint32]2147483649) | Out-Null   # ES_CONTINUOUS | ES_SYSTEM_REQUIRED

# 手順書の本文(先頭の frontmatter を除く)に、無人の定期実行であることを添えて渡す
$body = (Get-Content -LiteralPath $skillFile -Raw -Encoding utf8) -replace '(?s)\A---.*?---\s*', ''
$prompt = "(Windows のタスクスケジューラからの無人の定期実行。今は $(Get-Date -Format 'yyyy-MM-dd (ddd) HH:mm')。オーナーはいないので質問しない。手順書に「無人の定期実行」の決まりがあれば、それに従う。最後に、結論を日本語で3行以内で報告する。)`n`n" + $body

# 起動直後・スリープ復帰の直後はネットワークがまだつながっていないことがあるので、最大3分待つ
$deadline = (Get-Date).AddMinutes(3)
while ($true) {
    try { [System.Net.Dns]::GetHostAddresses('api.anthropic.com') | Out-Null; break } catch {}
    if ((Get-Date) -gt $deadline) { Write-Log 'ネットワークにつながらないまま実行する'; break }
    Start-Sleep -Seconds 10
}

Set-Location $companyDir
# 日本語を含む指示を claude に正しく渡す(PowerShell 5.1 の既定は ASCII)
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $OutputEncoding
$ErrorActionPreference = 'Continue'
# 無人の回はファイルの編集と調べものだけを許す。push はしない(会話の開始時のフックがまとめて送る)
$claudeArgs = @(
    '-p',
    '--permission-mode', 'acceptEdits',
    '--allowedTools', 'Bash', 'Read', 'Glob', 'Grep', 'Edit', 'Write', 'WebSearch', 'WebFetch',
    '--disallowedTools', 'Bash(git push:*)'
)
Write-Log "開始: $Skill"
try {
    $output = $prompt | & $claude @claudeArgs 2>&1
    $exit = $LASTEXITCODE
} catch {
    $output = $_.Exception.Message
    $exit = 1
}
Add-Content -LiteralPath $log -Value ($output | Out-String) -Encoding utf8
Write-Log "exit=$exit"
exit $exit
