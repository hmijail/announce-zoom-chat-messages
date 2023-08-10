import AppKit

extension AXUIElement {
    private func value<T>(forAttribute attribute: String) -> T? {
        var attributeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(self, attribute as CFString, &attributeValue)
        return attributeValue as? T
    }
    private func layoutDescription(depth: Int = 0) -> String {
        let pad: String = String(repeating: " ", count: depth * 2)
        
        return """
        \(pad)- (\(role ?? "(no role)")) \(value ?? "(no value)")/\(identifier ?? "(no identifier)/\(horizontalUnit ?? "...")")
        \(uiElements.map { $0.layoutDescription(depth: depth+1) }.joined())
        """
    }
    
    public var layoutDescription: String { layoutDescription(depth: 0) }
    public var identifier: String? { value(forAttribute: kAXIdentifierAttribute) }
    public var title: String? { value(forAttribute: kAXTitleAttribute) }
    public var role: String? { value(forAttribute: kAXRoleAttribute) }
    public var text: String? { value(forAttribute: kAXTextAttribute) }
    public var value: String? { value(forAttribute: kAXValueAttribute) }
    public var windows: [AXUIElement] { value(forAttribute: kAXWindowsAttribute) ?? [] }
    public var uiElements: [AXUIElement] { value(forAttribute: kAXChildrenAttribute) ?? [] }
    public var horizontalUnit: String? { value(forAttribute: kAXHorizontalUnitDescriptionAttribute) }
}

extension AXUIElement : CustomStringConvertible {
    public var description: String { value(forAttribute: kAXDescriptionAttribute) ?? "" }
}
