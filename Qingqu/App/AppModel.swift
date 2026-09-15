import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

enum MediaMode: String, CaseIterable, Identifiable {
    case video
    case audio
    var id: String { rawValue }
    var title: String { self == .video ? "视频" : "音频" }
}

enum VideoQuality: String, CaseIterable, Identifiable {
    case auto, q2160, q1080, q720, q480, q360
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: return "自动最佳"
        case .q2160: return "4K · 2160p"
        case .q1080: return "1080p"
        case .q720: return "720p"
        case .q480: return "480p"
        case .q360: return "360p"
        }
    }
    var maxHeight: Int? {
        switch self {
        case .auto: return nil
        case .q2160: return 2160
        case .q1080: return 1080
        case .q720: return 720
        case .q480: return 480
        case .q360: return 360
        }
    }
}

enum VideoContainer: String, CaseIterable, Identifiable {
    case mp4, mkv, webm, keep
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mp4: return "MP4"
        case .mkv: return "MKV"
        case .webm: return "WebM"
        case .keep: return "原格式"
        }
    }
}

enum AudioFormat: String, CaseIterable, Identifiable {
    case m4a, mp3, opus, flac
    var id: String { rawValue }
    var title: String {
        switch self {
        case .m4a: return "M4A"
        case .mp3: return "MP3"
        case .opus: return "Opus"
        case .flac: return "FLAC"
        }
    }
}

enum CookieBrowser: String, CaseIterable, Identifiable {
    case none, safari, chrome, edge
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "不使用"
        case .safari: return "Safari"
        case .chrome: return "Chrome"
        case .edge: return "Edge"
        }
    }
}

enum Phase: Equatable {
    case idle
    case running
    case success
    case failed
}

enum LinkParser {
    static func extract(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), isHTTP(url) { return url }
        let types = NSTextCheckingResult.CheckingType.link.rawValue
        guard let detector = try? NSDataDetector(types: types) else { return nil }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        if let match = detector.firstMatch(in: trimmed, options: [], range: range),
           let url = match.url, isHTTP(url) {
            return url
        }
        return nil
    }

    static func isHTTP(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "")
    }

    static func siteName(for raw: String) -> String? {
        guard let host = extract(from: raw)?.host?.lowercased() else { return nil }
        if host.contains("bilibili") || host.hasSuffix("b23.tv") || host.contains("b23.tv") { return "哔哩哔哩" }
        if host.contains("youtube") || host == "youtu.be" { return "YouTube" }
        if host.contains("douyin") || host.contains("iesdouyin") { return "抖音" }
        if host.contains("tiktok") { return "TikTok" }
        if host.contains("xiaohongshu") || host.contains("xhslink") || host.contains("xhscdn") { return "小红书" }
        if host == "x.com" || host.contains("twitter") { return "X" }
        if host.contains("instagram") { return "Instagram" }
        if host.contains("vimeo") { return "Vimeo" }
        if host.contains("weibo") { return "微博" }
        if host.contains("iqiyi") { return "爱奇艺" }
        if host.contains("youku") { return "优酷" }
        if host.contains("qq.com") { return "腾讯视频" }
        if host.contains("nicovideo") { return "niconico" }
        if host.contains("twitch") { return "Twitch" }
        if host.contains("facebook") || host.contains("fb.watch") { return "Facebook" }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    static func needsCookiesHint(for raw: String) -> String? {
        guard let site = siteName(for: raw) else { return nil }
        if site == "小红书" {
            return "小红书常需登录态，建议开启浏览器 Cookie"
        }
        if site == "哔哩哔哩" {
            return "大会员高码率需登录 Cookie"
        }
        return nil
    }
}

struct Toolchain {
    let ytDlp: String
    let ffmpeg: String

    static let searchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/opt/local/bin"
    ]

    static func resolve() -> Toolchain? {
        guard let yt = find("yt-dlp"), let ff = find("ffmpeg") else { return nil }
        return Toolchain(ytDlp: yt, ffmpeg: ff)
    }

    static func missingNames() -> [String] {
        var missing: [String] = []
        if find("yt-dlp") == nil { missing.append("yt-dlp") }
        if find("ffmpeg") == nil { missing.append("ffmpeg") }
        return missing
    }

    static func find(_ name: String) -> String? {
        for dir in searchPaths {
            let path = (dir as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return which(name)
    }

    static func which(_ name: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", "which \(name)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let path, FileManager.default.isExecutableFile(atPath: path) { return path }
        } catch {}
        return nil
    }

    var pathEnvironment: String {
        let extra = Self.searchPaths.joined(separator: ":")
        let current = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        return "\(extra):\(current)"
    }
}

