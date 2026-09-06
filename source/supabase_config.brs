' *******************************************************************
' ** Cabin Concierge TV - Supabase Configuration & Helper Module
' *******************************************************************

' Return the Supabase Project URL
function GetSupabaseUrl() as String
    appInfo = CreateObject("roAppInfo")
    manifestUrl = appInfo.GetValue("supabase_url")
    if manifestUrl <> invalid and manifestUrl <> ""
        return manifestUrl
    end if
    return "https://rbuyznszkwdyafiujhas.supabase.co"
end function

' Return the Supabase Anon / Public API Key
function GetSupabaseAnonKey() as String
    appInfo = CreateObject("roAppInfo")
    manifestKey = appInfo.GetValue("supabase_anon_key")
    if manifestKey <> invalid and manifestKey <> ""
        return manifestKey
    end if
    return ""
end function

' Check if Supabase has been configured with valid credentials
function IsSupabaseConfigured() as Boolean
    url = GetSupabaseUrl()
    key = GetSupabaseAnonKey()
    if url = "" or url.Instr("YOUR_SUPABASE_PROJECT_ID") >= 0
        return false
    end if
    if key = "" or key.Instr("YOUR_SUPABASE_ANON_KEY") >= 0
        return false
    end if
    if key.InStr("c2VydmljZV9yb2xl") >= 0
        return false
    end if
    return true
end function

function GetWeatherProxyUrl() as String
    baseUrl = GetSupabaseUrl()
    if Right(baseUrl, 1) = "/"
        baseUrl = Left(baseUrl, Len(baseUrl) - 1)
    end if
    return baseUrl + "/functions/v1/weather"
end function

function IsWeatherConfigured() as Boolean
    return IsSupabaseConfigured()
end function

' Configure roUrlTransfer headers & SSL certificates for Supabase HTTPS REST API
sub ApplySupabaseHeaders(transfer as Object)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    
    key = GetSupabaseAnonKey()
    transfer.AddHeader("apikey", key)
    transfer.AddHeader("Authorization", "Bearer " + key)
    transfer.AddHeader("Content-Type", "application/json")
    transfer.AddHeader("Accept", "application/json")
end sub
