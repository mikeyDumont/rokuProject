sub init()
    m.top.functionName = "executeTask"
end sub

sub executeTask()
    if not IsWeatherConfigured()
        m.top.errorMessage = "Weather service is not configured"
        return
    end if

    weatherData = getWeatherResponse(GetWeatherProxyUrl())
    if weatherData = invalid
        if m.top.errorMessage = "" then m.top.errorMessage = "Unable to retrieve weather data"
        return
    end if

    m.top.responseJson = weatherData
    m.top.responseSuccess = true
end sub

function getWeatherResponse(url as String) as Object
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(port)
    ApplySupabaseHeaders(transfer)
    transfer.SetUrl(url)

    if not transfer.AsyncGetToString()
        m.top.errorMessage = "Failed to start weather request"
        return invalid
    end if

    msg = wait(10000, port)
    if type(msg) <> "roUrlEvent"
        transfer.AsyncCancel()
        m.top.errorMessage = "Weather request timed out"
        return invalid
    end if

    responseCode = msg.GetResponseCode()
    if responseCode < 200 or responseCode > 299
        m.top.errorMessage = "Weather service returned HTTP " + responseCode.ToStr()
        return invalid
    end if

    parsed = ParseJson(msg.GetString())
    if type(parsed) <> "roAssociativeArray"
        m.top.errorMessage = "Weather service returned an invalid response"
        return invalid
    end if
    return parsed
end function