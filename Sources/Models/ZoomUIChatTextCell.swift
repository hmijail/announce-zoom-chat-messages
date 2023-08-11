/// A single line of text in the Zoom chat window, which may be:
/// - A route indicate the sender and recipient (e.g., "Me to Everyone", "Chad Chatter to Me")
/// - The chat message
struct ZoomUIChatTextCell {
    let isRoute: Bool
    let text: String
}
