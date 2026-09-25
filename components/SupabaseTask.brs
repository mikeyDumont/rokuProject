sub init()
    m.top.functionName = "executeTask"
end sub

sub executeTask()
    if m.top.requestType = "DOWNLOAD_AMBIENT_AUDIO_FILE"
        downloadAmbientAudioFile()
        return
    end if

    if not IsSupabaseConfigured()
        m.top.errorMessage = "Supabase is not configured"
        m.top.responseSuccess = false
        return
    end if

    baseUrl = GetSupabaseUrl()
    if Right(baseUrl, 1) = "/"
        baseUrl = Left(baseUrl, Len(baseUrl) - 1)
    end if

    endpoint = m.top.endpoint
    if endpoint = ""
        reqType = m.top.requestType
        if reqType = "GET_PROPERTY_BY_PIN" or reqType = "GET_PROPERTY_FOR_STAFF_REFRESH"
            endpoint = "rpc/get_active_property_display"
        else if reqType = "ENROLL_DEVICE"
            endpoint = "rpc/enroll_roku_device"
        else if reqType = "VERIFY_STAFF_PIN"
            endpoint = "rpc/verify_staff_company_pin"
        else if reqType = "GET_HOUSE_RULES"
            endpoint = "rpc/get_house_rules"
        else if reqType = "GET_RECOMMENDATIONS"
            endpoint = "rpc/get_recommendations"
        else if reqType = "GET_CHECKOUT_TASKS"
            endpoint = "rpc/get_checkout_tasks"
        else if reqType = "GET_ACTIVE_DISCOUNT"
            endpoint = "rpc/get_active_discount"
        else if reqType = "GET_ACTIVE_ALERTS"
            endpoint = "rpc/get_active_alerts"
        else if reqType = "POST_FEEDBACK"
            endpoint = "guest_feedback"
        end if
    end if

    apiPrefix = "/rest/v1/"
    if m.top.useStorageApi then apiPrefix = "/storage/v1/"
    fullUrl = baseUrl + apiPrefix + endpoint
    queryFilter = m.top.queryFilter

    if queryFilter = ""
        reqType = m.top.requestType
        if (reqType = "GET_PROPERTY_BY_PIN" or reqType = "GET_PROPERTY_FOR_STAFF_REFRESH") and m.top.deviceId <> "" and m.top.deviceToken <> ""
            quote = Chr(34)
            m.top.postBody = "{" + quote + "p_device_id" + quote + ":" + quote + m.top.deviceId + quote + "," + quote + "p_device_token" + quote + ":" + quote + m.top.deviceToken + quote + "," + quote + "p_staff_token" + quote + ":" + quote + m.top.staffToken + quote + "}"
        else if reqType = "ENROLL_DEVICE" and m.top.pin <> "" and m.top.deviceId <> ""
            quote = Chr(34)
            m.top.postBody = "{" + quote + "p_device_id" + quote + ":" + quote + m.top.deviceId + quote + "," + quote + "p_property_pin" + quote + ":" + quote + m.top.pin + quote + "}"
        else if reqType = "VERIFY_STAFF_PIN" and m.top.deviceId <> "" and m.top.deviceToken <> "" and m.top.companyPin <> ""
            quote = Chr(34)
            m.top.postBody = "{" + quote + "p_device_id" + quote + ":" + quote + m.top.deviceId + quote + "," + quote + "p_device_token" + quote + ":" + quote + m.top.deviceToken + quote + "," + quote + "p_company_pin" + quote + ":" + quote + m.top.companyPin + quote + "}"
        else if (reqType = "GET_HOUSE_RULES" or reqType = "GET_RECOMMENDATIONS" or reqType = "GET_CHECKOUT_TASKS" or reqType = "GET_ACTIVE_DISCOUNT" or reqType = "GET_ACTIVE_ALERTS") and m.top.deviceId <> "" and m.top.deviceToken <> ""
            quote = Chr(34)
            m.top.postBody = "{" + quote + "p_device_id" + quote + ":" + quote + m.top.deviceId + quote + "," + quote + "p_device_token" + quote + ":" + quote + m.top.deviceToken + quote + "}"
        end if
    end if

    if queryFilter <> ""
        fullUrl = fullUrl + "?" + queryFilter
    end if

    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(port)
    ApplySupabaseHeaders(transfer)
    transfer.SetUrl(fullUrl)

    isPost = (m.top.postBody <> "" or m.top.requestType = "POST_FEEDBACK")

    if isPost
        transfer.AddHeader("Prefer", "return=representation")
        sent = transfer.AsyncPostFromString(m.top.postBody)
    else
        sent = transfer.AsyncGetToString()
    end if

    if not sent
        m.top.responseSuccess = false
        m.top.errorMessage = "Failed to initiate URL transfer request"
        return
    end if

    msg = wait(10000, port)
    if type(msg) = "roUrlEvent"
        respCode = msg.GetResponseCode()
        respStr = msg.GetString()

        if respCode >= 200 and respCode <= 299
            m.top.responseSuccess = true
            parsed = ParseJson(respStr)
            if type(parsed) = "roArray"
                m.top.responseArray = parsed
                if parsed.Count() > 0 and type(parsed[0]) = "roAssociativeArray"
                    m.top.responseJson = parsed[0]
                end if
            else if type(parsed) = "roAssociativeArray"
                m.top.responseJson = parsed
            end if
        else
            m.top.responseSuccess = false
            m.top.errorMessage = "HTTP " + Str(respCode).Trim() + ": " + respStr
        end if
    else
        transfer.AsyncCancel()
        m.top.responseSuccess = false
        m.top.errorMessage = "Request timed out waiting for response"
    end if
