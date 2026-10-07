import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(NSRect(origin: windowFrame.origin, size: NSSize(width: 1180, height: 820)), display: true)
    self.contentMinSize = NSSize(width: 900, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
