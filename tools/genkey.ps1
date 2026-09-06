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

    Start-Sleep -Milliseconds 500

    # Wake prompt with newlines & CTRL+C
    $writer.Write("`r`n`x03`r`n")
    $writer.Flush()
    Start-Sleep -Milliseconds 500

    Write-Output "Sending 'genkey'..."
    $writer.Write("genkey`r`n")
    $writer.Flush()

    Start-Sleep -Seconds 5

    # Read output
    $buffer = New-Object byte[] 16384
    if ($stream.DataAvailable) {
        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
        $output = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
        Write-Output "--- Roku Console Response ---"
        Write-Output $output
    } else {
        Write-Output "No output received. Try running genkey directly in Command Prompt Telnet."
    }

    $client.Close()
} catch {
    Write-Error "Failed to connect to Roku TV: $_"
}
