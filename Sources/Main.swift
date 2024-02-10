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
        let disposeBag: DisposeBag = DisposeBag()
        URLSession.rx.shouldLogRequest = { _ in false }
        
        let publisher: ZoomChatPublisher = ZoomChatPublisher(
            destinationURL: destinationURL
        )
        let view: some View = LoggingView()
        publisher
            .scrapeAndPublishChatMessages()
            .subscribe(onNext: view.render)
            .disposed(by: disposeBag)
        
        RunLoop.current.run()
    }
}
