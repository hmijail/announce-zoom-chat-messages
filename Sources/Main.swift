import ArgumentParser
import Curses
import Foundation
import Logging
import LoggingFormatAndPipe
import RxSwift

@main
struct Main: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zoom-chat-publisher",
        abstract: "Scrapes Zoom chat messages and publishes them to an HTTP endpoint."
    )
    
    @Option(name: .shortAndLong, help: "The URL to publish chat messages to.")
    var destinationURL: URLComponents
    
    func run() {
        URLSession.rx.shouldLogRequest = { _ in false }
        let disposeBag: DisposeBag = DisposeBag()
        let publisher: ZoomChatPublisher = ZoomChatPublisher(
            destinationURL: destinationURL
        )
        
        // View
        class Handler: CursesHandlerProtocol {
            let screen: Screen
            
            init(_ screen: Screen) {
                self.screen = screen
            }
            
            func interruptHandler() {
                screen.shutDown()
                Main.exit(withError: nil)
            }
            
            func windowChangedHandler(_ terminalSize: Size) {}
        }
        
        let screen: Screen = Screen.shared
        screen.startUp(handler: Handler(screen))
        
        let statusOkAttribute: Attribute
        let statusBadAttribute: Attribute
        let successAttribute: Attribute
        let failureAttribute: Attribute
        let colors: Colors = Colors.shared
        if colors.areSupported {
            colors.startUp()
            statusOkAttribute = colors.newPair(foreground: .white, background: .green)
            statusBadAttribute = colors.newPair(foreground: .white, background: .red)
            successAttribute = colors.newPair(foreground: .green, background: .black)
            failureAttribute = colors.newPair(foreground: .red, background: .black)
        } else {
            statusOkAttribute = Attribute.reverse
            statusBadAttribute = Attribute.blink
            successAttribute = Attribute.dim
            failureAttribute = Attribute.blink
        }
        
        let view: some View = CursesView(
            screen: screen,
            statusOkAttribute: statusOkAttribute, statusBadAttribute: statusBadAttribute,
            successAttribute: successAttribute, failureAttribute: failureAttribute
        )
        publisher
            .scrapeAndPublishChatMessages()
            .subscribe(onNext: view.render)
            .disposed(by: disposeBag)
        
        RunLoop.current.run()
    }
}
