import AVFoundation
import CoreLocation
import Flutter
import Photos
import PhotosUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let imageManager = PHCachingImageManager()
  private var thumbnailRequests: [String: PHImageRequestID] = [:]
  private let formatter = ISO8601DateFormatter()
  private let geocoder = CLGeocoder()
  private var placeLabelCache: [String: String] = [:]

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
      case "loadPreview":
        let args = call.arguments as? [String: Any]
        self.loadPreview(id: args?["id"] as? String, maxPixelSize: args?["maxPixelSize"] as? Int, requestId: args?["requestId"] as? String, result: result)
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
      case "setFavorite":
        let args = call.arguments as? [String: Any]
        self.setFavorite(id: args?["id"] as? String, favorite: args?["favorite"] as? Bool ?? false, result: result)
      case "presentShareSheet":
        let args = call.arguments as? [String: Any]
        self.presentShareSheet(id: args?["id"] as? String, result: result)
      case "loadVideoPlaybackUrl":
        let args = call.arguments as? [String: Any]
        self.loadVideoPlaybackUrl(id: args?["id"] as? String, result: result)
      case "loadPlaceLabel":
        let args = call.arguments as? [String: Any]
        let latitude = args?["latitude"] as? Double ?? 0
        let longitude = args?["longitude"] as? Double ?? 0
        self.loadPlaceLabel(latitude: latitude, longitude: longitude, result: result)
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
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false

    let targetSize = CGSize(width: max(size, 1), height: max(size, 1))
    let request = imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
      let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
      let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
      let error = info?[PHImageErrorKey] as? NSError

      // Terminal states: cancelled, error, or final (non-degraded) result
      let isTerminal = cancelled || error != nil || !degraded

      if cancelled || error != nil {
        if let requestId {
          self.thumbnailRequests.removeValue(forKey: requestId)
        }
        if cancelled {
          result(nil)
        } else if let error = error {
          result(FlutterError(code: "phasset_error", message: error.localizedDescription, details: nil))
        }
        return
      }

      if degraded {
        // Intermediate degraded callback - wait for final
        return
      }

      // Final high-quality callback
      if let requestId {
        self.thumbnailRequests.removeValue(forKey: requestId)
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

  private func loadPreview(id: String?, maxPixelSize: Int?, requestId: String?, result: @escaping FlutterResult) {
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
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .exact
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false

    let screenScale = UIScreen.main.scale
    let maxSize = maxPixelSize ?? Int(UIScreen.main.bounds.width * screenScale)
    let targetSize = CGSize(width: maxSize, height: maxSize)
    let request = imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, info in
      let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
      let error = info?[PHImageErrorKey] as? NSError

      if cancelled || error != nil {
        if let requestId {
          self.thumbnailRequests.removeValue(forKey: requestId)
        }
        if cancelled {
          result(nil)
        } else if let error = error {
          result(FlutterError(code: "phasset_error", message: error.localizedDescription, details: nil))
        }
        return
      }

      if let requestId {
        self.thumbnailRequests.removeValue(forKey: requestId)
      }
      if asset.localIdentifier != id {
        result(nil)
        return
      }
      guard let data = image?.jpegData(compressionQuality: 0.85) else {
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

  private func fetchAsset(id: String?) -> PHAsset? {
    guard let id else { return nil }
    return PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
  }

  private func setFavorite(id: String?, favorite: Bool, result: @escaping FlutterResult) {
    guard let asset = fetchAsset(id: id) else {
      result(false)
      return
    }
    PHPhotoLibrary.shared().performChanges {
      PHAssetChangeRequest(for: asset).isFavorite = favorite
    } completionHandler: { success, _ in
      DispatchQueue.main.async { result(success) }
    }
  }

  private func presentShareSheet(id: String?, result: @escaping FlutterResult) {
    guard let asset = fetchAsset(id: id) else {
      result(false)
      return
    }
    let scale = UIScreen.main.scale
    let targetSize = CGSize(width: UIScreen.main.bounds.width * scale, height: UIScreen.main.bounds.height * scale)
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true
    imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
      guard let image else {
        result(false)
        return
      }
      let controller = self.window?.rootViewController
      let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
      // iPad requires an anchor; full-screen presentation avoids crashes.
      activity.popoverPresentationController?.sourceView = controller?.view
      controller?.present(activity, animated: true)
      result(true)
    }
  }

  private func loadVideoPlaybackUrl(id: String?, result: @escaping FlutterResult) {
    guard let asset = fetchAsset(id: id), asset.mediaType == .video else {
      result(nil)
      return
    }
    let options = PHVideoRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true
    imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
      DispatchQueue.main.async {
        if let urlAsset = avAsset as? AVURLAsset {
          result(urlAsset.url.absoluteString)
        } else {
          result(nil)
        }
      }
    }
  }

  private func loadPlaceLabel(latitude: Double, longitude: Double, result: @escaping FlutterResult) {
    // City-level label only; exact coordinates never leave this method's key.
    let cacheKey = String(format: "%.2f,%.2f", latitude, longitude)
    if let cached = placeLabelCache[cacheKey] {
      result(cached)
      return
    }
    let location = CLLocation(latitude: latitude, longitude: longitude)
    geocoder.reverseGeocodeLocation(location) { placemarks, _ in
      let placemark = placemarks?.first
      let label = placemark?.locality
        ?? placemark?.subAdministrativeArea
        ?? placemark?.administrativeArea
      if let label {
        self.placeLabelCache[cacheKey] = label
      }
      DispatchQueue.main.async { result(label) }
    }
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
