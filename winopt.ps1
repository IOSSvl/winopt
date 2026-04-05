# ============================================================
#  WinOpt.ps1 — Windows Optimization GUI (standalone)
#
#  One-liner GitHub:
#    irm https://raw.githubusercontent.com/TUONOME/winopt/main/winopt.ps1 | iex
#
#  Locale (doppio click su run-as-admin.bat oppure):
#    powershell -ExecutionPolicy Bypass -File winopt.ps1
# ============================================================

#region — Elevation
# Gestisce sia esecuzione da file che via "irm | iex"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    if ($PSCommandPath) {
        # Eseguito da file: rilancia direttamente
        Start-Process powershell -Verb RunAs `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    } else {
        # Eseguito via iex: salva in temp e rilancia
        $tmp = Join-Path $env:TEMP "winopt_run.ps1"
        $MyInvocation.MyCommand.ScriptBlock.ToString() | Out-File $tmp -Encoding UTF8
        Start-Process powershell -Verb RunAs `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }
    exit
}
#endregion

#region — Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
#endregion

#region — Tweaks (embedded)
$tweaksJson = @'
[
  {
    "id": "disable_telemetry",
    "label": "Disabilita Telemetria",
    "category": "Privacy",
    "risk": "safe",
    "description": "Imposta AllowTelemetry=0 nel registro. Blocca invio dati diagnostici a Microsoft.",
    "script": "reg add \"HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection\" /v AllowTelemetry /t REG_DWORD /d 0 /f"
  },
  {
    "id": "disable_diag_track",
    "label": "Stop servizio DiagTrack",
    "category": "Privacy",
    "risk": "safe",
    "description": "Ferma e disabilita Connected User Experiences and Telemetry.",
    "script": "Stop-Service DiagTrack -Force -EA SilentlyContinue; Set-Service DiagTrack -StartupType Disabled"
  },
  {
    "id": "disable_wer",
    "label": "Disabilita Windows Error Reporting",
    "category": "Privacy",
    "risk": "safe",
    "description": "Impedisce l'invio automatico di crash report a Microsoft.",
    "script": "Stop-Service WerSvc -Force -EA SilentlyContinue; Set-Service WerSvc -StartupType Disabled; reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows\\Windows Error Reporting\" /v Disabled /t REG_DWORD /d 1 /f"
  },
  {
    "id": "disable_location",
    "label": "Disabilita Location Tracking",
    "category": "Privacy",
    "risk": "safe",
    "description": "Disabilita il servizio di geolocalizzazione di Windows.",
    "script": "reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\location\" /v Value /t REG_SZ /d Deny /f"
  },
  {
    "id": "disable_activity_history",
    "label": "Disabilita Activity History",
    "category": "Privacy",
    "risk": "safe",
    "description": "Disabilita cronologia attivita e Timeline di Windows.",
    "script": "reg add \"HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\System\" /v EnableActivityFeed /t REG_DWORD /d 0 /f; reg add \"HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\System\" /v PublishUserActivities /t REG_DWORD /d 0 /f"
  },
  {
    "id": "disable_sysmain",
    "label": "Disabilita SysMain (Superfetch)",
    "category": "Performance",
    "risk": "safe",
    "description": "Inutile su SSD. Riduce scritture e CPU overhead in background.",
    "script": "Stop-Service SysMain -Force -EA SilentlyContinue; Set-Service SysMain -StartupType Disabled"
  },
  {
    "id": "disable_wsearch",
    "label": "Disabilita Windows Search Indexer",
    "category": "Performance",
    "risk": "safe",
    "description": "Ferma l'indicizzazione continua del disco. Utile se non usi la ricerca di Windows.",
    "script": "Stop-Service WSearch -Force -EA SilentlyContinue; Set-Service WSearch -StartupType Disabled"
  },
  {
    "id": "ultimate_power",
    "label": "Power Plan: Ultimate Performance",
    "category": "Performance",
    "risk": "safe",
    "description": "Attiva il piano nascosto Ultimate Performance. Elimina micro-stuttering e core parking.",
    "script": "powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null; powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61"
  },
  {
    "id": "disable_fast_startup",
    "label": "Disabilita Fast Startup",
    "category": "Performance",
    "risk": "safe",
    "description": "Fast Startup iberna il kernel invece di spegnere. Causa problemi con driver e dual boot.",
    "script": "powercfg /h off; reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Power\" /v HiberbootEnabled /t REG_DWORD /d 0 /f"
  },
  {
    "id": "trim_ssd",
    "label": "Abilita TRIM + Disabilita Defrag SSD",
    "category": "Performance",
    "risk": "safe",
    "description": "Assicura che TRIM sia attivo e blocca la deframmentazione schedulata sugli SSD.",
    "script": "fsutil behavior set DisableDeleteNotify 0; Get-ScheduledTask -TaskName 'ScheduledDefrag' -EA SilentlyContinue | Disable-ScheduledTask"
  },
  {
    "id": "hags",
    "label": "Abilita HAGS (GPU Scheduling)",
    "category": "Performance",
    "risk": "caution",
    "description": "Hardware-accelerated GPU Scheduling. Riduce latenza GPU su RTX 2000+ / RX 6000+. Richiede riavvio.",
    "script": "reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers\" /v HwSchMode /t REG_DWORD /d 2 /f"
  },
  {
    "id": "disable_core_parking",
    "label": "Disabilita Core Parking",
    "category": "Performance",
    "risk": "caution",
    "description": "Impedisce a Windows di parcheggiare core CPU inattivi. Gia disabilitato con Ultimate Performance.",
    "script": "reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power\\PowerSettings\\54533251-82be-4824-96c1-47b60b740d00\\0cc5b647-c1df-4637-891a-dec35c318583\" /v ValueMax /t REG_DWORD /d 0 /f"
  },
  {
    "id": "disable_prefetch",
    "label": "Disabilita Prefetch su NVMe",
    "category": "Performance",
    "risk": "caution",
    "description": "Su NVMe veloci (3000MB/s+) il prefetch e overhead inutile. Non usare su HDD.",
    "script": "reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management\\PrefetchParameters\" /v EnablePrefetcher /t REG_DWORD /d 0 /f; reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management\\PrefetchParameters\" /v EnableSuperfetch /t REG_DWORD /d 0 /f"
  },
  {
    "id": "disable_xbox",
    "label": "Disabilita Servizi Xbox",
    "category": "Debloat",
    "risk": "safe",
    "description": "Ferma XblAuthManager, XblGameSave, XboxNetApiSvc se non usi Xbox Game Bar.",
    "script": "$xbox = @('XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc'); foreach($s in $xbox){ Stop-Service $s -Force -EA SilentlyContinue; Set-Service $s -StartupType Disabled -EA SilentlyContinue }"
  },
  {
    "id": "remove_widgets",
    "label": "Rimuovi Widgets dalla taskbar",
    "category": "Debloat",
    "risk": "safe",
    "description": "Disabilita il pannello Widgets di Windows 11.",
    "script": "reg add \"HKLM\\SOFTWARE\\Policies\\Microsoft\\Dsh\" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f"
  },
  {
    "id": "disable_copilot",
    "label": "Disabilita Copilot",
    "category": "Debloat",
    "risk": "safe",
    "description": "Rimuove il bottone e il processo di Copilot dalla barra delle applicazioni.",
    "script": "reg add \"HKCU\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsCopilot\" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f; reg add \"HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsCopilot\" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f"
  },
  {
    "id": "remove_onedrive",
    "label": "Rimuovi OneDrive",
    "category": "Debloat",
    "risk": "caution",
    "description": "Disinstalla OneDrive dal sistema. Reinstallabile in seguito dal Microsoft Store.",
    "script": "Stop-Process -Name OneDrive -Force -EA SilentlyContinue; $p32 = \"$env:SystemRoot\\SysWOW64\\OneDriveSetup.exe\"; $p64 = \"$env:SystemRoot\\System32\\OneDriveSetup.exe\"; if (Test-Path $p32) { Start-Process $p32 '/uninstall' -Wait }; if (Test-Path $p64) { Start-Process $p64 '/uninstall' -Wait }"
  },
  {
    "id": "dns_cloudflare",
    "label": "DNS: Cloudflare 1.1.1.1",
    "category": "Rete",
    "risk": "safe",
    "description": "Imposta Cloudflare DNS su tutti gli adapter attivi (IPv4). Miglioramento immediato su lookup lenti.",
    "script": "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses ('1.1.1.1','1.0.0.1') }"
  },
  {
    "id": "flush_dns",
    "label": "Flush DNS Cache",
    "category": "Rete",
    "risk": "safe",
    "description": "Svuota la cache DNS locale. Utile dopo cambio DNS o problemi di navigazione.",
    "script": "ipconfig /flushdns; ipconfig /registerdns"
  },
  {
    "id": "tcp_tuning",
    "label": "TCP Tuning (Autotuning + CTCP)",
    "category": "Rete",
    "risk": "caution",
    "description": "Autotuning normale e disabilita chimney offload. Migliora throughput e latenza TCP.",
    "script": "netsh int tcp set global autotuninglevel=normal; netsh int tcp set global chimney=disabled; netsh int tcp set global ecncapability=disabled"
  },
  {
    "id": "classic_rightclick",
    "label": "Classic Right-Click Menu",
    "category": "UI",
    "risk": "safe",
    "description": "Ripristina il menu contestuale completo di Windows 10, senza il passaggio aggiuntivo.",
    "script": "reg add \"HKCU\\Software\\Classes\\CLSID\\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\\InprocServer32\" /ve /t REG_SZ /d \"\" /f; Stop-Process -Name explorer -Force"
  },
  {
    "id": "visual_performance",
    "label": "Visual Effects: massima performance",
    "category": "UI",
    "risk": "safe",
    "description": "Disabilita animazioni, trasparenze e ombre. Interfaccia piu reattiva, specialmente su 60Hz.",
    "script": "Set-ItemProperty -Path 'HKCU:\\Control Panel\\Desktop' -Name 'UserPreferencesMask' -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)); Set-ItemProperty -Path 'HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize' -Name 'EnableTransparency' -Value 0; Stop-Process -Name explorer -Force"
  },
  {
    "id": "disable_spectre",
    "label": "Disabilita Spectre/Meltdown Mitigations",
    "category": "Avanzato",
    "risk": "danger",
    "description": "SOLO gaming box isolati. Rimuove protezioni CPU side-channel. Fino al +15% CPU-bound. MAI su PC con dati sensibili.",
    "script": "reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management\" /v FeatureSettingsOverride /t REG_DWORD /d 3 /f; reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management\" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f"
  }
]
'@
$tweaks = $tweaksJson | ConvertFrom-Json
#endregion

