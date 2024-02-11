import Curses
import Foundation

struct CursesView: View {
    private let screen: Screen
    private let mainWindow: Window
    private let consoleWindow: Window
    private let statusOkAttribute: Attribute
    private let statusBadAttribute: Attribute
    private let successAttribute: Attribute
    private let failureAttribute: Attribute
    
    init(
        screen: Screen,
        statusOkAttribute: Attribute, statusBadAttribute: Attribute,
        successAttribute: Attribute, failureAttribute: Attribute
    ) {
        self.screen = screen
        self.mainWindow = screen.window
        self.consoleWindow = screen.newWindow(
            position: Point(x: 0, y: 1),
            size: Size(width: mainWindow.size.width, height: mainWindow.size.height - 1)
        )
        self.consoleWindow.setScroll(enabled: true)
        self.statusOkAttribute = statusOkAttribute
        self.statusBadAttribute = statusBadAttribute
        self.successAttribute = successAttribute
        self.failureAttribute = failureAttribute
    }
    
    private func writeZoomRunningStatus(ok: Bool) {
        mainWindow.cursor.position = Point(x: 1, y: 0)
        if ok {
            mainWindow.turnOn(statusOkAttribute)
            mainWindow.write("     Zoom Is Running     ")
            mainWindow.turnOff(statusOkAttribute)
        } else {
            mainWindow.turnOn(statusBadAttribute)
            mainWindow.write("     Zoom Not Running    ")
            mainWindow.turnOff(statusBadAttribute)
        }
    }
    
    private func writeMeetingOngoingStatus(ok: Bool?) {
        mainWindow.cursor.position = Point(x: 27, y: 0)
        switch ok {
        case .some(true):
            mainWindow.turnOn(statusOkAttribute)
            mainWindow.write("   Meeting In Progress    ")
            mainWindow.turnOff(statusOkAttribute)
        case .some(false):
            mainWindow.turnOn(statusBadAttribute)
            mainWindow.write("  No Meeting In Progress  ")
            mainWindow.turnOff(statusBadAttribute)
        case .none:
            mainWindow.turnOn(.invisible)
            mainWindow.write("                          ")
            mainWindow.turnOff(.invisible)
        }
    }
    
    private func writeChatOpenStatus(ok: Bool?) {
        mainWindow.cursor.position = Point(x: 54, y: 0)
        switch ok {
        case .some(true):
            mainWindow.turnOn(statusOkAttribute)
            mainWindow.write("       Chat Is Open      ")
            mainWindow.turnOff(statusOkAttribute)
        case .some(false):
            mainWindow.turnOn(statusBadAttribute)
            mainWindow.write("       Chat Not Open     ")
            mainWindow.turnOff(statusBadAttribute)
        case .none:
            mainWindow.turnOn(.invisible)
            mainWindow.write("                         ")
            mainWindow.turnOff(.invisible)
        }
    }
    
    private func writeStatuses(error: ZoomChatPublisherError?) {
        switch error {
        case .none:
            writeZoomRunningStatus(ok: true)
            writeMeetingOngoingStatus(ok: true)
            writeChatOpenStatus(ok: true)
            
        case .some(.chatNotOpen):
            writeZoomRunningStatus(ok: true)
            writeMeetingOngoingStatus(ok: true)
            writeChatOpenStatus(ok: false)
            
        case .some(.noMeetingInProgress):
            writeZoomRunningStatus(ok: true)
            writeMeetingOngoingStatus(ok: false)
            writeChatOpenStatus(ok: nil)
            
        case .some(.zoomNotRunning):
            writeZoomRunningStatus(ok: false)
            writeMeetingOngoingStatus(ok: nil)
            writeChatOpenStatus(ok: nil)
        }
    }
    
    func render(_ publishAttemptResult: Result<Event, ZoomChatPublisherError>) {
        switch publishAttemptResult {
        case .success(.publishAttempt(let chatMessage, let httpResponseResult)):
            writeStatuses(error: nil)
            
            let errorLength: Int
            consoleWindow.write("[")
            switch httpResponseResult {
            case .success(let response):
                let statusCode: Int = response.statusCode
                let statusAttribute: Attribute = statusCode == 204 ? successAttribute : failureAttribute
                consoleWindow.turnOn(statusAttribute)
                consoleWindow.write("\(statusCode)")
                consoleWindow.turnOff(statusAttribute)
                errorLength = 3
                
            case .failure(let error):
                consoleWindow.turnOn(failureAttribute)
                consoleWindow.write("\(error.localizedDescription)")
                consoleWindow.turnOff(failureAttribute)
                errorLength = error.localizedDescription.count
            }
            let maxTextLength: Int = consoleWindow.size.width - errorLength - 4 // 4 = [, ], space, and a space at the end
            let logOutputUntruncated: String = chatMessage.description
            let logOutput: String
            if logOutputUntruncated.count <= maxTextLength {
                logOutput = logOutputUntruncated
            } else {
                logOutput = logOutputUntruncated.prefix(maxTextLength - 1) + "…"
            }
            consoleWindow.write("] \(logOutput)\n")
            consoleWindow.refresh()
            
        case .success(.noOp):
            writeStatuses(error: nil)
            
        case .failure(let error):
            writeStatuses(error: error)
        }
        mainWindow.refresh()
    }
}
