' *******************************************************************
' ** Cabin Concierge TV - Native Roku BrightScript Entry Point
' *******************************************************************

sub Main(args as Dynamic)
    print "Starting Cabin Concierge Roku Native Channel..."
    
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.SetMessagePort(m.port)
    
    scene = screen.CreateScene("MainScene")
    screen.Show()

    if args <> invalid and args.pin <> invalid
        scene.deepLinkPin = args.pin
    end if
    
    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub
