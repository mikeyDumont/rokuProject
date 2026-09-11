sub init()
    m.top.setFocus(true)
    m.pinGateOverlay = m.top.findNode("pinGateOverlay")
    m.screensaverOverlay = m.top.findNode("screensaverOverlay")
    m.ambientAudio = m.top.findNode("ambientAudio")
    m.staffMenu = m.top.findNode("staffMenu")
    if m.staffMenu <> invalid
        m.staffMenu.observeField("staffAction", "onStaffMenuAction")
    end if
    if m.ambientAudio <> invalid
        ambientContent = CreateObject("roSGNode", "ContentNode")
        ambientContent.streamFormat = "mp3"
        m.ambientAudio.content = ambientContent
        m.ambientAudio.observeField("state", "onAmbientAudioStateChanged")
    end if
    m.inactivityTimer = m.top.findNode("inactivityTimer")
    m.checkoutCleanupTimer = m.top.findNode("checkoutCleanupTimer")
    m.preCheckinFetchTimer = m.top.findNode("preCheckinFetchTimer")
    m.staffLongPressTimer = m.top.findNode("staffLongPressTimer")
    m.keepAliveTimer = m.top.findNode("keepAliveTimer")
    m.pinGateFallbackTimer = m.top.findNode("pinGateFallbackTimer")
    if m.keepAliveTimer <> invalid
        m.keepAliveTimer.observeField("fire", "onKeepAliveTimerFire")
        m.keepAliveTimer.control = "start"
    end if
    if m.pinGateFallbackTimer <> invalid
        m.pinGateFallbackTimer.observeField("fire", "onPinGateFallbackTimerFire")
        m.pinGateFallbackTimer.control = "start"
    end if
    
    m.topHeader = m.top.findNode("topHeader")
    m.mainContentGroup = m.top.findNode("mainContentGroup")
    m.bottomTipBar = m.top.findNode("bottomTipBar")
    m.cabinTitleHeader = m.top.findNode("cabinTitleHeader")
    m.navRail = m.top.findNode("navRail")
    
    m.welcomeView = m.top.findNode("welcomeView")
    m.houseRulesView = m.top.findNode("houseRulesView")
    m.recommendationsView = m.top.findNode("recommendationsView")
    m.weatherView = m.top.findNode("weatherView")
    m.checkoutView = m.top.findNode("checkoutView")
    m.feedbackView = m.top.findNode("feedbackView")

    m.welcomeGuestLabel = m.top.findNode("welcomeGuestLabel")
    m.stayDatesLabel = m.top.findNode("stayDatesLabel")
    m.wifiNetLabel = m.top.findNode("wifiNetLabel")
    m.wifiPassLabel = m.top.findNode("wifiPassLabel")
    m.wifiQrPoster = m.top.findNode("wifiQrPoster")
    m.checkInOutLabel = m.top.findNode("checkInOutLabel")
    m.quietHoursLabel = m.top.findNode("quietHoursLabel")
    m.trashDayLabel = m.top.findNode("trashDayLabel")
    m.hostNameLabel = m.top.findNode("hostNameLabel")
    m.hostPhoneLabel = m.top.findNode("hostPhoneLabel")
    m.emergencyLabel = m.top.findNode("emergencyLabel")

    menuContent = CreateObject("roSGNode", "ContentNode")
    items = [
        "Welcome & Wi-Fi",
        "House Rules & Spa",
        "Local Recommendations",
        "Weather Forecast",
        "Departure Checklist",
        "Returning Guest Perk"
    ]
    for each title in items
        itemNode = menuContent.createChild("ContentNode")
        itemNode.title = title
    end for
    m.navRail.content = menuContent

    m.navRail.observeField("itemSelected", "onNavItemSelected")
    m.pinGateOverlay.observeField("isUnlocked", "onPinGateUnlocked")
    m.inactivityTimer.observeField("fire", "onInactivityTimerFire")
    m.checkoutCleanupTimer.observeField("fire", "onCheckoutCleanupTimerFire")
    m.preCheckinFetchTimer.observeField("fire", "onPreCheckinFetchTimerFire")
    m.staffLongPressTimer.observeField("fire", "onStaffLongPressTimerFire")

    loadAssignedProperty()
