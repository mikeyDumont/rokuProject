sub init()
    m.rulesList = m.top.findNode("rulesList")
    m.detailCategoryLabel = m.top.findNode("detailCategoryLabel")
    m.detailTitleLabel = m.top.findNode("detailTitleLabel")
    m.detailSummaryLabel = m.top.findNode("detailSummaryLabel")
    m.detailBodyLabel = m.top.findNode("detailBodyLabel")
    m.detailFineLabel = m.top.findNode("detailFineLabel")

    m.top.observeField("property", "loadRulesData")
    loadRulesData()
end sub

sub loadRulesData()
    if IsSupabaseConfigured()
        propId = ""
        if m.top.property <> invalid and m.top.property.id <> invalid
            propId = m.top.property.id
        end if

        m.task = CreateObject("roSGNode", "SupabaseTask")
        m.task.requestType = "GET_HOUSE_RULES"
        m.task.propertyId = propId
        m.task.observeField("state", "onRulesTaskStateChanged")
        m.task.control = "RUN"
    else
        m.rulesData = []
        populateRulesList()
    end if
end sub

sub onRulesTaskStateChanged()
    if m.task <> invalid and m.task.state = "stop"
        if m.task.responseSuccess and m.task.responseArray <> invalid and m.task.responseArray.Count() > 0
            m.rulesData = []
            for each row in m.task.responseArray
                rule = MapSupabaseHouseRule(row)
                if rule <> invalid then m.rulesData.Push(rule)
            end for
            populateRulesList()
        else
            m.rulesData = []
            populateRulesList()
        end if
    end if
end sub

sub populateRulesList()
    contentNode = CreateObject("roSGNode", "ContentNode")
    for each rule in m.rulesData
        item = contentNode.createChild("ContentNode")
        item.title = rule.title
    end for
    m.rulesList.content = contentNode
    m.rulesList.observeField("itemFocused", "onRuleItemFocused")
    updateDetailView(0)
end sub

sub onRuleItemFocused()
    updateDetailView(m.rulesList.itemFocused)
end sub

sub updateDetailView(index as Integer)
    if m.rulesData <> invalid and index >= 0 and index < m.rulesData.Count()
        rule = m.rulesData[index]
        m.detailCategoryLabel.text = UCase(rule.category)
        m.detailTitleLabel.text = rule.title
        m.detailSummaryLabel.text = rule.summary
        m.detailBodyLabel.text = rule.details
        m.detailFineLabel.text = "Important Policy: " + rule.fine
    end if
end sub
