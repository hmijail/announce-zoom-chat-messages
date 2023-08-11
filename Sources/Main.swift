import ArgumentParser
import Foundation

@main
struct Main: ParsableCommand {
    @Option(name: .shortAndLong, help: "The URL to publish chat messages to.")
    var destinationURL: URLComponents
    
    func run() {
        let publisher: ZoomChatEventPublisher = ZoomChatEventPublisher(
            destinationURL: destinationURL
        )
        publisher.scrapeAndPublishChatMessages()
    }
}
