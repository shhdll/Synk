import UIKit
import UniformTypeIdentifiers

// Synk in the share menu for pictures and links. Saves what was shared in
// the folder the app shares with this extension (or a named pasteboard),
// then opens Synk, which asks which chats it goes to (AppDelegate takes it
// from there).
class ShareViewController: UIViewController {
  private var started = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    Task { await share() }
  }

  private func share() async {
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
    let images = providers.filter {
      $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
    }
    // What was shared, as pasteboard items: picture data or text.
    var items: [[String: Any]] = []
    if images.isEmpty {
      // A link, with any text that came with it.
      if let text = await linkText(providers) {
        items.append([UTType.utf8PlainText.identifier: text])
      }
    } else {
      for provider in images {
        if let picture = await picture(provider) { items.append(picture) }
      }
    }
    guard !items.isEmpty, keep(items) else {
      return finish(note: Self.ar ? "ما قدرنا نشارك هذا" : "Couldn't share this")
    }
    guard let url = URL(string: "synk-share://open") else { return finish() }
    open(url) { opened in
      if opened {
        self.finish()
      } else {
        self.finish(note: Self.ar ? "انحفظ، افتح Synk عشان ترسله" : "Saved. Open Synk to send it.")
      }
    }
  }

  // Saves in the shared group folder and on the named pasteboard. Sideloading
  // can rename the group, so the app may not see the folder; it reads the
  // pasteboard then.
  private func keep(_ items: [[String: Any]]) -> Bool {
    var saved = false
    if let folder = sharedFolder() {
      for item in items {
        let (name, data) = file(item)
        if let data = data, (try? data.write(to: folder.appendingPathComponent(name))) != nil {
          saved = true
        }
      }
    }
    if let board = UIPasteboard(name: Self.board, create: true) {
      board.items = items
      if board.numberOfItems > 0 { saved = true }
    }
    return saved
  }

  private func file(_ item: [String: Any]) -> (String, Data?) {
    if let text = item[UTType.utf8PlainText.identifier] as? String {
      return ("\(fileStem()).txt", Data(text.utf8))
    }
    if let png = item[UTType.png.identifier] as? Data {
      return ("\(fileStem()).png", png)
    }
    return ("\(fileStem()).jpg", item[UTType.jpeg.identifier] as? Data)
  }

  private func finish(note: String? = nil) {
    guard let note else {
      extensionContext?.completeRequest(returningItems: nil)
      return
    }
    let alert = UIAlertController(title: nil, message: note, preferredStyle: .alert)
    alert.addAction(
      UIAlertAction(title: Self.ar ? "تمام" : "OK", style: .default) { _ in
        self.extensionContext?.completeRequest(returningItems: nil)
      })
    present(alert, animated: true)
  }

  private static let ar = Locale.preferredLanguages.first?.hasPrefix("ar") ?? false
  static let board = UIPasteboard.Name("synk.shared")

  private func linkText(_ providers: [NSItemProvider]) async -> String? {
    var text: String?
    var link: String?
    for provider in providers {
      if link == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
        let url = await item(provider, UTType.url) as? URL, !url.isFileURL
      {
        link = url.absoluteString
      } else if text == nil,
        provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
      {
        text = (await item(provider, UTType.plainText) as? String)?
          .trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    let parts = [text, link].compactMap { $0 }.filter { !$0.isEmpty }
    if parts.count == 2, parts[0].contains(parts[1]) { return parts[0] }
    return parts.isEmpty ? nil : parts.joined(separator: "\n")
  }

  private func item(_ provider: NSItemProvider, _ type: UTType) async -> NSSecureCoding? {
    await withCheckedContinuation { done in
      provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
        done.resume(returning: item)
      }
    }
  }

  private func fileStem() -> String {
    "\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString)"
  }

  // The group the signer gave this extension (from its provisioning
  // profile), else "group." plus the app's id, which is this extension's id
  // without its last part.
  private func sharedFolder() -> URL? {
    var id = Bundle.main.bundleIdentifier ?? ""
    if let dot = id.lastIndex(of: ".") { id = String(id[..<dot]) }
    for group in profileGroups() + ["group.\(id)"] {
      guard
        let container = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: group)
      else { continue }
      let folder = container.appendingPathComponent("Shared")
      try? FileManager.default.createDirectory(
        at: folder, withIntermediateDirectories: true)
      return folder
    }
    return nil
  }

  private func profileGroups() -> [String] {
    guard
      let file = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: file),
      let start = data.range(of: Data("<?xml".utf8)),
      let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
      let plist = try? PropertyListSerialization.propertyList(
        from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
      let entitlements = plist["Entitlements"] as? [String: Any]
    else { return [] }
    return entitlements["com.apple.security.application-groups"] as? [String] ?? []
  }

  private func picture(_ provider: NSItemProvider) async -> [String: Any]? {
    guard let data = await imageData(provider) else { return nil }
    if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return [UTType.png.identifier: data] }
    return [UTType.jpeg.identifier: UIImage(data: data)?.jpegData(compressionQuality: 0.9) ?? data]
  }

  private func imageData(_ provider: NSItemProvider) async -> Data? {
    await withCheckedContinuation { done in
      provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
        switch item {
        case let url as URL: done.resume(returning: try? Data(contentsOf: url))
        case let image as UIImage: done.resume(returning: image.pngData())
        case let data as Data: done.resume(returning: data)
        default: done.resume(returning: nil)
        }
      }
    }
  }

  // Extensions can't open apps directly; the app object up the responder
  // chain can. open is off limits to extensions at compile time, so it's
  // called by name.
  private func open(_ url: URL, done: @escaping (Bool) -> Void) {
    typealias Open = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
    let sel = NSSelectorFromString("openURL:options:completionHandler:")
    let finished: @convention(block) (Bool) -> Void = { opened in
      DispatchQueue.main.async { done(opened) }
    }
    var responder: UIResponder? = self
    while let current = responder {
      if current is UIApplication, current.responds(to: sel) {
        let call = unsafeBitCast(current.method(for: sel), to: Open.self)
        call(current, sel, url as NSURL, NSDictionary(), unsafeBitCast(finished, to: AnyObject.self))
        return
      }
      responder = current.next
    }
    done(false)
  }
}
