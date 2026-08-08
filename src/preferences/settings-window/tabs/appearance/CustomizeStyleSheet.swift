import Cocoa

private let tileSpacingResetTitle = NSLocalizedString("Default", comment: "Restore tile spacing to its default value")
private let tileSpacingAccessibilityHelp = NSLocalizedString("Horizontal and vertical space between tiles, from 0 to 16 points.", comment: "Tile spacing slider accessibility help")
private let tileSpacingResetHelp = NSLocalizedString("Restore tile spacing to 1 point.", comment: "Tile spacing reset button help")
private let tileSpacingValueFormat = NSLocalizedString("%d pt", comment: "Tile spacing value in points")

private final class TileSpacingPreviewView: NSView {
    private let tiles = (0..<6).map { _ in NSView() }
    private var spacing: CGFloat

    init(_ spacing: CGFloat) {
        self.spacing = spacing
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 460).isActive = true
        heightAnchor.constraint(equalToConstant: 58).isActive = true
        wantsLayer = true
        layer?.cornerRadius = TableGroupView.cornerRadius
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        setAccessibilityElement(false)
        for tile in tiles {
            tile.wantsLayer = true
            tile.layer?.cornerRadius = 4
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
        let tileSize = CGSize(width: 92, height: 20)
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

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        labelShowTitles,
        labelTitleTruncation,
        labelLayout,
        labelTileSpacing,
        tileSpacingResetTitle,
        tileSpacingAccessibilityHelp,
        tileSpacingResetHelp,
        ShowHideIllustratedView.hideStatusIconsLabel,
        ShowHideIllustratedView.hideStatusIconsSubtitle,
        ShowHideIllustratedView.hideSpaceNumberLabelsLabel,
        ShowHideIllustratedView.hideColoredCirclesLabel,
        IllustratedImageThemeView.placeholderLabelText,
    ] + ShowTitlesPreference.allCases.map { $0.localizedString }
      + TitleTruncationPreference.allCases.map { $0.localizedString }

    static let illustratedImageWidth = width

    let style = Preferences.appearanceStyle
    var illustratedImageView: IllustratedImageThemeView!
    var showHideIllustratedView: ShowHideIllustratedView!
    private var tileSpacingControl: TileSpacingControl!

    override func makeContentView() -> NSView {
        // The per-shortcut Customize sheet was trimmed to just style-tied global toggles. The
        // settings that used to live here either (a) moved to per-shortcut storage and now live
        // in `ControlsTab` (`showAppsOrWindows`, `showTabsAsWindows`) or (b) were dropped
        // entirely (`alignThumbnails`). The "Show & Hide" / "Advanced" tab control is gone too —
        // the remaining rows fit comfortably in one flat list.
        illustratedImageView = IllustratedImageThemeView(style, CustomizeStyleSheet.illustratedImageWidth)
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
        var views: [NSView] = [illustratedImageView]
        if style != .titles { views.append(makeLayoutView()) }
        views.append(contentsOf: [showHideView, advancedView])
        return TableGroupSetView(originalViews: views, padding: 0)
    }

    private func makeLayoutView() -> NSView {
        let table = TableGroupView(title: Self.labelLayout, width: CustomizeStyleSheet.width)
        tileSpacingControl = TileSpacingControl(Self.labelTileSpacing)
        table.addRow(leftViews: [TableGroupView.makeText(Self.labelTileSpacing)], rightViews: [tileSpacingControl.controls], secondaryViews: [tileSpacingControl.preview], secondaryViewsAlignment: .right, secondaryViewsTopGap: 8)
        return table
    }

    private func showTitlesIllustratedImage() {
        illustratedImageView.highlight(true, Preferences.showTitles.image.name)
    }
}
