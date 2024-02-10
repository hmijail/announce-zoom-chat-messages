import Curses

extension Window {
    func writeStatus(_ string: String, column: Int, attribute: Attribute) {
        cursor.position = Point(x: column, y: 0)
        turnOn(attribute)
        write(string)
        turnOff(attribute)
    }
}
