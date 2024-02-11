import AppKit
import RxCocoa
import RxSwift
import os

struct ZoomChatPublisher {
    private let scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .default)
    private let urlSession: URLSession = URLSession.shared
    let destinationURL: URLComponents
    
    /// A single line of text in the Zoom chat window, which may be:
    /// - A route indicate the sender and recipient (e.g., "Me to Everyone", "Chatty Chad to Me")
    /// - The chat text
    private enum ZoomUIChatTextCell {
        case route(String)
        case text(String)
    }
    
    private func zoomApplication() -> AXUIElement? {
        (
            NSRunningApplication
                .runningApplications(withBundleIdentifier: "us.zoom.xos")
                .first?
                .processIdentifier
        ).map(AXUIElementCreateApplication)
    }
    
    private func meetingWindow(app: AXUIElement) -> AXUIElement? {
        app.windows.first { $0.title == "Zoom Meeting" }
    }
    
    private func chatWindow(app: AXUIElement) -> AXUIElement? {
        // Used to look for "Meeting Chat",
        // but Zoom started using the meeting name as the title in some cases
        app.windows.first { $0.title != "Zoom Meeting" }
    }
    
    private func anyMeetingWindow(app: AXUIElement) -> AXUIElement? {
        meetingWindow(app: app) ?? app.windows.first {
            $0.title?.starts(with: "zoom share") ?? false
        }
    }
    
    private func windowChatTable(app: AXUIElement) -> AXUIElement? {
        chatWindow(app: app)?
            .uiElements.first { $0.role == kAXSplitGroupRole }?
            .uiElements.first { $0.role == kAXScrollAreaRole }?
            .uiElements.first { $0.role == kAXTableRole }
    }
    
    private func embeddedChatTable(app: AXUIElement) -> AXUIElement? {
        meetingWindow(app: app)?
            .uiElements.first { $0.role == kAXSplitGroupRole }?
            .uiElements.first { $0.role == kAXScrollAreaRole }?
            .uiElements.first { $0.role == kAXTableRole }
    }
    
    // Due to how Zoom draws chats, this could be a chat table be in a mid-update state
    private func chatTableSnapshot(app: AXUIElement) -> AXUIElement? {
        windowChatTable(app: app) ?? embeddedChatTable(app: app)
    }
    
    // Returns the first two identical chatTableSnapshots
    private func chatTable(app: AXUIElement) -> Observable<AXUIElement?> {
        Observable<Int>
            .timer(.seconds(0), period: .milliseconds(2), scheduler: scheduler)
            .map { _ in chatTableSnapshot(app: app) }
            .scan(
                ("", "", nil)
            ) { (accum: (String, String, AXUIElement?), nextTable: AXUIElement?) in
                let (_, prevDescr, _): (String, String, AXUIElement?) = accum
                
                return (prevDescr, nextTable?.layoutDescription ?? "", nextTable)
            }
            .skip(1)
            .filter { (prevDescr: String, descr: String, table: AXUIElement?) in
                prevDescr == descr || table == nil
            }
            .map { (_, _, table: AXUIElement?) in table }
            .take(1)
    }
    
    private func chatTables(app: AXUIElement) -> Observable<AXUIElement?> {
        Observable<Int>
            .timer(.seconds(0), period: .seconds(1), scheduler: scheduler)
            .take(while: { _ in
                // meeting is ongoing
                anyMeetingWindow(app: app) != nil
            })
            .concatMap { _ in chatTable(app: app) }
    }
    
    private func chatRows(chatTables: Observable<AXUIElement?>) -> Observable<AXUIElement> {
        chatTables
            .scan((0, [])) { (accum: (Int, ArraySlice<AXUIElement>), table: AXUIElement?) in
                let (processedCount, _): (Int, _) = accum
                guard let table: AXUIElement = table else {
                    return (processedCount, [])
                }
                
                let newRows: ArraySlice<AXUIElement> = table.uiElements
                    .dropFirst(processedCount)
                
                return (processedCount + newRows.count, newRows)
            }
            .concatMap { Observable.from($0.1) }
    }
    
    private func zoomUIChatTextFromRow(row: AXUIElement) -> [ZoomUIChatTextCell] {
        enum ChatRawElement {
            case text(value: String)
            case isMetadata
        }
        
        // Look in macOS system log to see what each row looks like
        // Note also that this may change with new versions of Zoom
        return row.uiElements.first?.uiElements
            .compactMap {
                switch $0.role {
                case kAXUnknownRole: return $0.value.map { .text(value: $0) }
                case kAXStaticTextRole: return .isMetadata // Chat time - indicates previous element is metadata
                default: return nil
                }
            }
            .reversed()
            .reduce(
                (false, [])
            ) { (accum: (Bool, [ZoomUIChatTextCell]), nextElem: ChatRawElement) in
                let (isRoute, chatTexts): (Bool, [ZoomUIChatTextCell]) = accum
                
                switch nextElem {
                case let .text(value):
                    return (false, [ isRoute ? .route(value) : .text(value) ] + chatTexts)
                case .isMetadata:
                    return (true, chatTexts)
                }
            }
            .1 ?? []
    }
    
    func scrapeAndPublishChatMessages() -> Observable<Result<Event, ZoomChatPublisherError>> {
        Observable<Int>
            .timer(.seconds(0), period: .seconds(2), scheduler: scheduler)
            .map { _ -> Result<AXUIElement, ZoomChatPublisherError> in
                guard let app = zoomApplication() else {
                    return .failure(.zoomNotRunning)
                }
                guard let _ = anyMeetingWindow(app: app) else {
                    return .failure(.noMeetingInProgress)
                }
                
                return .success(app)
            }
            .flatMapFirst { (appResult: Result<AXUIElement, ZoomChatPublisherError>) in
                switch appResult {
                case .success(let app):
                    let chatTables: Observable<AXUIElement?> = chatTables(app: app).share()
                    let metadata: Observable<Result<Event, ZoomChatPublisherError>> = chatTables
                        .map {
                            $0 != nil ? .success(.noOp) : .failure(.chatNotOpen)
                        }
                    let publishAttempts: Observable<Result<Event, ZoomChatPublisherError>> = chatRows(chatTables: chatTables)
                        .map { row -> Result<AXUIElement, ZoomChatPublisherError> in
                            os_log("Chat rows layout:\n%{public}s", row.layoutDescription)
                            return .success(row)
                        }
                        .concatMap {
                            (
                                rowResult: Result<AXUIElement, ZoomChatPublisherError>
                            ) -> Observable<Result<ZoomUIChatTextCell, ZoomChatPublisherError>>
                            in
                            
                            switch rowResult {
                            case .success(let row):
                                return Observable
                                    .from(zoomUIChatTextFromRow(row: row))
                                    .map { .success($0) }
                                
                            case .failure(let error):
                                return Observable.just(.failure(error))
                            }
                        }
                        .scan(
                            ("Unknown to Unknown", nil)
                        ) { (
                            accum: (String, Result<ChatMessage, ZoomChatPublisherError>?),
                            nextCellResult: Result<ZoomUIChatTextCell, ZoomChatPublisherError>
                        ) in
                            let (route, _): (String, _) = accum
                            switch nextCellResult {
                            case .success(let nextCell):
                                switch nextCell {
                                case .route(let nextRoute):
                                    return (nextRoute, nil)
                                case .text(let text):
                                    return (route, .success(ChatMessage(route: route, text: text)))
                                }
                                
                            case .failure(let error):
                                return (route, .failure(error))
                            }
                        }
                        .compactMap { $0.1 }
                        .concatMap { (
                            chatMessageResult: Result<ChatMessage, ZoomChatPublisherError>
                        ) -> Observable<Result<Event, ZoomChatPublisherError>> in
                            switch chatMessageResult {
                            case .success(let chatMessage):
                                var urlComps: URLComponents = destinationURL
                                urlComps.queryItems = [
                                    URLQueryItem(name: "route", value: chatMessage.route),
                                    URLQueryItem(name: "text", value: chatMessage.text)
                                ]
                                guard let url = urlComps.url else {
                                    return Observable.never()
                                }
                                var urlRequest: URLRequest = URLRequest(url: url)
                                urlRequest.httpMethod = "POST"
                                
                                return urlSession.rx.response(request: urlRequest)
                                    .map { .success($0.response) }
                                    .retry { (errors: Observable<Error>) in
                                        // Retry with delay, inspired by:
                                        // https://github.com/ReactiveX/RxSwift/issues/689#issuecomment-595117647
                                        let maxAttempts: Int = 3
                                        let delay: DispatchTimeInterval = .seconds(2)
                                        
                                        return errors.enumerated()
                                            .flatMap { (index: Int, error: Error) -> Observable<Int> in
                                                index <= maxAttempts
                                                ? Observable<Int>.timer(delay, scheduler: scheduler)
                                                : Observable.error(error)
                                            }
                                    }
                                    .catch { Observable.just(.failure($0)) }
                                    .map {
                                        .success(.publishAttempt(chatMessage: chatMessage, httpResponseResult: $0))
                                    }
                                
                            case .failure(let error):
                                return Observable.just(.failure(error))
                            }
                        }
                    return Observable.of(metadata, publishAttempts).merge()
                    
                case .failure(let error):
                    return Observable.just(.failure(error))
                }
            }
            .do(
                onCompleted: { os_log("Terminated (should not happen)", type: .fault) }
            )
    }
}
