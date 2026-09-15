sub init()
    m.discountSection = m.top.findNode("discountSection")
    m.discountPageTitleLabel = m.top.findNode("discountPageTitleLabel")
    m.discountPageSubtitleLabel = m.top.findNode("discountPageSubtitleLabel")
    m.discountTitleLabel = m.top.findNode("discountTitleLabel")
    m.discountCodeLabelLabel = m.top.findNode("discountCodeLabelLabel")
    m.discountCodeLabel = m.top.findNode("discountCodeLabel")
    m.discountDescLabel = m.top.findNode("discountDescLabel")
    m.discountBannerLabel = m.top.findNode("discountBannerLabel")
    m.discountWebsiteLabelLabel = m.top.findNode("discountWebsiteLabelLabel")
    m.discountWebsiteUrlLabel = m.top.findNode("discountWebsiteUrlLabel")
    m.discountFooterLabel = m.top.findNode("discountFooterLabel")

    ' Content is supplied by MainScene once the active discount lookup completes
    m.top.observeField("discount", "onDiscountFieldChanged")
    applyDiscount(m.top.discount)
end sub

sub onDiscountFieldChanged()
    applyDiscount(m.top.discount)
end sub

sub applyDiscount(discount as Object)
    if discount = invalid
        m.discountSection.visible = false
        return
    end if

    if discount.pageTitle <> invalid and discount.pageTitle <> "" then m.discountPageTitleLabel.text = discount.pageTitle
    if discount.pageSubtitle <> invalid and discount.pageSubtitle <> "" then m.discountPageSubtitleLabel.text = discount.pageSubtitle
    if discount.title <> invalid and discount.title <> "" then m.discountTitleLabel.text = discount.title
    if discount.codeLabel <> invalid and discount.codeLabel <> "" then m.discountCodeLabelLabel.text = discount.codeLabel
    if discount.code <> invalid and discount.code <> "" then m.discountCodeLabel.text = discount.code
    if discount.description <> invalid and discount.description <> "" then m.discountDescLabel.text = discount.description
    if discount.bannerText <> invalid and discount.bannerText <> "" then m.discountBannerLabel.text = discount.bannerText
    if discount.websiteLabel <> invalid and discount.websiteLabel <> "" then m.discountWebsiteLabelLabel.text = discount.websiteLabel
    if discount.websiteUrl <> invalid and discount.websiteUrl <> "" then m.discountWebsiteUrlLabel.text = discount.websiteUrl
    if discount.footerText <> invalid and discount.footerText <> "" then m.discountFooterLabel.text = discount.footerText

    m.discountSection.visible = true
end sub
