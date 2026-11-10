import AppKit
import CoreText
import Observation

enum Paper {
    static let bg = NSColor(srgbRed: 251 / 255, green: 250 / 255, blue: 246 / 255, alpha: 1)
    static let ink = NSColor(srgbRed: 25 / 255, green: 24 / 255, blue: 22 / 255, alpha: 1)
    static let rust = NSColor(srgbRed: 155 / 255, green: 45 / 255, blue: 28 / 255, alpha: 1)
    static let meta = NSColor(srgbRed: 120 / 255, green: 116 / 255, blue: 110 / 255, alpha: 1)
    static let faint = NSColor(srgbRed: 176 / 255, green: 172 / 255, blue: 164 / 255, alpha: 1)
    static let line = NSColor(srgbRed: 229 / 255, green: 228 / 255, blue: 224 / 255, alpha: 1)
    static let track = NSColor(srgbRed: 239 / 255, green: 238 / 255, blue: 234 / 255, alpha: 1)
    static let blush = NSColor(srgbRed: 245 / 255, green: 228 / 255, blue: 220 / 255, alpha: 1)
    static let green = NSColor(srgbRed: 63 / 255, green: 107 / 255, blue: 84 / 255, alpha: 1)
    static let url = NSColor(srgbRed: 108 / 255, green: 114 / 255, blue: 102 / 255, alpha: 1)
    static let blockOff = NSColor(srgbRed: 226 / 255, green: 224 / 255, blue: 218 / 255, alpha: 1)
    static let cardLine = NSColor(srgbRed: 232 / 255, green: 230 / 255, blue: 224 / 255, alpha: 1)

    static let usesGlass: Bool = {
        if #available(macOS 26.0, *) { return true }
        return false
    }()

    static let background: NSColor = usesGlass ? .clear : bg
    static let surface: NSColor = usesGlass ? .white.withAlphaComponent(0.18) : .white
}

final class PaperRoot: NSView, NSTextFieldDelegate {
    private let model: AppModel
    private var applying = false
    private var recentIDs: [String] = []

    private let scroll = NSScrollView()
    private let stack = NSStackView()
    private let dropOverlay = DashedPlate()

    private let urlField = NSTextField()
    private let pasteBox = HoverClick()
    private let checkBadge = CheckBadge()
    private let spinner = NSProgressIndicator()
    private let probeLabel = GlyphField()

    private let previewWrap = NSStackView()
    private let thumb = ThumbView()
    private let siteLabel = PassLabel(labelWithString: "")
    private let parsedMark = GlyphField()
    private let titleGlyph = GlyphField()
    private let detailGlyph = GlyphField()

    private let videoChip = ModeChip(title: "视频", english: "Video")
    private let audioChip = ModeChip(title: "仅音频", english: "Audio")
    private let qualityRow = NSStackView()
    private var qualityPills: [VideoQuality: Pill] = [:]
    private let videoFormatRow = NSStackView()
    private let audioFormatRow = NSStackView()
    private var videoPills: [VideoContainer: Pill] = [:]
    private var audioPills: [AudioFormat: Pill] = [:]
    private let cookiePopup = NSPopUpButton()

    private let dashedGroup = NSStackView()
    private let errorGlyph = GlyphField()
    private let dashedTitle = GlyphField(centersInk: true)
    private let captionGlyph = GlyphField()
    private let toolsGlyph = GlyphField()
    private let copyInstall = HoverClick()

    private let progressCard = Card()
    private let percentLabel = PassLabel(labelWithString: "")
    private let statusGlyph = GlyphField()
    private let pauseButton = OutlineButton(title: "暂停")
    private let cancelButton = OutlineButton(title: "取消")
    private let openButton = OutlineButton(title: "打开")
    private let againButton = OutlineButton(title: "再下一个")
    private let blockBar = BlockBar()
    private let fractionLabel = PassLabel(labelWithString: "")
    private let trailingLabel = PassLabel(labelWithString: "")

    private let recentWrap = NSStackView()
    private let folderLabel = PassLabel(labelWithString: "")
    private let changeMark = GlyphField()

    init(model: AppModel) {
        self.model = model
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Paper.background.cgColor
        build()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, model.urlText.isEmpty else { return }
        window?.makeFirstResponder(urlField)
    }

