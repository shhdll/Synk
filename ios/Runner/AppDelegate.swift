import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // GMSApiKey is filled from MAPS_API_KEY at build time (see Info.plist).
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SynkShared") {
      let channel = FlutterMethodChannel(
        name: "synk/shared", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "take" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(Self.takeShared())
      }
    }
  }

  // Pictures and links the ShareExtension saved in the shared group folder.
  // Pictures move into this app's temp folder for
  // lib/utils/shared_to_synk.dart; links are read and removed.
  private static func takeShared() -> [String: [String]] {
    var photos: [String] = []
    var texts: [String] = []
    let files = FileManager.default
    guard let id = Bundle.main.bundleIdentifier,
      let folder = files.containerURL(
        forSecurityApplicationGroupIdentifier: "group.\(id)")?
        .appendingPathComponent("Shared"),
      let saved = try? files.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: nil)
    else { return ["photos": photos, "texts": texts] }
    for file in saved.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      if file.pathExtension == "txt" {
        if let text = try? String(contentsOf: file, encoding: .utf8), !text.isEmpty {
          texts.append(text)
        }
        try? files.removeItem(at: file)
        continue
      }
      let target = files.temporaryDirectory.appendingPathComponent(file.lastPathComponent)
      try? files.removeItem(at: target)
      if (try? files.moveItem(at: file, to: target)) != nil {
        photos.append(target.path)
      }
    }
    return ["photos": photos, "texts": texts]
  }
}
