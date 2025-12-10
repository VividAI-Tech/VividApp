import Cocoa
import FlutterMacOS
import CoreAudio
import AVFoundation

@main
class AppDelegate: FlutterAppDelegate {
    
    private var meetingDetectionChannel: FlutterMethodChannel?
    private var floatingPanelChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    private var isMonitoring = false
    private var monitorTimer: Timer?
    private var lastMicState = false
    
    // Track all input devices and their listeners
    private var inputDeviceIDs: [AudioDeviceID] = []
    private var deviceListenerBlocks: [AudioDeviceID: AudioObjectPropertyListenerBlock] = [:]
    private var hardwareListenerBlock: AudioObjectPropertyListenerBlock?
    
    private var hasLaunched = false
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate during initial launch phase - window might not be visible yet
        return hasLaunched
    }
    
    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        // Get the Flutter engine and register channels
        if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
            let registrar = controller.engine.registrar(forPlugin: "MeetingDetectionPlugin")
            
            // Method channel for commands
            meetingDetectionChannel = FlutterMethodChannel(
                name: "com.vivid.meeting_detection",
                binaryMessenger: registrar.messenger
            )
            
            meetingDetectionChannel?.setMethodCallHandler { [weak self] call, result in
                self?.handleMethodCall(call, result: result)
            }
            
            // Method channel for floating panel
            floatingPanelChannel = FlutterMethodChannel(
                name: "com.vivid.floating_panel",
                binaryMessenger: registrar.messenger
            )
            
            floatingPanelChannel?.setMethodCallHandler { [weak self] call, result in
                self?.handleFloatingPanelCall(call, result: result)
            }
            
            // Set up floating panel callbacks
            setupFloatingPanelCallbacks()
            
            // Event channel for streaming mic status updates
            eventChannel = FlutterEventChannel(
                name: "com.vivid.meeting_detection/events",
                binaryMessenger: registrar.messenger
            )
            eventChannel?.setStreamHandler(self)
            
            NSLog("MeetingDetection: Channels registered successfully")
        }
        
        // Ensure window is visible and set hasLaunched after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.mainFlutterWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            self?.hasLaunched = true
            NSLog("Vivid: Window activation complete, termination check enabled")
        }
    }
    
    private func setupFloatingPanelCallbacks() {
        let panel = FloatingPanelController.shared
        
        panel.onStartRecording = { [weak self] in
            self?.floatingPanelChannel?.invokeMethod("onStartRecording", arguments: nil)
        }
        
        panel.onStopRecording = { [weak self] in
            self?.floatingPanelChannel?.invokeMethod("onStopRecording", arguments: nil)
        }
        
        panel.onPauseRecording = { [weak self] in
            self?.floatingPanelChannel?.invokeMethod("onPauseRecording", arguments: nil)
        }
        
        panel.onResumeRecording = { [weak self] in
            self?.floatingPanelChannel?.invokeMethod("onResumeRecording", arguments: nil)
        }
        
        panel.onDismiss = { [weak self] in
            self?.floatingPanelChannel?.invokeMethod("onDismiss", arguments: nil)
        }
    }
    
    private func handleFloatingPanelCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showMeetingPanel":
            FloatingPanelController.shared.showMeetingDetectedPanel()
            result(true)
        case "showRecordingPanel":
            let seconds = (call.arguments as? [String: Any])?["elapsedSeconds"] as? Int ?? 0
            FloatingPanelController.shared.showRecordingPanel(elapsedSeconds: seconds)
            result(true)
        case "showPausedPanel":
            let seconds = (call.arguments as? [String: Any])?["elapsedSeconds"] as? Int ?? 0
            FloatingPanelController.shared.showPausedPanel(elapsedSeconds: seconds)
            result(true)
        case "hidePanel":
            FloatingPanelController.shared.hidePanel()
            result(true)
        case "updateRecordingTime":
            let seconds = (call.arguments as? [String: Any])?["seconds"] as? Int ?? 0
            FloatingPanelController.shared.updateRecordingTime(seconds: seconds)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startMonitoring":
            startMicrophoneMonitoring()
            result(true)
        case "stopMonitoring":
            stopMicrophoneMonitoring()
            result(true)
        case "isMicrophoneInUse":
            result(checkAnyMicrophoneInUse())
        case "isMonitoring":
            result(isMonitoring)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startMicrophoneMonitoring() {
        guard !isMonitoring else { 
            NSLog("MeetingDetection: Already monitoring")
            return 
        }
        
        NSLog("MeetingDetection: Starting microphone monitoring...")
        isMonitoring = true
        
        // Get all input devices and set up listeners
        refreshInputDevices()
        
        // Set up hardware listener to detect device changes
        setupHardwareListener()
        
        // Check initial state
        lastMicState = checkAnyMicrophoneInUse()
        NSLog("MeetingDetection: Initial mic state: \(lastMicState)")
        
        // Start polling as fallback (every 1 second for faster detection)
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAndNotifyMicrophoneStatus()
        }
        
        NSLog("MeetingDetection: Monitoring started with \(inputDeviceIDs.count) input device(s)")
    }
    
    private func stopMicrophoneMonitoring() {
        guard isMonitoring else { return }
        
        NSLog("MeetingDetection: Stopping microphone monitoring...")
        isMonitoring = false
        
        // Stop polling timer
        monitorTimer?.invalidate()
        monitorTimer = nil
        
        // Remove all device listeners
        removeAllDeviceListeners()
        
        // Remove hardware listener
        removeHardwareListener()
        
        inputDeviceIDs.removeAll()
        
        NSLog("MeetingDetection: Monitoring stopped")
    }
    
    // MARK: - Device Management
    
    private func refreshInputDevices() {
        // Remove existing listeners first
        removeAllDeviceListeners()
        
        // Get all audio devices
        inputDeviceIDs = getAllInputDeviceIDs()
        
        NSLog("MeetingDetection: Found \(inputDeviceIDs.count) input device(s)")
        
        // Set up listener on each input device
        for deviceID in inputDeviceIDs {
            setupDeviceListener(for: deviceID)
        }
    }
    
    private func getAllInputDeviceIDs() -> [AudioDeviceID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else {
            NSLog("MeetingDetection: Failed to get devices data size: \(status)")
            return []
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else {
            NSLog("MeetingDetection: Failed to get devices: \(status)")
            return []
        }
        
        // Filter to only input devices
        var inputDevices: [AudioDeviceID] = []
        for deviceID in deviceIDs {
            if hasInputCapability(deviceID: deviceID) {
                let name = getDeviceName(deviceID: deviceID)
                NSLog("MeetingDetection: Input device found - ID: \(deviceID), Name: \(name)")
                inputDevices.append(deviceID)
            }
        }
        
        return inputDevices
    }
    
    private func hasInputCapability(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr, dataSize > 0 else { return false }
        
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }
        
        guard AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferListPointer) == noErr else {
            return false
        }
        
        let bufferList = bufferListPointer.pointee
        return bufferList.mNumberBuffers > 0
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        var cfName: Unmanaged<CFString>?
        
        let status = withUnsafeMutablePointer(to: &cfName) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                ptr
            )
        }
        
        if status == noErr, let unmanagedName = cfName {
            return unmanagedName.takeUnretainedValue() as String
        }
        return "Unknown"
    }
    
    // MARK: - Listeners
    
    private func setupDeviceListener(for deviceID: AudioDeviceID) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let listenerBlock: AudioObjectPropertyListenerBlock = { [weak self] (_, _) in
            DispatchQueue.main.async {
                self?.checkAndNotifyMicrophoneStatus()
            }
        }
        
        let status = AudioObjectAddPropertyListenerBlock(
            deviceID,
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )
        
        if status == noErr {
            deviceListenerBlocks[deviceID] = listenerBlock
            let name = getDeviceName(deviceID: deviceID)
            NSLog("MeetingDetection: Listener added for device: \(name) (ID: \(deviceID))")
        } else {
            NSLog("MeetingDetection: Failed to add listener for device \(deviceID): \(status)")
        }
    }
    
    private func removeAllDeviceListeners() {
        for (deviceID, block) in deviceListenerBlocks {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            AudioObjectRemovePropertyListenerBlock(
                deviceID,
                &propertyAddress,
                DispatchQueue.main,
                block
            )
        }
        deviceListenerBlocks.removeAll()
    }
    
    private func setupHardwareListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        hardwareListenerBlock = { [weak self] (_, _) in
            DispatchQueue.main.async {
                NSLog("MeetingDetection: Audio device configuration changed, refreshing...")
                self?.refreshInputDevices()
                self?.checkAndNotifyMicrophoneStatus()
            }
        }
        
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            hardwareListenerBlock!
        )
        
        if status != noErr {
            NSLog("MeetingDetection: Failed to add hardware listener: \(status)")
        }
    }
    
    private func removeHardwareListener() {
        guard let block = hardwareListenerBlock else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            block
        )
        
        hardwareListenerBlock = nil
    }
    
    // MARK: - Microphone Status Check
    
    private func checkAnyMicrophoneInUse() -> Bool {
        // Check all input devices (no logging here - gets called every second)
        for deviceID in inputDeviceIDs {
            if isDeviceRunning(deviceID: deviceID) {
                return true
            }
        }
        
        // Also check default input device as fallback
        let defaultDeviceID = getDefaultInputDeviceID()
        if defaultDeviceID != kAudioObjectUnknown && !inputDeviceIDs.contains(defaultDeviceID) {
            if isDeviceRunning(deviceID: defaultDeviceID) {
                return true
            }
        }
        
        return false
    }
    
    /// Get the name of the currently active microphone (for logging purposes only)
    private func getActiveMicrophoneName() -> String? {
        for deviceID in inputDeviceIDs {
            if isDeviceRunning(deviceID: deviceID) {
                return getDeviceName(deviceID: deviceID)
            }
        }
        return nil
    }
    
    private func isDeviceRunning(deviceID: AudioDeviceID) -> Bool {
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &size,
            &isRunning
        )
        
        return status == noErr && isRunning != 0
    }
    
    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &size,
            &deviceID
        )
        
        if status != noErr {
            NSLog("MeetingDetection: Failed to get default input device: \(status)")
        }
        
        return deviceID
    }
    
    private func checkAndNotifyMicrophoneStatus() {
        let currentMicState = checkAnyMicrophoneInUse()
        
        if currentMicState != lastMicState {
            // Log state change with device info
            if currentMicState {
                let deviceName = getActiveMicrophoneName() ?? "unknown device"
                NSLog("MeetingDetection: Mic became ACTIVE - \(deviceName)")
            } else {
                NSLog("MeetingDetection: Mic became INACTIVE")
            }
            lastMicState = currentMicState
            
            // Send event to Flutter
            if let sink = eventSink {
                sink(["isInUse": currentMicState])
            } else {
                NSLog("MeetingDetection: No event sink connected!")
            }
        }
    }
    
    override func applicationWillTerminate(_ notification: Notification) {
        stopMicrophoneMonitoring()
    }
}

// MARK: - FlutterStreamHandler
extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        NSLog("MeetingDetection: Event sink connected - Flutter is listening")
        
        // Send current state immediately
        let currentState = checkAnyMicrophoneInUse()
        events(["isInUse": currentState])
        NSLog("MeetingDetection: Sent initial state - isInUse: \(currentState)")
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        NSLog("MeetingDetection: Event sink disconnected")
        return nil
    }
}
