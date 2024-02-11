/// A single chat message
struct ChatMessage: CustomStringConvertible {
    let route: String
    let text: String
    
    var description: String {
        return "\(route): \(text)"
    }
}
