import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var dropTargeted = false

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                hero
                    .padding(.top, 8)
                field
                    .padding(.top, 18)
                metaRow
                    .padding(.top, 8)
                modePicker
                    .padding(.top, 16)
                optionsBlock
                    .padding(.top, 14)
                primaryButton
                    .padding(.top, 18)
                secondaryRow
                    .padding(.top, 10)
                Spacer(minLength: 24)
                footer
            }
            .frame(width: 392)
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 18)
            Spacer(minLength: 0)
        }
        .frame(minWidth: 440, minHeight: 660)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowConfigurator(closer: WindowCloser.shared).frame(width: 0, height: 0))
        .onDrop(of: [UTType.url, UTType.plainText, UTType.utf8PlainText], isTargeted: $dropTargeted) { providers in
            model.handleDrop(providers)
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .padding(10)
            }
        }
        .onAppear { model.adoptClipboardIfEmpty() }
        .onExitCommand {
            if model.phase == .running { model.cancel() }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(heroFill)
                    .frame(width: 78, height: 78)
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    .frame(width: 78, height: 78)
                if model.phase == .running {
                    Circle()
                        .trim(from: 0, to: max(model.progress, 0.03))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .frame(width: 78, height: 78)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.2), value: model.progress)
                }
                Image(systemName: heroSymbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(heroTint)
                    .symbolRenderingMode(.monochrome)
            }
            VStack(spacing: 4) {
                Text(model.heroTitle)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(model.heroSubtitle)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 360)
            }
        }
        .animation(.spring(duration: 0.32, bounce: 0.12), value: model.phase)
    }

    private var field: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("粘贴视频链接", text: $model.urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5))
                .disableAutocorrection(true)
                .onSubmit { if model.canDownload { model.start() } }
            if model.urlText.isEmpty {
                Button("粘贴") { model.pasteFromClipboard() }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            } else if model.phase != .running {
                Button {
                    model.urlText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .disabled(model.phase == .running)
    }

    @ViewBuilder
    private var metaRow: some View {
        HStack(spacing: 8) {
            if let site = model.siteLabel {
                Label(site, systemImage: "play.rectangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            if model.isProbing {
                ProgressView()
                    .controlSize(.mini)
            } else if let note = model.probeNote {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 16)
    }

    private var modePicker: some View {
        @Bindable var model = model
        return Picker("类型", selection: $model.mode) {
            ForEach(MediaMode.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(model.phase == .running)
        .controlSize(.regular)
    }

    private var optionsBlock: some View {
        @Bindable var model = model
        return VStack(spacing: 10) {
            if model.mode == .video {
                optionRow(title: "清晰度") {
                    Picker("清晰度", selection: $model.quality) {
                        ForEach(VideoQuality.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                optionRow(title: "格式") {
                    Picker("格式", selection: $model.container) {
                        ForEach(VideoContainer.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            } else {
                optionRow(title: "音频") {
                    Picker("音频", selection: $model.audioFormat) {
                        ForEach(AudioFormat.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }

            optionRow(title: "Cookie") {
                Picker("Cookie", selection: $model.cookieBrowser) {
                    ForEach(CookieBrowser.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .onChange(of: model.cookieBrowser) { _, _ in
                    model.persistCookieBrowser()
                }
            }

            if let hint = model.cookiesHint, model.cookieBrowser == .none {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035))
        )
        .disabled(model.phase == .running)
    }

    private func optionRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            content()
                .font(.system(size: 12.5, weight: .medium))
        }
        .frame(minHeight: 24)
    }

    private var primaryButton: some View {
        Button(action: model.primaryAction) {
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(buttonFill)
                    .frame(height: 38)
                if model.phase == .running {
                    GeometryReader { geo in
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.16))
                            .frame(width: max(8, geo.size.width * model.progress), height: 38)
                    }
                    .frame(height: 38)
                    .clipShape(Capsule(style: .continuous))
                }
                HStack(spacing: 6) {
                    if model.phase == .running {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9, weight: .bold))
                    }
                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(buttonEnabled ? Color.white : Color.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .disabled(!buttonEnabled)
        .keyboardShortcut(.defaultAction)
        .shadow(color: buttonEnabled && model.phase != .running ? Color.accentColor.opacity(0.28) : .clear, radius: 8, y: 3)
    }

    @ViewBuilder
    private var secondaryRow: some View {
        if model.phase == .success {
            Button("在访达中显示") { model.revealInFinder() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        } else if !model.missingTools.isEmpty {
            Button("复制安装命令") { model.copyInstallCommand() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        } else {
            Text(model.formatSummary)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.bottom, 10)
            HStack(spacing: 12) {
                Button(action: model.chooseFolder) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11, weight: .medium))
                        Text(model.folderLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.quaternary)
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(model.phase == .running)

                Spacer(minLength: 8)

                Text("⌃⌘F 全屏")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    private var heroSymbol: String {
        switch model.phase {
        case .idle: return "arrow.down.to.line"
        case .running: return "arrow.down.to.line"
        case .success: return "checkmark"
        case .failed: return "exclamationmark"
        }
    }

    private var heroTint: Color {
        switch model.phase {
        case .idle: return .accentColor
        case .running: return .accentColor
        case .success: return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .failed: return Color(red: 1.00, green: 0.27, blue: 0.23)
        }
    }

    private var heroFill: Color {
        heroTint.opacity(colorScheme == .dark ? 0.16 : 0.10)
    }

    private var buttonTitle: String {
        switch model.phase {
        case .idle: return model.missingTools.isEmpty ? "下载" : "重新检测"
        case .running: return "取消"
        case .success: return "再下一个"
        case .failed: return "重试"
        }
    }

    private var buttonEnabled: Bool {
        switch model.phase {
        case .idle: return model.canDownload || !model.missingTools.isEmpty
        case .running, .success, .failed: return true
        }
    }

    private var buttonFill: Color {
        if !buttonEnabled { return Color.primary.opacity(0.08) }
        switch model.phase {
        case .running: return Color.accentColor.opacity(0.85)
        case .failed: return Color(red: 1.00, green: 0.27, blue: 0.23)
        default: return Color.accentColor
        }
    }
}
