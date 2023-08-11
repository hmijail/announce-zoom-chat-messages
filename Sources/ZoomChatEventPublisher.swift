import AppKit
import Logging
import RxCocoa
import RxSwift

struct ZoomChatEventPublisher {
    private let log: Logger = Logger(label: "main")
    private let scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .default)
    private let urlSession: URLSession = URLSession.shared
    let destinationURL: URLComponents
    
    func logIfNil<T>(item: T?, message: String) -> T? {
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
    
    func windowChatTable(app: AXUIElement) -> AXUIElement? {
        app.windows
            .first { $0.title == "Meeting Chat" }?
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
            log.info("Please Show Chat")
        }
        
        return chatTable
    }
    
    func chatRows(app: AXUIElement) -> Observable<AXUIElement> {
        Observable<Int>
            .timer(.seconds(0), period: .seconds(1), scheduler: scheduler)
            .take(while: { _ in meetingWindow(app: app) != nil }) // while meeting is ongoing
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
                logIfNil(item: zoomApplication(), message: "Zoom not running")
            }
            .compactMap { app in
                logIfNil(item: meetingWindow(app: app), message: "No meeting in progress").map { _ in app }
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
                    return Observable<HTTPURLResponse>.empty()
                }
                var urlRequest: URLRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                
                return urlSession.rx.response(request: urlRequest).map { $0.response }
            }
            .subscribe(
                onNext: { response in
                    let statusCode: Int = response.statusCode
                    response.url.map { url in
                        if statusCode == 204 {
                            log.info("Successfully POSTed to \(url)")
                        } else {
                            log.warning("Failed POSTing to \(url) with \(statusCode)")
                        }
                    }
                },
                onCompleted: { log.info("Meeting ended") }
            )
        
        RunLoop.current.run()
    }
}
