param([int]$Segundos = 3)

$ErrorActionPreference = "Stop"
try {
    if ([Console]::IsOutputRedirected) { exit 0 }

    $largura = [Math]::Max(2, [Console]::WindowWidth) - 1
    $altura = [Math]::Max(2, [Console]::WindowHeight) - 1

    [Console]::CursorVisible = $false
    [Console]::BackgroundColor = "Black"
    [Console]::ForegroundColor = "Green"
    Clear-Host

    $glifos = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ$#@%&*+=<>".ToCharArray()
    $sorteio = [System.Random]::new()
    $gotas = New-Object int[] $largura
    for ($i = 0; $i -lt $largura; $i++) {
        $gotas[$i] = $sorteio.Next(-$altura, $altura)
    }

    $ate = [DateTime]::UtcNow.AddSeconds($Segundos)
    while ([DateTime]::UtcNow -lt $ate) {
        for ($x = 0; $x -lt $largura; $x++) {
            $y = $gotas[$x]
            if ($y -ge 0 -and $y -lt $altura) {
                [Console]::SetCursorPosition($x, $y)
                if ($sorteio.Next(8) -eq 0) {
                    [Console]::ForegroundColor = "White"
                } elseif ($sorteio.Next(3) -eq 0) {
                    [Console]::ForegroundColor = "DarkGreen"
                } else {
                    [Console]::ForegroundColor = "Green"
                }
                [Console]::Write($glifos[$sorteio.Next($glifos.Length)])
            }
            $rastro = $y - 14
            if ($rastro -ge 0 -and $rastro -lt $altura) {
                [Console]::SetCursorPosition($x, $rastro)
                [Console]::Write(" ")
            }
            $gotas[$x] = $y + 1
            if ($gotas[$x] -gt $altura + $sorteio.Next(4, 16)) {
                $gotas[$x] = -$sorteio.Next(0, $altura)
            }
        }
        Start-Sleep -Milliseconds 40
    }
} catch {
    # Se o console nao permitir desenho, segue sem travar a abertura.
} finally {
    try {
        [Console]::ForegroundColor = "Green"
        [Console]::BackgroundColor = "Black"
        [Console]::CursorVisible = $true
        Clear-Host
    } catch {}
}
