import Foundation
import Logging

/// View that simply logs events to the console.
struct LoggingView: View {
    static let log: Logging.Logger = Logging.Logger(label: "main")
    
    func render(_ publishAttemptResult: Result<PublishAttempt, ZoomChatPublisherError>) {
        switch publishAttemptResult {
        case .success(let publish):
            switch publish.httpResponseResult {
            case .success(let response):
                let statusCode: Int = response.statusCode
                response.url.map { (url: URL) in
                    if statusCode == 204 {
                        Self.log.info("POSTed to \(url)")
                    } else {
                        Self.log.warning("Got \(statusCode) POSTing to \(url)")
                    }
                }
                
            case .failure(let error):
                switch error {
                case let urlError as URLError:
                    urlError.failingURL.map { (url: URL) in
                        print(#""\#(urlError.localizedDescription)" POSTing to \#(url)"#)
                    }
                default: Self.log.warning("\(error)")
                }
            }
            
        case .failure(let error):
            switch error {
            case .zoomNotRunning:
                Self.log.info("Zoom not running")
            case .noMeetingInProgress:
                Self.log.info("No meeting in progress")
            case .chatNotOpen:
                Self.log.info("Chat not open")
            }
        }
    }
}