#region — Colori e font
$col = @{
    bg        = [System.Drawing.Color]::FromArgb(13,13,13)
    sidebar   = [System.Drawing.Color]::FromArgb(18,18,18)
    panel     = [System.Drawing.Color]::FromArgb(22,22,22)
    border    = [System.Drawing.Color]::FromArgb(35,35,35)
    text      = [System.Drawing.Color]::FromArgb(210,210,210)
    textDim   = [System.Drawing.Color]::FromArgb(90,90,90)
    safe      = [System.Drawing.Color]::FromArgb(52,211,153)
    caution   = [System.Drawing.Color]::FromArgb(251,191,36)
    danger    = [System.Drawing.Color]::FromArgb(248,113,113)
    accent    = [System.Drawing.Color]::FromArgb(232,255,71)
    accentDim = [System.Drawing.Color]::FromArgb(50,56,14)
    logBg     = [System.Drawing.Color]::FromArgb(10,10,10)
    logGreen  = [System.Drawing.Color]::FromArgb(126,231,135)
    logYellow = [System.Drawing.Color]::FromArgb(251,191,36)
    logRed    = [System.Drawing.Color]::FromArgb(248,113,113)
    logGray   = [System.Drawing.Color]::FromArgb(70,70,70)
    btnBg     = [System.Drawing.Color]::FromArgb(28,28,28)
}
function RiskColor($r) { switch($r){ "safe"{$col.safe} "caution"{$col.caution} "danger"{$col.danger} default{$col.textDim} } }

