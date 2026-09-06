sub init()
    m.top.functionName = "executeTask"
end sub

sub executeTask()
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
            endpoint = "house_rules"
        else if reqType = "GET_RECOMMENDATIONS"
            endpoint = "recommendations"
        else if reqType = "GET_CHECKOUT_TASKS"
            endpoint = "checkout_tasks"
        else if reqType = "POST_FEEDBACK"
            endpoint = "guest_feedback"
        end if
    end if

    fullUrl = baseUrl + "/rest/v1/" + endpoint
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
        else if reqType = "GET_HOUSE_RULES"
            if m.top.propertyId <> ""
                queryFilter = "or=(property_id.eq." + m.top.propertyId + ",property_id.is.null)&order=sort_order.asc"
            else
                queryFilter = "order=sort_order.asc"
            end if
        else if reqType = "GET_RECOMMENDATIONS"
            if m.top.propertyId <> ""
                queryFilter = "or=(property_id.eq." + m.top.propertyId + ",property_id.is.null)&order=sort_order.asc"
            else
                queryFilter = "order=sort_order.asc"
            end if
        else if reqType = "GET_CHECKOUT_TASKS"
            if m.top.propertyId <> ""
                queryFilter = "or=(property_id.eq." + m.top.propertyId + ",property_id.is.null)&order=sort_order.asc"
            else
                queryFilter = "order=sort_order.asc"
            end if
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
