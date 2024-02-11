import Curses
import Foundation

struct CursesView: View {
    private let screen: Screen
    private let mainWindow: Window
    private let consoleWindow: Window
    private let successAttribute: Attribute
    private let failureAttribute: Attribute
    
    init(screen: Screen, successAttribute: Attribute, failureAttribute: Attribute) {
        self.screen = screen
        self.mainWindow = screen.window
        self.consoleWindow = screen.newWindow(
            position: Point(x: 0, y: 1),
            size: Size(width: mainWindow.size.width, height: mainWindow.size.height - 1)
        )
        self.consoleWindow.setScroll(enabled: true)
        self.successAttribute = successAttribute
        self.failureAttribute = failureAttribute
    }
    
    private func writeZoomRunningStatus(ok: Bool) {
        mainWindow.cursor.position = Point(x: 1, y: 0)
        if ok {
            mainWindow.turnOn(successAttribute)
            mainWindow.write("     Zoom Is Running     ")
            mainWindow.turnOff(successAttribute)
        } else {
            mainWindow.turnOn(failureAttribute)
            mainWindow.write("     Zoom Not Running    ")
            mainWindow.turnOff(failureAttribute)
        }
    }
    
    private func writeMeetingOngoingStatus(ok: Bool?) {
        mainWindow.cursor.position = Point(x: 27, y: 0)
        switch ok {
        case .some(true):
            mainWindow.turnOn(successAttribute)
            mainWindow.write("   Meeting In Progress    ")
            mainWindow.turnOff(successAttribute)
        case .some(false):
            mainWindow.turnOn(failureAttribute)
            mainWindow.write("  No Meeting In Progress  ")
            mainWindow.turnOff(failureAttribute)
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
            mainWindow.turnOn(successAttribute)
            mainWindow.write("       Chat Is Open      ")
            mainWindow.turnOff(successAttribute)
        case .some(false):
            mainWindow.turnOn(failureAttribute)
            mainWindow.write("       Chat Not Open     ")
            mainWindow.turnOff(failureAttribute)
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
    
    func render(_ publishAttemptResult: Result<PublishAttempt, ZoomChatPublisherError>) {
        switch publishAttemptResult {
        case .success(let publish):
            writeStatuses(error: nil)
            switch publish.httpResponseResult {
            case .success(let response):
                let statusCode: Int = response.statusCode
                response.url.map { (url: URL) in
                    if statusCode == 204 {
                        consoleWindow.write("POSTed to \(url)\n")
                    } else {
                        consoleWindow.write("Got \(statusCode) POSTing to \(url)\n")
                    }
                }
                
            case .failure(let error):
                switch error {
                case let urlError as URLError:
                    urlError.failingURL.map { (url: URL) in
                        consoleWindow.write(#""\#(urlError.localizedDescription)" POSTing to \#(url)\n"#)
                    }
                default: consoleWindow.write(error.localizedDescription)
                }
            }
            consoleWindow.refresh()
            
        case .failure(let error):
            writeStatuses(error: error)
        }
        mainWindow.refresh()
    }
}