$fMono  = New-Object System.Drawing.Font("Consolas",9)
$fMonoS = New-Object System.Drawing.Font("Consolas",8)
$fBold  = New-Object System.Drawing.Font("Consolas",9,[System.Drawing.FontStyle]::Bold)
$fTitle = New-Object System.Drawing.Font("Consolas",13,[System.Drawing.FontStyle]::Bold)
$fSm    = New-Object System.Drawing.Font("Consolas",7.5)
#endregion

# ============================================================
#  FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text            = "WinOpt — Windows Optimizer"
$form.Size            = New-Object System.Drawing.Size(980,700)
$form.MinimumSize     = New-Object System.Drawing.Size(860,580)
$form.StartPosition   = "CenterScreen"
$form.BackColor       = $col.bg
$form.ForeColor       = $col.text
$form.Font            = $fMono
$form.FormBorderStyle = "Sizable"

#region — Header
$hdr = New-Object System.Windows.Forms.Panel
$hdr.Dock = "Top"; $hdr.Height = 52; $hdr.BackColor = $col.sidebar
$form.Controls.Add($hdr)

$lTitle = New-Object System.Windows.Forms.Label
$lTitle.Text = "WinOpt"; $lTitle.Font = $fTitle; $lTitle.ForeColor = $col.accent
$lTitle.AutoSize = $true; $lTitle.Location = New-Object System.Drawing.Point(18,14)
$hdr.Controls.Add($lTitle)

