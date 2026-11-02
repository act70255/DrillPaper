param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
try {
    $baseline=Get-Content -Raw -LiteralPath (Join-Path $EvidenceDirectory 'before.json') | ConvertFrom-Json
    $last=$baseline.sha256
    while(-not (Test-Path -LiteralPath (Join-Path $Root 'stop-antivirus'))) {
        $item=Get-Item -LiteralPath $baseline.path
        $hash=(Get-FileHash -LiteralPath $item.FullName).Hash
        $record=@{utc=[DateTime]::UtcNow.ToString('o');path=$item.FullName;length=$item.Length;lastWriteTimeUtc=$item.LastWriteTimeUtc.ToString('o');sha256=$hash}
        if($hash -cne $last) {
            $copy=Join-Path $EvidenceDirectory ('antivirus-change-'+[Guid]::NewGuid().ToString('N')+'.log')
            Copy-Item -LiteralPath $item.FullName -Destination $copy
            $record.snapshot=$copy
            Write-Output "AV_CHANGED：$copy"
        }
        $record | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $EvidenceDirectory 'antivirus-periodic.jsonl') -Encoding utf8
        $last=$hash
        Start-Sleep -Seconds 10
    }
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'antivirus-observer-error.log') -Encoding utf8
    [Console]::Error.WriteLine('錯誤：防毒只讀觀測未完成，請查看 antivirus-observer-error.log。')
    exit 1
}
