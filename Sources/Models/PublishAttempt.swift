import Foundation

/// A (possibly failed) attempt to publish a chat message to a destination service
struct PublishAttempt {
    let chatMessage: ChatMessage
    let httpResponseResult: Result<HTTPURLResponse, any Error>
}
