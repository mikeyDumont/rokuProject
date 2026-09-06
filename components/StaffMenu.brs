sub init()
    m.enteredDigits = ""
    m.selectedAction = ""
    m.currentDigitPos = 0
    m.digitValues = [0, 0, 0, 0]
    m.pinComplete = false
    m.pinVerified = false
    m.verificationPending = false
    m.selectedButton = "" ' "" | "refresh" | "reassign"

    m.pinBoxes = [
        m.top.findNode("staffPinBg1"),
        m.top.findNode("staffPinBg2"),
        m.top.findNode("staffPinBg3"),
        m.top.findNode("staffPinBg4")
    ]
    m.pinTexts = [
        m.top.findNode("staffPinText1"),
        m.top.findNode("staffPinText2"),
        m.top.findNode("staffPinText3"),
        m.top.findNode("staffPinText4")
    ]

    m.statusLabel = m.top.findNode("staffStatusLabel")
    m.btnRefreshBg = m.top.findNode("staffBtnRefreshBg")
    m.btnReassignBg = m.top.findNode("staffBtnReassignBg")
    m.btnRefreshLabel = m.top.findNode("staffBtnRefreshLabel")
    m.btnReassignLabel = m.top.findNode("staffBtnReassignLabel")

    updatePinDisplay()
end sub

sub updatePinDisplay()
    for i = 0 to 3
        if i = m.currentDigitPos and not m.pinComplete
            ' Active input: bright amber background with dark digit
            m.pinBoxes[i].color = "0xF59E0BFF"
            m.pinTexts[i].color = "0x06140DFF"
        else if m.pinComplete
            ' Confirmed: green background with dark digit
            m.pinBoxes[i].color = "0x10B981FF"
            m.pinTexts[i].color = "0x06140DFF"
        else
            ' Inactive: dark background with green digit
            m.pinBoxes[i].color = "0x162A20FF"
            m.pinTexts[i].color = "0x34D399FF"
        end if
        m.pinTexts[i].text = m.digitValues[i].ToStr()
    end for

    if m.pinComplete
        entered = ""
        for i = 0 to 3
            entered = entered + m.digitValues[i].ToStr()
        end for
        if m.pinVerified
            ' Auto-focus Refresh so staff can just press OK
            if m.selectedButton = ""
                m.selectedButton = "refresh"
            end if
            if m.selectedButton = "refresh"
                m.statusLabel.text = "Press OK to Refresh Reservation Info"
                m.statusLabel.color = "0x34D399FF"
                m.btnRefreshBg.color = "0x10B981FF"
                m.btnRefreshLabel.color = "0x06140DFF"
                m.btnReassignBg.color = "0x2E1A1AFF"
                m.btnReassignLabel.color = "0xFCA5A5FF"
            else if m.selectedButton = "reassign"
                m.statusLabel.text = "Press OK to Edit Device Assignment"
                m.statusLabel.color = "0xF87171FF"
                m.btnRefreshBg.color = "0x103E28FF"
                m.btnRefreshLabel.color = "0x6EE7B7FF"
                m.btnReassignBg.color = "0xEF4444FF"
                m.btnReassignLabel.color = "0xFFFFFFFF"
            end if
        else
            m.statusLabel.text = "Verifying company PIN..."
            m.statusLabel.color = "0xFBBF24FF"
        end if
    else
        m.statusLabel.text = "Digit " + (m.currentDigitPos + 1).ToStr() + " selected - Up/Down to change, Left/Right to move"
        m.statusLabel.color = "0x88DDBBFF"
        m.btnRefreshBg.color = "0x103E28FF"
        m.btnRefreshLabel.color = "0x6EE7B7FF"
        m.btnReassignBg.color = "0x2E1A1AFF"
        m.btnReassignLabel.color = "0xFCA5A5FF"
    end if
end sub

