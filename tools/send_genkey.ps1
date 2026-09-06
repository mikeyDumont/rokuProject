$ip = "192.168.1.120"
$port = 8085

Write-Host "Connecting to ${ip}:${port}..."
$socket = New-Object System.Net.Sockets.TcpClient($ip, $port)
$stream = $socket.GetStream()

Start-Sleep -Milliseconds 500

$buffer = New-Object byte[] 4096
while ($stream.DataAvailable) {
    $stream.Read($buffer, 0, $buffer.Length) | Out-Null
}

Write-Host "Sending 'genkey' command to Roku TV..."
$cmd = [System.Text.Encoding]::ASCII.GetBytes("genkey`r`n")
$stream.Write($cmd, 0, $cmd.Length)
$stream.Flush()

Start-Sleep -Seconds 3

Write-Host "Reading response..."
if ($stream.DataAvailable) {
    $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
    $response = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
    Write-Host "=== ROKU RESPONSE ==="
    Write-Host $response
} else {
    Write-Host "No response received over 8085."
}

$socket.Close()

