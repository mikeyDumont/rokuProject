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
    m.alertsCard = m.top.findNode("alertsCard")
    m.alertsListGroup = m.top.findNode("alertsListGroup")

    menuContent = CreateObject("roSGNode", "ContentNode")
    m.navBaseItems = [
        {title: "Welcome & Wi-Fi", key: "welcome"},
        {title: "House Rules & Spa", key: "houserules"},
        {title: "Local Recommendations", key: "recommendations"},
        {title: "Weather Forecast", key: "weather"},
        {title: "Departure Checklist", key: "checkout"}
    ]
    m.navViewKeys = []
    for each item in m.navBaseItems
        itemNode = menuContent.createChild("ContentNode")
        itemNode.title = item.title
        m.navViewKeys.Push(item.key)
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

sub rebuildNavMenu()
    menuContent = CreateObject("roSGNode", "ContentNode")
    m.navItemKeys = ["welcome", "rules", "recs", "weather", "checkout"]
    baseTitles = [
        "Welcome & Wi-Fi",
        "House Rules & Spa",
        "Local Recommendations",
        "Weather Forecast",
        "Departure Checklist"
    ]
    for each title in baseTitles
        itemNode = menuContent.createChild("ContentNode")
        itemNode.title = title
    end for

    if m.hasActiveDiscount
        navLabel = "Returning Guest Perks"
        if m.activeDiscount <> invalid and m.activeDiscount.navLabel <> invalid and m.activeDiscount.navLabel <> ""
            navLabel = m.activeDiscount.navLabel
        end if
        itemNode = menuContent.createChild("ContentNode")
        itemNode.title = navLabel
        m.navItemKeys.Push("perks")
    end if

    m.navRail.content = menuContent
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
            m.deepLinkEnrollTask = CreateObject("roSGNode", "SupabaseTask")
            m.deepLinkEnrollTask.requestType = "ENROLL_DEVICE"
            m.deepLinkEnrollTask.pin = pin
            m.deepLinkEnrollTask.deviceId = GetDeviceId()
            m.deepLinkEnrollTask.observeField("state", "onDeepLinkEnrollStateChanged")
            m.deepLinkEnrollTask.control = "RUN"
        end if
    end if
end sub

sub onDeepLinkEnrollStateChanged()
    if m.deepLinkEnrollTask = invalid or m.deepLinkEnrollTask.state <> "stop" then return
    if m.deepLinkEnrollTask.responseSuccess and m.deepLinkEnrollTask.responseJson <> invalid and m.deepLinkEnrollTask.responseJson.approved = true
        deviceToken = m.deepLinkEnrollTask.responseJson.device_token
        if deviceToken <> invalid and deviceToken <> ""
            SaveDeviceToken(deviceToken)
            m.deepLinkTask = CreateObject("roSGNode", "SupabaseTask")
            m.deepLinkTask.requestType = "GET_PROPERTY_BY_PIN"
            m.deepLinkTask.deviceId = GetDeviceId()
            m.deepLinkTask.deviceToken = deviceToken
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
            m.screensaverOverlay.cabinName = prop.name
            m.screensaverOverlay.guestName = prop.guestName

            ' Schedule event-driven timers for this reservation
            scheduleCheckoutCleanupTimer(prop)
            schedulePreCheckinFetchTimer(prop)
            loadActiveDiscount()
            loadActiveAlerts()
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

    if m.navViewKeys = invalid or index < 0 or index >= m.navViewKeys.Count() then return
    key = m.navViewKeys[index]

    if key = "welcome"
        m.welcomeView.visible = true
        m.navRail.setFocus(true)
    else if key = "houserules"
        m.houseRulesView.visible = true
        rulesList = m.houseRulesView.findNode("rulesList")
        if rulesList <> invalid then rulesList.setFocus(true)
    else if key = "recommendations"
        m.recommendationsView.visible = true
        recList = m.recommendationsView.findNode("recList")
        if recList <> invalid then recList.setFocus(true)
    else if key = "weather"
        m.weatherView.visible = true
        m.navRail.setFocus(true)
    else if key = "checkout"
        m.checkoutView.visible = true
        tasksList = m.checkoutView.findNode("tasksList")
        if tasksList <> invalid then tasksList.setFocus(true)
    else if key = "feedback"
        m.feedbackView.visible = true
        m.navRail.setFocus(true)
    end if
