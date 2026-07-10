import Cocoa

class MenuBarView: NSView {
    let topLabel = NSTextField()
    let bottomLabel = NSTextField()
    var config = Config()

    override init(frame: NSRect) {
        super.init(frame: frame)
        for label in [topLabel, bottomLabel] {
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.alignment = .center
            addSubview(label)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    @discardableResult
    func update(top: String, bottom: String, topColor: NSColor? = nil) -> CGFloat {
        topLabel.stringValue = top
        topLabel.font = NSFont.systemFont(ofSize: CGFloat(config.top_font_size), weight: .medium)
        topLabel.textColor = topColor ?? .labelColor
        topLabel.sizeToFit()

        bottomLabel.stringValue = bottom
        bottomLabel.font = NSFont.systemFont(ofSize: CGFloat(config.bottom_font_size), weight: .regular)
        bottomLabel.textColor = .labelColor
        bottomLabel.sizeToFit()

        let tw = max(topLabel.frame.width, bottomLabel.frame.width)
        let th = topLabel.frame.height + bottomLabel.frame.height
        let newSize = NSSize(width: tw + 2, height: th)
        if frame.size != newSize { frame.size = newSize }
        topLabel.frame.origin = NSPoint(x: frame.width / 2 - topLabel.frame.width / 2, y: bottomLabel.frame.height)
        bottomLabel.frame.origin = NSPoint(x: frame.width / 2 - bottomLabel.frame.width / 2, y: 0)
        return tw + 2
    }
}
