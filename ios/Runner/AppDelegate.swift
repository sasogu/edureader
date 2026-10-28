import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var documentsChannel: FlutterMethodChannel?

  private var incomingDirectory: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("IncomingEPUB", isDirectory: true)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "es.edutictac.edureader/documents",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else { result(FlutterMethodNotImplemented); return }
        switch call.method {
        case "pendingDocuments":
          result(self.pendingDocuments())
        case "discardDocument":
          guard let path = call.arguments as? String else { result(false); return }
          let file = URL(fileURLWithPath: path).standardizedFileURL
          guard file.deletingLastPathComponent() == self.incomingDirectory.standardizedFileURL else {
            result(false)
            return
          }
          do {
            try FileManager.default.removeItem(at: file)
            result(true)
          } catch {
            result(false)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      documentsChannel = channel
    }
    return launched
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.isFileURL, url.pathExtension.lowercased() == "epub" else {
      return super.application(app, open: url, options: options)
    }

    let hasAccess = url.startAccessingSecurityScopedResource()
    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
    do {
      try FileManager.default.createDirectory(
        at: incomingDirectory,
        withIntermediateDirectories: true
      )
      let staged = incomingDirectory.appendingPathComponent(
        "\(UUID().uuidString)_\(url.lastPathComponent)"
      )
      try FileManager.default.copyItem(at: url, to: staged)
      documentsChannel?.invokeMethod("documentOpened", arguments: staged.path)
      return true
    } catch {
      return false
    }
  }

  private func pendingDocuments() -> [String] {
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: incomingDirectory,
      includingPropertiesForKeys: nil
    ) else { return [] }
    return files
      .filter { $0.pathExtension.lowercased() == "epub" }
      .map(\.path)
      .sorted()
  }
}
