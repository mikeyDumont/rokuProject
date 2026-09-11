param(
    [Parameter(Mandatory=$true)]
    [string]$RokuIP,

    [int]$Port = 8085
)

$ErrorActionPreference = "Stop"

Write-Output "Connecting to Roku TV at ${RokuIP}:${Port}..."

try {
    $client = New-Object System.Net.Sockets.TcpClient($RokuIP, $Port)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)

    Start-Sleep -Milliseconds 1000

    Write-Output "--- Initial Console Output ---"
    while ($stream.DataAvailable) {
        $line = $reader.ReadLine()
        Write-Output $line
    }

    Write-Output "`nSending 'genkey' command..."
    $writer.WriteLine("genkey")
    $writer.Flush()
    
    Start-Sleep -Seconds 4

    Write-Output "--- Response from genkey ---"
    $buffer = New-Object byte[] 8192
    if ($stream.DataAvailable) {
        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
        $output = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
        Write-Output $output
    } else {
        Write-Output "(No output received from genkey - checking if app is sideloaded)"
    }

    $client.Close()
} catch {
    Write-Error "Failed to connect to Roku TV: $_"
}

