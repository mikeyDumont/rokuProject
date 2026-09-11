sub init()
    m.discountSection = m.top.findNode("discountSection")
    m.discountTitleLabel = m.top.findNode("discountTitleLabel")
    m.discountCodeLabel = m.top.findNode("discountCodeLabel")
    m.discountDescLabel = m.top.findNode("discountDescLabel")
    m.discountBannerLabel = m.top.findNode("discountBannerLabel")

    m.top.observeField("property", "loadDiscountData")
    loadDiscountData()
end sub

sub loadDiscountData()
    if IsSupabaseConfigured()
        propId = ""
        if m.top.property <> invalid and m.top.property.id <> invalid
            propId = m.top.property.id
        end if

        m.discountTask = CreateObject("roSGNode", "SupabaseTask")
        m.discountTask.requestType = "GET_ACTIVE_DISCOUNT"
        m.discountTask.propertyId = propId
        m.discountTask.observeField("state", "onDiscountTaskStateChanged")
        m.discountTask.control = "RUN"
    else
        applyDiscount(invalid)
    end if
end sub

sub onDiscountTaskStateChanged()
    if m.discountTask <> invalid and m.discountTask.state = "stop"
        discount = invalid
        if m.discountTask.responseSuccess and m.discountTask.responseArray <> invalid and m.discountTask.responseArray.Count() > 0
            discount = MapSupabaseDiscount(m.discountTask.responseArray[0])
        end if
        applyDiscount(discount)
    end if
end sub

sub applyDiscount(discount as Object)
    if discount = invalid
        m.discountSection.visible = false
        return
    end if

    if discount.title <> invalid and discount.title <> "" then m.discountTitleLabel.text = discount.title
    if discount.code <> invalid and discount.code <> "" then m.discountCodeLabel.text = discount.code
    if discount.description <> invalid and discount.description <> "" then m.discountDescLabel.text = discount.description
    if discount.bannerText <> invalid and discount.bannerText <> "" then m.discountBannerLabel.text = discount.bannerText

    m.discountSection.visible = true
end sub
