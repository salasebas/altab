import Cocoa

private let tileSpacingResetTitle = NSLocalizedString("Default", comment: "Restore tile spacing to its default value")
private let tileSpacingAccessibilityHelp = NSLocalizedString("Horizontal and vertical space between tiles, from 0 to 16 points.", comment: "Tile spacing slider accessibility help")
private let tileSpacingResetHelp = NSLocalizedString("Restore tile spacing to 8 points.", comment: "Tile spacing reset button help")
private let tileSpacingValueFormat = NSLocalizedString("%d pt", comment: "Tile spacing value in points")
private let uniformTileWidthsAccessibilityHelp = NSLocalizedString(
    "Make every thumbnail tile the same outer width, based on the widest window in the current set. Thumbnail images keep their size and aspect ratio.",
    comment: "Uniform tile widths switch accessibility help")

/// Live preview of variable vs uniform outer tile widths for the Thumbnails layout option.
private final class UniformTileWidthsPreviewView: NSView {
    private let tiles = (0..<3).map { _ in NSView() }
    private let images = (0..<3).map { _ in NSView() }
    private var uniform: Bool

    init(_ uniform: Bool) {
        self.uniform = uniform
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 460).isActive = true
        heightAnchor.constraint(equalToConstant: 96).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        setAccessibilityElement(false)
        for (tile, image) in zip(tiles, images) {
            tile.wantsLayer = true
            tile.layer?.cornerRadius = 8
            tile.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.22).cgColor
            image.wantsLayer = true
            image.layer?.cornerRadius = 6
            image.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.85).cgColor
            tile.addSubview(image)
            addSubview(tile)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func update(_ uniform: Bool) {
        self.uniform = uniform
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let imageWidths: [CGFloat] = [44, 78, 56]
        let imageHeight: CGFloat = 48
        let inset: CGFloat = 8
        let spacing: CGFloat = 12
        let naturalOuter = imageWidths.map { $0 + inset * 2 }
        let outerWidths = AppearanceTestable.resolvedTileWidths(naturalOuter, uniform)
        let rowWidth = outerWidths.reduce(CGFloat(0), +) + spacing * CGFloat(outerWidths.count - 1)
        var x = ((bounds.width - rowWidth) / 2).rounded()
        let y = ((bounds.height - imageHeight - inset * 2) / 2).rounded()
        for index in tiles.indices {
            let outer = outerWidths[index]
            tiles[index].frame = CGRect(x: x, y: y, width: outer, height: imageHeight + inset * 2)
            let imageWidth = imageWidths[index]
            images[index].frame = CGRect(
                x: ((outer - imageWidth) / 2).rounded(),
                y: inset,
                width: imageWidth,
                height: imageHeight)
            x += outer + spacing
        }
    }
}

private final class TileSpacingPreviewView: NSView {
    private let tiles = (0..<6).map { _ in NSView() }
    private var spacing: CGFloat

    init(_ spacing: CGFloat) {
        self.spacing = spacing
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 460).isActive = true
        heightAnchor.constraint(equalToConstant: 136).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        setAccessibilityElement(false)
        for tile in tiles {
            tile.wantsLayer = true
            tile.layer?.cornerRadius = 8
            tile.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.75).cgColor
            addSubview(tile)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func update(_ spacing: CGFloat) {
        self.spacing = spacing
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let tileSize = CGSize(width: 78, height: 52)
        let gridSize = CGSize(width: tileSize.width * 3 + spacing * 2, height: tileSize.height * 2 + spacing)
        let origin = CGPoint(x: ((bounds.width - gridSize.width) / 2).rounded(), y: ((bounds.height - gridSize.height) / 2).rounded())
        for (index, tile) in tiles.enumerated() {
            let column = CGFloat(index % 3)
            let row = CGFloat(index / 3)
            tile.frame = CGRect(x: origin.x + column * (tileSize.width + spacing), y: origin.y + row * (tileSize.height + spacing), width: tileSize.width, height: tileSize.height)
        }
    }
}

private final class TileSpacingControl {
    let controls: NSStackView
    let preview: TileSpacingPreviewView
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private let resetButton = NSButton(title: tileSpacingResetTitle, target: nil, action: nil)