sub resetPin()
    m.digitValues = [0, 0, 0, 0]
    m.currentDigitPos = 0
    m.pinComplete = false
    m.pinVerified = false
    m.verificationPending = false
    m.selectedButton = ""
    m.enteredDigits = ""
    updatePinDisplay()
end sub

sub verifyCompanyPin()
    if m.verificationPending then return
    if m.top.propertyPin = "" then
        showVerificationFailure("This TV is not assigned to a property.")
        return
    end if

    entered = ""
    for i = 0 to 3
        entered = entered + m.digitValues[i].ToStr()
    end for

    m.verificationPending = true
    m.verifyTask = CreateObject("roSGNode", "SupabaseTask")
    m.verifyTask.requestType = "VERIFY_STAFF_PIN"
    m.verifyTask.deviceId = m.top.deviceId
    m.verifyTask.deviceToken = m.top.deviceToken
    m.verifyTask.companyPin = entered
    m.verifyTask.observeField("state", "onCompanyPinVerificationChanged")
    m.verifyTask.control = "RUN"
end sub

sub onCompanyPinVerificationChanged()
    if m.verifyTask = invalid or m.verifyTask.state <> "stop" then return

    m.verificationPending = false
    if m.verifyTask.responseSuccess and m.verifyTask.responseJson <> invalid and m.verifyTask.responseJson.approved = true
        m.pinVerified = true
        m.top.staffToken = m.verifyTask.responseJson.staff_token
        m.selectedButton = "refresh"
        updatePinDisplay()
    else
        if m.verifyTask.responseSuccess and m.verifyTask.responseJson <> invalid
            retryAfterSeconds = 0
            if m.verifyTask.responseJson.retry_after_seconds <> invalid
                retryAfterSeconds = m.verifyTask.responseJson.retry_after_seconds
            end if
            if retryAfterSeconds > 0
                retryMinutes = Int((retryAfterSeconds + 59) / 60)
                showVerificationFailure("Staff access is locked. Try again in " + retryMinutes.ToStr() + " minutes.")
            else
                showVerificationFailure("Company PIN was not accepted.")
            end if
        else
            print "Staff PIN verification failed: "; m.verifyTask.errorMessage
            showVerificationFailure("Unable to verify company PIN. Check Supabase setup.")
        end if
    end if
end sub

sub showVerificationFailure(message as String)
    resetPin()
    if m.statusLabel <> invalid
        m.statusLabel.text = message
        m.statusLabel.color = "0xF87171FF"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.verificationPending then return true

    if key = "back"
        m.top.visible = false
        resetPin()
        return true
    else if key = "up"
        if not m.pinComplete
            m.digitValues[m.currentDigitPos] = (m.digitValues[m.currentDigitPos] + 1) mod 10
            updatePinDisplay()
        end if
        return true
    else if key = "down"
        if not m.pinComplete
            m.digitValues[m.currentDigitPos] = (m.digitValues[m.currentDigitPos] - 1 + 10) mod 10
            updatePinDisplay()
        end if
        return true
    else if key = "left"
        if not m.pinComplete
            m.currentDigitPos = (m.currentDigitPos - 1 + 4) mod 4
            updatePinDisplay()
        else
            ' Select refresh action
            m.selectedButton = "refresh"
            updatePinDisplay()
        end if
        return true
    else if key = "right"
        if not m.pinComplete
            m.currentDigitPos = (m.currentDigitPos + 1) mod 4
            updatePinDisplay()
        else
            ' Select reassign action
            m.selectedButton = "reassign"
            updatePinDisplay()
        end if
        return true
    else if key = "OK"
        if not m.pinComplete
            m.pinComplete = true
            updatePinDisplay()
            verifyCompanyPin()
        else if m.pinVerified and m.selectedButton <> ""
            ' PIN valid and action selected - execute it
            m.top.staffAction = m.selectedButton
            resetPin()
        end if
        return true
    end if
    return false
end function
