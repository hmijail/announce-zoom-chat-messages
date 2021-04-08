currApp = Application.currentApplication()
currApp.includeStandardAdditions = true

SE = Application('System Events')
SE.strictPropertyScope = true
SE.strictCommandScope = true
SE.includeStandardAdditions = true

past_length = undefined
dormant = false

//get_chat_length()

function is_meeting_ongoing() {
 return (SE.applicationProcesses.byName("zoom.us").windows.whose({ name: { _contains: 'Zoom Meeting' } }).length == 1)
}

function get_chat_length(){
	// returns the number of lines in chat (including the name lines!)

    // get content of detached chat window
    zwc = SE.applicationProcesses.byName("zoom.us").windows.whose({ name: { _contains: 'Chat' } })
	if (zwc.length == 1) {
		// there is a chat window
    	zwcs = zwc.splitterGroups.at(0)
    	zwcss = zwcs.scrollAreas.at(0)
		zwcsst = zwcss.tables.at(0)
		zwcsstr = zwcsst.rows
		return zwcsstr.length
    }

    // get content of attached chat window
    zwc2 = SE.applicationProcesses.byName("zoom.us").windows.whose({ name: { _contains: 'Zoom Meeting' } })

    sidepanel = zwc2.splitterGroups[0]
	chat_embedded = sidepanel.splitterGroups[0]
	if (chat_embedded()[0] == null) {
		// the chat panel is not where it should
		return null
	}

	text_rows = chat_embedded.scrollAreas[0].tables[0].rows
	return text_rows.length

}


function idle(){
	if (! is_meeting_ongoing()) {
		if (! dormant) {
			// let's warn and go dormant
			past_length = undefined
			dormant = true
			currApp.beep(1)
        	currApp.displayNotification("Waiting for any new meeting...",
            	{withTitle:"No Zoom meeting detected"})
		}
		return 30
	}
	dormant = false
    try {
        length = get_chat_length()
    } catch (error) {
        SE.displayAlert("Unable to get the chat length", {
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
    if (length == null) {
		currApp.beep(1)
        currApp.displayNotification("Please open it to detect changes",
            {withTitle:"The chat window seems to be closed!"})
        past_length = undefined
        return 5
    } else  {
        if (typeof past_length == 'undefined'){
            currApp.displayNotification("Currently contains " + length + " lines",
                {withTitle:"Tracking chat..."})
        } else if (length != past_length) {
            //content_new = content.slice(past_length)
            //text_new_asciipos = text_new.search(/\w/)
            //text_new_ascii = text_new.slice(text_new_asciipos)
            currApp.beep(3)
            currApp.displayNotification("",
                {withTitle:"New text in chat"})
        }
        past_length = length
    }

    return 1
}


function quit(){
    currApp.displayNotification("",{withTitle:"Chat is no longer tracked"})
    return true
}