$lSub = New-Object System.Windows.Forms.Label
$lSub.Text = "Windows 11 Optimization Tool"; $lSub.Font = $fSm; $lSub.ForeColor = $col.textDim
$lSub.AutoSize = $true; $lSub.Location = New-Object System.Drawing.Point(98,20)
$hdr.Controls.Add($lSub)

$lAdmin = New-Object System.Windows.Forms.Label
$lAdmin.Text = "▲ ADMIN"; $lAdmin.Font = $fSm; $lAdmin.ForeColor = $col.safe; $lAdmin.AutoSize = $true
$hdr.Controls.Add($lAdmin)
$hdr.Add_Resize({ $lAdmin.Location = New-Object System.Drawing.Point(($hdr.Width - $lAdmin.Width - 18),20) })

$sepH = New-Object System.Windows.Forms.Panel
$sepH.Dock = "Top"; $sepH.Height = 1; $sepH.BackColor = $col.border
$form.Controls.Add($sepH)
#endregion

#region — Run bar (bottom)
$runBar = New-Object System.Windows.Forms.Panel
$runBar.Dock = "Bottom"; $runBar.Height = 56; $runBar.BackColor = $col.sidebar
$form.Controls.Add($runBar)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "▶  ESEGUI SELEZIONATI"; $btnRun.Font = $fBold
$btnRun.Size = New-Object System.Drawing.Size(224,34); $btnRun.Location = New-Object System.Drawing.Point(14,11)
$btnRun.FlatStyle = "Flat"; $btnRun.BackColor = $col.accentDim; $btnRun.ForeColor = $col.accent
$btnRun.FlatAppearance.BorderColor = $col.accent; $btnRun.Cursor = [System.Windows.Forms.Cursors]::Hand
$runBar.Controls.Add($btnRun)

$btnRP = New-Object System.Windows.Forms.Button
$btnRP.Text = "🛡  Restore Point"; $btnRP.Font = $fMonoS
$btnRP.Size = New-Object System.Drawing.Size(148,34); $btnRP.Location = New-Object System.Drawing.Point(248,11)
$btnRP.FlatStyle = "Flat"; $btnRP.BackColor = $col.btnBg; $btnRP.ForeColor = $col.textDim
$btnRP.FlatAppearance.BorderColor = $col.border
$runBar.Controls.Add($btnRP)

