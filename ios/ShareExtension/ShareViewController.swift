import UIKit
import UniformTypeIdentifiers

// Synk in the share menu for pictures and links. Saves what was shared in
// the folder the app shares with this extension, then opens Synk, which asks
// which chats it goes to (AppDelegate takes it from there).
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
    var saved = false
    if let folder = sharedFolder() {
      if images.isEmpty {
        // A link, with any text that came with it.
        if let text = await linkText(providers) {
          saved = (try? text.write(
            to: folder.appendingPathComponent("\(fileStem()).txt"),
            atomically: true, encoding: .utf8)) != nil
        }
      } else {
        for provider in images {
          if await save(provider, into: folder) { saved = true }
        }
      }
    }
    if saved, let url = URL(string: "synk-share://open") {
      open(url)
    }
    extensionContext?.completeRequest(returningItems: nil)
  }

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

  // The app's group is "group." plus the app's id, which is this
  // extension's id without its last part.
  private func sharedFolder() -> URL? {
    var id = Bundle.main.bundleIdentifier ?? ""
    if let dot = id.lastIndex(of: ".") { id = String(id[..<dot]) }
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.\(id)")
    else { return nil }
    let folder = container.appendingPathComponent("Shared")
    try? FileManager.default.createDirectory(
      at: folder, withIntermediateDirectories: true)
    return folder
  }

  private func save(_ provider: NSItemProvider, into folder: URL) async -> Bool {
    guard let data = await imageData(provider) else { return false }
    let isPng = data.starts(with: [0x89, 0x50, 0x4E, 0x47])
    let body = isPng ? data : (UIImage(data: data)?.jpegData(compressionQuality: 0.9) ?? data)
    let name = "\(fileStem()).\(isPng ? "png" : "jpg")"
    return (try? body.write(to: folder.appendingPathComponent(name))) != nil
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
  // chain can.
  private func open(_ url: URL) {
    var responder: UIResponder? = self
    while let current = responder {
      if let app = current as? UIApplication {
        app.open(url, options: [:], completionHandler: nil)
        return
      }
      responder = current.next
    }
  }
}
