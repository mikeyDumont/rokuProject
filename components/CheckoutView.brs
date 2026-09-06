sub init()
    m.tasksList = m.top.findNode("tasksList")
    m.checkoutTimeLabel = m.top.findNode("checkoutTimeLabel")
    m.trashScheduleLabel = m.top.findNode("trashScheduleLabel")
    m.hostContactLabel = m.top.findNode("hostContactLabel")
    m.emergencyLabel = m.top.findNode("emergencyLabel")

    m.completedStates = {}
    m.selectedTaskIndex = 0

    m.top.observeField("property", "onPropertyChanged")
    m.tasksList.observeField("itemSelected", "onTaskSelected")
    loadCheckoutTasks()
end sub

sub onPropertyChanged()
    prop = m.top.property
    if prop <> invalid
        if prop.checkOutTime <> invalid then m.checkoutTimeLabel.text = "Check-Out: " + prop.checkOutTime
        if prop.trashDay <> invalid then m.trashScheduleLabel.text = "Trash: " + prop.trashDay
        if prop.hostName <> invalid and prop.hostPhone <> invalid
            m.hostContactLabel.text = prop.hostName + " • " + prop.hostPhone
        end if
        if prop.emergencyContact <> invalid then m.emergencyLabel.text = "Emergency: " + prop.emergencyContact
    end if
    loadCheckoutTasks()
end sub

sub loadCheckoutTasks()
    if IsSupabaseConfigured()
        propId = ""
        if m.top.property <> invalid and m.top.property.id <> invalid
            propId = m.top.property.id
        end if

        m.task = CreateObject("roSGNode", "SupabaseTask")
        m.task.requestType = "GET_CHECKOUT_TASKS"
        m.task.propertyId = propId
        m.task.observeField("state", "onCheckoutTasksStateChanged")
        m.task.control = "RUN"
    else
        m.tasksData = []
        refreshTaskList()
    end if
end sub

sub onCheckoutTasksStateChanged()
    if m.task <> invalid and m.task.state = "stop"
        if m.task.responseSuccess and m.task.responseArray <> invalid and m.task.responseArray.Count() > 0
            m.tasksData = []
            for each row in m.task.responseArray
                t = MapSupabaseCheckoutTask(row)
                if t <> invalid then m.tasksData.Push(t)
            end for
            refreshTaskList()
        else
            m.tasksData = []
            refreshTaskList()
        end if
    end if
end sub

sub refreshTaskList()
    if m.tasksData = invalid return
    contentNode = CreateObject("roSGNode", "ContentNode")
    for i = 0 to m.tasksData.Count() - 1
        task = m.tasksData[i]
        item = contentNode.createChild("ContentNode")
        status = "[ ] "
        if m.completedStates.DoesExist(task.id) and m.completedStates[task.id] = true
            status = "[X] "
        end if
        item.title = status + task.title + " (" + task.time + ")"
    end for
    m.tasksList.content = contentNode
    m.tasksList.jumpToItem = m.selectedTaskIndex
end sub

sub onTaskSelected()
    if m.tasksData = invalid return
    idx = m.tasksList.itemSelected
    if idx >= 0 and idx < m.tasksData.Count()
        m.selectedTaskIndex = idx
        task = m.tasksData[idx]
        if m.completedStates.DoesExist(task.id) and m.completedStates[task.id] = true
            m.completedStates[task.id] = false
        else
            m.completedStates[task.id] = true
        end if
        refreshTaskList()
    end if
end sub
