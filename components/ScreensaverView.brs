sub init()
    m.ssTimeLabel = m.top.findNode("ssTimeLabel")
    m.ssCabinLabel = m.top.findNode("ssCabinLabel")
    m.ssGuestLabel = m.top.findNode("ssGuestLabel")
    onCabinChanged()
    onGuestChanged()
    m.clockTimer = m.top.findNode("clockTimer")
    m.floatingCard = m.top.findNode("floatingCard")
    m.driftAnimation = m.top.findNode("driftAnimation")
    m.driftInterpolator = m.top.findNode("driftInterpolator")

    ' Keep bounds deterministic even though this component initializes while hidden.
    m.cardWidth = 800
    m.cardHeight = 242

    ' Keep the complete label bounds inside a conservative TV overscan-safe area.
    horizontalMargin = 160
    verticalMargin = 100
    m.minX = horizontalMargin
    m.maxX = 1920 - m.cardWidth - horizontalMargin
    m.minY = verticalMargin
    m.maxY = 1080 - m.cardHeight - verticalMargin

    ' Start at true center.
    m.posX = (1920 - m.cardWidth) / 2
    m.posY = (1080 - m.cardHeight) / 2
    m.driftSpeed = 8.0

    m.floatingCard.translation = [m.posX, m.posY]

    m.clockTimer.observeField("fire", "onClockTimerFire")
    m.clockTimer.control = "start"
    if m.driftAnimation <> invalid
        m.driftAnimation.observeField("state", "onDriftAnimationStateChanged")
        m.top.observeField("visible", "onScreensaverVisibilityChanged")
        if m.top.visible then startNextDrift()
    end if
    updateClock()
end sub

sub onClockTimerFire()
    updateClock()
end sub

sub onScreensaverVisibilityChanged()
    if m.top.visible
        startNextDrift()
    else
        m.driftAnimation.control = "stop"
    end if
end sub

sub onDriftAnimationStateChanged()
    if m.driftAnimation.state = "stopped" and m.top.visible
        startNextDrift()
    end if
end sub

sub startNextDrift()
    startPosition = m.floatingCard.translation
    targetX = m.minX + Rnd(m.maxX - m.minX)
    targetY = m.minY + Rnd(m.maxY - m.minY)
    deltaX = targetX - startPosition[0]
    deltaY = targetY - startPosition[1]
    distance = Sqr(deltaX * deltaX + deltaY * deltaY)

    m.driftInterpolator.keyValue = [startPosition, [targetX, targetY]]
    m.driftAnimation.duration = distance / m.driftSpeed
    if m.driftAnimation.duration < 20 then m.driftAnimation.duration = 20
    m.driftAnimation.control = "start"
end sub

sub updateClock()
    date = CreateObject("roDateTime")
    date.ToLocalTime()
    hours = date.GetHours()
    mins = date.GetMinutes()
    ampm = "AM"
    if hours >= 12
        ampm = "PM"
        if hours > 12 then hours = hours - 12
    end if
    if hours = 0 then hours = 12
    minStr = Str(mins).Trim()
    if Len(minStr) < 2 then minStr = "0" + minStr
    m.ssTimeLabel.text = Str(hours).Trim() + ":" + minStr + " " + ampm
end sub

sub onCabinChanged()
    if m.ssCabinLabel <> invalid
        m.ssCabinLabel.text = m.top.cabinName
    end if
end sub

sub onGuestChanged()
    if m.ssGuestLabel <> invalid
        if m.top.guestName <> ""
            m.ssGuestLabel.text = "Welcome, " + m.top.guestName
        else
            m.ssGuestLabel.text = ""
        end if
    end if
end sub
