import ArgumentParser
import Foundation
import Logging
import LoggingFormatAndPipe

@main
struct Main: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zoom-chat-event-publisher",
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
        let publisher: ZoomChatEventPublisher = ZoomChatEventPublisher(
            destinationURL: destinationURL
        )
        publisher.scrapeAndPublishChatMessages()
        
        RunLoop.current.run()
    }
}