end sub

sub loadAssignedProperty()
    token = GetSavedDeviceToken()
    if token = "" then return
    m.assignedDeviceTask = CreateObject("roSGNode", "SupabaseTask")
    m.assignedDeviceTask.requestType = "GET_PROPERTY_BY_PIN"
    m.assignedDeviceTask.deviceId = GetDeviceId()
    m.assignedDeviceTask.deviceToken = token
    m.assignedDeviceTask.observeField("state", "onAssignedDeviceStateChanged")
    m.assignedDeviceTask.control = "RUN"
end sub

sub onAssignedDeviceStateChanged()
    if m.assignedDeviceTask = invalid or m.assignedDeviceTask.state <> "stop" then return
    if m.assignedDeviceTask.responseSuccess and m.assignedDeviceTask.responseJson <> invalid
        prop = MapSupabasePropertyToProfile(m.assignedDeviceTask.responseJson)
        if prop <> invalid and prop.name <> ""
            m.pinGateOverlay.unlockedProperty = prop
            m.pinGateOverlay.isUnlocked = true
            return
        end if
    end if
    ClearDeviceAssignment()
    m.pinGateOverlay.showGate = true
    m.pinGateOverlay.setFocus(true)
end sub

sub onPinGateFallbackTimerFire()
    ' If still not unlocked after 3 seconds, show PIN gate
    ' This handles the case where no saved PIN exists
    if not m.pinGateOverlay.isUnlocked and not m.pinGateOverlay.showGate
        m.pinGateOverlay.showGate = true
        m.pinGateOverlay.setFocus(true)
    end if
end sub

sub onDeepLinkPinChanged()
    pin = m.top.deepLinkPin
    if pin <> "" and Len(pin) = 4
        if IsSupabaseConfigured()
            m.deepLinkTask = CreateObject("roSGNode", "SupabaseTask")
            m.deepLinkTask.requestType = "GET_PROPERTY_BY_PIN"
            m.deepLinkTask.pin = pin
            m.deepLinkTask.observeField("state", "onDeepLinkSupabaseTaskStateChanged")
            m.deepLinkTask.control = "RUN"
        end if
    end if
end sub

sub onDeepLinkSupabaseTaskStateChanged()
    if m.deepLinkTask <> invalid and m.deepLinkTask.state = "stop"
        if m.deepLinkTask.responseSuccess and m.deepLinkTask.responseJson <> invalid
            prop = MapSupabasePropertyToProfile(m.deepLinkTask.responseJson)
            if prop <> invalid and prop.name <> ""
                m.pinGateOverlay.unlockedProperty = prop
                m.pinGateOverlay.currentPin = m.top.deepLinkPin
                m.pinGateOverlay.isUnlocked = true
                return
            end if
        end if

    end if
end sub

