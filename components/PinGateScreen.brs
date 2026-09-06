sub init()
    m.enteredDigits = ""
    m.deviceId = GetDeviceId()

    ' Start fully hidden - MainScene will reveal when ready
    m.top.opacity = 0.0
    m.top.visible = false

    ' Cache child nodes for show/hide
    m.bgCanvas = m.top.findNode("bgCanvas")
    m.headerGroup = m.top.findNode("headerGroup")
    m.keypadCard = m.top.findNode("keypadCard")
    m.cabinsCard = m.top.findNode("cabinsCard")
    m.footerGroup = m.top.findNode("footerGroup")

    m.pinBox1 = m.top.findNode("pinBox1")
    m.pinBox2 = m.top.findNode("pinBox2")
    m.pinBox3 = m.top.findNode("pinBox3")
    m.pinBox4 = m.top.findNode("pinBox4")

    m.pinText1 = m.top.findNode("pinText1")
    m.pinText2 = m.top.findNode("pinText2")
    m.pinText3 = m.top.findNode("pinText3")
    m.pinText4 = m.top.findNode("pinText4")

    m.statusLabel = m.top.findNode("statusLabel")

    m.keyBackgrounds = [
        [m.top.findNode("bg_0_0"), m.top.findNode("bg_0_1"), m.top.findNode("bg_0_2")],
        [m.top.findNode("bg_1_0"), m.top.findNode("bg_1_1"), m.top.findNode("bg_1_2")],
        [m.top.findNode("bg_2_0"), m.top.findNode("bg_2_1"), m.top.findNode("bg_2_2")],
        [m.top.findNode("bg_3_0"), m.top.findNode("bg_3_1"), m.top.findNode("bg_3_2")]
    ]

    m.keyLabels = [
        [m.top.findNode("lbl_0_0"), m.top.findNode("lbl_0_1"), m.top.findNode("lbl_0_2")],
        [m.top.findNode("lbl_1_0"), m.top.findNode("lbl_1_1"), m.top.findNode("lbl_1_2")],
        [m.top.findNode("lbl_2_0"), m.top.findNode("lbl_2_1"), m.top.findNode("lbl_2_2")],
        [m.top.findNode("lbl_3_0"), m.top.findNode("lbl_3_1"), m.top.findNode("lbl_3_2")]
    ]

    m.cabinBackgrounds = [
        m.top.findNode("cabinBg_0"),
        m.top.findNode("cabinBg_1"),
        m.top.findNode("cabinBg_2")
    ]
    m.cabinAccents = [
        m.top.findNode("cabinAccent_0"),
        m.top.findNode("cabinAccent_1"),
        m.top.findNode("cabinAccent_2")
    ]
    m.cabinTitles = [
        m.top.findNode("cabinTitle_0"),
        m.top.findNode("cabinTitle_1"),
        m.top.findNode("cabinTitle_2")
    ]
    m.cabinSubs = [
        m.top.findNode("cabinSub_0"),
        m.top.findNode("cabinSub_1"),
        m.top.findNode("cabinSub_2")
    ]
    m.cabinPinBadges = [
        m.top.findNode("cabinPinBadge_0"),
        m.top.findNode("cabinPinBadge_1"),
        m.top.findNode("cabinPinBadge_2")
    ]

    m.cabinPins = []
    for i = 0 to 2
        m.top.findNode("cabinCard_" + i.ToStr()).visible = false
    end for

    m.activeZone = "keypad"
    m.curRow = 0
    m.curCol = 0
    m.curCabin = 0

    updatePinDisplay()
    renderFocusState()

    if not IsSupabaseConfigured()
        m.statusLabel.text = "Property database is not configured"
        m.statusLabel.color = "0xF87171FF"
    end if

    ' In reassign mode, show current PIN state but don't auto-submit
    savedPin = GetSavedPropertyPin()
    if savedPin <> "" and Len(savedPin) = 4
        if m.top.reassignMode
            ' Show that a PIN is currently assigned
            m.enteredDigits = savedPin
            updatePinDisplay()
            m.statusLabel.text = "Current PIN: " + savedPin + " - Press CLEAR to remove, or enter new PIN"
            m.statusLabel.color = "0xFBBF24FF"
        else
            ' One-time migration of legacy assigned TVs to device credentials.
            m.enteredDigits = savedPin
            submitPin()
        end if
    end if
end sub