$lHint = New-Object System.Windows.Forms.Label
$lHint.Text = "Crea sempre un Restore Point prima di eseguire."; $lHint.Font = $fSm
$lHint.ForeColor = $col.textDim; $lHint.AutoSize = $true
$lHint.Location = New-Object System.Drawing.Point(410,20)
$runBar.Controls.Add($lHint)

$sepBot = New-Object System.Windows.Forms.Panel
$sepBot.Dock = "Bottom"; $sepBot.Height = 1; $sepBot.BackColor = $col.border
$form.Controls.Add($sepBot)
#endregion

#region — Layout principale
$main = New-Object System.Windows.Forms.TableLayoutPanel
$main.Dock = "Fill"; $main.ColumnCount = 2; $main.RowCount = 1; $main.BackColor = $col.bg
$main.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,300))) | Out-Null
$main.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100))) | Out-Null
$form.Controls.Add($main)
#endregion

#region — Sidebar
$sb = New-Object System.Windows.Forms.Panel
$sb.Dock = "Fill"; $sb.BackColor = $col.sidebar
$main.Controls.Add($sb,0,0)

$sepV = New-Object System.Windows.Forms.Panel
$sepV.Dock = "Right"; $sepV.Width = 1; $sepV.BackColor = $col.border
$sb.Controls.Add($sepV)

$categories = @("Tutte") + ($tweaks | Select-Object -ExpandProperty category -Unique | Sort-Object)
$catBtns    = @{}

$lCatHdr = New-Object System.Windows.Forms.Label
$lCatHdr.Text = "CATEGORIA"; $lCatHdr.Font = $fSm; $lCatHdr.ForeColor = $col.textDim
$lCatHdr.AutoSize = $false; $lCatHdr.Size = New-Object System.Drawing.Size(278,18)
$lCatHdr.Location = New-Object System.Drawing.Point(14,14)
$sb.Controls.Add($lCatHdr)

$cy = 36
foreach ($cat in $categories) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $cat; $b.Font = $fMonoS; $b.Tag = $cat
    $b.Size = New-Object System.Drawing.Size(268,26); $b.Location = New-Object System.Drawing.Point(10,$cy)
    $b.FlatStyle = "Flat"; $b.FlatAppearance.BorderSize = 1
    if ($cat -eq "Tutte") {
        $b.BackColor = $col.accentDim; $b.ForeColor = $col.accent
        $b.FlatAppearance.BorderColor = $col.accent
    } else {
        $b.BackColor = $col.sidebar; $b.ForeColor = $col.textDim
        $b.FlatAppearance.BorderColor = $col.border
    }
    $catBtns[$cat] = $b; $sb.Controls.Add($b); $cy += 30
}

$ly = $cy + 16
foreach ($item in @(@{l="● SAFE";c=$col.safe},@{l="● ATTENZIONE";c=$col.caution},@{l="● DANGER";c=$col.danger})) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $item.l; $l.Font = $fSm; $l.ForeColor = $item.c
    $l.AutoSize = $true; $l.Location = New-Object System.Drawing.Point(14,$ly)
    $sb.Controls.Add($l); $ly += 18
}

$lCount = New-Object System.Windows.Forms.Label
$lCount.Text = "0 selezionati"; $lCount.Font = $fSm; $lCount.ForeColor = $col.textDim
$lCount.AutoSize = $false; $lCount.Size = New-Object System.Drawing.Size(268,16)
$lCount.Location = New-Object System.Drawing.Point(14,($ly+12))
$sb.Controls.Add($lCount)

$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Text = "Seleziona tutti"; $btnAll.Font = $fSm
$btnAll.Size = New-Object System.Drawing.Size(128,24); $btnAll.Location = New-Object System.Drawing.Point(10,($ly+32))
$btnAll.FlatStyle = "Flat"; $btnAll.BackColor = $col.btnBg; $btnAll.ForeColor = $col.textDim
$btnAll.FlatAppearance.BorderColor = $col.border
$sb.Controls.Add($btnAll)

