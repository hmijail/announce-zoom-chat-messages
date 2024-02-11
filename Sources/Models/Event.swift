import Foundation

enum Event {
    /// A (possibly failed) attempt to publish a chat message to a destination service
    case publishAttempt(
        chatMessage: ChatMessage,
        httpResponseResult: Result<HTTPURLResponse, any Error>
    )
    case noOp
}