end sub

' Fetches the current active discount and toggles the "Returning Guest Perks" menu item accordingly
sub refreshActiveDiscount(prop as Object)
    if not IsSupabaseConfigured()
        applyDiscountResult(invalid)
        return
    end if

    propId = ""
    if prop <> invalid and prop.id <> invalid then propId = prop.id

    m.discountTask = CreateObject("roSGNode", "SupabaseTask")
    m.discountTask.requestType = "GET_ACTIVE_DISCOUNT"
    m.discountTask.propertyId = propId
    m.discountTask.observeField("state", "onDiscountTaskStateChanged")
    m.discountTask.control = "RUN"
end sub

sub onDiscountTaskStateChanged()
    if m.discountTask = invalid or m.discountTask.state <> "stop" then return
    discount = invalid
    if m.discountTask.responseSuccess and m.discountTask.responseArray <> invalid and m.discountTask.responseArray.Count() > 0
        discount = MapSupabaseDiscount(m.discountTask.responseArray[0])
    end if
    applyDiscountResult(discount)
end sub

sub applyDiscountResult(discount as Object)
    m.activeDiscount = discount
    m.hasActiveDiscount = (discount <> invalid)
    rebuildNavMenu()
    m.feedbackView.discount = discount

    if not m.hasActiveDiscount and m.feedbackView.visible
        switchView(0)
    end if
end sub

sub resetInactivityTimer()
    m.inactivityTimer.control = "stop"
    m.inactivityTimer.control = "start"
end sub

sub loadActiveDiscount()
    if not IsSupabaseConfigured() then return
    token = GetSavedDeviceToken()
    if token = "" then return

    m.activeDiscountTask = CreateObject("roSGNode", "SupabaseTask")
    m.activeDiscountTask.requestType = "GET_ACTIVE_DISCOUNT"
    m.activeDiscountTask.deviceId = GetDeviceId()
    m.activeDiscountTask.deviceToken = token
    m.activeDiscountTask.observeField("state", "onActiveDiscountStateChanged")
    m.activeDiscountTask.control = "RUN"
end sub

sub onActiveDiscountStateChanged()
    if m.activeDiscountTask = invalid or m.activeDiscountTask.state <> "stop" then return

    discount = invalid
    if m.activeDiscountTask.responseSuccess and m.activeDiscountTask.responseArray <> invalid and m.activeDiscountTask.responseArray.Count() > 0
        discount = MapSupabaseDiscount(m.activeDiscountTask.responseArray[0])
    end if

    m.feedbackView.discountData = discount

    perkLabel = "Returning Guest Perk"
    if discount <> invalid and discount.navLabel <> invalid and discount.navLabel <> "" then perkLabel = discount.navLabel
    rebuildNavRail(discount <> invalid, perkLabel)
end sub

sub loadActiveAlerts()
    if not IsSupabaseConfigured() then return
    token = GetSavedDeviceToken()
    if token = "" then return

    m.activeAlertsTask = CreateObject("roSGNode", "SupabaseTask")
    m.activeAlertsTask.requestType = "GET_ACTIVE_ALERTS"
    m.activeAlertsTask.deviceId = GetDeviceId()
    m.activeAlertsTask.deviceToken = token
    m.activeAlertsTask.observeField("state", "onActiveAlertsStateChanged")
    m.activeAlertsTask.control = "RUN"
end sub

sub onActiveAlertsStateChanged()
    if m.activeAlertsTask = invalid or m.activeAlertsTask.state <> "stop" then return

    alerts = []
    if m.activeAlertsTask.responseSuccess and m.activeAlertsTask.responseArray <> invalid
        for each row in m.activeAlertsTask.responseArray
            alert = MapSupabaseAlert(row)
            if alert <> invalid then alerts.Push(alert)
        end for
    end if

    renderAlerts(alerts)
end sub

