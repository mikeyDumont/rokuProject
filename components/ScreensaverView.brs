sub init()
    m.ssTimeLabel = m.top.findNode("ssTimeLabel")
    m.ssCabinLabel = m.top.findNode("ssCabinLabel")
    m.ssGuestLabel = m.top.findNode("ssGuestLabel")
    onCabinChanged()
    onGuestChanged()
    m.clockTimer = m.top.findNode("clockTimer")
    m.driftTimer = m.top.findNode("driftTimer")
    m.floatingCard = m.top.findNode("floatingCard")

    ' Get actual card dimensions from its rendered bounds after layout
    m.cardWidth = 800
    m.cardHeight = 200
    if m.floatingCard <> invalid
        ' Force layout to get actual size
        m.floatingCard.visible = true
        rect = m.floatingCard.sceneBoundingRect()
        if rect.width > 0 then m.cardWidth = rect.width
        if rect.height > 0 then m.cardHeight = rect.height
    end if

    ' Full TV canvas: 1920x1080, with margin from edges
    margin = 80
    m.minX = margin
    m.maxX = 1920 - m.cardWidth - margin
    m.minY = margin
    m.maxY = 1080 - m.cardHeight - margin

    ' Start at true center
    m.posX = (1920 - m.cardWidth) / 2
    m.posY = (1080 - m.cardHeight) / 2

    ' Organic wander: direction vector + speed, not fixed velocity
    m.dirX = (Rnd(200) - 100) / 100.0  ' Random -1.0 to 1.0
    m.dirY = (Rnd(200) - 100) / 100.0
    ' Normalize
    len = Sqr(m.dirX * m.dirX + m.dirY * m.dirY)
    if len > 0
        m.dirX = m.dirX / len
        m.dirY = m.dirY / len
    else
        m.dirX = 1.0
        m.dirY = 0.0
    end if
    m.baseSpeed = 3.5
    m.turnRate = 0.015           ' Gentle curve per tick
    m.turnTimer = 0
    m.turnDuration = 90 + Rnd(120)  ' Change direction every 1.5-3.5 min

    m.floatingCard.translation = [m.posX, m.posY]

    m.clockTimer.observeField("fire", "onClockTimerFire")
    m.clockTimer.control = "start"
    if m.driftTimer <> invalid
        m.driftTimer.observeField("fire", "onDriftTimerFire")
        m.driftTimer.control = "start"
    end if
    updateClock()
end sub

sub onClockTimerFire()
    updateClock()
end sub

' Organic wander: smooth curves with occasional direction shifts
sub onDriftTimerFire()
    if not m.top.visible then return

    ' Periodic gentle turn (creates arcs, not straight lines)
    m.turnTimer = m.turnTimer + 1
    if m.turnTimer >= m.turnDuration
        m.turnTimer = 0
        m.turnDuration = 90 + Rnd(120)
        ' Random turn: rotate direction by -45° to +45°
        turnAmount = (Rnd(160) - 80) / 100.0  ' -0.8 to +0.8
        ' Rotate direction vector
        cosT = Cos(turnAmount)
        sinT = Sin(turnAmount)
        newDirX = m.dirX * cosT - m.dirY * sinT
        newDirY = m.dirX * sinT + m.dirY * cosT
        m.dirX = newDirX
        m.dirY = newDirY
    end if

    ' Continuous subtle curve ( sinusoidal steering )
    curve = Sin(m.turnTimer * 0.05) * m.turnRate
    cosC = Cos(curve)
    sinC = Sin(curve)
    curDirX = m.dirX * cosC - m.dirY * sinC
    curDirY = m.dirX * sinC + m.dirY * cosC

    ' Speed varies slightly for organic feel
    speed = m.baseSpeed + (Sin(m.turnTimer * 0.03) * 0.8)

    ' Move
    m.posX = m.posX + (curDirX * speed)
    m.posY = m.posY + (curDirY * speed)

    ' Soft bounds: steer toward center when approaching edge
    edgeMargin = 150
    centerX = (m.minX + m.maxX) / 2
    centerY = (m.minY + m.maxY) / 2
    
    nearLeft = m.posX < m.minX + edgeMargin
    nearRight = m.posX > m.maxX - edgeMargin
    nearTop = m.posY < m.minY + edgeMargin
    nearBottom = m.posY > m.maxY - edgeMargin
    
    if nearLeft or nearRight or nearTop or nearBottom
        ' Direction toward center
        toCenterX = centerX - m.posX
        toCenterY = centerY - m.posY
        len = Sqr(toCenterX * toCenterX + toCenterY * toCenterY)
        if len > 0
            toCenterX = toCenterX / len
            toCenterY = toCenterY / len
            ' Blend current direction with center-seeking direction
            blend = 0.06
            m.dirX = m.dirX * (1.0 - blend) + toCenterX * blend
            m.dirY = m.dirY * (1.0 - blend) + toCenterY * blend
            ' Re-normalize
            len = Sqr(m.dirX * m.dirX + m.dirY * m.dirY)
            if len > 0
                m.dirX = m.dirX / len
                m.dirY = m.dirY / len
            end if
        end if
    end if

    ' Hard clamp at absolute bounds with bounce-back toward center
    if m.posX < m.minX
        m.posX = m.minX
        m.dirX = Abs(m.dirX)  ' Ensure moving right
    end if
    if m.posX > m.maxX
        m.posX = m.maxX
        m.dirX = -Abs(m.dirX)  ' Ensure moving left
    end if
    if m.posY < m.minY
        m.posY = m.minY
        m.dirY = Abs(m.dirY)  ' Ensure moving down
    end if
    if m.posY > m.maxY
        m.posY = m.maxY
        m.dirY = -Abs(m.dirY)  ' Ensure moving up
    end if

    m.floatingCard.translation = [m.posX, m.posY]
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