sub onPinGateUnlocked()
    if m.pinGateOverlay.isUnlocked
        prop = m.pinGateOverlay.unlockedProperty
        if prop <> invalid
            m.cabinTitleHeader.text = prop.name
            if prop.guestName <> ""
                m.welcomeGuestLabel.text = "Welcome, " + prop.guestName
                m.stayDatesLabel.text = "Reservation Stay: " + prop.stayDates
            else
                m.welcomeGuestLabel.text = "Welcome to " + prop.name
                m.stayDatesLabel.text = "Guest stay information is available at check-in."
            end if

            m.wifiNetLabel.text = "Network: " + prop.wifiNetwork
            m.wifiPassLabel.text = "Password: " + prop.wifiPassword
            if m.wifiQrPoster <> invalid
                m.wifiQrPoster.uri = BuildWifiQrUri(prop.wifiNetwork, prop.wifiPassword)
            end if

            m.checkInOutLabel.text = "Check-In: " + prop.checkInTime + " • Out: " + prop.checkOutTime
            m.quietHoursLabel.text = "Quiet Hours: " + prop.quietHours
            m.trashDayLabel.text = "Trash: " + prop.trashDay

            m.hostNameLabel.text = "Host: " + prop.hostName
            m.hostPhoneLabel.text = "Call/Text: " + prop.hostPhone
            m.emergencyLabel.text = "Emergency: " + prop.emergencyContact

            m.houseRulesView.property = prop
            m.recommendationsView.property = prop
            m.checkoutView.property = prop
            m.feedbackView.property = prop
            m.screensaverOverlay.cabinName = prop.name
            m.screensaverOverlay.guestName = prop.guestName

            ' Schedule event-driven timers for this reservation
            scheduleCheckoutCleanupTimer(prop)
            schedulePreCheckinFetchTimer(prop)
        end if

        m.pinGateOverlay.visible = false
        m.topHeader.visible = true
        m.mainContentGroup.visible = true
        m.bottomTipBar.visible = true
        m.navRail.setFocus(true)
        playAmbientAudio()

        resetInactivityTimer()
    else
        m.pinGateOverlay.showGate = true
        m.topHeader.visible = false
        m.mainContentGroup.visible = false
        m.bottomTipBar.visible = false
        m.pinGateOverlay.setFocus(true)
        stopAmbientAudio()
    end if
end sub

sub onNavItemSelected()
    idx = m.navRail.itemSelected
    switchView(idx)
    resetInactivityTimer()
end sub

sub switchView(index as Integer)
    m.welcomeView.visible = false
    m.houseRulesView.visible = false
    m.recommendationsView.visible = false
    m.weatherView.visible = false
    m.checkoutView.visible = false
    m.feedbackView.visible = false

    if index = 0
        m.welcomeView.visible = true
        m.navRail.setFocus(true)
    else if index = 1
        m.houseRulesView.visible = true
        rulesList = m.houseRulesView.findNode("rulesList")
        if rulesList <> invalid then rulesList.setFocus(true)
    else if index = 2
        m.recommendationsView.visible = true
        recList = m.recommendationsView.findNode("recList")
        if recList <> invalid then recList.setFocus(true)
    else if index = 3
        m.weatherView.visible = true
        m.navRail.setFocus(true)
    else if index = 4
        m.checkoutView.visible = true
        tasksList = m.checkoutView.findNode("tasksList")
        if tasksList <> invalid then tasksList.setFocus(true)
    else if index = 5
        m.feedbackView.visible = true
        m.navRail.setFocus(true)
    end if
end sub

sub resetInactivityTimer()
    m.inactivityTimer.control = "stop"
    m.inactivityTimer.control = "start"
end sub

sub onInactivityTimerFire()
    if not m.pinGateOverlay.visible and not m.screensaverOverlay.visible
        m.screensaverOverlay.visible = true
        m.screensaverOverlay.setFocus(true)
    end if
end sub

' Schedule checkout cleanup: 30 minutes after departure time, clear guest data
sub scheduleCheckoutCleanupTimer(prop as Object)
    if prop = invalid or prop.checkOutTime = "" then return

    ' Parse checkOutTime (e.g., "11:00 AM") and calculate seconds until 30 min after
    checkoutSeconds = ParseTimeToSeconds(prop.checkOutTime)
    if checkoutSeconds = -1 then return

    nowSeconds = GetSecondsSinceMidnight()
    ' 30 minutes after checkout
    targetSeconds = checkoutSeconds + (30 * 60)
    secondsUntilTarget = targetSeconds - nowSeconds

    ' If target is in the past, don't schedule (already cleared or will be handled by refresh)
    if secondsUntilTarget > 0
        m.checkoutCleanupTimer.duration = secondsUntilTarget
        m.checkoutCleanupTimer.control = "stop"
        m.checkoutCleanupTimer.control = "start"
    end if
end sub

