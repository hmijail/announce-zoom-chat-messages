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
        \(pad)- [.\(
            role ?? "(no role)"
        ), \(
            identifier.map { "#\($0)" } ?? "(no identifier)"
        ), \(
            size.map { "\($0.width)x\($0.height)" } ?? "(no size)"
        )]: \(value ?? "(no value)")
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
    public var size: CGSize? {
        guard
            let axValue: AXValue = value(forAttribute: kAXSizeAttribute),
            AXValueGetType(axValue) == .cgSize
        else {
            return nil
        }
        
        var cgSize: CGSize = CGSize()
        AXValueGetValue(axValue, .cgSize, &cgSize)
        return cgSize
    }
}

extension AXUIElement : CustomStringConvertible {
    public var description: String { value(forAttribute: kAXDescriptionAttribute) ?? "" }
}
