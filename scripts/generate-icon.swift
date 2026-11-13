// Original vector-drawn identity rendered with native AppKit. No third-party artwork.
import AppKit
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.055, green: 0.25, blue: 0.17, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
NSColor(calibratedRed: 0.40, green: 0.84, blue: 0.61, alpha: 1).setStroke()
let ring = NSBezierPath(ovalIn: NSRect(x: 174, y: 174, width: 676, height: 676)); ring.lineWidth = 28; ring.stroke()
NSColor(calibratedRed: 0.92, green: 0.99, blue: 0.95, alpha: 1).setFill()
let leaf = NSBezierPath()
leaf.move(to: NSPoint(x: 356, y: 343))
leaf.curve(to: NSPoint(x: 697, y: 720), controlPoint1: NSPoint(x: 249, y: 599), controlPoint2: NSPoint(x: 476, y: 778))
leaf.curve(to: NSPoint(x: 356, y: 343), controlPoint1: NSPoint(x: 755, y: 476), controlPoint2: NSPoint(x: 567, y: 296))
leaf.close(); leaf.fill()
NSColor(calibratedRed: 0.055, green: 0.25, blue: 0.17, alpha: 1).setStroke()
let vein = NSBezierPath(); vein.move(to: NSPoint(x: 330, y: 300)); vein.curve(to: NSPoint(x: 620, y: 640), controlPoint1: NSPoint(x: 410, y: 420), controlPoint2: NSPoint(x: 515, y: 530)); vein.lineWidth = 22; vein.lineCapStyle = .round; vein.stroke()
NSGraphicsContext.restoreGraphicsState()
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "MyFinance/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
