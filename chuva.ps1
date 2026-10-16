param([int]$Segundos = 3)

$ErrorActionPreference = "SilentlyContinue"
if ([Console]::IsOutputRedirected) { exit 0 }

$largura = [Console]::WindowWidth
$altura = [Console]::WindowHeight
if ($largura -lt 2 -or $altura -lt 2) { exit 0 }
$largura--
$altura--

[Console]::CursorVisible = $false
[Console]::BackgroundColor = "Black"
[Console]::ForegroundColor = "Green"
Clear-Host

$glifos = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
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
            try {
                [Console]::SetCursorPosition($x, $y)
                if ($sorteio.Next(6) -eq 0) { [Console]::ForegroundColor = "White" } else { [Console]::ForegroundColor = "Green" }
                [Console]::Write($glifos[$sorteio.Next($glifos.Length)])
            } catch {}
        }
        $rastro = $y - 12
        if ($rastro -ge 0 -and $rastro -lt $altura) {
            try {
                [Console]::SetCursorPosition($x, $rastro)
                [Console]::Write(" ")
            } catch {}
        }
        $gotas[$x] = $y + 1
        if ($gotas[$x] -gt $altura + $sorteio.Next(4, 16)) {
            $gotas[$x] = -$sorteio.Next(0, $altura)
        }
    }
    Start-Sleep -Milliseconds 45
}

[Console]::ForegroundColor = "Green"
[Console]::BackgroundColor = "Black"
[Console]::CursorVisible = $true
Clear-Host