$btnNone = New-Object System.Windows.Forms.Button
$btnNone.Text = "Deseleziona tutti"; $btnNone.Font = $fSm
$btnNone.Size = New-Object System.Drawing.Size(136,24); $btnNone.Location = New-Object System.Drawing.Point(142,($ly+32))
$btnNone.FlatStyle = "Flat"; $btnNone.BackColor = $col.btnBg; $btnNone.ForeColor = $col.textDim
$btnNone.FlatAppearance.BorderColor = $col.border
$sb.Controls.Add($btnNone)
#endregion

#region — Right panel
$rp = New-Object System.Windows.Forms.Panel
$rp.Dock = "Fill"; $rp.BackColor = $col.bg
$main.Controls.Add($rp,1,0)

$rl = New-Object System.Windows.Forms.TableLayoutPanel
$rl.Dock = "Fill"; $rl.RowCount = 3; $rl.ColumnCount = 1; $rl.BackColor = $col.bg
$rl.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,58)))  | Out-Null
$rl.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,1)))  | Out-Null
$rl.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,42)))  | Out-Null
$rp.Controls.Add($rl)

$tc = New-Object System.Windows.Forms.Panel
$tc.Dock = "Fill"; $tc.BackColor = $col.bg; $tc.AutoScroll = $true
$tc.Padding = New-Object System.Windows.Forms.Padding(12,8,12,8)
$rl.Controls.Add($tc,0,0)

$sepMid = New-Object System.Windows.Forms.Panel
$sepMid.Dock = "Fill"; $sepMid.BackColor = $col.border
$rl.Controls.Add($sepMid,0,1)

$logP = New-Object System.Windows.Forms.Panel
$logP.Dock = "Fill"; $logP.BackColor = $col.logBg
$rl.Controls.Add($logP,0,2)

$logHdr = New-Object System.Windows.Forms.Panel
$logHdr.Dock = "Top"; $logHdr.Height = 30; $logHdr.BackColor = $col.sidebar
$logP.Controls.Add($logHdr)

$lLog = New-Object System.Windows.Forms.Label
$lLog.Text = "OUTPUT LOG"; $lLog.Font = $fSm; $lLog.ForeColor = $col.textDim
$lLog.AutoSize = $true; $lLog.Location = New-Object System.Drawing.Point(14,8)
$logHdr.Controls.Add($lLog)

$btnClr = New-Object System.Windows.Forms.Button
$btnClr.Text = "Pulisci"; $btnClr.Font = $fSm
$btnClr.Size = New-Object System.Drawing.Size(58,20); $btnClr.FlatStyle = "Flat"
$btnClr.BackColor = $col.btnBg; $btnClr.ForeColor = $col.textDim
$btnClr.FlatAppearance.BorderColor = $col.border
$logHdr.Controls.Add($btnClr)
$logHdr.Add_Resize({ $btnClr.Location = New-Object System.Drawing.Point(($logHdr.Width - 72),5) })

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Dock = "Fill"; $logBox.BackColor = $col.logBg; $logBox.ForeColor = $col.text
$logBox.Font = $fMonoS; $logBox.ReadOnly = $true; $logBox.BorderStyle = "None"
$logBox.ScrollBars = "Vertical"; $logBox.Padding = New-Object System.Windows.Forms.Padding(8)
$logP.Controls.Add($logBox)
#endregion

# ============================================================
#  LOGICA
# ============================================================
$cbMap = @{}

function Write-Log {
    param([string]$msg, [string]$type = "info")
    $ts = Get-Date -Format "HH:mm:ss"
    $clr = switch($type){ "ok"{$col.logGreen} "warn"{$col.logYellow} "error"{$col.logRed} "skip"{$col.logGray} default{$col.text} }
    $logBox.SelectionStart = $logBox.TextLength; $logBox.SelectionLength = 0
    $logBox.SelectionColor = $col.logGray;  $logBox.AppendText("[$ts] ")
    $logBox.SelectionColor = $clr;          $logBox.AppendText("$msg`n")
    $logBox.ScrollToCaret()
}

