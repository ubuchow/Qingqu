import AppKit
import CoreText

enum AppFonts {
    /// 华文中宋（本机安装文件的 PostScript 名为 JBHGZCS）
    private static let bodyCandidates = [
        "JBHGZCS",
        "华文中宋",
        "STZhongsong",
        "STZhongSong"
    ]

    /// 方正公文小标宋（优先），回退方正小标宋简体
    private static let titleCandidates = [
        "FZDXBS--GBK1-0",
        "FZDocXiaoBiaoSong",
        "方正公文小标宋",
        "FZXBSJW--GB1-0",
        "FZXiaoBiaoSong-B05S",
        "方正小标宋简体"
    ]

    private static var didRegister = false

    static func registerBundledFonts() {
        guard !didRegister else { return }
        didRegister = true
        var urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        urls += Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: "Fonts") ?? []
        if urls.isEmpty {
            urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
            urls += Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? []
        }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func nsBody(_ size: CGFloat) -> NSFont {
        if let name = resolve(bodyCandidates), let font = NSFont(name: name, size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size)
    }

    static func nsTitle(_ size: CGFloat) -> NSFont {
        if let name = resolve(titleCandidates), let font = NSFont(name: name, size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: .semibold)
    }

    static func times(_ size: CGFloat, italic: Bool = false) -> NSFont {
        let name = italic ? "Times-Italic" : "Times-Roman"
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
    }

    private static func resolve(_ candidates: [String]) -> String? {
        for name in candidates {
            if NSFont(name: name, size: 16) != nil {
                return name
            }
        }
        let families = NSFontManager.shared.availableFontFamilies
        for family in families {
            for candidate in candidates where family == candidate || family.contains(candidate) || candidate.contains(family) {
                if let members = NSFontManager.shared.availableMembers(ofFontFamily: family),
                   let first = members.first,
                   let postScript = first.first as? String {
                    return postScript
                }
                return family
            }
        }
        return nil
    }
}