@MainActor
@Observable
final class AppModel {
    var urlText = "" {
        didSet {
            if urlText != oldValue {
                scheduleProbe()
            }
        }
    }
    var mode: MediaMode = .video
    var quality: VideoQuality = .q1080
    var container: VideoContainer = .mp4
    var audioFormat: AudioFormat = .m4a
    var cookieBrowser: CookieBrowser = .none
    var phase: Phase = .idle
    var progress: Double = 0
    var speedText = ""
    var etaText = ""
    var statusText = ""
    var filename = ""
    var fileSizeText = ""
    var outputURL: URL?
    var errorMessage: String?
    var saveFolder: URL
    var missingTools: [String] = []
    var isProbing = false
    var probedTitle: String?
    var availableHeights: [Int] = []
    var probeNote: String?

    var siteLabel: String? { LinkParser.siteName(for: urlText) }
    var cookiesHint: String? { LinkParser.needsCookiesHint(for: urlText) }
    var canDownload: Bool {
        LinkParser.extract(from: urlText) != nil && phase != .running && missingTools.isEmpty
    }

    var folderLabel: String {
        let home = NSHomeDirectory()
        var path = saveFolder.path
        if path.hasPrefix(home) {
            path = "~" + String(path.dropFirst(home.count))
        }
        return path.replacingOccurrences(of: "/Downloads/", with: "/下载/")
            .replacingOccurrences(of: "~/Downloads", with: "~/下载")
    }

    var heroTitle: String {
        switch phase {
        case .idle: return "轻取"
        case .running: return progress > 0 ? "\(Int((progress * 100).rounded()))%" : "准备中"
        case .success: return "已保存"
        case .failed: return "未能完成"
        }
    }

    var heroSubtitle: String {
        switch phase {
        case .idle:
            if !missingTools.isEmpty {
                return "需要先安装 \(missingTools.joined(separator: " 和 "))"
            }
            if isProbing { return "正在识别清晰度…" }
            if let title = probedTitle, !title.isEmpty { return title }
            return "粘贴链接，选择清晰度后下载"
        case .running:
            if !filename.isEmpty { return filename }
            if !statusText.isEmpty { return statusText }
            return "正在解析视频…"
        case .success:
            let size = fileSizeText.isEmpty ? "" : " · \(fileSizeText)"
            return (filename.isEmpty ? "下载完成" : filename) + size
        case .failed:
            return errorMessage ?? "请检查链接后重试"
        }
    }

    var formatSummary: String {
        if mode == .audio {
            return "导出 \(audioFormat.title) 音频"
        }
        let q = quality.title
        let c = container.title
        if availableHeights.isEmpty {
            return "\(q) · \(c)"
        }
        let maxH = availableHeights.max() ?? 0
        return "\(q) · \(c) · 源最高 \(maxH)p"
    }

    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var lineBuffer = ""
    @ObservationIgnored private var lastFilePath: String?
    @ObservationIgnored private var probeTask: Task<Void, Never>?
    @ObservationIgnored private var probeToken = 0