sub updatePinDisplay()
    l = Len(m.enteredDigits)

    if l >= 1
        m.pinText1.text = Mid(m.enteredDigits, 1, 1)
        m.pinBox1.color = "0x0F5132FF"
    else
        m.pinText1.text = ""
        m.pinBox1.color = "0x162A20FF"
    end if

    if l >= 2
        m.pinText2.text = Mid(m.enteredDigits, 2, 1)
        m.pinBox2.color = "0x0F5132FF"
    else
        m.pinText2.text = ""
        m.pinBox2.color = "0x162A20FF"
    end if

    if l >= 3
        m.pinText3.text = Mid(m.enteredDigits, 3, 1)
        m.pinBox3.color = "0x0F5132FF"
    else
        m.pinText3.text = ""
        m.pinBox3.color = "0x162A20FF"
    end if

    if l >= 4
        m.pinText4.text = Mid(m.enteredDigits, 4, 1)
        m.pinBox4.color = "0x0F5132FF"
    else
        m.pinText4.text = ""
        m.pinBox4.color = "0x162A20FF"
    end if

    if l = 0
        m.statusLabel.text = "Use D-Pad to navigate keypad, or press numbers on remote"
        m.statusLabel.color = "0x88DDBBFF"
    else if l < 4
        m.statusLabel.text = "Entered " + Str(l).Trim() + " of 4 digits..."
        m.statusLabel.color = "0xFBBF24FF"
    end if
end sub

sub renderFocusState()
    for r = 0 to 3
        for c = 0 to 2
            bgNode = m.keyBackgrounds[r][c]
            lblNode = m.keyLabels[r][c]
            isFocused = (m.activeZone = "keypad" and m.curRow = r and m.curCol = c)

            if isFocused
                if r = 3 and c = 0
                    bgNode.color = "0xEF4444FF"
                    lblNode.color = "0xFFFFFFFF"
                else if r = 3 and c = 2
                    bgNode.color = "0x10B981FF"
                    lblNode.color = "0x06140DFF"
                else
                    bgNode.color = "0x10B981FF"
                    lblNode.color = "0x06140DFF"
                end if
            else
                if r = 3 and c = 0
                    bgNode.color = "0x2E1A1AFF"
                    lblNode.color = "0xFCA5A5FF"
                else if r = 3 and c = 2
                    bgNode.color = "0x103E28FF"
                    lblNode.color = "0x6EE7B7FF"
                else
                    bgNode.color = "0x182C22FF"
                    lblNode.color = "0xFFFFFFFF"
                end if
            end if
        end for
    end for

    for i = 0 to 2
        bgNode = m.cabinBackgrounds[i]
        accentNode = m.cabinAccents[i]
        titleNode = m.cabinTitles[i]
        isCabinFocused = (m.activeZone = "cabins" and m.curCabin = i)

        if isCabinFocused
            bgNode.color = "0x10B981FF"
            accentNode.color = "0xFFFFFFFF"
            titleNode.color = "0x06140DFF"
        else
            bgNode.color = "0x15281EFF"
            if i = 0 then accentNode.color = "0x10B981FF"
            if i = 1 then accentNode.color = "0x3B82F6FF"
            if i = 2 then accentNode.color = "0xF59E0BFF"
            titleNode.color = "0xFFFFFFFF"
        end if
    end for
end sub

sub handleDigitInput(digit as String)
    if Len(m.enteredDigits) < 4
        m.enteredDigits = m.enteredDigits + digit
        updatePinDisplay()
        if Len(m.enteredDigits) = 4 then submitPin()
    end if
end sub

sub submitPin()
    if Len(m.enteredDigits) <> 4
        m.statusLabel.text = "Please enter all 4 digits of your Property PIN"
        m.statusLabel.color = "0xF87171FF"
        return
    end if

    if IsSupabaseConfigured()
        m.statusLabel.text = "Verifying PIN with Supabase DB..."
        m.statusLabel.color = "0xFBBF24FF"

        m.supabaseTask = CreateObject("roSGNode", "SupabaseTask")
        m.supabaseTask.requestType = "ENROLL_DEVICE"
        m.supabaseTask.pin = m.enteredDigits
        m.supabaseTask.deviceId = m.deviceId
        m.supabaseTask.observeField("state", "onSupabasePinTaskStateChanged")
        m.supabaseTask.control = "RUN"
    else
        m.statusLabel.text = "Property database is not configured"
        m.statusLabel.color = "0xF87171FF"
    end if
end sub

sub onSupabasePinTaskStateChanged()
    if m.supabaseTask <> invalid and m.supabaseTask.state = "stop"
        if m.supabaseTask.responseSuccess and m.supabaseTask.responseJson <> invalid and m.supabaseTask.responseJson.approved = true
            deviceToken = m.supabaseTask.responseJson.device_token
            if deviceToken <> invalid and deviceToken <> ""
                SaveDeviceToken(deviceToken)
                m.displayTask = CreateObject("roSGNode", "SupabaseTask")
                m.displayTask.requestType = "GET_PROPERTY_BY_PIN"
                m.displayTask.deviceId = m.deviceId
                m.displayTask.deviceToken = deviceToken
                m.displayTask.observeField("state", "onDeviceEnrollmentDisplayChanged")
                m.displayTask.control = "RUN"
                return
            end if
        end if

        m.statusLabel.text = "Unable to verify this PIN with the property database"
        m.statusLabel.color = "0xF87171FF"
        m.enteredDigits = ""
        updatePinDisplay()
    end if
end sub

