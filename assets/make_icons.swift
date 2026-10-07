// Rigenera le icone dell'app da assets/icon.svg (serve macOS 14+).
// Uso, dalla cartella del progetto: swift assets/make_icons.swift
import AppKit

let svg = NSImage(data: try! Data(contentsOf: URL(fileURLWithPath: "assets/icon.svg")))!

/// PNG quadrato di lato `size`. `crop`: ingrandisce per togliere il margine trasparente del riquadro macOS (100 px su 1024).
func png(_ size: Int, crop: Bool = false) -> Data {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  NSGraphicsContext.current!.imageInterpolation = .high
  let s = CGFloat(size), k = crop ? 1024.0 / 824.0 : 1.0
  svg.draw(in: NSRect(x: -s * (k - 1) / 2, y: -s * (k - 1) / 2, width: s * k, height: s * k))
  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
  try! png(size).write(to: URL(fileURLWithPath: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_\(size).png"))
}

// .ico di Windows: intestazione + una voce per formato, con i PNG incorporati così come sono
let sizes = [16, 24, 32, 48, 64, 128, 256]
let images = sizes.map { png($0, crop: true) }
var ico = Data()
func le<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { ico.append(contentsOf: $0) } }
le(UInt16(0)); le(UInt16(1)); le(UInt16(sizes.count))
var offset = 6 + 16 * sizes.count
for (size, data) in zip(sizes, images) {
  ico.append(UInt8(size % 256)); ico.append(UInt8(size % 256)); ico.append(0); ico.append(0)  // 256 si scrive 0
  le(UInt16(1)); le(UInt16(32)); le(UInt32(data.count)); le(UInt32(offset))
  offset += data.count
}
images.forEach { ico.append($0) }
try! ico.write(to: URL(fileURLWithPath: "windows/runner/resources/app_icon.ico"))
print("Icone rigenerate.")