    init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        if let data = UserDefaults.standard.data(forKey: "saveFolderBookmark"),
           let url = Self.resolveBookmark(data) {
            saveFolder = url
        } else {
            saveFolder = downloads.appendingPathComponent("轻取", isDirectory: true)
        }
        if let raw = UserDefaults.standard.string(forKey: "cookieBrowser"),
           let browser = CookieBrowser(rawValue: raw) {
            cookieBrowser = browser
        }
        refreshTools()
    }

    func refreshTools() {
        missingTools = Toolchain.missingNames()
    }

    func adoptClipboardIfEmpty() {
        guard phase == .idle, urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        pasteFromClipboard()
    }

    func pasteFromClipboard() {
        let pb = NSPasteboard.general
        let raw = pb.string(forType: .string) ?? pb.string(forType: .URL) ?? ""
        if let url = LinkParser.extract(from: raw) {
            urlText = url.absoluteString
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                    guard let url else { return }
                    Task { @MainActor in
                        self?.urlText = url.absoluteString
                    }
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                    let raw: String
                    if let string = item as? String {
                        raw = string
                    } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                        raw = string
                    } else {
                        return
                    }
                    Task { @MainActor in
                        if let url = LinkParser.extract(from: raw) {
                            self?.urlText = url.absoluteString
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "选取"
        panel.directoryURL = saveFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveFolder = url
        persistFolder()
    }

    func copyInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("brew install yt-dlp ffmpeg", forType: .string)
    }

    func persistCookieBrowser() {
        UserDefaults.standard.set(cookieBrowser.rawValue, forKey: "cookieBrowser")
        scheduleProbe()
    }

    func primaryAction() {
        switch phase {
        case .idle, .failed:
            start()
        case .running:
            cancel()
        case .success:
            resetForNext()
        }
    }

    func scheduleProbe() {
        probeTask?.cancel()
        probedTitle = nil
        availableHeights = []
        probeNote = nil
        guard LinkParser.extract(from: urlText) != nil, missingTools.isEmpty else {
            isProbing = false
            return
        }
        isProbing = true
        probeToken += 1
        let token = probeToken
        let urlString = urlText
        let cookies = cookieBrowser
        probeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            await self?.probe(urlString: urlString, cookies: cookies, token: token)
        }
    }

    private func probe(urlString: String, cookies: CookieBrowser, token: Int) async {
        guard let tools = Toolchain.resolve(),
              let url = LinkParser.extract(from: urlString) else {
            isProbing = false
            return
        }

        var args = [
            "--no-playlist",
            "--no-warnings",
            "--ignore-config",
            "--skip-download",
            "-J"
        ]
        if cookies != .none {
            args += ["--cookies-from-browser", cookies.rawValue]
        }
        args.append(url.absoluteString)

        let result = await Self.runCapture(
            executable: tools.ytDlp,
            arguments: args,
            path: tools.pathEnvironment
        )

        guard token == probeToken else { return }
        isProbing = false

        guard result.status == 0,
              let data = result.stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let err = result.stderr + result.stdout
            if err.localizedCaseInsensitiveContains("No video formats") {
                probeNote = siteLabel == "小红书"
                    ? "未能解析小红书视频，可换 Cookie 浏览器或更新 yt-dlp"
                    : "未能识别可用清晰度"
            } else if !err.isEmpty {
                probeNote = "识别失败，仍可尝试直接下载"
            }
            return
        }

        probedTitle = (json["title"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = json["formats"] as? [[String: Any]] ?? []
        let heights = Set(formats.compactMap { $0["height"] as? Int }.filter { $0 > 0 })
        availableHeights = heights.sorted(by: >)
        if let maxH = availableHeights.first {
            probeNote = "可下载清晰度至 \(maxH)p"
            // If current quality is higher than available, snap down
            if let qh = quality.maxHeight, qh > maxH {
                quality = Self.nearestQuality(for: maxH)
            }
        } else if !(json["url"] == nil && formats.isEmpty) {
            probeNote = "已识别链接"
        }
    }

    private static func nearestQuality(for height: Int) -> VideoQuality {
        let ordered: [VideoQuality] = [.q2160, .q1080, .q720, .q480, .q360]
        return ordered.first(where: { ($0.maxHeight ?? 0) <= height }) ?? .auto
    }

    func start() {
        refreshTools()
        guard missingTools.isEmpty else {
            phase = .failed
            errorMessage = "未找到 \(missingTools.joined(separator: " 和 "))，请先执行 brew install yt-dlp ffmpeg"
            return
        }
        guard let url = LinkParser.extract(from: urlText) else { return }
        guard let tools = Toolchain.resolve() else { return }

        do {
            try FileManager.default.createDirectory(at: saveFolder, withIntermediateDirectories: true)
        } catch {
            phase = .failed
            errorMessage = "无法创建下载文件夹"
            return
        }

        urlText = url.absoluteString
        phase = .running
        progress = 0
        speedText = ""
        etaText = ""
        statusText = "正在解析视频…"
        filename = ""
        fileSizeText = ""
        outputURL = nil
        errorMessage = nil
        lastFilePath = nil
        lineBuffer = ""
        NSApp.dockTile.badgeLabel = nil

        let outputTemplate = saveFolder
            .appendingPathComponent("%(title).180B.%(ext)s", isDirectory: false)
            .path

        var args = [
            "--no-playlist",
            "--newline",
            "--no-colors",
            "--ignore-config",
            "--no-mtime",
            "--retries", "3",
            "--ffmpeg-location", tools.ffmpeg,
            "--print", "after_move:QINGQU_FILE:%(filepath)s",
            "-o", outputTemplate
        ]

        if cookieBrowser != .none {
            args += ["--cookies-from-browser", cookieBrowser.rawValue]
        }

        args += formatArguments()
        args.append(url.absoluteString)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: tools.ytDlp)
        proc.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = tools.pathEnvironment
        env["PYTHONUNBUFFERED"] = "1"
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] file in
            let data = file.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.ingest(chunk)
            }
        }

        proc.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            Task { @MainActor in
                handle.readabilityHandler = nil
                self?.process = nil
                self?.finish(status: status)
            }
        }

        do {
            try proc.run()
            process = proc
        } catch {
            phase = .failed
            errorMessage = "无法启动下载"
        }
    }

    private func formatArguments() -> [String] {
        if mode == .audio {
            return [
                "-x",
                "--audio-format", audioFormat.rawValue,
                "--audio-quality", "0",
                "-f", "ba/b"
            ]
        }

        var selector: String
        if let height = quality.maxHeight {
            selector = "bv*[height<=\(height)]+ba/b[height<=\(height)]/bv*[height<=\(height)]+ba/b/b[height<=\(height)]/b"
        } else {
            selector = "bv*+ba/b/b"
        }

        // Prefer MP4-compatible streams when remuxing to mp4
        if container == .mp4 {
            if let height = quality.maxHeight {
                selector = "bv*[height<=\(height)][ext=mp4]+ba[ext=m4a]/bv*[height<=\(height)]+ba/b/b"
            } else {
                selector = "bv*[ext=mp4]+ba[ext=m4a]/bv*+ba/b/b"
            }
        }

        var args = ["-f", selector]
        switch container {
        case .mp4:
            args += ["--merge-output-format", "mp4"]
        case .mkv:
            args += ["--merge-output-format", "mkv"]
        case .webm:
            args += ["--merge-output-format", "webm"]
        case .keep:
            break
        }
        return args
    }

    func cancel() {
        process?.terminate()
        process = nil
        phase = .idle
        progress = 0
        statusText = ""
        NSApp.dockTile.badgeLabel = nil
    }

    func revealInFinder() {
        guard let url = outputURL else {
            NSWorkspace.shared.open(saveFolder)
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func resetForNext() {
        phase = .idle
        progress = 0
        urlText = ""
        filename = ""
        fileSizeText = ""
        outputURL = nil
        errorMessage = nil
        statusText = ""
        speedText = ""
        etaText = ""
        probedTitle = nil
        availableHeights = []
        probeNote = nil
        NSApp.dockTile.badgeLabel = nil
    }

    private func ingest(_ chunk: String) {
        lineBuffer += chunk
        var lines = lineBuffer.components(separatedBy: "\n")
        lineBuffer = lines.popLast() ?? ""
        for line in lines {
            parse(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if !lineBuffer.isEmpty {
            parse(lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func parse(_ line: String) {
        guard !line.isEmpty else { return }

        if line.hasPrefix("QINGQU_FILE:") {
            remember(path: String(line.dropFirst("QINGQU_FILE:".count)))
            return
        }
        if line.hasPrefix("ERROR:") {
            errorMessage = Self.humanize(String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces))
            return
        }
        if let dest = value(after: "[download] Destination: ", in: line) {
            remember(path: dest)
            statusText = "正在写入文件…"
            return
        }
        if let dest = value(after: "[Merger] Merging formats into \"", in: line)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) {
            remember(path: dest)
            statusText = "正在合并音画…"
            progress = max(progress, 0.97)
            return
        }
        if let dest = value(after: "[ExtractAudio] Destination: ", in: line) {
            remember(path: dest)
            statusText = "正在提取音频…"
            progress = max(progress, 0.97)
            return
        }
        if line.contains("has already been downloaded") {
            if let path = line
                .replacingOccurrences(of: "[download] ", with: "")
                .components(separatedBy: " has already been downloaded")
                .first {
                remember(path: path)
            }
            progress = 1
            return
        }
        if line.contains("[Merger]") { statusText = "正在合并音画…"; return }
        if line.contains("[ExtractAudio]") { statusText = "正在提取音频…"; return }
        if line.contains("[info]") && filename.isEmpty {
            statusText = "正在解析视频…"
        }

        guard line.contains("[download]"), line.contains("%") else { return }
        let body = line.replacingOccurrences(of: "[download]", with: "")
        let tokens = body.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if let percentToken = tokens.first(where: { $0.hasSuffix("%") }),
           let value = Double(percentToken.dropLast()) {
            progress = min(max(value / 100.0, 0), 1)
            let percent = Int((progress * 100).rounded())
            NSApp.dockTile.badgeLabel = percent > 0 && percent < 100 ? "\(percent)" : nil
        }
        if let idx = tokens.firstIndex(of: "at"), idx + 1 < tokens.count {
            speedText = tokens[idx + 1]
        }
        if let idx = tokens.firstIndex(of: "ETA"), idx + 1 < tokens.count {
            etaText = tokens[idx + 1]
        }
        if !speedText.isEmpty {
            statusText = [speedText, etaText.isEmpty ? nil : "剩余 \(etaText)"]
                .compactMap { $0 }
                .joined(separator: " · ")
        }
    }

    private func remember(path: String) {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastFilePath = trimmed
        filename = URL(fileURLWithPath: trimmed).lastPathComponent
    }

    private func finish(status: Int32) {
        NSApp.dockTile.badgeLabel = nil
        if !lineBuffer.isEmpty {
            parse(lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
            lineBuffer = ""
        }

        if status == 0 {
            if let path = lastFilePath {
                let url = URL(fileURLWithPath: path)
                outputURL = url
                filename = url.lastPathComponent
                if let size = try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64 {
                    fileSizeText = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                }
            }
            phase = .success
            progress = 1
            NSApp.requestUserAttention(.informationalRequest)
            return
        }

        if phase == .idle { return }
        phase = .failed
        progress = 0
        if errorMessage == nil {
            errorMessage = (status == 15 || status == 9) ? "已取消" : "下载失败，请检查链接或网络"
        }
    }

    private func persistFolder() {
        do {
            let data = try saveFolder.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: "saveFolderBookmark")
        } catch {
            UserDefaults.standard.set(saveFolder.path, forKey: "saveFolderPath")
        }
    }

    private static func resolveBookmark(_ data: Data) -> URL? {
        var stale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }

    private func value(after prefix: String, in line: String) -> String? {
        guard line.contains(prefix), let range = line.range(of: prefix) else { return nil }
        return String(line[range.upperBound...])
    }

    private static func humanize(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("Unsupported URL") { return "这个链接暂时不支持" }
        if text.localizedCaseInsensitiveContains("No video formats") {
            return "未找到可下载的视频流（小红书常需登录 Cookie）"
        }
        if text.localizedCaseInsensitiveContains("private") { return "视频是私密的，无法下载" }
        if text.localizedCaseInsensitiveContains("login") || text.contains("cookies") {
            return "该视频需要登录，请在下方选择浏览器 Cookie"
        }
        if text.contains("404") { return "视频不存在或已删除" }
        if text.localizedCaseInsensitiveContains("ffmpeg") { return "缺少 ffmpeg，请执行 brew install ffmpeg" }
        if text.contains("Unable to extract") { return "无法解析该视频，请检查链接" }
        if text.contains("Video unavailable") { return "视频不可用" }
        if text.localizedCaseInsensitiveContains("could not find") && text.contains("cookies") {
            return "未找到该浏览器的 Cookie，请换一个已登录的浏览器"
        }
        if text.count > 90 { return String(text.prefix(90)) + "…" }
        return text
    }

    private struct CaptureResult {
        var status: Int32
        var stdout: String
        var stderr: String
    }

    private static func runCapture(executable: String, arguments: [String], path: String) async -> CaptureResult {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: executable)
                proc.arguments = arguments
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = path
                env["PYTHONUNBUFFERED"] = "1"
                proc.environment = env
                let out = Pipe()
                let err = Pipe()
                proc.standardOutput = out
                proc.standardError = err
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    cont.resume(returning: CaptureResult(status: proc.terminationStatus, stdout: stdout, stderr: stderr))
                } catch {
                    cont.resume(returning: CaptureResult(status: -1, stdout: "", stderr: error.localizedDescription))
                }
            }
        }
    }
}