    private func refresh() {
        withObservationTracking {
            self.apply()
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    private func apply() {
        applying = true
        defer { applying = false }

        let phase = model.phase
        let probing = model.isProbing
        let title = model.probedTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasTitle = !title.isEmpty
        let url = model.urlText
        let running = phase == .running

        if urlField.stringValue != url {
            urlField.stringValue = url
        }
        urlField.isEditable = !running

        let empty = url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        pasteBox.isHidden = !empty || running
        spinner.isHidden = !probing
        if probing { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
        checkBadge.isHidden = probing || empty || !hasTitle

        if probing && !hasTitle {
            probeLabel.configure(text: "正在解析链接…", font: AppFonts.nsBody(12), color: Paper.meta, alignment: .left, lineLimit: 1, tracking: 0)
            probeLabel.isHidden = false
        } else if !hasTitle, let note = model.probeNote, !note.isEmpty {
            probeLabel.configure(text: note, font: AppFonts.nsBody(12), color: Paper.meta, alignment: .left, lineLimit: 2, tracking: 0)
            probeLabel.isHidden = false
        } else {
            probeLabel.isHidden = true
        }

        previewWrap.isHidden = !hasTitle
        if hasTitle {
            let site = model.siteLabel
            let latin = site?.unicodeScalars.allSatisfy(\.isASCII) ?? false
            siteLabel.isHidden = site == nil
            siteLabel.attributedStringValue = NSAttributedString(
                string: latin ? (site ?? "").uppercased() : (site ?? ""),
                attributes: [
                    .font: latin ? AppFonts.times(11) : AppFonts.nsBody(12),
                    .foregroundColor: Paper.rust,
                    .kern: latin ? 0.8 : 0
                ]
            )
            titleGlyph.configure(text: title, font: AppFonts.nsBody(16), color: Paper.ink, alignment: .left, lineLimit: 2, tracking: 0)
            let detail = model.previewDetail
            detailGlyph.isHidden = detail.isEmpty
            detailGlyph.configure(text: detail, font: AppFonts.nsBody(12), color: Paper.meta, alignment: .left, lineLimit: 1, tracking: 0)
            thumb.setImage(model.thumbnail, duration: model.durationLabel)
        } else {
            _ = model.thumbnail
            _ = model.durationLabel
            _ = model.previewDetail
        }

        videoChip.setOn(model.mode == .video)
        audioChip.setOn(model.mode == .audio)
        qualityRow.isHidden = model.mode != .video
        videoFormatRow.isHidden = model.mode != .video
        audioFormatRow.isHidden = model.mode != .audio
        let hdr = model.probeHDR
        for (quality, pill) in qualityPills {
            let label = (quality == .q2160 && hdr) ? "4K HDR" : quality.pill
            pill.setTitle(label)
            pill.setOn(model.quality == quality)
        }
        for (container, pill) in videoPills {
            pill.setOn(model.container == container)
        }
        for (format, pill) in audioPills {
            pill.setOn(model.audioFormat == format)
        }
        let cookieIndex = CookieBrowser.allCases.firstIndex(of: model.cookieBrowser) ?? 0
        if cookiePopup.indexOfSelectedItem != cookieIndex {
            cookiePopup.selectItem(at: cookieIndex)
        }

        let showProgress = phase == .running || phase == .success
        dashedGroup.isHidden = showProgress
        progressCard.isHidden = !showProgress
        if phase == .failed, let message = model.errorMessage, !message.isEmpty {
            errorGlyph.configure(text: message, font: AppFonts.nsBody(13), color: Paper.rust, alignment: .center, lineLimit: 2, tracking: 0)
            errorGlyph.isHidden = false
        } else {
            errorGlyph.isHidden = true
            _ = model.errorMessage
        }
        let retry = phase == .failed
        dashedTitle.configure(
            text: retry ? "重试" : "下载",
            font: AppFonts.nsBody(22),
            color: Paper.faint.withAlphaComponent(model.canDownload || retry ? 1 : 0.65),
            alignment: .center,
            lineLimit: 1,
            tracking: retry ? 12 : 14
        )
        let missing = model.missingTools
        toolsGlyph.isHidden = missing.isEmpty
        copyInstall.isHidden = missing.isEmpty
        captionGlyph.isHidden = !missing.isEmpty
        if missing.isEmpty {
            captionGlyph.configure(text: model.captionLine, font: AppFonts.nsBody(12), color: Paper.faint, alignment: .center, lineLimit: 2, tracking: 0)
        } else {
            toolsGlyph.configure(
                text: "需要先安装 \(missing.joined(separator: " 和 "))",
                font: AppFonts.nsBody(12),
                color: Paper.meta,
                alignment: .center,
                lineLimit: 2,
                tracking: 0
            )
            _ = model.captionLine
        }

        let percent = phase == .success ? 100 : Int((min(max(model.progress, 0), 1) * 100).rounded())
        percentLabel.attributedStringValue = percentString(percent)
        statusGlyph.configure(text: liveStatus(phase: phase), font: AppFonts.nsBody(13), color: Paper.rust, alignment: .left, lineLimit: 1, tracking: 0)
        pauseButton.setTitle(model.isPaused ? "继续" : "暂停")
        pauseButton.isHidden = phase != .running
        cancelButton.isHidden = phase != .running
        openButton.isHidden = phase != .success
        againButton.isHidden = phase != .success
        blockBar.progress = phase == .success ? 1 : min(max(model.progress, 0), 1)
        fractionLabel.stringValue = fractionLine(phase: phase)
        trailingLabel.stringValue = trailingLine(phase: phase)
        _ = model.speedText
        _ = model.etaText
        _ = model.fileSizeText
        _ = model.filename
        _ = model.statusText

        let items = Array(model.recents.prefix(3))
        let ids = items.map(\.id)
        if ids != recentIDs {
            recentIDs = ids
            rebuildRecents(items)
        }
        recentWrap.isHidden = items.isEmpty || running

        folderLabel.stringValue = model.folderLabel
        folderLabel.lineBreakMode = .byTruncatingMiddle
        changeMark.configure(
            text: "更改",
            font: AppFonts.nsBody(13),
            color: running ? Paper.faint : Paper.rust,
            alignment: .left,
            lineLimit: 1,
            tracking: 0
        )
    }

    private func liveStatus(phase: Phase) -> String {
        if phase == .success { return "已保存" }
        if model.isPaused { return "已暂停" }
        if model.progress <= 0 {
            return model.statusText.isEmpty ? "正在解析" : model.statusText
        }
        if model.statusText.contains("合并") || model.statusText.contains("提取") || model.statusText.contains("写入") {
            return model.statusText
        }
        return "正在下载"
    }

    private func fractionLine(phase: Phase) -> String {
        if !model.progressFractionText.isEmpty { return model.progressFractionText }
        if phase == .success { return model.fileSizeText }
        return ""
    }

    private func trailingLine(phase: Phase) -> String {
        if phase == .success { return model.filename }
        return model.progressMetaText
    }

    private func percentString(_ value: Int) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: "\(value)",
            attributes: [.font: AppFonts.times(52), .foregroundColor: Paper.ink]
        )
        text.append(NSAttributedString(
            string: "%",
            attributes: [
                .font: AppFonts.times(18),
                .foregroundColor: Paper.ink,
                .baselineOffset: 22
            ]
        ))
        return text
    }

    private func build() {
        let wordmark = PassLabel(labelWithString: "")
        wordmark.attributedStringValue = NSAttributedString(
            string: "QINGQU",
            attributes: [
                .font: AppFonts.times(13),
                .foregroundColor: Paper.meta,
                .kern: 4.5
            ]
        )
        wordmark.alignment = .center

        let footer = makeFooter()
        configureScroll()

        addSubview(wordmark)
        addSubview(scroll)
        addSubview(footer)
        addSubview(dropOverlay)
        for view in [wordmark, scroll, footer, dropOverlay] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        dropOverlay.isHidden = true
        NSLayoutConstraint.activate([
            wordmark.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            wordmark.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 80),
            wordmark.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -80),
            wordmark.heightAnchor.constraint(equalToConstant: 22),

            footer.leadingAnchor.constraint(equalTo: leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor),

            scroll.topAnchor.constraint(equalTo: wordmark.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor),

            dropOverlay.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            dropOverlay.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            dropOverlay.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dropOverlay.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        fillStack()
        registerForDraggedTypes([.URL, .string, .fileURL])
    }

    private func configureScroll() {
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsetsZero
        scroll.contentView.drawsBackground = false

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 28, bottom: 22, right: 28)
        stack.setContentHuggingPriority(.required, for: .vertical)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let document = TopDocument()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])
        scroll.documentView = document
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
    }

    private func fillStack() {
        add(makeHeader())
        add(gap(18))
        add(section("LINK", "视频链接"))
        add(gap(8))
        add(makeLinkField())
        probeLabel.isHidden = true
        add(probeLabel)
        add(makePreview())
        add(gap(26))
        add(section("OPTIONS", "下载选项"))
        add(gap(12))
        add(makeModeTrack())
        add(makeQualityRow())
        add(hairline())
        add(makeVideoFormats())
        add(makeAudioFormats())
        add(hairline())
        add(makeCookieRow())
        add(gap(22))
        add(makeDashedGroup())
        add(makeProgressCard())
        add(makeRecentWrap())
    }

    private func add(_ view: NSView) {
        stack.addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -56).isActive = true
    }

    private func makeHeader() -> NSView {
        let block = NSStackView()
        block.orientation = .vertical
        block.alignment = .leading
        block.spacing = 8

        let kicker = NSStackView()
        kicker.orientation = .horizontal
        kicker.alignment = .centerY
        kicker.spacing = 6
        kicker.addArrangedSubview(times("DOWNLOADER", size: 11, color: Paper.rust, kern: 1.4))
        kicker.addArrangedSubview(times("·", size: 11, color: Paper.rust))
        kicker.addArrangedSubview(glyph("视频下载", 12, Paper.rust))

        let titles = NSStackView()
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 4
        titles.addArrangedSubview(glyph("轻取", 48, Paper.ink, title: true))
        titles.addArrangedSubview(glyph("粘贴链接，选好清晰度，一键保存到本机", 14, Paper.meta))

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        titles.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(titles)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        row.addArrangedSubview(spacer)
        let circle = CircleDown()
        circle.onClick = { [weak self] in
            guard let self, self.model.canDownload else { return }
            self.model.start()
        }
        circle.widthAnchor.constraint(equalToConstant: 54).isActive = true
        circle.heightAnchor.constraint(equalToConstant: 54).isActive = true
        row.addArrangedSubview(circle)

        block.addArrangedSubview(kicker)
        block.addArrangedSubview(row)
        block.addArrangedSubview(gap(8))
        block.addArrangedSubview(hairline())
        kicker.widthAnchor.constraint(equalTo: block.widthAnchor).isActive = true
        row.widthAnchor.constraint(equalTo: block.widthAnchor).isActive = true
        return block
    }

    private func makeLinkField() -> NSView {
        let box = Card(radius: 16)
        box.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        icon.contentTintColor = Paper.faint
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)

        urlField.isBordered = false
        urlField.drawsBackground = false
        urlField.focusRingType = .none
        urlField.font = AppFonts.nsBody(15)
        urlField.textColor = Paper.url
        urlField.placeholderAttributedString = NSAttributedString(
            string: "粘贴视频链接",
            attributes: [.font: AppFonts.nsBody(15), .foregroundColor: Paper.faint]
        )
        urlField.delegate = self
        urlField.target = self
        urlField.action = #selector(submitLink)
        urlField.cell?.sendsActionOnEndEditing = false
        urlField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        urlField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let pasteLabel = glyph("粘贴", 13, Paper.rust, centered: true)
        let shortcut = GlyphField(centersInk: true)
        shortcut.configure(text: "⌘V", font: AppFonts.times(12), color: Paper.rust, alignment: .center, lineLimit: 1, tracking: 0)
        let pasteRow = NSStackView()
        pasteRow.orientation = .horizontal
        pasteRow.alignment = .centerY
        pasteRow.spacing = 5
        pasteRow.addArrangedSubview(pasteLabel)
        pasteRow.addArrangedSubview(shortcut)
        pasteBox.wantsLayer = true
        pasteBox.layer?.backgroundColor = Paper.blush.cgColor
        pasteBox.layer?.cornerRadius = 12
        pasteBox.addSubview(pasteRow)
        pasteRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pasteRow.leadingAnchor.constraint(equalTo: pasteBox.leadingAnchor, constant: 10),
            pasteRow.trailingAnchor.constraint(equalTo: pasteBox.trailingAnchor, constant: -10),
            pasteRow.topAnchor.constraint(equalTo: pasteBox.topAnchor, constant: 5),
            pasteRow.bottomAnchor.constraint(equalTo: pasteBox.bottomAnchor, constant: -5)
        ])
        pasteBox.onClick = { [weak self] in
            self?.model.pasteFromClipboard()
            self?.window?.makeFirstResponder(self?.urlField)
        }

        checkBadge.widthAnchor.constraint(equalToConstant: 22).isActive = true
        checkBadge.heightAnchor.constraint(equalToConstant: 22).isActive = true
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.widthAnchor.constraint(equalToConstant: 18).isActive = true
        spinner.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.addArrangedSubview(icon)
        row.addArrangedSubview(urlField)
        row.addArrangedSubview(pasteBox)
        row.addArrangedSubview(spinner)
        row.addArrangedSubview(checkBadge)
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        box.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ])
        return box
    }

    private func makePreview() -> NSView {
        previewWrap.orientation = .vertical
        previewWrap.alignment = .leading
        previewWrap.spacing = 14
        previewWrap.addArrangedSubview(gap(0))

        let card = Card(radius: 16)
        let textCol = NSStackView()
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 4

        let siteRow = NSStackView()
        siteRow.orientation = .horizontal
        siteRow.alignment = .centerY
        siteRow.spacing = 5
        siteLabel.font = AppFonts.times(11)
        siteLabel.textColor = Paper.rust
        parsedMark.configure(text: "已解析", font: AppFonts.nsBody(12), color: Paper.rust, alignment: .left, lineLimit: 1, tracking: 0)
        let dot = times("·", size: 11, color: Paper.rust)
        siteRow.addArrangedSubview(siteLabel)
        siteRow.addArrangedSubview(dot)
        siteRow.addArrangedSubview(parsedMark)

        titleGlyph.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleGlyph.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textCol.addArrangedSubview(siteRow)
        textCol.addArrangedSubview(titleGlyph)
        textCol.addArrangedSubview(detailGlyph)
        titleGlyph.widthAnchor.constraint(equalTo: textCol.widthAnchor).isActive = true

        thumb.widthAnchor.constraint(equalToConstant: 124).isActive = true
        thumb.heightAnchor.constraint(equalToConstant: 74).isActive = true
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        row.addArrangedSubview(thumb)
        textCol.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(textCol)
        card.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            textCol.widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])
        previewWrap.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: previewWrap.widthAnchor).isActive = true
        previewWrap.isHidden = true
        return previewWrap
    }

    private func makeModeTrack() -> NSView {
        let track = NSView()
        track.wantsLayer = true
        track.layer?.backgroundColor = Paper.track.withAlphaComponent(Paper.usesGlass ? 0.25 : 1).cgColor
        track.layer?.cornerRadius = 13
        track.heightAnchor.constraint(equalToConstant: 44).isActive = true
        videoChip.onClick = { [weak self] in self?.model.mode = .video }
        audioChip.onClick = { [weak self] in self?.model.mode = .audio }
        track.addSubview(videoChip)
        track.addSubview(audioChip)
        videoChip.translatesAutoresizingMaskIntoConstraints = false
        audioChip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            videoChip.leadingAnchor.constraint(equalTo: track.leadingAnchor, constant: 4),
            videoChip.topAnchor.constraint(equalTo: track.topAnchor, constant: 4),
            videoChip.bottomAnchor.constraint(equalTo: track.bottomAnchor, constant: -4),
            audioChip.trailingAnchor.constraint(equalTo: track.trailingAnchor, constant: -4),
            audioChip.topAnchor.constraint(equalTo: videoChip.topAnchor),
            audioChip.bottomAnchor.constraint(equalTo: videoChip.bottomAnchor),
            audioChip.leadingAnchor.constraint(equalTo: videoChip.trailingAnchor, constant: 4),
            videoChip.widthAnchor.constraint(equalTo: audioChip.widthAnchor)
        ])
        return track
    }

    private func makeQualityRow() -> NSView {
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 2
        for quality in [VideoQuality.q2160, .q1440, .q1080, .q720, .q480] {
            let pill = Pill(title: quality.pill)
            pill.onClick = { [weak self] in self?.model.quality = quality }
            qualityPills[quality] = pill
            controls.addArrangedSubview(pill)
        }
        let row = optionRow(chinese: "清晰度", english: "QUALITY", controls: controls)
        qualityRow.orientation = .vertical
        qualityRow.addArrangedSubview(row)
        return qualityRow
    }

    private func makeVideoFormats() -> NSView {
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 2
        controls.alignment = .centerY
        for item in [VideoContainer.mp4, .mkv, .webm] {
            let pill = Pill(title: item.title)
            pill.onClick = { [weak self] in self?.model.container = item }
            videoPills[item] = pill
            controls.addArrangedSubview(pill)
        }
        videoFormatRow.orientation = .vertical
        videoFormatRow.addArrangedSubview(optionRow(chinese: "格式", english: "FORMAT", controls: controls))
        return videoFormatRow
    }

    private func makeAudioFormats() -> NSView {
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 2
        controls.alignment = .centerY
        for item in AudioFormat.allCases {
            let pill = Pill(title: item.title)
            pill.onClick = { [weak self] in self?.model.audioFormat = item }
            audioPills[item] = pill
            controls.addArrangedSubview(pill)
        }
        audioFormatRow.orientation = .vertical
        audioFormatRow.addArrangedSubview(optionRow(chinese: "格式", english: "FORMAT", controls: controls))
        audioFormatRow.isHidden = true
        return audioFormatRow
    }

    private func makeCookieRow() -> NSView {
        let labels = NSStackView()
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        labels.addArrangedSubview(times("Cookie", size: 16, color: Paper.ink))
        labels.addArrangedSubview(glyph("登录状态", 11, Paper.meta))

        cookiePopup.isBordered = false
        cookiePopup.font = AppFonts.nsBody(13)
        cookiePopup.addItems(withTitles: CookieBrowser.allCases.map(\.title))
        if let cell = cookiePopup.cell as? NSPopUpButtonCell {
            cell.arrowPosition = .noArrow
        }
        cookiePopup.target = self
        cookiePopup.action = #selector(cookiePicked)
        let diamond = times("◇", size: 10, color: Paper.meta)
        let right = NSStackView()
        right.orientation = .horizontal
        right.alignment = .centerY
        right.spacing = 4
        right.addArrangedSubview(cookiePopup)
        right.addArrangedSubview(diamond)

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.addArrangedSubview(labels)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(right)
        row.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 4, right: 0)
        return row
    }

    private func makeDashedGroup() -> NSView {
        dashedGroup.orientation = .vertical
        dashedGroup.alignment = .centerX
        dashedGroup.spacing = 10

        errorGlyph.isHidden = true
        let plate = DashedPlate()
        let box = HoverClick()
        box.addSubview(plate)
        box.addSubview(dashedTitle)
        plate.translatesAutoresizingMaskIntoConstraints = false
        dashedTitle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            plate.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            plate.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            plate.topAnchor.constraint(equalTo: box.topAnchor),
            plate.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            dashedTitle.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            dashedTitle.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            box.heightAnchor.constraint(equalToConstant: 74)
        ])
        box.onClick = { [weak self] in
            guard let self else { return }
            if self.model.phase == .failed || self.model.canDownload || !self.model.missingTools.isEmpty {
                self.model.primaryAction()
            }
        }

        captionGlyph.configure(text: " ", font: AppFonts.nsBody(12), color: Paper.faint, alignment: .center, lineLimit: 2, tracking: 0)
        toolsGlyph.isHidden = true
        let copyLabel = glyph("复制安装命令", 12, Paper.rust, centered: true)
        copyInstall.addSubview(copyLabel)
        copyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            copyLabel.leadingAnchor.constraint(equalTo: copyInstall.leadingAnchor),
            copyLabel.trailingAnchor.constraint(equalTo: copyInstall.trailingAnchor),
            copyLabel.topAnchor.constraint(equalTo: copyInstall.topAnchor),
            copyLabel.bottomAnchor.constraint(equalTo: copyInstall.bottomAnchor)
        ])
        copyInstall.isHidden = true
        copyInstall.onClick = { [weak self] in self?.model.copyInstallCommand() }

        dashedGroup.addArrangedSubview(errorGlyph)
        dashedGroup.addArrangedSubview(box)
        dashedGroup.addArrangedSubview(captionGlyph)
        dashedGroup.addArrangedSubview(toolsGlyph)
        dashedGroup.addArrangedSubview(copyInstall)
        errorGlyph.widthAnchor.constraint(equalTo: dashedGroup.widthAnchor).isActive = true
        box.widthAnchor.constraint(equalTo: dashedGroup.widthAnchor).isActive = true
        captionGlyph.widthAnchor.constraint(equalTo: dashedGroup.widthAnchor).isActive = true
        toolsGlyph.widthAnchor.constraint(equalTo: dashedGroup.widthAnchor).isActive = true
        return dashedGroup
    }

    private func makeProgressCard() -> NSView {
        progressCard.isHidden = true
        let top = NSStackView()
        top.orientation = .horizontal
        top.alignment = .centerY
        top.spacing = 10
        percentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        top.addArrangedSubview(percentLabel)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        top.addArrangedSubview(spacer)
        let dot = Dot()
        dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
        top.addArrangedSubview(dot)
        top.addArrangedSubview(statusGlyph)
        pauseButton.onClick = { [weak self] in self?.model.togglePause() }
        cancelButton.onClick = { [weak self] in self?.model.cancel() }
        openButton.onClick = { [weak self] in self?.model.revealInFinder() }
        againButton.onClick = { [weak self] in self?.model.resetForNext() }
        top.addArrangedSubview(pauseButton)
        top.addArrangedSubview(cancelButton)
        top.addArrangedSubview(openButton)
        top.addArrangedSubview(againButton)

        blockBar.heightAnchor.constraint(equalToConstant: 13).isActive = true
        fractionLabel.font = AppFonts.times(12)
        fractionLabel.textColor = Paper.meta
        trailingLabel.font = AppFonts.nsBody(12)
        trailingLabel.textColor = Paper.meta
        trailingLabel.alignment = .right
        trailingLabel.lineBreakMode = .byTruncatingMiddle
        let bottom = NSStackView()
        bottom.orientation = .horizontal
        bottom.alignment = .centerY
        bottom.addArrangedSubview(fractionLabel)
        let spacer2 = NSView()
        spacer2.setContentHuggingPriority(.init(1), for: .horizontal)
        bottom.addArrangedSubview(spacer2)
        bottom.addArrangedSubview(trailingLabel)

        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 10
        inner.addArrangedSubview(top)
        inner.addArrangedSubview(blockBar)
        inner.addArrangedSubview(bottom)
        progressCard.addSubview(inner)
        inner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: progressCard.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: progressCard.trailingAnchor, constant: -16),
            inner.topAnchor.constraint(equalTo: progressCard.topAnchor, constant: 14),
            inner.bottomAnchor.constraint(equalTo: progressCard.bottomAnchor, constant: -14),
            top.widthAnchor.constraint(equalTo: inner.widthAnchor),
            blockBar.widthAnchor.constraint(equalTo: inner.widthAnchor),
            bottom.widthAnchor.constraint(equalTo: inner.widthAnchor)
        ])
        return progressCard
    }

    private func makeRecentWrap() -> NSView {
        recentWrap.orientation = .vertical
        recentWrap.alignment = .leading
        recentWrap.spacing = 0
        recentWrap.isHidden = true
        return recentWrap
    }

    private func rebuildRecents(_ items: [RecentDownload]) {
        for view in recentWrap.arrangedSubviews {
            recentWrap.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        guard !items.isEmpty else { return }
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        let title = section("RECENT", "最近下载")
        title.setContentHuggingPriority(.init(1), for: .horizontal)
        let clear = OutlineButton(title: "清空")
        clear.toolTip = "仅清空最近下载记录，不删除下载文件"
        clear.onClick = { [weak self] in self?.model.clearRecentDownloads() }
        header.addArrangedSubview(title)
        header.addArrangedSubview(clear)
        recentWrap.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: recentWrap.widthAnchor).isActive = true
        for (index, item) in items.enumerated() {
            let row = recentRow(number: index + 1, item: item)
            recentWrap.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: recentWrap.widthAnchor).isActive = true
            let line = hairline()
            recentWrap.addArrangedSubview(line)
            line.widthAnchor.constraint(equalTo: recentWrap.widthAnchor).isActive = true
        }
    }

    private func recentRow(number: Int, item: RecentDownload) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.edgeInsets = NSEdgeInsets(top: 11, left: 0, bottom: 11, right: 0)
        let index = times(String(format: "%02d", number), size: 13, color: Paper.meta)
        index.widthAnchor.constraint(equalToConstant: 28).isActive = true
        let title = glyph(item.title, 14, Paper.ink)
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spec = times(item.spec, size: 12, color: Paper.meta, italic: true)
        spec.lineBreakMode = .byTruncatingTail
        spec.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        let open = HoverClick()
        let openLabel = glyph("打开", 13, Paper.rust)
        open.addSubview(openLabel)
        openLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            openLabel.leadingAnchor.constraint(equalTo: open.leadingAnchor),
            openLabel.trailingAnchor.constraint(equalTo: open.trailingAnchor),
            openLabel.topAnchor.constraint(equalTo: open.topAnchor),
            openLabel.bottomAnchor.constraint(equalTo: open.bottomAnchor)
        ])
        open.onClick = { [weak self] in self?.model.openRecent(item) }
        row.addArrangedSubview(index)
        row.addArrangedSubview(title)
        row.addArrangedSubview(spec)
        row.addArrangedSubview(open)
        return row
    }

    private func makeFooter() -> NSView {
        let wrap = NSView()
        wrap.wantsLayer = true
        wrap.layer?.backgroundColor = Paper.background.cgColor
        let line = hairline()
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        let folder = HoverClick()
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        icon.contentTintColor = Paper.ink.withAlphaComponent(0.75)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        folderLabel.font = AppFonts.nsBody(13)
        folderLabel.textColor = Paper.ink.withAlphaComponent(0.8)
        folderLabel.lineBreakMode = .byTruncatingMiddle
        folderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        changeMark.configure(text: "更改", font: AppFonts.nsBody(13), color: Paper.rust, alignment: .left, lineLimit: 1, tracking: 0)
        let folderRow = NSStackView()
        folderRow.orientation = .horizontal
        folderRow.alignment = .centerY
        folderRow.spacing = 8
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 14).isActive = true
        folderRow.addArrangedSubview(icon)
        folderRow.addArrangedSubview(folderLabel)
        folderRow.addArrangedSubview(changeMark)
        folder.addSubview(folderRow)
        folderRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            folderRow.leadingAnchor.constraint(equalTo: folder.leadingAnchor),
            folderRow.trailingAnchor.constraint(equalTo: folder.trailingAnchor),
            folderRow.topAnchor.constraint(equalTo: folder.topAnchor),
            folderRow.bottomAnchor.constraint(equalTo: folder.bottomAnchor)
        ])
        folder.onClick = { [weak self] in
            guard let self, self.model.phase != .running else { return }
            self.model.chooseFolder()
        }

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        row.addArrangedSubview(folder)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(footerShortcut("⌘V", "粘贴") { [weak self] in
            guard let self, self.model.phase != .running else { return }
            self.model.pasteFromClipboard()
            self.window?.makeFirstResponder(self.urlField)
        })

        wrap.addSubview(line)
        wrap.addSubview(row)
        line.translatesAutoresizingMaskIntoConstraints = false
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: wrap.topAnchor),
            line.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            row.topAnchor.constraint(equalTo: line.bottomAnchor, constant: 10),
            row.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 22),
            row.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -22),
            row.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -12)
        ])
        return wrap
    }

    private func footerShortcut(_ keys: String, _ title: String, action: @escaping () -> Void) -> NSView {
        let box = HoverClick()
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 4
        row.addArrangedSubview(times(keys, size: 12, color: Paper.meta))
        row.addArrangedSubview(glyph(title, 12, Paper.meta))
        box.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 6),
            row.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            row.topAnchor.constraint(equalTo: box.topAnchor),
            row.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
        box.onClick = action
        return box
    }

    private func optionRow(chinese: String, english: String, controls: NSView) -> NSView {
        let labels = NSStackView()
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        labels.addArrangedSubview(glyph(chinese, 15, Paper.ink))
        labels.addArrangedSubview(times(english, size: 10, color: Paper.faint, kern: 1.3))
        labels.widthAnchor.constraint(equalToConstant: 72).isActive = true
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        row.addArrangedSubview(labels)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(controls)
        return row
    }

    private func section(_ english: String, _ chinese: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.addArrangedSubview(times(english, size: 11, color: Paper.meta, kern: 1.6))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(glyph(chinese, 12, Paper.meta))
        return row
    }

    private func gap(_ height: CGFloat) -> NSView {
        let view = NSView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    private func hairline() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Paper.line.cgColor
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    private func glyph(_ text: String, _ size: CGFloat, _ color: NSColor, title: Bool = false, centered: Bool = false) -> GlyphField {
        let view = GlyphField(centersInk: centered)
        view.configure(
            text: text,
            font: title ? AppFonts.nsTitle(size) : AppFonts.nsBody(size),
            color: color,
            alignment: .left,
            lineLimit: 1,
            tracking: 0
        )
        return view
    }

    private func times(_ text: String, size: CGFloat, color: NSColor, kern: CGFloat = 0, italic: Bool = false) -> PassLabel {
        let label = PassLabel(labelWithString: text)
        let font = AppFonts.times(size, italic: italic)
        label.attributedStringValue = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color, .kern: kern]
        )
        return label
    }

    @objc private func submitLink() {
        if model.canDownload { model.start() }
    }

    @objc private func cookiePicked() {
        guard !applying else { return }
        let index = cookiePopup.indexOfSelectedItem
        let all = CookieBrowser.allCases
        guard all.indices.contains(index) else { return }
        model.cookieBrowser = all[index]
        model.persistCookieBrowser()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard !applying else { return }
        let value = urlField.stringValue
        if model.urlText != value {
            model.urlText = value
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        if let editor = urlField.currentEditor() as? NSTextView {
            editor.insertionPointColor = Paper.rust
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropOverlay.isHidden = false
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropOverlay.isHidden = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropOverlay.isHidden = true
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first, LinkParser.isHTTP(url) {
            model.urlText = url.absoluteString
            return true
        }
        if let text = pasteboard.string(forType: .string), let url = LinkParser.extract(from: text) {
            model.urlText = url.absoluteString
            return true
        }
        return false
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, model.phase == .running {
            model.cancel()
            return
        }
        super.keyDown(with: event)
    }
}

final class TopDocument: NSView {
    override var isFlipped: Bool { true }
}

final class GlyphField: NSView {
    private var store = ""
    private var font = NSFont.systemFont(ofSize: 14)
    private var color = NSColor.labelColor
    private var align: NSTextAlignment = .left
    private var limit = 1
    private var kern: CGFloat = 0
    private var lastWidth: CGFloat = -1
    private let centersInk: Bool
    private var centeredLine: CTLine?
    private var inkBounds = CGRect.zero
    private var lineWidth: CGFloat = 0

    init(centersInk: Bool = false) {
        self.centersInk = centersInk
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(
        text: String,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment,
        lineLimit: Int,
        tracking: CGFloat
    ) {
        let same = store == text
            && self.font.fontName == font.fontName
            && abs(self.font.pointSize - font.pointSize) < 0.2
            && self.color == color
            && align == alignment
            && limit == lineLimit
            && abs(kern - tracking) < 0.2
        guard !same else { return }
        store = text
        self.font = font
        self.color = color
        align = alignment
        limit = max(1, lineLimit)
        kern = tracking
        if centersInk {
            let text = NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: color.cgColor, .kern: tracking
            ])
            let line = CTLineCreateWithAttributedString(text)
            centeredLine = line
            inkBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        }
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    func measured(maxWidth: CGFloat) -> CGSize {
        guard !store.isEmpty else { return CGSize(width: 1, height: 1) }
        let wrap = limit == 1 ? 8000 : max(1, maxWidth)
        let rect = (store as NSString).boundingRect(
            with: NSSize(width: wrap, height: 8000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes()
        )
        let lineHeight = ceil(font.boundingRectForFont.height + 2)
        var height = ceil(rect.height) + 4
        height = min(max(height, lineHeight), lineHeight * CGFloat(limit) + 4)
        let width = limit == 1 ? ceil(rect.width) + 2 : maxWidth
        return CGSize(width: max(1, width), height: height)
    }

    override var intrinsicContentSize: NSSize {
        if limit > 1 {
            let width = bounds.width > 2 ? bounds.width : 280
            return measured(maxWidth: width)
        }
        return measured(maxWidth: 8000)
    }

    override func layout() {
        super.layout()
        if limit > 1, abs(bounds.width - lastWidth) > 0.5 {
            lastWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !store.isEmpty else { return }
        if let line = centeredLine, let context = NSGraphicsContext.current?.cgContext {
            let x: CGFloat
            switch align {
            case .center: x = (bounds.width - lineWidth) / 2
            case .right: x = bounds.width - lineWidth
            default: x = 0
            }
            context.saveGState()
            context.clip(to: bounds)
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: x, y: bounds.height / 2 - inkBounds.midY)
            CTLineDraw(line, context)
            context.restoreGState()
            return
        }
        let box = NSRect(x: 0, y: 1, width: bounds.width, height: max(1, bounds.height - 2))
        (store as NSString).draw(
            with: box,
            options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
            attributes: attributes()
        )
    }

    private func attributes() -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = limit == 1 ? .byTruncatingTail : .byWordWrapping
        style.lineSpacing = font.pointSize * 0.06
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style,
            .kern: kern
        ]
    }
}

