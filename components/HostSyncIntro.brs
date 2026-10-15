sub init()
    m.introRoot = m.top.findNode("introRoot")
    m.revealAnimation = m.top.findNode("revealAnimation")
    m.fadeOutAnimation = m.top.findNode("fadeOutAnimation")
    m.revealAnimation.observeField("state", "onRevealStateChanged")
    m.fadeOutAnimation.observeField("state", "onFadeOutStateChanged")
    m.revealAnimation.control = "start"
end sub

sub onRevealStateChanged()
    if m.revealAnimation.state = "stopped"
        m.top.revealComplete = true
    end if
end sub

sub onDismissChanged()
    if not m.top.dismiss then return
    ' Jump to the finished lockup if dismissed early, so the fade never shows a half-drawn name.
    if m.revealAnimation.state <> "stopped"
        m.revealAnimation.control = "finish"
    end if
    m.fadeOutAnimation.control = "start"
end sub

sub onFadeOutStateChanged()
    if m.fadeOutAnimation.state = "stopped"
        m.top.visible = false
    end if
end sub