    init(_ accessibilityLabel: String) {
        let value = Preferences.tileSpacingPoints
        preview = TileSpacingPreviewView(CGFloat(value))
        slider.minValue = Double(TileSpacingPreference.validRange.lowerBound)
        slider.maxValue = Double(TileSpacingPreference.validRange.upperBound)
        slider.integerValue = value
        slider.numberOfTickMarks = TileSpacingPreference.validRange.count
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 220).isActive = true
        slider.setAccessibilityLabel(accessibilityLabel)
        slider.setAccessibilityHelp(tileSpacingAccessibilityHelp)
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        valueLabel.alignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        resetButton.bezelStyle = .rounded
        resetButton.controlSize = .small
        resetButton.toolTip = tileSpacingResetHelp
        resetButton.setAccessibilityHelp(tileSpacingResetHelp)
        controls = NSStackView(views: [slider, valueLabel, resetButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8
        _ = LabelAndControl.setupControl(slider, "tileSpacingPoints", extraAction: { [weak self] control in
            self?.update(control.integerValue)
        })
        resetButton.onAction = { [weak self] _ in
            guard let self else { return }
            self.slider.integerValue = TileSpacingPreference.defaultValue
            self.slider.onAction?(self.slider)
        }
        update(value)
    }

    private func update(_ value: Int) {
        let value = TileSpacingPreference.clamped(value)
        let description = String(format: tileSpacingValueFormat, value)
        valueLabel.stringValue = description
        slider.setAccessibilityValueDescription(description)
        resetButton.isEnabled = value != TileSpacingPreference.defaultValue
        preview.update(CGFloat(value))
    }
}

class CustomizeStyleSheet: SheetWindow {
    // Local labels (rows owned by this sheet). The Show/Hide rows below are sourced from
    // `ShowHideIllustratedView`'s static constants so each NSLocalizedString call lives in
    // exactly one place across the codebase.
    private static let labelShowTitles = NSLocalizedString("Show titles", comment: "")
    private static let labelTitleTruncation = NSLocalizedString("Title truncation", comment: "")
    private static let labelLayout = NSLocalizedString("Layout", comment: "")
    private static let labelTileSpacing = NSLocalizedString("Tile spacing", comment: "")
    private static let labelRowAlignment = NSLocalizedString("Row alignment", comment: "")
    private static let labelUniformTileWidths = NSLocalizedString("Uniform tile widths", comment: "")

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static var searchableStrings: [String] {
        var strings = [
            labelShowTitles,
            labelTitleTruncation,
            ShowHideIllustratedView.hideStatusIconsLabel,
            ShowHideIllustratedView.hideStatusIconsSubtitle,
            ShowHideIllustratedView.hideSpaceNumberLabelsLabel,
            ShowHideIllustratedView.hideColoredCirclesLabel,
            ShowHideIllustratedView.showSymbolsInHoverControlsLabel,
            IllustratedImageThemeView.placeholderLabelText,
        ] + ShowTitlesPreference.allCases.map { $0.localizedString }
          + TitleTruncationPreference.allCases.map { $0.localizedString }
        if Preferences.appearanceStyle != .titles {
            strings += [labelLayout, labelTileSpacing, labelRowAlignment, tileSpacingResetTitle, tileSpacingAccessibilityHelp, tileSpacingResetHelp]
                + RowAlignmentPreference.allCases.map { $0.localizedString }
        }
        if Preferences.appearanceStyle == .thumbnails {
            strings += [labelUniformTileWidths, uniformTileWidthsAccessibilityHelp]
        }
        return strings
    }

    static let illustratedImageWidth = width

    let style = Preferences.appearanceStyle
    var illustratedImageView: IllustratedImageThemeView!
    var showHideIllustratedView: ShowHideIllustratedView!
    private var tileSpacingControl: TileSpacingControl!
    private var uniformTileWidthsPreview: UniformTileWidthsPreviewView?

    /// Keep the style illustration pinned above the scrolling options so hover previews stay visible
    /// even when the list is long (Layout / Show & Hide / titles).
    override func makeHeaderView() -> NSView? {
        illustratedImageView = IllustratedImageThemeView(style, CustomizeStyleSheet.illustratedImageWidth)
        return illustratedImageView
    }