final class PassLabel: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBezeled = false
        drawsBackground = false
        isEditable = false
        isSelectable = false
        lineBreakMode = .byTruncatingTail
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

class HoverClick: NSView {
    var onClick: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseUp(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        if bounds.contains(local) { onClick?() }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

final class Card: NSView {
    init(radius: CGFloat = 16) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Paper.surface.cgColor
        layer?.cornerRadius = radius
        layer?.borderWidth = 1
        layer?.borderColor = Paper.cardLine.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

final class DashedPlate: NSView {
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.8, dy: 0.8), xRadius: 16, yRadius: 16)
        let pattern: [CGFloat] = [4, 4]
        path.setLineDash(pattern, count: 2, phase: 0)
        Paper.faint.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

final class CircleDown: HoverClick {
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let oval = NSBezierPath(ovalIn: bounds.insetBy(dx: 1.2, dy: 1.2))
        Paper.ink.setStroke()
        oval.lineWidth = 1.15
        oval.stroke()
        guard let image = NSImage(systemSymbolName: "arrow.down", accessibilityDescription: nil) else { return }
        let configured = image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)) ?? image
        let side: CGFloat = 18
        let box = NSRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        configured.draw(in: box)
    }
}

final class CheckBadge: NSView {
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        Paper.green.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 0.4, dy: 0.4)).fill()
        let path = NSBezierPath()
        let w = bounds.width
        let h = bounds.height
        path.move(to: NSPoint(x: w * 0.28, y: h * 0.52))
        path.line(to: NSPoint(x: w * 0.44, y: h * 0.34))
        path.line(to: NSPoint(x: w * 0.74, y: h * 0.68))
        NSColor.white.setStroke()
        path.lineWidth = 1.7
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}

