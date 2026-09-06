sub init()
    m.recList = m.top.findNode("recList")
    m.recCategoryLabel = m.top.findNode("recCategoryLabel")
    m.recRatingLabel = m.top.findNode("recRatingLabel")
    m.recNameLabel = m.top.findNode("recNameLabel")
    m.recDistanceLabel = m.top.findNode("recDistanceLabel")
    m.recDescLabel = m.top.findNode("recDescLabel")
    m.recHostTipLabel = m.top.findNode("recHostTipLabel")

    m.top.observeField("property", "loadRecommendationsData")
    loadRecommendationsData()
end sub

sub loadRecommendationsData()
    if IsSupabaseConfigured()
        propId = ""
        if m.top.property <> invalid and m.top.property.id <> invalid
            propId = m.top.property.id
        end if

        m.task = CreateObject("roSGNode", "SupabaseTask")
        m.task.requestType = "GET_RECOMMENDATIONS"
        m.task.propertyId = propId
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
        m.recRatingLabel.text = place.rating + " • " + place.price
        m.recNameLabel.text = place.name
        m.recDistanceLabel.text = place.distance + " from cabin"
        m.recDescLabel.text = place.description
        m.recHostTipLabel.text = place.hostTip
    end if
end sub
