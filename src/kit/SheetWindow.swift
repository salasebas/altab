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
    private var scrollView: NSScrollView!
    private var scrollDocument: NSView!
    private var scrollHeightConstraint: NSLayoutConstraint!

    convenience init() {
        self.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        makeDoneButton()
        setupView()
    }

    func setupView() {
        let contentView = makeContentView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Document holds only the sheet body so the Done footer can stay pinned while content scrolls.
        scrollDocument = NSView()
        scrollDocument.translatesAutoresizingMaskIntoConstraints = false
        scrollDocument.addSubview(contentView)
        let padding = TableGroupSetView.padding
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollDocument.topAnchor, constant: padding),
            contentView.leadingAnchor.constraint(equalTo: scrollDocument.leadingAnchor, constant: padding),
            contentView.trailingAnchor.constraint(equalTo: scrollDocument.trailingAnchor, constant: -padding),
            contentView.bottomAnchor.constraint(equalTo: scrollDocument.bottomAnchor),
            contentView.widthAnchor.constraint(equalToConstant: SheetWindow.width),
        ])

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = scrollDocument

        let clipView = scrollView.contentView
        NSLayoutConstraint.activate([
            scrollDocument.topAnchor.constraint(equalTo: clipView.topAnchor),
            scrollDocument.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            scrollDocument.widthAnchor.constraint(equalTo: clipView.widthAnchor),
        ])

        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.tableSeparatorColor.cgColor

        let root = WindowContentView(separator)
        root.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)
        root.addSubview(separator)
        root.addSubview(doneButton)

        let sheetWidth = SheetWindow.width + 2 * padding
        scrollHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 400)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollHeightConstraint,

            separator.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: padding),
            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            doneButton.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: padding),
            doneButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -padding),
            doneButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -padding),

            root.widthAnchor.constraint(equalToConstant: sheetWidth),
        ])
        self.contentView = root
        // Initial size; real clamp happens in prepareForDisplay(relativeTo:) before the sheet is shown.
        setContentSize(NSSize(width: sheetWidth, height: 400 + footerHeight()))
    }

    /// Size the sheet so AppKit does not shove the parent window upward to make room.
    /// Sheets hang under the parent title bar; if the sheet would extend past the bottom of the
    /// visible screen, AppKit moves the parent. Cap height to the space currently available.
    func prepareForDisplay(relativeTo parent: NSWindow) {
        let padding = TableGroupSetView.padding
        let sheetWidth = SheetWindow.width + 2 * padding
        scrollDocument.layoutSubtreeIfNeeded()
        let contentHeight = max(scrollDocument.fittingSize.height, 1)
        let maxScrollHeight = max(200, maxHeightPreservingParentPosition(parent) - footerHeight())
        let scrollHeight = min(contentHeight, maxScrollHeight)
        scrollHeightConstraint.constant = scrollHeight
        setContentSize(NSSize(width: sheetWidth, height: scrollHeight + footerHeight()))
    }

    private func footerHeight() -> CGFloat {
        let padding = TableGroupSetView.padding
        // separator (1) + paddings around separator/button + button height
        return padding + 1 + padding + doneButton.intrinsicContentSize.height + padding
    }

    private func maxHeightPreservingParentPosition(_ parent: NSWindow) -> CGFloat {
        guard let screen = parent.screen ?? NSScreen.main else { return 560 }
        // Bottom of the parent title bar in screen coordinates ≈ top edge of a document-modal sheet.
        let sheetTopY = parent.frame.minY + parent.contentLayoutRect.maxY
        let available = sheetTopY - screen.visibleFrame.minY - 8
        // Never taller than ~70% of the screen either — keeps the pair visually centered-ish.
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
        doneButton.widthAnchor.constraint(equalToConstant: 70).isActive = true
        if #available(macOS 10.14, *) {
            doneButton.bezelColor = NSColor.controlAccentColor
        }
    }

    // allow to close with the escape key
    @objc func cancel(_ sender: Any?) {
        sheetParent!.endSheet(self)
    }
}
