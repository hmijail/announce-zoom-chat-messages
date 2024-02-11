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
        
        let successAttribute: Attribute
        let failureAttribute: Attribute
        let colors: Colors = Colors.shared
        if colors.areSupported {
            colors.startUp()
            successAttribute = colors.newPair(foreground: .white, background: .green)
            failureAttribute = colors.newPair(foreground: .white, background: .red)
        } else {
            successAttribute = Attribute.reverse
            failureAttribute = Attribute.blink
        }
        
        let view: some View = CursesView(
            screen: screen, successAttribute: successAttribute, failureAttribute: failureAttribute
        )
        publisher
            .scrapeAndPublishChatMessages()
            .subscribe(onNext: view.render)
            .disposed(by: disposeBag)
        
        RunLoop.current.run()
    }
}