    override func makeContentView() -> NSView {
        // Illustration lives in the sticky header (`makeHeaderView`); body is the option groups only.
        // ShowHideIllustratedView still needs the image view for hover highlight callbacks.
        if illustratedImageView == nil {
            illustratedImageView = IllustratedImageThemeView(style, CustomizeStyleSheet.illustratedImageWidth)
        }
        showHideIllustratedView = ShowHideIllustratedView(style, illustratedImageView)
        let showHideView = showHideIllustratedView.makeView()
        let advancedTable = TableGroupView(width: CustomizeStyleSheet.width)
        let showTitles = TableGroupView.Row(leftTitle: Self.labelShowTitles,
            rightViews: [LabelAndControl.makeDropdown(
                "showTitles", ShowTitlesPreference.allCases, extraAction: { [weak self] _ in
                    self?.showTitlesIllustratedImage()
                })])
        advancedTable.addRow(showTitles, onMouseEntered: { [weak self] _, _ in
            self?.showTitlesIllustratedImage()
        })
        let titleTruncation = TableGroupView.Row(leftTitle: Self.labelTitleTruncation,
            rightViews: LabelAndControl.makeRadioButtons("titleTruncation", TitleTruncationPreference.allCases))
        advancedTable.addRow(titleTruncation)
        advancedTable.onMouseExited = { [weak self] event, view in
            guard let self else { return }
            IllustratedImageThemeView.resetImage(self.illustratedImageView, event, view)
        }
        let advancedView = TableGroupSetView(originalViews: [advancedTable], padding: 0)
        var views: [NSView] = []
        if style != .titles { views.append(makeLayoutView()) }
        views.append(contentsOf: [showHideView, advancedView])
        return TableGroupSetView(originalViews: views, padding: 0)
    }

    private func makeLayoutView() -> NSView {
        let table = TableGroupView(title: Self.labelLayout, width: CustomizeStyleSheet.width)
        let rowAlignment = TableGroupView.Row(leftTitle: Self.labelRowAlignment,
            rightViews: LabelAndControl.makeRadioButtons("alignThumbnails", RowAlignmentPreference.allCases, extraAction: { [weak self] _ in
                self?.showRowAlignmentIllustratedImage()
            }))
        table.addRow(rowAlignment, onMouseEntered: { [weak self] _, _ in
            self?.showRowAlignmentIllustratedImage()
        })
        if style == .thumbnails {
            let preview = UniformTileWidthsPreviewView(Preferences.uniformTileWidths)
            uniformTileWidthsPreview = preview
            let uniformSwitch = LabelAndControl.makeSwitch("uniformTileWidths", extraAction: { [weak self] _ in
                self?.uniformTileWidthsPreview?.update(Preferences.uniformTileWidths)
            })
            uniformSwitch.setAccessibilityLabel(Self.labelUniformTileWidths)
            uniformSwitch.setAccessibilityHelp(uniformTileWidthsAccessibilityHelp)
            table.addRow(
                leftViews: [TableGroupView.makeText(Self.labelUniformTileWidths)],
                rightViews: [uniformSwitch],
                secondaryViews: [preview],
                secondaryViewsAlignment: .right,
                secondaryViewsTopGap: 8)
        }
        tileSpacingControl = TileSpacingControl(Self.labelTileSpacing)
        table.addRow(leftViews: [TableGroupView.makeText(Self.labelTileSpacing)], rightViews: [tileSpacingControl.controls], secondaryViews: [tileSpacingControl.preview], secondaryViewsAlignment: .right, secondaryViewsTopGap: 8)
        table.onMouseExited = { [weak self] event, view in
            guard let self else { return }
            IllustratedImageThemeView.resetImage(self.illustratedImageView, event, view)
        }
        return table
    }

    private func showTitlesIllustratedImage() {
        illustratedImageView.highlight(true, Preferences.showTitles.image.name)
    }

    private func showRowAlignmentIllustratedImage() {
        illustratedImageView.highlight(true, Preferences.rowAlignment.image.name)
    }
}