function Update-Counter {
    $n = ($cbMap.Keys | Where-Object { $cbMap[$_].Checked }).Count
    $lCount.Text      = "$n selezionati"
    $lCount.ForeColor = if ($n -gt 0){ $col.accent } else { $col.textDim }
}

function Render-Tweaks([string]$cat) {
    $tc.Controls.Clear(); $cbMap.Clear()
    $list = if ($cat -eq "Tutte"){ $tweaks } else { $tweaks | Where-Object { $_.category -eq $cat } }
    $y = 2
    foreach ($t in $list) {
        $rc = RiskColor $t.risk
        $w  = $tc.ClientSize.Width - 24

        $row = New-Object System.Windows.Forms.Panel
        $row.Size = New-Object System.Drawing.Size($w,62); $row.Location = New-Object System.Drawing.Point(0,$y)
        $row.BackColor = $col.panel; $row.Cursor = [System.Windows.Forms.Cursors]::Hand; $row.Tag = $t.id

        $bar = New-Object System.Windows.Forms.Panel
        $bar.BackColor = $rc; $bar.Size = New-Object System.Drawing.Size(3,62); $bar.Location = New-Object System.Drawing.Point(0,0)
        $row.Controls.Add($bar)

        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Size = New-Object System.Drawing.Size(18,18); $cb.Location = New-Object System.Drawing.Point(14,22)
        $cb.BackColor = $col.panel; $cb.Tag = $t.id
        $cb.Add_CheckedChanged({ Update-Counter })
        $row.Controls.Add($cb); $cbMap[$t.id] = $cb

        $lT = New-Object System.Windows.Forms.Label
        $lT.Text = $t.label; $lT.Font = $fBold; $lT.ForeColor = $col.text
        $lT.AutoSize = $false; $lT.Size = New-Object System.Drawing.Size(($w-160),17)
        $lT.Location = New-Object System.Drawing.Point(38,9); $row.Controls.Add($lT)

        $lR = New-Object System.Windows.Forms.Label
        $lR.Text = $t.risk.ToUpper(); $lR.Font = $fSm; $lR.ForeColor = $rc
        $lR.AutoSize = $true; $lR.Location = New-Object System.Drawing.Point(38,29); $row.Controls.Add($lR)

        $lC = New-Object System.Windows.Forms.Label
        $lC.Text = "[$($t.category)]"; $lC.Font = $fSm; $lC.ForeColor = $col.textDim
        $lC.AutoSize = $true; $lC.Location = New-Object System.Drawing.Point(96,29); $row.Controls.Add($lC)

        $lD = New-Object System.Windows.Forms.Label
        $lD.Text = $t.description; $lD.Font = $fSm; $lD.ForeColor = $col.textDim
        $lD.AutoSize = $false; $lD.Size = New-Object System.Drawing.Size(($w-48),15)
        $lD.Location = New-Object System.Drawing.Point(38,46); $row.Controls.Add($lD)

        # Click toggle con closure corretta
        $tid = $t.id
        $clk = [scriptblock]::Create("if(`$script:cbMap.ContainsKey('$tid')){`$script:cbMap['$tid'].Checked = -not `$script:cbMap['$tid'].Checked}")
        $row.Add_Click($clk)
        foreach ($ch in $row.Controls) { if ($ch -isnot [System.Windows.Forms.CheckBox]){ $ch.Add_Click($clk) } }

        $row.Add_MouseEnter({ param($s,$e) $s.BackColor = [System.Drawing.Color]::FromArgb(30,30,30) })
        $row.Add_MouseLeave({ param($s,$e) $s.BackColor = [System.Drawing.Color]::FromArgb(22,22,22) })

        $tc.Controls.Add($row); $y += 66
    }
    Update-Counter
}

$tc.Add_Resize({
    $w = $tc.ClientSize.Width - 24
    foreach ($r in $tc.Controls) { if ($r -is [System.Windows.Forms.Panel]){ $r.Width = $w } }
})

