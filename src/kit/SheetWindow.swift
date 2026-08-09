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
    private var headerView: NSView?
    private var bodyHeightConstraint: NSLayoutConstraint!
    private var headerHeight: CGFloat = 0
    private var sheetWidth: CGFloat { SheetWindow.width + 2 * TableGroupSetView.padding }

    convenience init() {
        self.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        makeDoneButton()
        setupView()
    }

    /// Optional fixed header above the scrollable body (e.g. Customize more illustration so hover
    /// previews stay visible while the options list scrolls).
    func makeHeaderView() -> NSView? { nil }

    func makeContentView() -> NSView {
        return NSView()
    }

    func setupView() {
        let padding = TableGroupSetView.padding
        headerView = makeHeaderView()
        bodyContent = makeContentView()
        bodyContent.translatesAutoresizingMaskIntoConstraints = true

        // Frame-based document sizing avoids NSScrollView + Auto Layout ambiguity overlays.
        let document = FlippedDocumentView(frame: NSRect(x: 0, y: 0, width: sheetWidth, height: 1))
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
        if let headerView {
            headerView.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(headerView)
        }
        root.addSubview(bodyScrollView)
        root.addSubview(separator)
        root.addSubview(doneButton)

        bodyHeightConstraint = bodyScrollView.heightAnchor.constraint(equalToConstant: 400)
        var constraints: [NSLayoutConstraint] = [
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
        ]
        if let headerView {
            constraints += [
                headerView.topAnchor.constraint(equalTo: root.topAnchor, constant: padding),
                headerView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: padding),
                headerView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -padding),
                headerView.widthAnchor.constraint(equalToConstant: SheetWindow.width),
                bodyScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: TableGroupSetView.spacing),
            ]
        } else {
            constraints.append(bodyScrollView.topAnchor.constraint(equalTo: root.topAnchor, constant: padding))
        }
        NSLayoutConstraint.activate(constraints)
        contentView = root
        layoutDocument()
        measureHeader()
        setContentSize(NSSize(width: sheetWidth, height: totalHeight(body: bodyHeightConstraint.constant)))
    }

    /// Cap height so AppKit does not shove the parent Settings window upward.
    func prepareForDisplay(relativeTo parent: NSWindow) {
        layoutDocument()
        measureHeader()
        let contentHeight = max(bodyScrollView.documentView?.frame.height ?? 1, 1)
        let chrome = footerHeight() + headerChromeHeight()
        let maxBody = max(160, maxHeightPreservingParentPosition(parent) - chrome)
        bodyHeightConstraint.constant = min(contentHeight, maxBody)
        contentView?.layoutSubtreeIfNeeded()
        setContentSize(NSSize(width: sheetWidth, height: totalHeight(body: bodyHeightConstraint.constant)))
    }

    private func layoutDocument() {
        let padding = TableGroupSetView.padding
        guard let document = bodyScrollView.documentView else { return }
        bodyContent.translatesAutoresizingMaskIntoConstraints = false
        let measureConstraints = [
            bodyContent.widthAnchor.constraint(equalToConstant: SheetWindow.width),
        ]
        NSLayoutConstraint.activate(measureConstraints)
        bodyContent.layoutSubtreeIfNeeded()
        let bodyHeight = max(bodyContent.fittingSize.height, 1)
        NSLayoutConstraint.deactivate(measureConstraints)
        bodyContent.translatesAutoresizingMaskIntoConstraints = true
        // When a sticky header is present, spacing under the header already separates it from the
        // body; only add top padding inside the document when the body is the first chrome.
        let topInset = headerView == nil ? padding : 0
        let documentHeight = bodyHeight + topInset
        document.frame = NSRect(x: 0, y: 0, width: sheetWidth, height: documentHeight)
        bodyContent.frame = NSRect(x: padding, y: topInset, width: SheetWindow.width, height: bodyHeight)
        bodyContent.autoresizingMask = [.maxYMargin]
    }

    private func measureHeader() {
        guard let headerView else {
            headerHeight = 0
            return
        }
        headerView.layoutSubtreeIfNeeded()
        headerHeight = max(headerView.fittingSize.height, headerView.intrinsicContentSize.height, 1)
    }

    private func headerChromeHeight() -> CGFloat {
        guard headerView != nil else { return TableGroupSetView.padding }
        return TableGroupSetView.padding + headerHeight + TableGroupSetView.spacing
    }

    private func footerHeight() -> CGFloat {
        let padding = TableGroupSetView.padding
        return padding + 1 + padding + doneButton.intrinsicContentSize.height + padding
    }

    private func totalHeight(body: CGFloat) -> CGFloat {
        headerChromeHeight() + body + footerHeight()
    }

    private func maxHeightPreservingParentPosition(_ parent: NSWindow) -> CGFloat {
        guard let screen = parent.screen ?? NSScreen.main else { return 560 }
        let sheetTopY = parent.frame.minY + parent.contentLayoutRect.maxY
        let available = sheetTopY - screen.visibleFrame.minY - 8
        let screenCap = screen.visibleFrame.height * 0.7
        return max(240, min(available, screenCap))
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
