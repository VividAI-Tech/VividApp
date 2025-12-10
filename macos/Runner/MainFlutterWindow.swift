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
    
    // Keep traffic lights visible - DO NOT set isOpaque=false or backgroundColor=clear
    // as this can cause the window to be invisible on some systems
    
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    
    // Explicitly show and activate the window with delay to ensure Flutter is ready
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.setIsVisible(true)
      self.center()
      self.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
  }
  
  override var canBecomeKey: Bool {
    return true
  }
  
  override var canBecomeMain: Bool {
    return true
  }
}

