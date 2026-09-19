sub init()
    m.discountSection = m.top.findNode("discountSection")
    m.pageTitleLabel = m.top.findNode("pageTitleLabel")
    m.pageSubtitleLabel = m.top.findNode("pageSubtitleLabel")
    m.discountTitleLabel = m.top.findNode("discountTitleLabel")
    m.discountCodeLabel = m.top.findNode("discountCodeLabel")
    m.discountDescLabel = m.top.findNode("discountDescLabel")
    m.discountBannerLabel = m.top.findNode("discountBannerLabel")
    m.codeLabelText = m.top.findNode("codeLabelText")
    m.websiteLabelText = m.top.findNode("websiteLabelText")
    m.websiteUrlLabel = m.top.findNode("websiteUrlLabel")
    m.footerTextLabel = m.top.findNode("footerTextLabel")

    m.top.observeField("discountData", "onDiscountDataChanged")
    applyDiscount(m.top.discountData)
end sub

sub onDiscountDataChanged()
    applyDiscount(m.top.discountData)
end sub

sub applyDiscount(discount as Object)
    if discount = invalid
        m.discountSection.visible = false
        return
    end if

    if discount.pageTitle <> invalid and discount.pageTitle <> "" then m.pageTitleLabel.text = discount.pageTitle
    if discount.pageSubtitle <> invalid and discount.pageSubtitle <> "" then m.pageSubtitleLabel.text = discount.pageSubtitle
    if discount.title <> invalid and discount.title <> "" then m.discountTitleLabel.text = discount.title
    if discount.code <> invalid and discount.code <> "" then m.discountCodeLabel.text = discount.code
    if discount.description <> invalid and discount.description <> "" then m.discountDescLabel.text = discount.description
    if discount.bannerText <> invalid and discount.bannerText <> "" then m.discountBannerLabel.text = discount.bannerText
    if discount.codeLabel <> invalid and discount.codeLabel <> "" then m.codeLabelText.text = discount.codeLabel
    if discount.websiteLabel <> invalid and discount.websiteLabel <> "" then m.websiteLabelText.text = discount.websiteLabel
    if discount.websiteUrl <> invalid then m.websiteUrlLabel.text = discount.websiteUrl
    if discount.footerText <> invalid then m.footerTextLabel.text = discount.footerText

    m.discountSection.visible = true
end sub
