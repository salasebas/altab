import Cocoa

class SheetWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    class WindowContentView: NSView {
        var separator: NSView!

        init(_ separator: NSView) {
            super.init(frame: .zero)
            self.separator = separator
        }

        required init?(coder: NSCoder) {
            fatalError("Class only supports programmatic initialization")
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            separator.layer?.backgroundColor = NSColor.tableSeparatorColor.cgColor
        }
    }

    static let width = CGFloat(500)
    let separator = NSView()
    var doneButton: NSButton!
    private var bodyScrollView: NSScrollView!
    private var bodyContent: NSView!
    private var bodyHeightConstraint: NSLayoutConstraint!
    private var sheetWidth: CGFloat { SheetWindow.width + 2 * TableGroupSetView.padding }

    convenience init() {
        self.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        makeDoneButton()
        setupView()
    }

    func setupView() {
        let padding = TableGroupSetView.padding
        bodyContent = makeContentView()
        // Frame-based document sizing — NSScrollView + full Auto Layout is what paints the purple
        // "Layout is ambiguous" debugger overlay.
        let document = FlippedDocumentView(frame: NSRect(x: 0, y: 0, width: sheetWidth, height: 1))
        bodyContent.translatesAutoresizingMaskIntoConstraints = true
        document.addSubview(bodyContent)

        bodyScrollView = NSScrollView()
        bodyScrollView.translatesAutoresizingMaskIntoConstraints = false
        bodyScrollView.drawsBackground = false
        bodyScrollView.borderType = .noBorder
        bodyScrollView.hasVerticalScroller = true
        bodyScrollView.hasHorizontalScroller = false
        bodyScrollView.autohidesScrollers = true
        bodyScrollView.scrollerStyle = .overlay
        bodyScrollView.documentView = document

        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.tableSeparatorColor.cgColor

        let root = WindowContentView(separator)
        root.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(bodyScrollView)
        root.addSubview(separator)
        root.addSubview(doneButton)

        bodyHeightConstraint = bodyScrollView.heightAnchor.constraint(equalToConstant: 400)
        NSLayoutConstraint.activate([
            bodyScrollView.topAnchor.constraint(equalTo: root.topAnchor),
            bodyScrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bodyScrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bodyHeightConstraint,

            separator.topAnchor.constraint(equalTo: bodyScrollView.bottomAnchor, constant: padding),
            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            doneButton.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: padding),
            doneButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -padding),
            doneButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -padding),
            doneButton.widthAnchor.constraint(equalToConstant: 70),

            root.widthAnchor.constraint(equalToConstant: sheetWidth),
        ])
        contentView = root
        layoutDocument()
        setContentSize(NSSize(width: sheetWidth, height: bodyHeightConstraint.constant + footerHeight()))
    }

    /// Cap height to the space under the parent title bar so AppKit does not move Settings upward.
    func prepareForDisplay(relativeTo parent: NSWindow) {
        layoutDocument()
        let contentHeight = max(bodyScrollView.documentView?.frame.height ?? 1, 1)
        let maxBody = max(200, maxHeightPreservingParentPosition(parent) - footerHeight())
        bodyHeightConstraint.constant = min(contentHeight, maxBody)
        contentView?.layoutSubtreeIfNeeded()
        setContentSize(NSSize(width: sheetWidth, height: bodyHeightConstraint.constant + footerHeight()))
    }

    private func layoutDocument() {
        let padding = TableGroupSetView.padding
        guard let document = bodyScrollView.documentView else { return }
        // Temporarily use Auto Layout only to measure the body, then bake into frames.
        bodyContent.translatesAutoresizingMaskIntoConstraints = false
        let measureConstraints = [
            bodyContent.widthAnchor.constraint(equalToConstant: SheetWindow.width),
        ]
        NSLayoutConstraint.activate(measureConstraints)
        bodyContent.layoutSubtreeIfNeeded()
        let bodyHeight = max(bodyContent.fittingSize.height, 1)
        NSLayoutConstraint.deactivate(measureConstraints)
        bodyContent.translatesAutoresizingMaskIntoConstraints = true
        let documentHeight = bodyHeight + padding
        document.frame = NSRect(x: 0, y: 0, width: sheetWidth, height: documentHeight)
        bodyContent.frame = NSRect(x: padding, y: 0, width: SheetWindow.width, height: bodyHeight)
        bodyContent.autoresizingMask = [.maxYMargin]
    }

    private func footerHeight() -> CGFloat {
        let padding = TableGroupSetView.padding
        return padding + 1 + padding + doneButton.intrinsicContentSize.height + padding
    }

    private func maxHeightPreservingParentPosition(_ parent: NSWindow) -> CGFloat {
        guard let screen = parent.screen ?? NSScreen.main else { return 560 }
        let sheetTopY = parent.frame.minY + parent.contentLayoutRect.maxY
        let available = sheetTopY - screen.visibleFrame.minY - 8
        let screenCap = screen.visibleFrame.height * 0.7
        return max(240, min(available, screenCap))
    }

    func makeContentView() -> NSView {
        return NSView()
    }

    private func makeDoneButton() {
        doneButton = NSButton(title: NSLocalizedString("Done", comment: ""), target: self, action: #selector(cancel))
        doneButton.keyEquivalent = "\r"
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(macOS 10.14, *) {
            doneButton.bezelColor = NSColor.controlAccentColor
        }
    }

    @objc func cancel(_ sender: Any?) {
        sheetParent!.endSheet(self)
    }
}

/// Top-left origin so content grows downward inside the scroll view.
private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}
