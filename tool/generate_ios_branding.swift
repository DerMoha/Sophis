import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Native vector artwork shared by the app icon and launch image.
func artwork(size: Int, launch: Bool = false) -> NSBitmapImageRep {
  let height = launch ? Int(Double(size) * 185 / 168) : size
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let context = NSGraphicsContext.current!.cgContext
  context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
  if launch {
    context.translateBy(x: 220, y: 270)
    context.scaleBy(x: 0.57, y: 0.57)
  }
  let background = launch ? NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), xRadius: 240, yRadius: 240) : NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024))
  NSGradient(starting: NSColor(red: 0.20, green: 0.51, blue: 1, alpha: 1), ending: NSColor(red: 0.67, green: 0.55, blue: 0.93, alpha: 1))!.draw(in: background, angle: 30)
  let mark = NSBezierPath()
  mark.move(to: NSPoint(x: 512, y: 300))
  mark.line(to: NSPoint(x: 512, y: 470))
  mark.move(to: NSPoint(x: 512, y: 350))
  mark.curve(to: NSPoint(x: 285, y: 600), controlPoint1: NSPoint(x: 365, y: 365), controlPoint2: NSPoint(x: 280, y: 465))
  mark.curve(to: NSPoint(x: 512, y: 350), controlPoint1: NSPoint(x: 435, y: 585), controlPoint2: NSPoint(x: 510, y: 490))
  mark.move(to: NSPoint(x: 512, y: 350))
  mark.curve(to: NSPoint(x: 739, y: 600), controlPoint1: NSPoint(x: 659, y: 365), controlPoint2: NSPoint(x: 744, y: 465))
  mark.curve(to: NSPoint(x: 512, y: 350), controlPoint1: NSPoint(x: 589, y: 585), controlPoint2: NSPoint(x: 514, y: 490))
  mark.move(to: NSPoint(x: 512, y: 710))
  mark.curve(to: NSPoint(x: 512, y: 500), controlPoint1: NSPoint(x: 415, y: 605), controlPoint2: NSPoint(x: 445, y: 550))
  mark.curve(to: NSPoint(x: 512, y: 710), controlPoint1: NSPoint(x: 579, y: 550), controlPoint2: NSPoint(x: 609, y: 605))
  mark.lineWidth = 28
  mark.lineCapStyle = .round
  mark.lineJoinStyle = .round
  NSColor.white.setStroke()
  mark.stroke()
  NSGraphicsContext.restoreGraphicsState()
  return bitmap
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconDir = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let contents = try JSONSerialization.jsonObject(with: Data(contentsOf: iconDir.appendingPathComponent("Contents.json"))) as! [String: Any]
for item in contents["images"] as! [[String: String]] {
  let points = Double(item["size"]!.split(separator: "x")[0])!
  let scale = Double(item["scale"]!.dropLast())!
  let bitmap = artwork(size: Int(points * scale))
  let size = Int(points * scale)
  let opaque = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  opaque.draw(bitmap.cgImage!, in: CGRect(x: 0, y: 0, width: size, height: size))
  let destination = CGImageDestinationCreateWithURL(iconDir.appendingPathComponent(item["filename"]!) as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, opaque.makeImage()!, nil)
  precondition(CGImageDestinationFinalize(destination))
}
let launchDir = root.appendingPathComponent("ios/Runner/Assets.xcassets/LaunchImage.imageset")
for scale in 1...3 {
  let name = scale == 1 ? "LaunchImage.png" : "LaunchImage@\(scale)x.png"
  try artwork(size: 168 * scale, launch: true).representation(using: .png, properties: [:])!.write(to: launchDir.appendingPathComponent(name))
}
