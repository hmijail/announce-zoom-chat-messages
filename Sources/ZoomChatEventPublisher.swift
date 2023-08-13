import AppKit
import Logging
import RxCocoa
import RxSwift

struct ZoomChatEventPublisher {
    private let log: Logger = Logger(label: "main")
    private let scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .default)
    private let urlSession: URLSession = URLSession.shared
    let destinationURL: URLComponents
    
    func logIfNil<T>(_ item: T?, message: String) -> T? {
        if item == nil { log.info("\(message)") }
        return item
    }
    
    func zoomApplication() -> AXUIElement? {
        (
            NSRunningApplication
                .runningApplications(withBundleIdentifier: "us.zoom.xos")
                .first?
                .processIdentifier
        ).map(AXUIElementCreateApplication)
    }
    
    func meetingWindow(app: AXUIElement) -> AXUIElement? {
        app.windows.first { $0.title == "Zoom Meeting" }
    }
    
    func chatWindow(app: AXUIElement) -> AXUIElement? {
        app.windows.first { $0.title == "Meeting Chat" }
    }
    
    func anyMeetingWindow(app: AXUIElement) -> AXUIElement? {
        chatWindow(app: app) ?? meetingWindow(app: app) ??
        app.windows.first { $0.title?.starts(with: "zoom share") ?? false }
    }
    
    func windowChatTable(app: AXUIElement) -> AXUIElement? {
        chatWindow(app: app)?
            .uiElements.first { $0.role == kAXSplitGroupRole }?
            .uiElements.first { $0.role == kAXGroupRole }?
            .uiElements.first { $0.role == kAXScrollAreaRole }?
            .uiElements.first { $0.role == kAXTableRole }
    }
    
    func embeddedChatTable(app: AXUIElement) -> AXUIElement? {
        meetingWindow(app: app)?
            .uiElements.first { $0.role == kAXSplitGroupRole }?
            .uiElements.first { $0.role == kAXGroupRole }?
            .uiElements.first { $0.role == kAXScrollAreaRole }?
            .uiElements.first { $0.role == kAXTableRole }
    }
    
    func chatTable(app: AXUIElement) -> AXUIElement? {
        let chatTable: AXUIElement? = windowChatTable(app: app) ?? embeddedChatTable(app: app)
        if chatTable == nil {
            log.info("Chat not visible")
        }
        
        return chatTable
    }
    
    func chatRows(app: AXUIElement) -> Observable<AXUIElement> {
        Observable<Int>
            .timer(.seconds(0), period: .seconds(1), scheduler: scheduler)
            .take(while: { _ in
                // meeting is ongoing
                logIfNil(anyMeetingWindow(app: app), message: "Meeting ended") != nil
            })
            .compactMap { _ in chatTable(app: app) }
            .scan((0, [])) { (accum: (Int, ArraySlice<AXUIElement>), table: AXUIElement) in
                let (processedCount, _): (Int, _) = accum
                let newRows: ArraySlice<AXUIElement> = table.uiElements.dropFirst(processedCount)
                
                return (processedCount + newRows.count, newRows)
            }
            .concatMap { Observable.from($0.1) }
    }
    
    func zoomUIChatTextFromRow(row: AXUIElement) -> [ZoomUIChatTextCell] {
        enum ChatRawElement {
            case text(value: String)
            case isMetadata
        }
        
        return row.uiElements.first?.uiElements
            .compactMap {
                switch $0.role {
                case kAXUnknownRole: return $0.value.map { .text(value: $0) }
                case kAXStaticTextRole: return .isMetadata // Chat time - indicates next element is metadata
                default: return nil
                }
            }
            .reversed()
            .reduce((false, [])) { (accum: (Bool, [ZoomUIChatTextCell]), nextElem: ChatRawElement) in
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
    
    func scrapeAndPublishChatMessages() {
        URLSession.rx.shouldLogRequest = { request in false }
        
        _ = Observable<Int>
            .timer(.seconds(0), period: .seconds(30), scheduler: scheduler)
            .compactMap { _ in
                logIfNil(zoomApplication(), message: "Zoom not running")
            }
            .filter { app in
                logIfNil(anyMeetingWindow(app: app), message: "No meeting in progress") != nil
            }
            .flatMapFirst(chatRows)
            .flatMap { row in Observable.from(zoomUIChatTextFromRow(row: row)) }
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
            .flatMap {
                var urlComps: URLComponents = destinationURL
                urlComps.queryItems = [
                    URLQueryItem(name: "route", value: $0.route),
                    URLQueryItem(name: "text", value: $0.text)
                ]
                guard let url = urlComps.url else {
                    return Observable<Result<HTTPURLResponse, Error>>.never()
                }
                var urlRequest: URLRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                
                return urlSession.rx.response(request: urlRequest)
                    .map { .success($0.response) }
                    .retry { errors in
                        // Retry with delay, inspired by:
                        // https://github.com/ReactiveX/RxSwift/issues/689#issuecomment-595117647
                        let maxAttempts: Int = 3
                        let delay: DispatchTimeInterval = .seconds(2)
                        
                        return errors.enumerated().flatMap { (index, error) -> Observable<Int> in
                            index <= maxAttempts
                            ? Observable<Int>.timer(delay, scheduler: scheduler)
                            : Observable.error(error)
                        }
                    }
                    .catch { Observable.of(.failure($0)) }
            }
            .subscribe(
                onNext: { responseResult in
                    switch responseResult {
                    case .success(let response):
                        let statusCode: Int = response.statusCode
                        response.url.map { url in
                            if statusCode == 204 {
                                log.info("POSTed to \(url)")
                            } else {
                                log.warning("Got \(statusCode) POSTing to \(url)")
                            }
                        }
                        
                    case .failure(let error):
                        switch error {
                        case let urlError as URLError:
                            urlError.failingURL.map { url in
                                log.warning(#""\#(urlError.localizedDescription)" POSTing to \#(url)"#)
                            }
                        default: log.warning("\(error)")
                        }
                    }
                },
                onCompleted: { log.info("Terminated (should not happen)") }
            )
        
        RunLoop.current.run()
    }
}
