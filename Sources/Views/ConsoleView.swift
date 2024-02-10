import Foundation

/// View that simply logs events to the console.
struct ConsoleView: View {
    func render(_ publishAttemptResult: Result<PublishAttempt, ZoomChatPublisherError>) {
        switch publishAttemptResult {
        case .success(let publish):
            switch publish.httpResponseResult {
            case .success(let response):
                let statusCode: Int = response.statusCode
                response.url.map { (url: URL) in
                    if statusCode == 204 {
                        print("POSTed to \(url)")
                    } else {
                        print("Got \(statusCode) POSTing to \(url)")
                    }
                }
                
            case .failure(let error):
                switch error {
                case let urlError as URLError:
                    urlError.failingURL.map { (url: URL) in
                        print(#""\#(urlError.localizedDescription)" POSTing to \#(url)"#)
                    }
                default: print("\(error)")
                }
            }
            
        case .failure(let error):
            switch error {
            case .zoomNotRunning:
                print("Zoom not running")
            case .noMeetingInProgress:
                print("No meeting in progress")
            case .chatNotOpen:
                print("Chat not open")
            }
        }
    }
}
