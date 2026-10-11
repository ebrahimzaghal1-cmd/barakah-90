import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var orderAlarmPlayer: AVAudioPlayer?
  private var orderAlarmTimeout: Timer?
  private var notificationChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.barakah.market/notifications",
        binaryMessenger: controller.binaryMessenger
      )
      notificationChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return result(nil) }
        switch call.method {
        case "startAdminOrderAlarm":
          do {
            try self.startOrderAlarm()
            result(nil)
          } catch {
            result(FlutterError(code: "order_alarm_failed", message: error.localizedDescription, details: nil))
          }
        case "stopAdminOrderAlarm":
          self.stopOrderAlarm()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func startOrderAlarm() throws {
    guard UIApplication.shared.applicationState == .active else { return }
    if orderAlarmPlayer?.isPlaying == true { return }
    guard let url = Bundle.main.url(forResource: "barakah_admin_order", withExtension: "wav") else {
      throw NSError(domain: "BarakahOrderAlarm", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Order alarm sound is missing"])
    }
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [.duckOthers])
    try session.setActive(true)
    let player = try AVAudioPlayer(contentsOf: url)
    player.numberOfLoops = -1
    player.prepareToPlay()
    guard player.play() else {
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw NSError(domain: "BarakahOrderAlarm", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Order alarm could not start"])
    }
    orderAlarmPlayer = player
    orderAlarmTimeout = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
      self?.stopOrderAlarm()
    }
    NSLog("Barakah: repeating order alarm started")
  }

  private func stopOrderAlarm() {
    orderAlarmTimeout?.invalidate()
    orderAlarmTimeout = nil
    guard orderAlarmPlayer != nil else { return }
    orderAlarmPlayer?.stop()
    orderAlarmPlayer = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    NSLog("Barakah: repeating order alarm stopped")
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Background delivery uses APNs sound. Avoid an unbounded foreground alarm
    // continuing after Dart has been suspended and cannot process stop events.
    stopOrderAlarm()
    super.applicationDidEnterBackground(application)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("Barakah: APNs registration failed: %@", error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
