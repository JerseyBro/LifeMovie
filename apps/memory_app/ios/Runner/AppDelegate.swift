import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.lifemovie/media_library", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getPermissionStatus": result(self.photoPermissionStatus())
      case "requestPermission":
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in DispatchQueue.main.async { result(self.photoPermissionStatus()) } }
      case "fetchAssets":
        let args = call.arguments as? [String: Any]
        result(self.fetchAssets(offset: args?["offset"] as? Int ?? 0, limit: args?["limit"] as? Int ?? 100))
      case "fetchAssetsByDateRange": result([])
      case "loadThumbnail": result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func photoPermissionStatus() -> String {
    switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
    case .authorized: return "authorized"
    case .limited: return "limited"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "notDetermined"
    }
  }

  private func fetchAssets(offset: Int, limit: Int) -> [[String: Any]] {
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    let assets = PHAsset.fetchAssets(with: options)
    let start = min(max(offset, 0), assets.count)
    let end = min(start + max(limit, 1), assets.count)
    var output: [[String: Any]] = []
    for index in start..<end {
      let asset = assets.object(at: index)
      let type = asset.mediaType == .video ? "video" : "image"
      let formatter = ISO8601DateFormatter()
      output.append(["id": asset.localIdentifier, "type": type, "creationDate": asset.creationDate.map { formatter.string(from: $0) } as Any, "durationMs": Int(asset.duration * 1000), "width": asset.pixelWidth, "height": asset.pixelHeight, "isFavorite": asset.isFavorite, "isLivePhoto": asset.mediaSubtypes.contains(.photoLive), "localIdentifier": asset.localIdentifier])
    }
    return output
  }
}
