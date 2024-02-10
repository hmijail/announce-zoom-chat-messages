/// Application error
enum ZoomChatPublisherError: Error {
    case zoomNotRunning
    case noMeetingInProgress
    case chatNotVisible
}
