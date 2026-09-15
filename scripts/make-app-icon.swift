// 生成 1024 全出血 App 图标：系统蓝渐变 + SF 风格下载符号
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: size * 4,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

let top = CGColor(red: 0.10, green: 0.42, blue: 0.98, alpha: 1)
let bot = CGColor(red: 0.31, green: 0.69, blue: 1.00, alpha: 1)
let grad = CGGradient(colorsSpace: space, colors: [top, bot] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    grad,
    start: CGPoint(x: 0, y: CGFloat(size)),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// 顶部玻璃高光
let shine = CGGradient(
    colorsSpace: space,
    colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.28),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    shine,
    start: CGPoint(x: 0, y: CGFloat(size)),
    end: CGPoint(x: 0, y: 620),
    options: []
)

ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

// 箭杆
ctx.setLineWidth(86)
ctx.move(to: CGPoint(x: 512, y: 708))
ctx.addLine(to: CGPoint(x: 512, y: 448))
ctx.strokePath()

// 箭头
ctx.setLineWidth(86)
ctx.move(to: CGPoint(x: 338, y: 560))
ctx.addLine(to: CGPoint(x: 512, y: 386))
ctx.addLine(to: CGPoint(x: 686, y: 560))
ctx.strokePath()

// 托盘
ctx.setLineWidth(72)
ctx.move(to: CGPoint(x: 292, y: 318))
ctx.addLine(to: CGPoint(x: 292, y: 248))
ctx.addLine(to: CGPoint(x: 732, y: 248))
ctx.addLine(to: CGPoint(x: 732, y: 318))
ctx.strokePath()

guard let img = ctx.makeImage() else { fatalError("img") }
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png")
try? FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("dest")
}
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write") }
print("icon written: \(out.path)")