# Category click
foreach ($cat in $categories) {
    $catSB = [scriptblock]::Create("
        param(`$s,`$e)
        `$clicked = `$s.Tag
        foreach(`$c in @('" + ($categories -join "','") + "')){
            `$script:catBtns[`$c].BackColor = [System.Drawing.Color]::FromArgb(18,18,18)
            `$script:catBtns[`$c].ForeColor = [System.Drawing.Color]::FromArgb(90,90,90)
            `$script:catBtns[`$c].FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(35,35,35)
        }
        `$script:catBtns[`$clicked].BackColor = [System.Drawing.Color]::FromArgb(50,56,14)
        `$script:catBtns[`$clicked].ForeColor = [System.Drawing.Color]::FromArgb(232,255,71)
        `$script:catBtns[`$clicked].FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(232,255,71)
        Render-Tweaks `$clicked
    ")
    $catBtns[$cat].Add_Click($catSB)
}

$btnAll.Add_Click({ foreach($k in $cbMap.Keys){ $cbMap[$k].Checked = $true }; Update-Counter })
$btnNone.Add_Click({ foreach($k in $cbMap.Keys){ $cbMap[$k].Checked = $false }; Update-Counter })
$btnClr.Add_Click({ $logBox.Clear() })

$btnRP.Add_Click({
    Write-Log "Creazione Restore Point..." "info"; $btnRP.Enabled = $false
    try {
        Enable-ComputerRestore -Drive "C:\" -EA SilentlyContinue
        Checkpoint-Computer -Description "WinOpt $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType MODIFY_SETTINGS -EA Stop
        Write-Log "Restore Point creato." "ok"
    } catch { Write-Log "Errore: $($_.Exception.Message)" "error" }
    $btnRP.Enabled = $true
})

$btnRun.Add_Click({
    $sel = $tweaks | Where-Object { $cbMap.ContainsKey($_.id) -and $cbMap[$_.id].Checked }
    if (-not $sel){ Write-Log "Nessun tweak selezionato." "warn"; return }

    $danger = @($sel | Where-Object { $_.risk -eq "danger" })
    if ($danger.Count -gt 0) {
        $names = ($danger | ForEach-Object { "  - $($_.label)" }) -join "`n"
        $ok = [System.Windows.Forms.MessageBox]::Show(
            "Tweaks DANGER selezionati:`n`n$names`n`nSei sicuro?",
            "WinOpt — Conferma DANGER","YesNo","Warning")
        if ($ok -ne "Yes"){ Write-Log "Annullato." "skip"; return }
    }

    $btnRun.Enabled = $false; $btnRun.Text = "⏳  ESECUZIONE..."
    $total = @($sel).Count; $nOk = 0; $nErr = 0

    Write-Log "── Inizio: $total tweaks ──" "info"
    foreach ($t in $sel) {
        Write-Log "Running: $($t.label)..." "info"
        try {
            Invoke-Expression $t.script 2>&1 | Out-Null
            Write-Log "[OK] $($t.label)" "ok"; $nOk++
        } catch {
            Write-Log "[ERRORE] $($t.label): $($_.Exception.Message)" "error"; $nErr++
        }
        Start-Sleep -Milliseconds 100
    }
    Write-Log "── Fine: $nOk OK | $nErr errori | $total totale ──" $(if($nErr -gt 0){"warn"}else{"ok"})

    if ($nOk -gt 0) {
        $r = [System.Windows.Forms.MessageBox]::Show(
            "$nOk tweak applicati.`n`nRiavviare ora per applicare tutte le modifiche?",
            "WinOpt — Completato","YesNo","Information")
        if ($r -eq "Yes"){ Restart-Computer -Force }
    }
    $btnRun.Enabled = $true; $btnRun.Text = "▶  ESEGUI SELEZIONATI"
})

# ── Init
Render-Tweaks "Tutte"
Write-Log "WinOpt avviato — seleziona tweaks e premi Esegui." "info"
Write-Log "Consiglio: crea prima un Restore Point." "warn"

[System.Windows.Forms.Application]::Run($form)