' Renders 0..N active alerts in the fixed-height alertsCard, shrinking the font
' as the count grows so several short alerts still fit without overflowing.
sub renderAlerts(alerts as Object)
    if m.alertsCard = invalid or m.alertsListGroup = invalid then return

    while m.alertsListGroup.getChildCount() > 0
        m.alertsListGroup.removeChildIndex(0)
    end while

    if alerts = invalid or alerts.Count() = 0
        m.alertsCard.visible = false
        return
    end if

    alertFont = "font:MediumBoldSystemFont"
    maxVisible = 2
    if alerts.Count() = 2
        alertFont = "font:SmallBoldSystemFont"
        maxVisible = 2
    else if alerts.Count() >= 3
        alertFont = "font:SmallestBoldSystemFont"
        maxVisible = 4
    end if

    visibleCount = alerts.Count()
    if visibleCount > maxVisible then visibleCount = maxVisible

    for i = 0 to visibleCount - 1
        alert = alerts[i]
        label = m.alertsListGroup.createChild("Label")
        label.text = "• " + alert.message
        label.font = alertFont
        label.color = AlertSeverityColor(alert.severity)
        label.width = 1344
        label.wrap = true
    end for

    if alerts.Count() > maxVisible
        moreLabel = m.alertsListGroup.createChild("Label")
        moreLabel.text = "+ " + Str(alerts.Count() - maxVisible).Trim() + " more alert(s)"
        moreLabel.font = "font:SmallestSystemFont"
        moreLabel.color = "0x88AAAAFF"
        moreLabel.width = 1344
    end if

    m.alertsCard.visible = true
end sub

function AlertSeverityColor(severity as String) as String
    if severity = "critical" then return "0xF87171FF"
    if severity = "warning" then return "0xFBBF24FF"
    return "0xFDE68AFF"
end function

' Only show the Returning Guest Perk tab when an active discount exists for this org/property
sub rebuildNavRail(showPerk as Boolean, perkLabel as String)
    menuContent = CreateObject("roSGNode", "ContentNode")
    m.navViewKeys = []
    for each item in m.navBaseItems
        itemNode = menuContent.createChild("ContentNode")
        itemNode.title = item.title
        m.navViewKeys.Push(item.key)
    end for

    if showPerk
        perkNode = menuContent.createChild("ContentNode")
        perkNode.title = perkLabel
        m.navViewKeys.Push("feedback")
    end if

    m.navRail.content = menuContent
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
    if m.ambientAudio = invalid then return
    if not IsSupabaseConfigured() then return

    ' A fresh short-lived signed URL is fetched before each loop start instead of
    ' bundling the mp3 in the package (keeps the sideload package under the size limit).
    m.ambientAudioSignTask = CreateObject("roSGNode", "SupabaseTask")
    m.ambientAudioSignTask.requestType = "GET_SIGNED_AMBIENT_AUDIO_URL"
    m.ambientAudioSignTask.useStorageApi = true
    m.ambientAudioSignTask.endpoint = "object/sign/channel-media/ambient/forest_ambience-v1.mp3"
    m.ambientAudioSignTask.postBody = "{" + Chr(34) + "expiresIn" + Chr(34) + ":3600}"
    m.ambientAudioSignTask.observeField("state", "onAmbientAudioSignStateChanged")
    m.ambientAudioSignTask.control = "RUN"
end sub

sub onAmbientAudioSignStateChanged()
    if m.ambientAudioSignTask = invalid or m.ambientAudioSignTask.state <> "stop" then return
    if m.ambientAudioSignTask.responseSuccess and m.ambientAudioSignTask.responseJson <> invalid and m.ambientAudioSignTask.responseJson.signedURL <> invalid
        baseUrl = GetSupabaseUrl()
        if Right(baseUrl, 1) = "/" then baseUrl = Left(baseUrl, Len(baseUrl) - 1)

        ambientContent = CreateObject("roSGNode", "ContentNode")
        ambientContent.url = baseUrl + "/storage/v1" + m.ambientAudioSignTask.responseJson.signedURL
        ambientContent.streamFormat = "mp3"
        m.ambientAudio.content = ambientContent
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
            playAmbientAudio()
        end if
    end if
end sub