' Schedule pre-check-in fetch: 30 minutes before standard check-in time
sub schedulePreCheckinFetchTimer(prop as Object)
    if prop = invalid or prop.checkInTime = "" then return

    ' Parse checkInTime (e.g., "4:00 PM") and calculate seconds until 30 min before
    checkinSeconds = ParseTimeToSeconds(prop.checkInTime)
    if checkinSeconds = -1 then return

    nowSeconds = GetSecondsSinceMidnight()
    ' 30 minutes before check-in
    targetSeconds = checkinSeconds - (30 * 60)
    secondsUntilTarget = targetSeconds - nowSeconds

    ' If target is in the past, skip (fetch will happen on next unlock or staff refresh)
    if secondsUntilTarget > 0
        m.preCheckinFetchTimer.duration = secondsUntilTarget
        m.preCheckinFetchTimer.control = "stop"
        m.preCheckinFetchTimer.control = "start"
    end if
end sub

' Helper: Parse "4:00 PM" to seconds since midnight
function ParseTimeToSeconds(timeStr as String) as Integer
    if timeStr = "" then return -1

    ' Extract hour, minute, and AM/PM
    timeStr = UCase(timeStr).Trim()
    isPM = timeStr.Instr("PM") >= 0
    isAM = timeStr.Instr("AM") >= 0

    ' Remove AM/PM and trim
    timeStr = timeStr.Replace("AM", "").Replace("PM", "").Trim()

    ' Split on :
    parts = timeStr.Split(":")
    if parts.Count() < 2 then return -1

    hour = Val(parts[0])
    minute = Val(parts[1])

    ' Convert to 24-hour
    if isPM and hour <> 12
        hour = hour + 12
    else if isAM and hour = 12
        hour = 0
    end if

    return (hour * 3600) + (minute * 60)
end function

' Helper: Get current seconds since midnight
function GetSecondsSinceMidnight() as Integer
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    return (dt.GetHours() * 3600) + (dt.GetMinutes() * 60) + dt.GetSeconds()
end function

sub onCheckoutCleanupTimerFire()
    ' Departing guest checkout time reached - clear guest data immediately
    ' Stop the timer first to prevent recursive scheduling
    m.checkoutCleanupTimer.control = "stop"
    if m.pinGateOverlay.isUnlocked and m.pinGateOverlay.currentPin <> ""
        prop = m.pinGateOverlay.unlockedProperty
        if prop <> invalid
            prop.guestName = ""
            prop.stayDates = ""
            m.pinGateOverlay.unlockedProperty = prop
            onPinGateUnlocked()
        end if
    end if
end sub

sub onPreCheckinFetchTimerFire()
    ' Pre-arrival guest data is deliberately staff-authorized only.
end sub

sub fetchPropertyDisplay()
    m.propertyRefreshTask = CreateObject("roSGNode", "SupabaseTask")
    m.propertyRefreshTask.requestType = "GET_PROPERTY_FOR_STAFF_REFRESH"
    m.propertyRefreshTask.deviceId = GetDeviceId()
    m.propertyRefreshTask.deviceToken = GetSavedDeviceToken()
    m.propertyRefreshTask.staffToken = m.staffMenu.staffToken
    m.propertyRefreshTask.observeField("state", "onPropertyDisplayRefreshStateChanged")
    m.propertyRefreshTask.control = "RUN"
end sub

