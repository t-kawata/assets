#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# ============================================================
# 設定
# ============================================================

$desktop  = 'HKCU:\Control Panel\Desktop'
$explorer = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
$dwm      = 'HKCU:\Software\Microsoft\Windows\DWM'
$themes   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$keyboard = 'HKLM:\SYSTEM\CurrentControlSet\Services\i8042prt\Parameters'
$ime      = 'HKCU:\Software\Microsoft\Input\TSF\Tsf3Override\{03b5835f-f03c-411b-9ce2-aa23e1171e36}'

$changes = @(
    # 視覚効果：カスタム
    @{ Path = "$explorer\VisualEffects"; Name = 'VisualFXSetting'; Type = 'DWord'; Value = 3 }

    # アニメーション・装飾を無効化
    @{ Path = "$desktop\WindowMetrics"; Name = 'MinAnimate'; Type = 'String'; Value = '0' }
    @{ Path = "$explorer\Advanced"; Name = 'TaskbarAnimations'; Type = 'DWord'; Value = 0 }
    @{ Path = "$explorer\Advanced"; Name = 'ListviewAlphaSelect'; Type = 'DWord'; Value = 0 }
    @{ Path = "$explorer\Advanced"; Name = 'ListviewShadow'; Type = 'DWord'; Value = 0 }
    @{ Path = $desktop; Name = 'DragFullWindows'; Type = 'String'; Value = '0' }
    @{
        Path  = $desktop
        Name  = 'UserPreferencesMask'
        Type  = 'Binary'
        Value = [byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)
    }
    @{ Path = $dwm; Name = 'EnableAeroPeek'; Type = 'DWord'; Value = 0 }
    @{ Path = $dwm; Name = 'AlwaysHibernateThumbnails'; Type = 'DWord'; Value = 0 }

    # フォント平滑化・サムネイルは維持
    @{ Path = $desktop; Name = 'FontSmoothing'; Type = 'String'; Value = '2' }
    @{ Path = "$explorer\Advanced"; Name = 'IconsOnly'; Type = 'DWord'; Value = 0 }

    # 透明効果を無効化
    @{ Path = $themes; Name = 'EnableTransparency'; Type = 'DWord'; Value = 0 }

    # 日本語キーボード（106/109キー）
    @{ Path = $keyboard; Name = 'LayerDriver JPN'; Type = 'String'; Value = 'kbd106.dll' }
    @{ Path = $keyboard; Name = 'OverrideKeyboardIdentifier'; Type = 'String'; Value = 'PCAT_106KEY' }
    @{ Path = $keyboard; Name = 'OverrideKeyboardType'; Type = 'DWord'; Value = 7 }
    @{ Path = $keyboard; Name = 'OverrideKeyboardSubtype'; Type = 'DWord'; Value = 2 }

    # 以前のバージョンのMicrosoft IMEを使用
    @{ Path = $ime; Name = 'NoTsf3Override2'; Type = 'DWord'; Value = 1 }
)

# ============================================================
# 変更する値だけをバックアップ
# ============================================================

$backupDir = Join-Path $env:USERPROFILE (
    'WindowsSettings-Backup-' +
    (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
)
New-Item -ItemType Directory -Path $backupDir | Out-Null

$backup = foreach ($change in $changes) {
    $key = Get-Item -LiteralPath $change.Path -ErrorAction SilentlyContinue
    $exists = $false
    $kind = $null
    $value = $null

    if ($null -ne $key) {
        $exists = $key.GetValueNames() -contains $change.Name

        if ($exists) {
            $kind = $key.GetValueKind($change.Name).ToString()
            $value = $key.GetValue(
                $change.Name,
                $null,
                [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
            )
        }
    }

    [pscustomobject]@{
        Path   = $change.Path
        Name   = $change.Name
        Exists = $exists
        Kind   = $kind
        Value  = $value
    }
}

$backup | Export-Clixml -LiteralPath (
    Join-Path $backupDir 'RegistryValues.clixml'
)

# 復元スクリプトも一緒に作成
@'
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$backup = Import-Clixml -LiteralPath (
    Join-Path $PSScriptRoot 'RegistryValues.clixml'
)

foreach ($entry in $backup) {
    if ($entry.Exists) {
        if (-not (Test-Path -LiteralPath $entry.Path)) {
            New-Item -Path $entry.Path -Force | Out-Null
        }

        New-ItemProperty `
            -LiteralPath $entry.Path `
            -Name $entry.Name `
            -PropertyType $entry.Kind `
            -Value $entry.Value `
            -Force | Out-Null
    }
    elseif (Test-Path -LiteralPath $entry.Path) {
        $key = Get-Item -LiteralPath $entry.Path
        if ($key.GetValueNames() -contains $entry.Name) {
            Remove-ItemProperty `
                -LiteralPath $entry.Path `
                -Name $entry.Name
        }
    }
}

Write-Host '変更前の値に復元しました。作業を保存して再起動してください。'
'@ | Set-Content -LiteralPath (
    Join-Path $backupDir 'Restore.ps1'
) -Encoding UTF8

# ============================================================
# 適用
# ============================================================

Write-Host "バックアップ先: $backupDir"

try {
    foreach ($change in $changes) {
        if (-not (Test-Path -LiteralPath $change.Path)) {
            New-Item -Path $change.Path -Force | Out-Null
        }

        New-ItemProperty `
            -LiteralPath $change.Path `
            -Name $change.Name `
            -PropertyType $change.Type `
            -Value $change.Value `
            -Force | Out-Null
    }
}
catch {
    Write-Warning '設定の適用途中で失敗しました。一部だけ適用されている可能性があります。'
    Write-Warning "復元する場合は $backupDir 内の Restore.ps1 を実行してください。"
    throw
}

# スタートアップは勝手に無効化せず、選択画面を開く
try {
    Start-Process 'ms-settings:startupapps'
}
catch {
    Write-Warning '設定 → アプリ → スタートアップを手動で開いてください。'
}

Write-Host @"

設定を適用しました。

【再起動前】
開いたスタートアップ設定で、不要なアプリだけオフにしてください。

【再起動後】
旧Microsoft IMEの詳細設定で、次の項目を手動変更してください。
  編集操作 → キー設定 → 変更
  「英数」の「入力／変換済み文字なし」→「IME-オフ」

【確認】
Win + R → SystemPropertiesPerformance.exe
で視覚効果を確認できます。

【復元】
バックアップフォルダー内の Restore.ps1 を
管理者権限のPowerShellで実行してください。
スタートアップの手動変更は復元対象に含みません。

自動再起動はしません。作業を保存してWindowsを再起動してください。
"@
