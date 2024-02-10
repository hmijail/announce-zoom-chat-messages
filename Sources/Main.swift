import ArgumentParser
import Foundation
import Logging
import LoggingFormatAndPipe
import RxSwift

@main
struct Main: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zoom-chat-publisher",
        abstract: "Scrapes Zoom chat messages and publishes them to an HTTP endpoint."
    )
    
    @Option(name: .shortAndLong, help: "The URL to publish chat messages to.")
    var destinationURL: URLComponents
    
    @Flag(name: .shortAndLong, help: "More verbose logging.")
    var verbose: Bool = false
    
    func run() {
        LoggingSystem.bootstrap { _ in
            var handler: Handler = LoggingFormatAndPipe.Handler(
                formatter: BasicFormatter.apple,
                pipe: LoggerTextOutputStreamPipe.standardOutput
            )
            handler.logLevel = verbose ? .debug : .info
            
            return handler
        }
        let log: Logging.Logger = Logging.Logger(label: "main")
        let disposeBag: DisposeBag = DisposeBag()
        URLSession.rx.shouldLogRequest = { _ in false }
        
        let publisher: ZoomChatPublisher = ZoomChatPublisher(
            destinationURL: destinationURL
        )
        publisher
            .scrapeAndPublishChatMessages()
            .subscribe(
                onNext: { (publishResult: Result<PublishAttempt, ZoomChatPublisherError>) in
                    switch publishResult {
                    case .success(let publish):
                        switch publish.httpResponseResult {
                        case .success(let response):
                            let statusCode: Int = response.statusCode
                            response.url.map { (url: URL) in
                                if statusCode == 204 {
                                    log.info("POSTed to \(url)")
                                } else {
                                    log.warning("Got \(statusCode) POSTing to \(url)")
                                }
                            }
                            
                        case .failure(let error):
                            switch error {
                            case let urlError as URLError:
                                urlError.failingURL.map { (url: URL) in
                                    log.warning(#""\#(urlError.localizedDescription)" POSTing to \#(url)"#)
                                }
                            default: log.warning("\(error)")
                            }
                        }
                        
                    case .failure(let error):
                        switch error {
                        case .zoomNotRunning:
                            log.info("Zoom not running")
                        case .noMeetingInProgress:
                            log.info("No meeting in progress")
                        case .chatNotOpen:
                            log.info("Chat not open")
                        }
                    }
                }
            )
            .disposed(by: disposeBag)
        
        RunLoop.current.run()
    }
}