final class Dot: NSView {
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        Paper.rust.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
}

final class BlockBar: NSView {
    var progress: Double = 0 { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let block: CGFloat = 7
        let gap: CGFloat = 3
        let count = max(16, Int((bounds.width + gap) / (block + gap)))
        let filled = Int((Double(count) * min(max(progress, 0), 1)).rounded())
        let y = (bounds.height - 13) / 2
        for index in 0..<count {
            let rect = NSRect(x: CGFloat(index) * (block + gap), y: y, width: block, height: 13)
            let path = NSBezierPath(roundedRect: rect, xRadius: 1.2, yRadius: 1.2)
            (index < filled ? Paper.ink : Paper.blockOff).setFill()
            path.fill()
        }
    }
}

final class Pill: HoverClick {
    private static let titleFont = AppFonts.times(15)
    private let label = GlyphField(centersInk: true)

    init(title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderColor = Paper.ink.cgColor
        setTitle(title)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            // 保留原选项文字的 18pt 行框，不改变按钮高度。
            label.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func setTitle(_ text: String) {
        label.configure(text: text, font: Self.titleFont, color: Paper.ink, alignment: .center, lineLimit: 1, tracking: 0)
    }

    func setOn(_ on: Bool) {
        layer?.borderWidth = on ? 1.15 : 0
    }
}

final class ModeChip: HoverClick {
    private static let englishFont = AppFonts.times(14, italic: true)
    let chinese = GlyphField(centersInk: true)
    let english = GlyphField(centersInk: true)
    private let title: String
    private let englishText: String

