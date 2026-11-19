// アプリアイコン（案A：虫眼鏡＋円マーク）を描いて PNG に書き出すスクリプト。
// 使い方: xcrun swiftc -o /tmp/makeicon tools/make_app_icon.swift && /tmp/makeicon FurimaKakakuCheck/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

import AppKit
import CoreGraphics
import CoreText

let size = 1024
let k = CGFloat(size) / 120.0   // デザイン案(120pt)からの拡大率
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// 左上原点に揃える
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)

// 背景（角丸はiOSが付けるので四角のまま塗る）
ctx.setFillColor(CGColor(srgbRed: 0xE2/255, green: 0x4B/255, blue: 0x4A/255, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
ctx.setStrokeColor(white)
ctx.setLineCap(.round)

// 虫眼鏡のレンズ
ctx.setLineWidth(9 * k)
ctx.strokeEllipse(in: CGRect(x: (52 - 26) * k, y: (52 - 26) * k, width: 52 * k, height: 52 * k))
// 持ち手
// 付け根はレンズの線の中心から平らに出し、先端だけ丸くする（つなぎ目に段差が出ないように）
let jointOffset = 26 / CGFloat(2).squareRoot()
ctx.setLineWidth(11 * k)
ctx.setLineCap(.butt)
ctx.move(to: CGPoint(x: (52 + jointOffset) * k, y: (52 + jointOffset) * k))
ctx.addLine(to: CGPoint(x: 92 * k, y: 92 * k))
ctx.strokePath()
ctx.setFillColor(white)
ctx.fillEllipse(in: CGRect(x: (92 - 5.5) * k, y: (92 - 5.5) * k, width: 11 * k, height: 11 * k))

// ¥ マーク（レンズの中央）
let font = CTFontCreateWithName("SFProRounded-Bold" as CFString, 33 * k, nil)
let fallback = NSFont.systemFont(ofSize: 33 * k, weight: .bold)
let useFont: CTFont = (CTFontCopyPostScriptName(font) as String).contains("Rounded") ? font : fallback
let attr = NSAttributedString(string: "¥", attributes: [
    .font: useFont, .foregroundColor: NSColor.white])
let line = CTLineCreateWithAttributedString(attr)
let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
ctx.saveGState()
ctx.textMatrix = .identity
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)  // テキスト描画は下原点に戻す
let cx = 52 * k, cy = CGFloat(size) - 52 * k
ctx.textPosition = CGPoint(x: cx - bounds.midX, y: cy - bounds.midY)
CTLineDraw(line, ctx)
ctx.restoreGState()

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let out = CommandLine.arguments[1]
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote", out)
