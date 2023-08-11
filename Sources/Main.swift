import ArgumentParser
import Foundation
import Logging
import LoggingFormatAndPipe

@main
struct Main: ParsableCommand {
    @Option(name: .shortAndLong, help: "The URL to publish chat messages to.")
    var destinationURL: URLComponents
    
    func run() {
        LoggingSystem.bootstrap { _ in
            LoggingFormatAndPipe.Handler(
                formatter: BasicFormatter.apple,
                pipe: LoggerTextOutputStreamPipe.standardOutput
            )
        }
        let publisher: ZoomChatEventPublisher = ZoomChatEventPublisher(
            destinationURL: destinationURL
        )
        publisher.scrapeAndPublishChatMessages()
    }
}