    init(title: String, english englishText: String) {
        self.title = title
        self.englishText = englishText
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        chinese.configure(text: title, font: AppFonts.nsBody(15), color: Paper.ink, alignment: .center, lineLimit: 1, tracking: 0)
        english.configure(text: englishText, font: Self.englishFont, color: Paper.ink, alignment: .center, lineLimit: 1, tracking: 0)
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.addArrangedSubview(chinese)
        row.addArrangedSubview(english)
        addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func setOn(_ on: Bool) {
        layer?.backgroundColor = (on ? Paper.ink : NSColor.clear).cgColor
        chinese.configure(
            text: title,
            font: AppFonts.nsBody(15),
            color: on ? .white : Paper.ink,
            alignment: .center,
            lineLimit: 1,
            tracking: 0
        )
        english.configure(text: englishText, font: Self.englishFont, color: on ? .white : Paper.ink.withAlphaComponent(0.82), alignment: .center, lineLimit: 1, tracking: 0)
    }
}

final class OutlineButton: HoverClick {
    private let label = GlyphField(centersInk: true)

    init(title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = Paper.ink.withAlphaComponent(0.22).cgColor
        layer?.backgroundColor = Paper.surface.cgColor
        label.configure(text: title, font: AppFonts.nsBody(13), color: Paper.ink, alignment: .center, lineLimit: 1, tracking: 0)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5)
        ])
        identifier = NSUserInterfaceItemIdentifier(title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func setTitle(_ text: String) {
        label.configure(text: text, font: AppFonts.nsBody(13), color: Paper.ink, alignment: .center, lineLimit: 1, tracking: 0)
    }
}

final class ThumbView: NSView {
    private let imageView = NSImageView()
    private let badge = NSView()
    private let duration = PassLabel(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        imageView.imageScaling = .scaleAxesIndependently
        imageView.imageAlignment = .alignCenter
        addSubview(imageView)
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        badge.layer?.cornerRadius = 3
        duration.font = AppFonts.times(10)
        duration.textColor = .white
        duration.alignment = .center
        addSubview(badge)
        badge.addSubview(duration)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func setImage(_ image: NSImage?, duration text: String?) {
        imageView.image = image
        imageView.isHidden = image == nil
        if image == nil { needsDisplay = true }
        if let text, !text.isEmpty {
            duration.stringValue = text
            badge.isHidden = false
        } else {
            badge.isHidden = true
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
        duration.sizeToFit()
        let width = duration.frame.width + 10
        let height = max(14, duration.frame.height + 3)
        badge.frame = NSRect(x: bounds.width - width - 5, y: 5, width: width, height: height)
        duration.frame = NSRect(x: 5, y: 1, width: duration.frame.width, height: height - 2)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard imageView.image == nil else { return }
        let gradient = NSGradient(colors: [
            NSColor(srgbRed: 0.16, green: 0.18, blue: 0.26, alpha: 1),
            NSColor(srgbRed: 0.42, green: 0.28, blue: 0.18, alpha: 1)
        ])
        gradient?.draw(in: bounds, angle: -90)
    }
}

