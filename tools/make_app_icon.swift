// アプリアイコン（ネミル カメラ：カメラの輪郭＋虫眼鏡＋円マーク）を描いて PNG に書き出すスクリプト。
// ネミルのアイコン（虫眼鏡と¥）の後ろに、一般的なカメラの形を置いたデザイン。
// 姉妹アプリ（赤）と見分けやすいよう、背景は紺色にする。カメラは特定メーカーの機種に見えない形にする。
// 使い方: xcrun swiftc -o /tmp/makeicon tools/make_app_icon.swift && /tmp/makeicon NemiruCamera/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

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

let red = CGColor(srgbRed: 0x1F/255, green: 0x3B/255, blue: 0x63/255, alpha: 1)  // 背景色（紺）
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

// 背景（角丸はiOSが付けるので四角のまま塗る）
ctx.setFillColor(red)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// カメラの輪郭（左上寄り）：本体＋上部の出っ張り（ファインダー部）＋レンズの円
ctx.setStrokeColor(white)
ctx.setLineWidth(6 * k)
ctx.setLineJoin(.round)
let body = CGMutablePath()
body.addRoundedRect(in: CGRect(x: 10 * k, y: 30 * k, width: 76 * k, height: 50 * k), cornerWidth: 9 * k, cornerHeight: 9 * k)
ctx.addPath(body)
ctx.strokePath()
// ファインダー部（台形）
ctx.move(to: CGPoint(x: 30 * k, y: 30 * k))
ctx.addLine(to: CGPoint(x: 36 * k, y: 20 * k))
ctx.addLine(to: CGPoint(x: 58 * k, y: 20 * k))
ctx.addLine(to: CGPoint(x: 64 * k, y: 30 * k))
ctx.strokePath()
// シャッターボタン
ctx.setFillColor(white)
ctx.fill(CGRect(x: 70 * k, y: 23.5 * k, width: 9 * k, height: 4 * k))
// 本体のレンズ
ctx.strokeEllipse(in: CGRect(x: 19 * k, y: 41 * k, width: 23 * k, height: 23 * k))

// 虫眼鏡（カメラの右下に重ねる。レンズの内側は背景色で塗って、後ろのカメラの線を隠す）
let lens = CGPoint(x: 72, y: 70)
let radius: CGFloat = 22
ctx.setFillColor(red)
ctx.fillEllipse(in: CGRect(x: (lens.x - radius) * k, y: (lens.y - radius) * k, width: 2 * radius * k, height: 2 * radius * k))
ctx.setLineWidth(8 * k)
ctx.strokeEllipse(in: CGRect(x: (lens.x - radius) * k, y: (lens.y - radius) * k, width: 2 * radius * k, height: 2 * radius * k))
// 持ち手：付け根はレンズの線の中心から平らに出し、先端だけ丸くする（つなぎ目に段差が出ないように）
let handleEnd = CGPoint(x: 100, y: 98)
let angle = atan2(handleEnd.y - lens.y, handleEnd.x - lens.x)
ctx.setLineWidth(10 * k)
ctx.setLineCap(.butt)
ctx.move(to: CGPoint(x: (lens.x + radius * cos(angle)) * k, y: (lens.y + radius * sin(angle)) * k))
ctx.addLine(to: CGPoint(x: handleEnd.x * k, y: handleEnd.y * k))
ctx.strokePath()
ctx.setFillColor(white)
ctx.fillEllipse(in: CGRect(x: (handleEnd.x - 5) * k, y: (handleEnd.y - 5) * k, width: 10 * k, height: 10 * k))

// ¥ マーク（レンズの中央）
let font = CTFontCreateWithName("SFProRounded-Bold" as CFString, 26 * k, nil)
let fallback = NSFont.systemFont(ofSize: 26 * k, weight: .bold)
let useFont: CTFont = (CTFontCopyPostScriptName(font) as String).contains("Rounded") ? font : fallback
let attr = NSAttributedString(string: "¥", attributes: [
    .font: useFont, .foregroundColor: NSColor.white])
let line = CTLineCreateWithAttributedString(attr)
let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
ctx.saveGState()
ctx.textMatrix = .identity
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)  // テキスト描画は下原点に戻す
ctx.textPosition = CGPoint(x: lens.x * k - bounds.midX, y: CGFloat(size) - lens.y * k - bounds.midY)
CTLineDraw(line, ctx)
ctx.restoreGState()

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let out = CommandLine.arguments[1]
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote", out)
