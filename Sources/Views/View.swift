/// View renderer operations
protocol View {
    func render(_ publishAttemptResult: Result<PublishAttempt, ZoomChatPublisherError>)
}
