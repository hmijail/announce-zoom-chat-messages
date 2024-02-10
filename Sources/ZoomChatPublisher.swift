import AppKit
import RxCocoa
import RxSwift
import os

struct ZoomChatPublisher {
    private let scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .default)
    private let urlSession: URLSession = URLSession.shared
    let destinationURL: URLComponents
    
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
        let chatTable: AXUIElement? = windowChatTable(app: app) ?? embeddedChatTable(app: app)
        
        return chatTable
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
    
    private func chatRows(app: AXUIElement) -> Observable<AXUIElement?> {
        Observable<Int>
            .timer(.seconds(0), period: .seconds(1), scheduler: scheduler)
            .take(while: { _ in
                // meeting is ongoing
                anyMeetingWindow(app: app) != nil
            })
            .flatMap { _ in chatTable(app: app) }
            .scan((0, [])) { (accum: (Int, [AXUIElement?]), table: AXUIElement?) in
                let (processedCount, _): (Int, _) = accum
                guard let table: AXUIElement = table else {
                    return (processedCount, [nil])
                }
                
                let newRows: [AXUIElement?] = table.uiElements
                    .dropFirst(processedCount)
                    .map { .some($0) }
                
                return (processedCount + newRows.count, newRows)
            }
            .concatMap { Observable.from($0.1) }
    }
    
    private func zoomUIChatTextFromRow(row: AXUIElement) -> [ZoomUIChatTextCell] {
        enum ChatRawElement {
            case text(value: String)
            case isMetadata
        }
        
        // Run with -v/--verbose flag to see what each row looks like
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
                    return (false, [ZoomUIChatTextCell(isRoute: isRoute, text: value)] + chatTexts)
                case .isMetadata:
                    return (true, chatTexts)
                }
            }
            .1 ?? []
    }
    
    func scrapeAndPublishChatMessages() -> Observable<Result<PublishAttempt, ZoomChatPublisherError>> {
        Observable<Int>
            .timer(.seconds(0), period: .seconds(5), scheduler: scheduler)
            .map { _ -> Result<AXUIElement, ZoomChatPublisherError> in
                guard let app = zoomApplication() else {
                    return .failure(.zoomNotRunning)
                }
                guard let _ = anyMeetingWindow(app: app) else {
                    return .failure(.noMeetingInProgress)
                }
                
                return .success(app)
            }
            .flatMapFirst {
                switch $0 {
                case .success(let app):
                    return chatRows(app: app)
                        .map { row -> Result<AXUIElement, ZoomChatPublisherError> in
                            guard let row = row else {
                                return .failure(.chatNotOpen)
                            }
                            
                            os_log("Chat rows layout:\n%s", row.layoutDescription)
                            return .success(row)
                        }
                        .flatMap {
                            switch $0 {
                            case .success(let row):
                                return Observable.from(zoomUIChatTextFromRow(row: row))
                                    .scan(
                                        ("Unknown to Unknown", nil)
                                    ) { (accum: (String, ChatMessage?), nextCell: ZoomUIChatTextCell) in
                                        let (route, _): (String, _) = accum
                                        
                                        if nextCell.isRoute {
                                            return (nextCell.text, nil)
                                        } else {
                                            return (route, ChatMessage(route: route, text: nextCell.text))
                                        }
                                    }
                                    .compactMap { $0.1 }
                                    .concatMap { (chatMessage: ChatMessage) -> Observable<Result<PublishAttempt, ZoomChatPublisherError>> in
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
                                                .success(PublishAttempt(chatMessage: chatMessage, httpResponseResult: $0))
                                            }
                                    }
                                
                            case .failure(let err):
                                return Observable.just(.failure(err))
                            }
                        }
                    
                case .failure(let error):
                    return Observable.just(.failure(error))
                }
            }
    }
}
