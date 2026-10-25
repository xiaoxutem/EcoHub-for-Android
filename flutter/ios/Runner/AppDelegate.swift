import Flutter
import UIKit
import AVKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var pipManager: Any?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 配置后台音视频会话
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {}

    if let registrar = self.registrar(forPlugin: "IosPipPlugin") {
      if #available(iOS 14.0, *) {
        pipManager = IosPipManager(appDelegate: self, binaryMessenger: registrar.messenger())
      }
    } else if let controller = window?.rootViewController as? FlutterViewController {
      if #available(iOS 14.0, *) {
        pipManager = IosPipManager(appDelegate: self, binaryMessenger: controller.binaryMessenger)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

@available(iOS 14.0, *)
class IosPipManager: NSObject, AVPictureInPictureControllerDelegate {
  private weak var appDelegate: FlutterAppDelegate?
  private var pipController: AVPictureInPictureController?
  private var pipPlayerLayer: AVPlayerLayer?
  private var pipChannel: FlutterMethodChannel?
  private var autoPipEnabled: Bool = false
  private var aspectNum: Int = 16
  private var aspectDen: Int = 9

  init(appDelegate: FlutterAppDelegate, binaryMessenger: FlutterBinaryMessenger) {
    self.appDelegate = appDelegate
    super.init()
    pipChannel = FlutterMethodChannel(name: "com.ecohub.ecohub/pip", binaryMessenger: binaryMessenger)
    pipChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "isPipSupported":
        result(AVPictureInPictureController.isPictureInPictureSupported())
      case "enterPip":
        if AVPictureInPictureController.isPictureInPictureSupported() {
          self.preparePipController()
          if let pc = self.pipController, pc.isPictureInPicturePossible {
            pc.startPictureInPicture()
            result(true)
          } else {
            result(false)
          }
        } else {
          result(false)
        }
      case "setAutoPip":
        let args = call.arguments as? [String: Any]
        self.autoPipEnabled = args?["enabled"] as? Bool ?? false
        if let num = args?["numerator"] as? Int, let den = args?["denominator"] as? Int {
          self.aspectNum = max(1, num)
          self.aspectDen = max(1, den)
        }
        if #available(iOS 14.2, *), AVPictureInPictureController.isPictureInPictureSupported() {
          self.preparePipController()
          self.pipController?.canStartPictureInPictureAutomaticallyFromInline = self.autoPipEnabled
        }
        result(true)
      case "updatePipActions":
        result(true)
      case "updateAspectRatio":
        let args = call.arguments as? [String: Any]
        if let num = args?["numerator"] as? Int, let den = args?["denominator"] as? Int {
          self.aspectNum = max(1, num)
          self.aspectDen = max(1, den)
        }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func preparePipController() {
    guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
    let player = findActivePlayer()
    if pipPlayerLayer == nil {
      let layer = AVPlayerLayer()
      layer.frame = CGRect(x: 0, y: 0, width: 16, height: 9)
      layer.isHidden = false
      layer.opacity = 0.01
      appDelegate?.window?.rootViewController?.view.layer.addSublayer(layer)
      pipPlayerLayer = layer
    }
    if let player = player, pipPlayerLayer?.player !== player {
      pipPlayerLayer?.player = player
    }
    if pipController == nil, let layer = pipPlayerLayer {
      pipController = AVPictureInPictureController(playerLayer: layer)
      pipController?.delegate = self
    }
    if #available(iOS 14.2, *) {
      pipController?.canStartPictureInPictureAutomaticallyFromInline = autoPipEnabled
    }
  }

  private func findActivePlayer() -> AVPlayer? {
    if let registrar = appDelegate?.registrar(forPlugin: "PipManager") {
      if let plugin = registrar.valuePublished(byPlugin: "FVPVideoPlayerPlugin") {
        if let players = (plugin as AnyObject).value(forKey: "playersByIdentifier") as? [NSNumber: NSObject] {
          for (_, playerObj) in players {
            if let avPlayer = playerObj.value(forKey: "player") as? AVPlayer {
              return avPlayer
            }
          }
        }
      }
    }
    return nil
  }

  // MARK: - AVPictureInPictureControllerDelegate
  func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    pipChannel?.invokeMethod("onPipModeChanged", arguments: true)
  }

  func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    pipChannel?.invokeMethod("onPipModeChanged", arguments: true)
  }

  func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    pipChannel?.invokeMethod("onPipModeChanged", arguments: false)
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    pipChannel?.invokeMethod("onPipModeChanged", arguments: false)
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    pipChannel?.invokeMethod("onPipModeChanged", arguments: false)
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    pipChannel?.invokeMethod("onPipModeChanged", arguments: false)
    completionHandler(true)
  }
}