sub onDeviceEnrollmentDisplayChanged()
    if m.displayTask <> invalid and m.displayTask.state = "stop"
        if m.displayTask.responseSuccess and m.displayTask.responseJson <> invalid
            prop = MapSupabasePropertyToProfile(m.displayTask.responseJson)
            if prop <> invalid and prop.name <> ""
                m.statusLabel.text = "Property assigned! Unlocking " + prop.name + "..."
                m.statusLabel.color = "0x34D399FF"
                m.top.unlockedProperty = prop
                m.top.currentPin = ""
                m.top.isUnlocked = true
                m.top.reassignMode = false
                return
            end if
        end if
        m.statusLabel.text = "Unable to load the assigned property"
        m.statusLabel.color = "0xF87171FF"
    end if
end sub

sub onShowGateChanged()
    if m.top.showGate
        showPinGate()
    end if
end sub

sub showPinGate()
    m.bgCanvas.visible = true
    m.headerGroup.visible = true
    m.keypadCard.visible = true
    ' cabinsCard stays hidden - removed from UI
    m.footerGroup.visible = true
    m.top.opacity = 1.0
    m.top.visible = true
end sub

sub onReassignModeChanged()
    if m.top.reassignMode
        ' Clear entered digits and show current state
        m.enteredDigits = ""
        updatePinDisplay()
        savedPin = GetSavedPropertyPin()
        if savedPin <> "" and Len(savedPin) = 4
            m.enteredDigits = savedPin
            updatePinDisplay()
            m.statusLabel.text = "Current PIN: " + savedPin + " - Press CLEAR to remove, or enter new PIN"
            m.statusLabel.color = "0xFBBF24FF"
        else
            if m.top.previousPropertyName <> ""
                m.statusLabel.text = "Previously assigned: " + m.top.previousPropertyName + ". Enter new 4-digit Property PIN."
            else
                m.statusLabel.text = "No PIN assigned. Enter 4-digit Property PIN to assign."
            end if
            m.statusLabel.color = "0x88DDBBFF"
        end if
    end if
end sub

sub resetPin()
    m.enteredDigits = ""
    updatePinDisplay()
    if m.top.reassignMode
        m.statusLabel.text = "PIN cleared. Enter new 4-digit Property PIN"
        m.statusLabel.color = "0x88AAAAFF"
    else
        m.statusLabel.text = "PIN cleared. Enter your 4-digit Property PIN"
        m.statusLabel.color = "0x88AAAAFF"
    end if
end sub

sub handleOKPress()
    if m.activeZone = "keypad"
        r = m.curRow
        c = m.curCol

        if r = 0 and c = 0 then handleDigitInput("1")
        if r = 0 and c = 1 then handleDigitInput("2")
        if r = 0 and c = 2 then handleDigitInput("3")

        if r = 1 and c = 0 then handleDigitInput("4")
        if r = 1 and c = 1 then handleDigitInput("5")
        if r = 1 and c = 2 then handleDigitInput("6")

        if r = 2 and c = 0 then handleDigitInput("7")
        if r = 2 and c = 1 then handleDigitInput("8")
        if r = 2 and c = 2 then handleDigitInput("9")

        if r = 3 and c = 0 then resetPin()
        if r = 3 and c = 1 then handleDigitInput("0")
        if r = 3 and c = 2 then submitPin()

    else if m.activeZone = "cabins"
        if m.curCabin >= 0 and m.curCabin < m.cabinPins.Count()
            selectedPin = m.cabinPins[m.curCabin]
            m.enteredDigits = selectedPin
            updatePinDisplay()
            submitPin()
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    handled = false
    if not press then return false

    if key >= "0" and key <= "9"
        handleDigitInput(key)
        return true
    else if key = "back" or key = "replay"
        if Len(m.enteredDigits) > 0
            m.enteredDigits = Left(m.enteredDigits, Len(m.enteredDigits) - 1)
            updatePinDisplay()
            return true
        end if
    else if key = "OK"
        handleOKPress()
        return true
    else if key = "right"
        if m.activeZone = "keypad"
            if m.curCol < 2
                m.curCol = m.curCol + 1
            else
                m.curCol = 0
            end if
            renderFocusState()
            handled = true
        end if
    else if key = "left"
        if m.activeZone = "cabins"
            m.activeZone = "keypad"
            m.curCol = 2
            m.curRow = m.curCabin
            renderFocusState()
            handled = true
        else if m.activeZone = "keypad"
            if m.curCol > 0
                m.curCol = m.curCol - 1
                renderFocusState()
                handled = true
            end if
        end if
    else if key = "down"
        if m.activeZone = "keypad"
            if m.curRow < 3
                m.curRow = m.curRow + 1
                renderFocusState()
                handled = true
            end if
        else if m.activeZone = "cabins"
            if m.curCabin < 2
                m.curCabin = m.curCabin + 1
                renderFocusState()
                handled = true
            end if
        end if
    else if key = "up"
        if m.activeZone = "keypad"
            if m.curRow > 0
                m.curRow = m.curRow - 1
                renderFocusState()
                handled = true
            end if
        else if m.activeZone = "cabins"
            if m.curCabin > 0
                m.curCabin = m.curCabin - 1
                renderFocusState()
                handled = true
            end if
        end if
    end if
    return handled
end function
