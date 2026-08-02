import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Documents handed over by the share sheet that Flutter has not collected
  /// yet.
  ///
  /// A cold launch delivers the URL before the Dart side has registered its
  /// handler, so they queue here instead of being dropped. Dart drains the
  /// queue on start and again on resume.
  private var pendingDocuments: [String] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Receives both shared files and the Google Sign-In redirect. Only file
  /// URLs are ours; anything else has to reach super, or the consent screen
  /// opens and never comes back.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.isFileURL {
      pendingDocuments.append(url.path)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "agentrix/shared_documents",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "takePending" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // Handing the paths over clears the queue, so a shared file is imported
      // once rather than again on every resume.
      let taken = self?.pendingDocuments ?? []
      self?.pendingDocuments = []
      result(taken)
    }
  }
}
