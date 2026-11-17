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

  // Pictures and links the ShareExtension saved in the shared group folder
  // or on the named pasteboard. Pictures move into this app's temp folder
  // for lib/utils/shared_to_synk.dart; links are read and removed.
  private static func takeShared() -> [String: [String]] {
    var photos: [String] = []
    var texts: [String] = []
    let files = FileManager.default
    var saved: [URL] = []
    for group in groups() {
      guard
        let folder = files.containerURL(forSecurityApplicationGroupIdentifier: group)?
          .appendingPathComponent("Shared"),
        let found = try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
      else { continue }
      saved += found
    }
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
    // The extension puts the same things on the pasteboard, read only when
    // the folder had nothing.
    if let board = UIPasteboard(name: UIPasteboard.Name("synk.shared"), create: false),
      board.numberOfItems > 0
    {
      let items = photos.isEmpty && texts.isEmpty ? board.items : []
      board.items = []
      for item in items {
        if let text = item["public.utf8-plain-text"] as? String, !text.isEmpty {
          texts.append(text)
          continue
        }
        let png = item["public.png"] as? Data
        guard let data = png ?? item["public.jpeg"] as? Data else { continue }
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString)"
        let target = files.temporaryDirectory
          .appendingPathComponent(name).appendingPathExtension(png == nil ? "jpg" : "png")
        if (try? data.write(to: target)) != nil { photos.append(target.path) }
      }
    }
    return ["photos": photos, "texts": texts]
  }

  // The groups the signer gave this app (from its provisioning profile),
  // then "group." plus the app's id. Sideloading can rename the group.
  private static func groups() -> [String] {
    var found: [String] = []
    if let file = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: file),
      let start = data.range(of: Data("<?xml".utf8)),
      let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
      let plist = try? PropertyListSerialization.propertyList(
        from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
      let entitlements = plist["Entitlements"] as? [String: Any],
      let listed = entitlements["com.apple.security.application-groups"] as? [String]
    {
      found = listed
    }
    if let id = Bundle.main.bundleIdentifier, !found.contains("group.\(id)") {
      found.append("group.\(id)")
    }
    return found
  }
}