sub onPropertyDisplayRefreshStateChanged()
    if m.propertyRefreshTask <> invalid and m.propertyRefreshTask.state = "stop"
        if m.propertyRefreshTask.responseSuccess and m.propertyRefreshTask.responseJson <> invalid
            prop = MapSupabasePropertyToProfile(m.propertyRefreshTask.responseJson)
            if prop <> invalid and prop.name <> ""
                m.pinGateOverlay.unlockedProperty = prop
                onPinGateUnlocked()
            end if
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    handled = false
    if press
        resetInactivityTimer()

        if m.screensaverOverlay.visible
            m.screensaverOverlay.visible = false
            m.navRail.setFocus(true)
            return true
        end if

        ' Staff combo: hold Replay button for 3 seconds
        if key = "replay"
            if m.staffLongPressTimer <> invalid and m.staffMenu <> invalid and not m.staffMenu.visible
                m.staffLongPressTimer.control = "start"
            end if
            return true ' Consume the event
        end if

        if key = "back" or key = "left"
            if m.staffMenu <> invalid and m.staffMenu.visible
                m.staffMenu.visible = false
                m.navRail.setFocus(true)
                return true
            end if
            if not m.pinGateOverlay.visible
                if not m.navRail.hasFocus()
                    m.navRail.setFocus(true)
                    handled = true
                end if
            end if
        end if
    else
        ' Replay released: cancel long-press if timer hasn't fired
        if key = "replay"
            if m.staffLongPressTimer <> invalid
                m.staffLongPressTimer.control = "stop"
            end if
            return true ' Consume the event
        end if
    end if
    return handled
end function

sub onStaffLongPressTimerFire()
    if m.staffMenu <> invalid and not m.staffMenu.visible
        m.staffMenu.deviceId = GetDeviceId()
        m.staffMenu.deviceToken = GetSavedDeviceToken()
        m.staffMenu.visible = true
        m.staffMenu.setFocus(true)
    end if
end sub

' Prevent Roku idle shutdown by resetting inactivity timer every 30 minutes
sub onKeepAliveTimerFire()
    ' Send a harmless key event to reset Roku's idle timer
    ' This simulates user activity without affecting UI state
    resetInactivityTimer()
end sub

sub onStaffMenuAction()
    if m.staffMenu = invalid then return
    action = m.staffMenu.staffAction
    m.staffMenu.visible = false

    if action = "refresh"
        ' Force immediate property display refresh
        if m.pinGateOverlay.isUnlocked and GetSavedDeviceToken() <> ""
            fetchPropertyDisplay()
        end if
        m.navRail.setFocus(true)
    else if action = "reassign"
        ' Lock and show PIN gate for new assignment
        previousProperty = m.pinGateOverlay.unlockedProperty
        if previousProperty <> invalid and previousProperty.name <> invalid
            m.pinGateOverlay.previousPropertyName = previousProperty.name
        else
            m.pinGateOverlay.previousPropertyName = ""
        end if
        ClearDeviceAssignment()
        m.pinGateOverlay.isUnlocked = false
        m.pinGateOverlay.reassignMode = true
        onPinGateUnlocked()
    else
        m.navRail.setFocus(true)
    end if
end sub

sub playAmbientAudio()
    if m.ambientAudio <> invalid
        audioUrl = buildAmbientAudioUrl()
        if audioUrl = "" then return
        if m.ambientAudio.content <> invalid and m.ambientAudio.content.url <> audioUrl
            m.ambientAudio.content.url = audioUrl
        end if
        m.ambientAudio.control = "play"
    end if
end sub

function buildAmbientAudioUrl() as String
    deviceId = GetDeviceId()
    deviceToken = GetSavedDeviceToken()
    if deviceId = "" or deviceToken = ""
        return ""
    end if

    baseUrl = GetSupabaseUrl()
    if Right(baseUrl, 1) = "/"
        baseUrl = Left(baseUrl, Len(baseUrl) - 1)
    end if
    return baseUrl + "/functions/v1/ambient-audio?device_id=" + UrlEncodeString(deviceId) + "&device_token=" + UrlEncodeString(deviceToken)
end function

sub stopAmbientAudio()
    if m.ambientAudio <> invalid
        m.ambientAudio.control = "stop"
    end if
end sub

sub onAmbientAudioStateChanged()
    if m.ambientAudio <> invalid and m.ambientAudio.state = "finished"
        if m.pinGateOverlay <> invalid and not m.pinGateOverlay.visible
            m.ambientAudio.control = "play"
        end if
    end if
end sub
