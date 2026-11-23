import EventKit
import EventKitUI
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
    // Adds an activity to the iPhone's calendar (lib/utils/add_to_calendar.dart).
    // Shows Apple's event editor on the scene's window and says whether
    // the user saved it.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SynkCalendar") {
      let channel = FlutterMethodChannel(
        name: "synk/calendar", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "add", let args = call.arguments as? [String: Any] else {
          result(FlutterMethodNotImplemented)
          return
        }
        CalendarAdder.add(args, result: result)
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

// Shows Apple's "New Event" editor filled in with an activity, and answers
// "saved", "cancelled", "denied" (no calendar access before iOS 17) or
// "unavailable" (nothing to show it on).
final class CalendarAdder: NSObject, EKEventEditViewDelegate {
  // Kept until the editor closes, since it only holds a weak delegate.
  private static var current: CalendarAdder?
  private let result: FlutterResult

  private init(result: @escaping FlutterResult) {
    self.result = result
  }

  static func add(_ args: [String: Any], result: @escaping FlutterResult) {
    let store = EKEventStore()
    let answer: (String) -> Void = { outcome in
      DispatchQueue.main.async { result(outcome) }
    }
    let show = {
      DispatchQueue.main.async {
        guard let top = CalendarAdder.topController() else {
          result("unavailable")
          return
        }
        let event = EKEvent(eventStore: store)
        event.title = args["title"] as? String
        event.notes = args["description"] as? String
        event.location = args["location"] as? String
        if let start = args["start"] as? NSNumber {
          event.startDate = Date(timeIntervalSince1970: start.doubleValue / 1000)
        }
        if let end = args["end"] as? NSNumber {
          event.endDate = Date(timeIntervalSince1970: end.doubleValue / 1000)
        }
        if let minutes = args["reminderMinutes"] as? NSNumber {
          event.addAlarm(EKAlarm(relativeOffset: -minutes.doubleValue * 60))
        }
        let editor = EKEventEditViewController()
        editor.event = event
        editor.eventStore = store
        let adder = CalendarAdder(result: result)
        CalendarAdder.current = adder
        editor.editViewDelegate = adder
        top.present(editor, animated: true)
      }
    }

    // From iOS 17 the editor needs no calendar access at all.
    if #available(iOS 17, *) {
      show()
      return
    }
    switch EKEventStore.authorizationStatus(for: .event) {
    case .authorized:
      show()
    case .notDetermined:
      store.requestAccess(to: .event) { granted, _ in
        if granted { show() } else { answer("denied") }
      }
    default:
      answer("denied")
    }
  }

  // The screen on top in the app's active window.
  private static func topController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    let window = windows.first { $0.isKeyWindow } ?? windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  func eventEditViewController(
    _ controller: EKEventEditViewController,
    didCompleteWith action: EKEventEditViewAction
  ) {
    let outcome = action == .saved ? "saved" : "cancelled"
    controller.dismiss(animated: true) {
      self.result(outcome)
      CalendarAdder.current = nil
    }
  }
}
