$ip = "192.168.1.120"
$port = 8085

Write-Host "Connecting to ${ip}:${port}..."
$client = New-Object System.Net.Sockets.TcpClient($ip, $port)
$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$reader = New-Object System.IO.StreamReader($stream)
$writer.AutoFlush = $true

Start-Sleep -Seconds 1

Write-Host "Sending CTRL+C to trigger Debugger prompt..."
$writer.Write("`x03`r`n")

Start-Sleep -Seconds 1

Write-Host "Sending genkey..."
$writer.WriteLine("genkey")

$startTime = [DateTime]::Now
while (([DateTime]::Now - $startTime).TotalSeconds -lt 6) {
    if ($stream.DataAvailable) {
        $line = $reader.ReadLine()
        Write-Host "ROKU > $line"
    } else {
        Start-Sleep -Milliseconds 200
    }
}

$client.Close()
Write-Host "Finished."

