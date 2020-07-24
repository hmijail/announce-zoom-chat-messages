currApp = Application.currentApplication()
currApp.includeStandardAdditions = true

SE = Application('System Events')
SE.strictPropertyScope = true
SE.strictCommandScope = true
SE.includeStandardAdditions = true

past_length = undefined

function idle(){
    try {
        text = get_chat_text()
    } catch (error) {
        SE.displayAlert("Unable to get the chat text", {
            message: "Please check that the script is allowed in System Preferences " +
                "- Security & Privacy - Privacy - Accessibility.\n\nYou might need to " +
                "UNCHECK its checkbox and RE-CHECK it again.",
            as: "critical",
            buttons: ["Show me where"],
            defaultButton: "Show me where"
            }
        )
        SP = Application("System Preferences")
        SP.panes.byId("com.apple.preference.security").anchors.byName("Privacy_Accessibility").reveal()
        SP.activate()
        ObjC.import('stdlib')
        $.exit(1)
    }
    if (!! text) {
        l=text.length
        if (typeof past_length == 'undefined'){
            currApp.displayNotification("Currently contains " + l + " chars",
                {withTitle:"Tracking chat..."})
        } else if (l != past_length) {
            text_new = text.slice(past_length)
            text_new_asciipos = text_new.search(/\w/)
            text_new_ascii = text_new.slice(text_new_asciipos)
            currApp.beep(3)
            currApp.displayNotification(text_new_ascii,
                {withTitle:"New text in chat"})
        }
        past_length = l

    } else  {
        currApp.beep(1)
        currApp.displayNotification("Please open it to detect changes",
            {withTitle:"The chat window seems to be closed!"})
        past_length = undefined
        return 5
    }

    return 1
}

function quit(){
    currApp.displayNotification("",{withTitle:"Chat is no longer tracked"})
    return true
}

function get_chat_text(){
    // get text from the detached chat window
    zwc = SE.applicationProcesses.byName("zoom.us").windows.whose({ name: { _contains: 'chat' } })
    zwcs = zwc.splitterGroups.at(0)
    zwcss0 = zwcs.scrollAreas.at(0)
    zwcss0t = zwcss0.textAreas.at(0)
    text = zwcss0t.value()[0]

    if (!!text) {
        return text
    }

    // get text from the attached chat window
    zwc2 = SE.applicationProcesses.byName("zoom.us").windows.whose({ name: { _contains: 'Zoom Meeting' } })
    zwc2s = zwc2.splitterGroups.at(0)
    zwc2ss = zwc2s.splitterGroups.at(0)
    zwc2sss = zwc2ss.scrollAreas.at(0)
    zwc2ssst = zwc2sss.textAreas.at(0)
    text = zwc2ssst.value()[0]

    return text
}