end sub
' Signs and downloads the ambient audio track once to local storage so looping
' playback can reuse the file instead of re-fetching it from Supabase Storage.
' roFileSystem is a MAIN|TASK-only component, so the cache check must happen
' here on the Task thread rather than on MainScene's render thread.
sub downloadAmbientAudioFile()
    localPath = "tmp:/ambient_audio_v1.mp3"
    fs = CreateObject("roFileSystem")
    if fs.Exists(localPath)
        m.top.responseSuccess = true
        m.top.localFilePath = localPath
        return
    end if

    if not IsSupabaseConfigured()
        m.top.errorMessage = "Supabase is not configured"
        m.top.responseSuccess = false
        return
    end if

    baseUrl = GetSupabaseUrl()
    if Right(baseUrl, 1) = "/" then baseUrl = Left(baseUrl, Len(baseUrl) - 1)

    port = CreateObject("roMessagePort")

    signTransfer = CreateObject("roUrlTransfer")
    signTransfer.SetMessagePort(port)
    ApplySupabaseHeaders(signTransfer)
    signTransfer.SetUrl(baseUrl + "/storage/v1/object/sign/channel-media/ambient/forest_ambience-v1.mp3")
    signTransfer.AddHeader("Prefer", "return=representation")
    sent = signTransfer.AsyncPostFromString("{" + Chr(34) + "expiresIn" + Chr(34) + ":3600}")
    if not sent
        m.top.responseSuccess = false
        m.top.errorMessage = "Failed to initiate signed URL request"
        return
    end if

    msg = wait(10000, port)
    if type(msg) <> "roUrlEvent" or msg.GetResponseCode() < 200 or msg.GetResponseCode() > 299
        signTransfer.AsyncCancel()
        m.top.responseSuccess = false
        m.top.errorMessage = "Failed to sign ambient audio URL"
        return
    end if

    parsed = ParseJson(msg.GetString())
    if parsed = invalid or parsed.signedURL = invalid
        m.top.responseSuccess = false
        m.top.errorMessage = "Storage returned an invalid signed URL"
        return
    end if

    fileTransfer = CreateObject("roUrlTransfer")
    fileTransfer.SetMessagePort(port)
    fileTransfer.SetUrl(baseUrl + "/storage/v1" + parsed.signedURL)
    sent = fileTransfer.AsyncGetToFile(localPath)
    if not sent
        m.top.responseSuccess = false
        m.top.errorMessage = "Failed to start ambient audio download"
        return
    end if

    msg = wait(20000, port)
    if type(msg) = "roUrlEvent" and msg.GetResponseCode() >= 200 and msg.GetResponseCode() <= 299
        m.top.responseSuccess = true
        m.top.localFilePath = localPath
    else
        fileTransfer.AsyncCancel()
        m.top.responseSuccess = false
        m.top.errorMessage = "Failed to download ambient audio file"
    end if
end sub
