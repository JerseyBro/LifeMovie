import Flutter
import Photos
import PhotosUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let imageManager = PHCachingImageManager()
  private var thumbnailRequests: [String: PHImageRequestID] = [:]
  private let formatter = ISO8601DateFormatter()

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
        result(self.fetchAssets(offset: args?["offset"] as? Int ?? 0, limit: args?["limit"] as? Int ?? 200, filter: args?["filter"] as? String ?? "all"))
      case "fetchAssetsByDateRange":
        let args = call.arguments as? [String: Any]
        result(self.fetchAssetsByDateRange(start: args?["start"] as? String, end: args?["end"] as? String, filter: args?["filter"] as? String ?? "all", offset: args?["offset"] as? Int ?? 0, limit: args?["limit"] as? Int ?? 500))
      case "loadThumbnail":
        let args = call.arguments as? [String: Any]
        self.loadThumbnail(id: args?["id"] as? String, size: args?["size"] as? Int ?? 320, requestId: args?["requestId"] as? String, result: result)
      case "cancelThumbnailRequest":
        let args = call.arguments as? [String: Any]
        self.cancelThumbnailRequest(requestId: args?["requestId"] as? String)
        result(nil)
      case "presentLimitedLibraryPicker":
        if #available(iOS 15, *) {
          PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller) { _ in
            DispatchQueue.main.async { result(self.photoPermissionStatus()) }
          }
        } else if #available(iOS 14, *) {
          PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
          result(self.photoPermissionStatus())
        } else {
          result(self.photoPermissionStatus())
        }
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

  private func fetchAssets(offset: Int, limit: Int, filter: String) -> [[String: Any]] {
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    options.predicate = mediaPredicate(filter: filter)
    let assets = PHAsset.fetchAssets(with: options)
    let start = min(max(offset, 0), assets.count)
    let end = min(start + max(limit, 1), assets.count)
    var output: [[String: Any]] = []
    for index in start..<end {
      let asset = assets.object(at: index)
      output.append(assetPayload(asset))
    }
    return output
  }

  private func fetchAssetsByDateRange(start: String?, end: String?, filter: String, offset: Int, limit: Int) -> [[String: Any]] {
    guard let start, let end, let startDate = formatter.date(from: start), let endDate = formatter.date(from: end) else {
      return []
    }
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    let datePredicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", startDate as NSDate, endDate as NSDate)
    if let media = mediaPredicate(filter: filter) {
      options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, media])
    } else {
      options.predicate = datePredicate
    }
    var output: [[String: Any]] = []
    let assets = PHAsset.fetchAssets(with: options)
    let startIndex = min(max(offset, 0), assets.count)
    let endIndex = min(startIndex + max(limit, 1), assets.count)
    for index in startIndex..<endIndex {
      output.append(assetPayload(assets.object(at: index)))
    }
    return output
  }

  private func loadThumbnail(id: String?, size: Int, requestId: String?, result: @escaping FlutterResult) {
    guard let id else {
      result(FlutterError(code: "missing_asset_id", message: "Missing asset id", details: nil))
      return
    }
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
    guard let asset = assets.firstObject else {
      result(nil)
      return
    }

    let options = PHImageRequestOptions()
    options.deliveryMode = .opportunistic
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = false
    options.isSynchronous = false

    let targetSize = CGSize(width: max(size, 1), height: max(size, 1))
    let request = imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
      if let requestId {
        self.thumbnailRequests.removeValue(forKey: requestId)
      }
      let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
      let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
      if cancelled || degraded {
        result(nil)
        return
      }
      if asset.localIdentifier != id {
        result(nil)
        return
      }
      guard let data = image?.jpegData(compressionQuality: 0.72) else {
        result(nil)
        return
      }
      result(FlutterStandardTypedData(bytes: data))
    }
    if let requestId {
      thumbnailRequests[requestId] = request
    }
  }

  private func cancelThumbnailRequest(requestId: String?) {
    guard let requestId, let request = thumbnailRequests.removeValue(forKey: requestId) else {
      return
    }
    imageManager.cancelImageRequest(request)
  }

  private func mediaPredicate(filter: String) -> NSPredicate? {
    switch filter {
    case "photo":
      return NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    case "video":
      return NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
    default:
      return nil
    }
  }

  private func assetPayload(_ asset: PHAsset) -> [String: Any] {
    let isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
    let type = asset.mediaType == .video ? "video" : (isLivePhoto ? "livePhoto" : "image")
    var payload: [String: Any] = [
      "id": asset.localIdentifier,
      "localIdentifier": asset.localIdentifier,
      "type": type,
      "durationMs": Int(asset.duration * 1000),
      "width": asset.pixelWidth,
      "height": asset.pixelHeight,
      "isFavorite": asset.isFavorite,
      "isLivePhoto": isLivePhoto
    ]
    if let creationDate = asset.creationDate {
      payload["creationDate"] = formatter.string(from: creationDate)
    }
    if let modificationDate = asset.modificationDate {
      payload["modificationDate"] = formatter.string(from: modificationDate)
    }
    if let location = asset.location {
      payload["latitude"] = location.coordinate.latitude
      payload["longitude"] = location.coordinate.longitude
    }
    return payload
  }
}
