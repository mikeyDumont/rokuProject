' *******************************************************************
' ** Cabin Concierge TV - BrightScript Complete API & Data Store
' *******************************************************************

function GetSavedPropertyPin() as String
    sec = CreateObject("roRegistrySection", "CabinConciergeAuth")
    if sec.Exists("PropertyPin")
        return sec.Read("PropertyPin")
    end if
    return ""
end function

function SavePropertyPin(pin as String) as Boolean
    sec = CreateObject("roRegistrySection", "CabinConciergeAuth")
    sec.Write("PropertyPin", pin)
    sec.Flush()
    return true
end function

function ClearPropertyPin() as Boolean
    sec = CreateObject("roRegistrySection", "CabinConciergeAuth")
    sec.Delete("PropertyPin")
    sec.Flush()
    return true
end function

function GetDeviceId() as String
    sec = CreateObject("roRegistrySection", "CabinConciergeAuth")
    if sec.Exists("DeviceId") then return sec.Read("DeviceId")
    stamp = CreateObject("roDateTime").AsSeconds().ToStr()
    deviceId = "roku-" + stamp + "-" + Rnd(999999).ToStr()
    sec.Write("DeviceId", deviceId)
    sec.Flush()
    return deviceId
end function

function GetSavedDeviceToken() as String
    sec = CreateObject("roRegistrySection", "CabinConciergeAuth")
    if sec.Exists("DeviceToken") then return sec.Read("DeviceToken")
    return ""
end function

function SaveDeviceToken(token as String) as Boolean
    sec = CreateObject("roRegistrySection", "CabinConciergeAuth")
    sec.Write("DeviceToken", token)
    sec.Delete("PropertyPin")
    sec.Flush()
    return true
end function

function ClearDeviceAssignment() as Boolean
    sec = CreateObject("roRegistrySection", "CabinConciergeAuth")
    sec.Delete("DeviceToken")
    sec.Delete("PropertyPin")
    sec.Flush()
    return true
end function

function MapSupabasePropertyToProfile(row as Object) as Object
    if row = invalid then return invalid

    idVal = ""
    if row.id <> invalid then idVal = row.id.ToStr()

    pinVal = ""
    if row.pin <> invalid then pinVal = row.pin.ToStr()

    nameVal = ""
    if row.name <> invalid then nameVal = row.name

    taglineVal = ""
    if row.tagline <> invalid then taglineVal = row.tagline

    locVal = ""
    if row.location <> invalid then locVal = row.location

    addrVal = ""
    if row.address <> invalid then addrVal = row.address

    guestNameVal = ""
    if row.guest_name <> invalid then guestNameVal = row.guest_name

    stayDatesVal = ""
    if row.stay_dates <> invalid then stayDatesVal = row.stay_dates

    wifiNetVal = ""
    if row.wifi_network <> invalid then wifiNetVal = row.wifi_network

    wifiPassVal = ""
    if row.wifi_password <> invalid then wifiPassVal = row.wifi_password

    wifiSpeedVal = ""
    if row.wifi_speed <> invalid then wifiSpeedVal = row.wifi_speed

    checkInVal = "4:00 PM"
    if row.check_in_time <> invalid then checkInVal = row.check_in_time

    checkOutVal = "11:00 AM"
    if row.check_out_time <> invalid then checkOutVal = row.check_out_time

    trashVal = ""
    if row.trash_day <> invalid then trashVal = row.trash_day

    quietVal = "10:00 PM – 8:00 AM"
    if row.quiet_hours <> invalid then quietVal = row.quiet_hours

    maxOccVal = 8
    if row.max_occupancy <> invalid then maxOccVal = row.max_occupancy

    hostNameVal = ""
    if row.host_name <> invalid then hostNameVal = row.host_name

    hostPhoneVal = ""
    if row.host_phone <> invalid then hostPhoneVal = row.host_phone

    emergencyVal = "Dial 911"
    if row.emergency_contact <> invalid then emergencyVal = row.emergency_contact

    return {
        id: idVal,
        pin: pinVal,
        name: nameVal,
        tagline: taglineVal,
        location: locVal,
        address: addrVal,
        guestName: guestNameVal,
        stayDates: stayDatesVal,
        wifiNetwork: wifiNetVal,
        wifiPassword: wifiPassVal,
        wifiSpeed: wifiSpeedVal,
        checkInTime: checkInVal,
        checkOutTime: checkOutVal,
        trashDay: trashVal,
        quietHours: quietVal,
        maxOccupancy: maxOccVal,
        hostName: hostNameVal,
        hostPhone: hostPhoneVal,
        emergencyContact: emergencyVal
    }
end function

function MapSupabaseHouseRule(row as Object) as Object
    if row = invalid then return invalid
    return {
        title: row.title,
        category: row.category,
        summary: row.summary,
        details: row.details,
        fine: row.fine
    }
end function

function MapSupabaseRecommendation(row as Object) as Object
    if row = invalid then return invalid
    return {
        name: row.name,
        category: row.category,
        distance: row.distance,
        rating: row.rating,
        price: row.price,
        description: row.description,
        hostTip: row.host_tip
    }
end function

function MapSupabaseCheckoutTask(row as Object) as Object
    if row = invalid then return invalid
    taskId = "task"
    if row.task_key <> invalid and row.task_key <> ""
        taskId = row.task_key
    else if row.id <> invalid
        taskId = "task_" + row.id.ToStr()
    end if
    return {
        id: taskId,
        title: row.title,
        time: row.time_estimate,
        required: row.is_required
    }
end function

function MapSupabaseDiscount(row as Object) as Object
    if row = invalid then return invalid
    return {
        title: row.title,
        code: row.code,
        description: row.description,
        bannerText: row.banner_text
    }
end function

function BuildWifiQrUri(ssid as String, password as String) as String
    wifiPayload = "WIFI:T:WPA;S:" + ssid + ";P:" + password + ";;"
    encodedPayload = UrlEncodeString(wifiPayload)
    return "https://api.qrserver.com/v1/create-qr-code/?size=360x360&qzone=1&data=" + encodedPayload
end function

' Manual percent-encoding avoids relying on roUrlTransfer's Escape() behavior across firmware versions
function UrlEncodeString(text as String) as String
    result = ""
    for i = 1 to Len(text)
        ch = Mid(text, i, 1)
        code = Asc(ch)
        isUnreserved = (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or ch = "-" or ch = "_" or ch = "." or ch = "~"
        if isUnreserved
            result = result + ch
        else
            result = result + "%" + ByteToHex(code)
        end if
    end for
    return result
end function

' BrightScript has no built-in Hex() global function, so bytes are converted via a digit lookup table
function ByteToHex(code as Integer) as String
    hexDigits = "0123456789ABCDEF"
    highNibble = Int(code / 16)
    lowNibble = code - (highNibble * 16)
    return Mid(hexDigits, highNibble + 1, 1) + Mid(hexDigits, lowNibble + 1, 1)
end function
