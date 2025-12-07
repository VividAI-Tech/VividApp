import Cocoa

/// A floating panel that appears above all windows for meeting detection and recording
class FloatingPanelController: NSObject {
    
    private var panel: NSPanel?
    private var recordingTimer: Timer?
    private var recordingSeconds: Int = 0
    
    // UI Elements
    private var containerView: NSView?
    private var indicatorView: NSView?
    private var titleLabel: NSTextField?
    private var subtitleLabel: NSTextField?
    private var recordButton: NSButton?
    private var closeButton: NSButton?
    private var timerLabel: NSTextField?
    
    // State
    private var isRecording = false
    private var isPaused = false
    private var isMinimized = false
    private var lastPanelPosition: NSPoint? // Remember position for minimize/expand
    private var currentMode: PanelMode = .meetingDetected
    
    // Callbacks
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    var onPauseRecording: (() -> Void)?
    var onResumeRecording: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    // Colors (matching AppTheme)
    private let primaryColor = NSColor(red: 0.46, green: 0.35, blue: 0.96, alpha: 1.0) // #7659F5
    private let recordingRed = NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1.0)
    private let bgCard = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.95) // Semi-transparent dark
    private let textPrimary = NSColor.white
    private let textMuted = NSColor(white: 0.6, alpha: 1.0)
    
    static let shared = FloatingPanelController()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Panel Management
    
    func showMeetingDetectedPanel() {
        DispatchQueue.main.async { [weak self] in
            self?.createAndShowPanel(mode: .meetingDetected)
        }
    }
    
    func showRecordingPanel(elapsedSeconds: Int = 0) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
            self?.isPaused = false
            self?.recordingSeconds = elapsedSeconds
            self?.createAndShowPanel(mode: .recording)
            self?.startTimer()
        }
    }
    
    func showPausedPanel(elapsedSeconds: Int = 0) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
            self?.isPaused = true
            self?.recordingSeconds = elapsedSeconds
            self?.updateForPaused()
        }
    }
    
    func updateRecordingTime(seconds: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.recordingSeconds = seconds
            self?.timerLabel?.stringValue = self?.formatTime(seconds) ?? "00:00:00"
        }
    }
    
    func hidePanel() {
        DispatchQueue.main.async { [weak self] in
            self?.stopTimer()
            self?.panel?.orderOut(nil)
            self?.panel = nil
            self?.isRecording = false
            self?.isPaused = false
            self?.recordingSeconds = 0
        }
    }
    
    // MARK: - Panel Creation
    
    private enum PanelMode {
        case meetingDetected
        case recording
        case minimized
    }
    
    private func createAndShowPanel(mode: PanelMode) {
        // Close existing panel if any
        panel?.orderOut(nil)
        
        // Get screen size for positioning
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        
        // Panel size based on mode
        var panelWidth: CGFloat
        var panelHeight: CGFloat
        
        switch mode {
        case .minimized:
            panelWidth = 50
            panelHeight = 50
        case .recording:
            panelWidth = 240  // Slightly wider to fit minimize button
            panelHeight = 60
        case .meetingDetected:
            panelWidth = 440  // Slightly wider to fit minimize button
            panelHeight = 60
        }
        
        // Position at top center of screen (or use last position if available)
        var panelX: CGFloat
        var panelY: CGFloat
        
        if let lastPos = lastPanelPosition {
            panelX = lastPos.x
            panelY = lastPos.y
        } else {
            panelX = screenRect.origin.x + (screenRect.width - panelWidth) / 2
            panelY = screenRect.origin.y + screenRect.height - panelHeight - 8
        }
        
        let panelRect = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)
        
        // Create panel with floating level
        panel = NSPanel(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel?.level = .floating
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel?.isFloatingPanel = true
        panel?.becomesKeyOnlyIfNeeded = true
        panel?.hidesOnDeactivate = false
        panel?.isOpaque = false
        panel?.backgroundColor = .clear
        panel?.hasShadow = true
        panel?.isMovableByWindowBackground = true // Enable dragging the panel
        
        // Create content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = bgCard.cgColor
        contentView.layer?.cornerRadius = 12
        contentView.layer?.borderWidth = 1
        contentView.layer?.borderColor = NSColor(white: 0.3, alpha: 0.5).cgColor
        
        // Add shadow
        contentView.shadow = NSShadow()
        contentView.layer?.shadowColor = NSColor.black.cgColor
        contentView.layer?.shadowOpacity = 0.3
        contentView.layer?.shadowOffset = CGSize(width: 0, height: -3)
        contentView.layer?.shadowRadius = 10
        
        containerView = contentView
        currentMode = mode
        
        switch mode {
        case .meetingDetected:
            setupMeetingDetectedUI(in: contentView)
        case .recording:
            setupRecordingUI(in: contentView)
        case .minimized:
            setupMinimizedUI(in: contentView)
        }
        
        panel?.contentView = contentView
        panel?.orderFrontRegardless()
    }
    
    // MARK: - Meeting Detected UI
    
    private func setupMeetingDetectedUI(in container: NSView) {
        let width = container.bounds.width
        let height = container.bounds.height
        
        // Red indicator dot
        let indicator = NSView(frame: NSRect(x: 16, y: (height - 10) / 2, width: 10, height: 10))
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = recordingRed.cgColor
        indicator.layer?.cornerRadius = 5
        container.addSubview(indicator)
        indicatorView = indicator
        
        // Start pulse animation
        startPulseAnimation(for: indicator)
        
        // Title label
        let title = NSTextField(labelWithString: "Audio/Video Call Detected")
        title.frame = NSRect(x: 36, y: height - 28, width: 250, height: 18)
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.textColor = textPrimary
        container.addSubview(title)
        titleLabel = title
        
        // Subtitle label
        let subtitle = NSTextField(labelWithString: "Your microphone is being used by another app")
        subtitle.frame = NSRect(x: 36, y: 10, width: 250, height: 16)
        subtitle.font = NSFont.systemFont(ofSize: 12)
        subtitle.textColor = textMuted
        container.addSubview(subtitle)
        subtitleLabel = subtitle
        
        // Record button
        let button = NSButton(frame: NSRect(x: width - 110, y: (height - 32) / 2, width: 80, height: 32))
        button.title = "Record"
        button.bezelStyle = .rounded
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = primaryColor.cgColor
        button.layer?.cornerRadius = 16
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        button.contentTintColor = .white
        button.target = self
        button.action = #selector(recordButtonClicked)
        container.addSubview(button)
        recordButton = button
        
        // Close button (using text instead of SF Symbol for macOS 10.15 compatibility)
        let close = NSButton(frame: NSRect(x: width - 28, y: (height - 20) / 2, width: 20, height: 20))
        close.bezelStyle = .inline
        close.isBordered = false
        close.title = "×"
        close.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        close.contentTintColor = textMuted
        close.target = self
        close.action = #selector(closeButtonClicked)
        container.addSubview(close)
        closeButton = close
    }
    
    // MARK: - Recording UI
    
    private func setupRecordingUI(in container: NSView) {
        let width = container.bounds.width
        let height = container.bounds.height
        
        // Red indicator dot
        let indicator = NSView(frame: NSRect(x: 16, y: (height - 12) / 2, width: 12, height: 12))
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = recordingRed.cgColor
        indicator.layer?.cornerRadius = 6
        container.addSubview(indicator)
        indicatorView = indicator
        
        // Start pulse animation
        startPulseAnimation(for: indicator)
        
        // Timer label
        let timer = NSTextField(labelWithString: formatTime(recordingSeconds))
        timer.frame = NSRect(x: 36, y: (height - 20) / 2, width: 80, height: 20)
        timer.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        timer.textColor = textPrimary
        container.addSubview(timer)
        timerLabel = timer
        
        // Mic indicator (using text instead of SF Symbol for macOS 10.15 compatibility)
        let micLabel = NSTextField(labelWithString: "🎙")
        micLabel.frame = NSRect(x: 120, y: (height - 20) / 2, width: 20, height: 20)
        micLabel.font = NSFont.systemFont(ofSize: 14)
        micLabel.isBordered = false
        micLabel.isEditable = false
        micLabel.backgroundColor = .clear
        container.addSubview(micLabel)
        
        // Stop button (using text instead of SF Symbol for macOS 10.15 compatibility)
        let stopButton = NSButton(frame: NSRect(x: width - 44, y: (height - 28) / 2, width: 36, height: 28))
        stopButton.bezelStyle = .inline
        stopButton.isBordered = false
        stopButton.title = "⏹"
        stopButton.font = NSFont.systemFont(ofSize: 18)
        stopButton.contentTintColor = recordingRed
        stopButton.target = self
        stopButton.action = #selector(stopButtonClicked)
        container.addSubview(stopButton)
        
        // Minimize/Hide button
        let minimizeBtn = NSButton(frame: NSRect(x: width - 80, y: (height - 28) / 2, width: 28, height: 28))
        minimizeBtn.bezelStyle = .inline
        minimizeBtn.isBordered = false
        minimizeBtn.title = "−"
        minimizeBtn.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        minimizeBtn.contentTintColor = textMuted
        minimizeBtn.target = self
        minimizeBtn.action = #selector(minimizeButtonClicked)
        minimizeBtn.toolTip = "Minimize panel"
        container.addSubview(minimizeBtn)
    }
    
    // MARK: - Minimized UI
    
    private func setupMinimizedUI(in container: NSView) {
        let width = container.bounds.width
        let height = container.bounds.height
        
        // Make the entire container clickable to expand
        container.layer?.cornerRadius = width / 2  // Make it circular
        
        // Red pulsing indicator (the whole minimized view is essentially a dot)
        let indicator = NSView(frame: NSRect(x: (width - 24) / 2, y: (height - 24) / 2, width: 24, height: 24))
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = isRecording ? recordingRed.cgColor : primaryColor.cgColor
        indicator.layer?.cornerRadius = 12
        container.addSubview(indicator)
        indicatorView = indicator
        
        // Start pulse animation
        startPulseAnimation(for: indicator)
        
        // Add click gesture to expand
        let expandButton = NSButton(frame: container.bounds)
        expandButton.bezelStyle = .inline
        expandButton.isBordered = false
        expandButton.title = ""
        expandButton.isTransparent = true
        expandButton.target = self
        expandButton.action = #selector(expandButtonClicked)
        expandButton.toolTip = "Click to expand recording panel"
        container.addSubview(expandButton)
    }
    
    private func updateForPaused() {
        indicatorView?.layer?.backgroundColor = NSColor.orange.cgColor
        // Could also update other UI elements for paused state
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        stopTimer()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording, !self.isPaused else { return }
            self.recordingSeconds += 1
            self.timerLabel?.stringValue = self.formatTime(self.recordingSeconds)
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    
    // MARK: - Animations
    
    private func startPulseAnimation(for view: NSView) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.4
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        view.layer?.add(animation, forKey: "pulse")
    }
    
    // MARK: - Actions
    
    @objc private func recordButtonClicked() {
        NSLog("FloatingPanel: Record button clicked")
        onStartRecording?()
    }
    
    @objc private func stopButtonClicked() {
        NSLog("FloatingPanel: Stop button clicked")
        onStopRecording?()
    }
    
    @objc private func closeButtonClicked() {
        NSLog("FloatingPanel: Close button clicked")
        hidePanel()
        onDismiss?()
    }
    
    @objc private func minimizeButtonClicked() {
        NSLog("FloatingPanel: Minimize button clicked")
        // Save current position before minimizing
        if let frame = panel?.frame {
            lastPanelPosition = NSPoint(x: frame.origin.x, y: frame.origin.y)
        }
        isMinimized = true
        createAndShowPanel(mode: .minimized)
    }
    
    @objc private func expandButtonClicked() {
        NSLog("FloatingPanel: Expand button clicked")
        isMinimized = false
        // Restore to the appropriate mode
        if isRecording {
            if isPaused {
                createAndShowPanel(mode: .recording)
                updateForPaused()
            } else {
                createAndShowPanel(mode: .recording)
                startTimer()
            }
        } else {
            createAndShowPanel(mode: .meetingDetected)
        }
    }
}
