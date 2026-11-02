function New-DrillPaperTestWorkspace {
    <# 建立非 Temp、含繁中與空白的獨立測試目錄。
    Args:
        Name: 受測工具名稱，只接受安全的單一名稱。
    Returns:
        新建立且位於 USERPROFILE/DrillPaperTests 下的絕對路徑。
    #>
    param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9-]+$')][string]$Name)
    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) { throw '缺少 USERPROFILE，無法建立非 Temp 測試目錄。' }
    $prefix = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE 'DrillPaperTests'))
    $root = [IO.Path]::GetFullPath((Join-Path $prefix ('回歸 含空白/' + $Name + '-' + [Guid]::NewGuid().ToString('N'))))
    $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $root.StartsWith($prefix.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $root.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase)) {
        throw '測試資料必須位於非 Temp 使用者目錄。'
    }
    [void][IO.Directory]::CreateDirectory($root)
    return $root
}
