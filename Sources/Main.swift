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
