param(
    [Parameter(Mandatory = $true)]
    [string]$WowDir,

    [Parameter(Mandatory = $true)]
    [string]$ServerUserHost,

    [string]$RemoteClient = "/home/ubuntu/wow-client"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $WowDir)) {
    throw "Нет каталога клиента: $WowDir"
}
if (-not (Test-Path (Join-Path $WowDir "Wow.exe")) -and -not (Test-Path (Join-Path $WowDir "wow.exe"))) {
    Write-Warning "Wow.exe не найден — проверьте, что это корень 3.3.5a"
}

Write-Host "Копирую клиент на $ServerUserHost:$RemoteClient (долго)"
ssh $ServerUserHost "mkdir -p $RemoteClient"
# rsync предпочтительнее scp, если есть в PATH (Git for Windows / cwRsync)
$rsync = Get-Command rsync -ErrorAction SilentlyContinue
if ($rsync) {
    & rsync -a --info=progress2 "$WowDir/" "${ServerUserHost}:${RemoteClient}/"
} else {
    scp -r "$WowDir\*" "${ServerUserHost}:${RemoteClient}/"
}

Write-Host @"
Дальше на ВМ:

  scripts/extract-from-client.sh $RemoteClient playerbots

Серверные dbc лучше enUS. Играть — с ruRU клиента, realmlist = IP ВМ.
"@
