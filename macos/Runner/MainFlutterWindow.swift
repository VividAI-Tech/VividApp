import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Configure titlebar to be integrated with content
    self.styleMask.insert(.fullSizeContentView)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    
    // Keep the traffic lights but make them overlay on content
    // This gives a modern macOS look
    self.isOpaque = false
    self.backgroundColor = .clear
    
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
  
  override var canBecomeKey: Bool {
    return true
  }
  
  override var canBecomeMain: Bool {
    return true
  }
}
