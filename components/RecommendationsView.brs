sub init()
    m.recList = m.top.findNode("recList")
    m.recCategoryLabel = m.top.findNode("recCategoryLabel")
    m.recRatingLabel = m.top.findNode("recRatingLabel")
    m.recNameLabel = m.top.findNode("recNameLabel")
    m.recAddressLabel = m.top.findNode("recAddressLabel")
    m.recDescLabel = m.top.findNode("recDescLabel")
    m.recImagePoster = m.top.findNode("recImagePoster")
    m.recMapsQrGroup = m.top.findNode("recMapsQrGroup")
    m.recMapsQrPoster = m.top.findNode("recMapsQrPoster")

    m.top.observeField("property", "loadRecommendationsData")
    loadRecommendationsData()
end sub

sub loadRecommendationsData()
    if IsSupabaseConfigured()
        token = GetSavedDeviceToken()
        if token = ""
            m.places = []
            populateRecList()
            return
        end if

        m.task = CreateObject("roSGNode", "SupabaseTask")
        m.task.requestType = "GET_RECOMMENDATIONS"
        m.task.deviceId = GetDeviceId()
        m.task.deviceToken = token
        m.task.observeField("state", "onRecsTaskStateChanged")
        m.task.control = "RUN"
    else
        m.places = []
        populateRecList()
    end if
end sub

sub onRecsTaskStateChanged()
    if m.task <> invalid and m.task.state = "stop"
        if m.task.responseSuccess and m.task.responseArray <> invalid and m.task.responseArray.Count() > 0
            m.places = []
            for each row in m.task.responseArray
                place = MapSupabaseRecommendation(row)
                if place <> invalid then m.places.Push(place)
            end for
            populateRecList()
        else
            m.places = []
            populateRecList()
        end if
    end if
end sub

sub populateRecList()
    contentNode = CreateObject("roSGNode", "ContentNode")
    for each place in m.places
        item = contentNode.createChild("ContentNode")
        item.title = place.name
    end for
    m.recList.content = contentNode
    m.recList.observeField("itemFocused", "onRecItemFocused")
    updateDetailView(0)
end sub

sub onRecItemFocused()
    updateDetailView(m.recList.itemFocused)
end sub

sub updateDetailView(index as Integer)
    if m.places <> invalid and index >= 0 and index < m.places.Count()
        place = m.places[index]
        m.recCategoryLabel.text = UCase(place.category)
        if place.isSponsored
            m.recRatingLabel.text = "SPONSORED"
        else
            m.recRatingLabel.text = ""
        end if
        m.recNameLabel.text = place.name
        m.recDistanceLabel.text = place.address
        m.recDescLabel.text = place.description
        if m.recImagePoster <> invalid
            if place.imageUrl <> ""
                m.recImagePoster.uri = place.imageUrl
                m.recImagePoster.visible = true
            else
                m.recImagePoster.visible = false
            end if
        end if
        if m.recMapsQrGroup <> invalid and m.recMapsQrPoster <> invalid
            if place.address <> ""
                m.recMapsQrPoster.uri = BuildMapsQrUri(place.address)
                m.recMapsQrGroup.visible = true
            else
                m.recMapsQrGroup.visible = false
            end if
        end if
    end if
end sub
