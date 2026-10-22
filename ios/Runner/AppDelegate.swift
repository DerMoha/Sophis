import Flutter
import UIKit
import Vision
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required for flutter_local_notifications on iOS 10+
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NutritionTextRecognition") {
      NutritionTextRecognition.register(with: registrar)
    }
  }
}


/// The same line/word geometry contract as the Android ML Kit reader.
/// All recognition runs locally, off the main thread.
private final class NutritionTextRecognition: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "sophis/nutrition_text", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(NutritionTextRecognition(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognize",
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      result(FlutterMethodNotImplemented)
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        guard let input = UIImage(contentsOfFile: path) else {
          throw NSError(domain: "NutritionOCR", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode image"])
        }
        // Normalize EXIF orientation; coordinates now match upright crop pixels.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let upright = UIGraphicsImageRenderer(size: input.size, format: format).image { _ in
          input.draw(in: CGRect(origin: .zero, size: input.size))
        }
        guard let image = upright.cgImage else {
          throw NSError(domain: "NutritionOCR", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot normalize image"])
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        func pixels(_ rect: CGRect) -> CGRect {
          CGRect(x: rect.minX * width, y: (1 - rect.maxY) * height,
                 width: rect.width * width, height: rect.height * height)
        }
        let words = try NSRegularExpression(pattern: "\\S+")
        let lines: [[String: Any]] = (request.results ?? []).compactMap { observation in
          guard let text = observation.topCandidates(1).first else { return nil }
          let rect = pixels(observation.boundingBox)
          let tokens: [[String: Any]] = words.matches(in: text.string, range: NSRange(text.string.startIndex..., in: text.string)).compactMap { match in
            guard let range = Range(match.range, in: text.string),
                  let box = try? text.boundingBox(for: range) else { return nil }
            let wordRect = pixels(box.boundingBox)
            return ["text": String(text.string[range]), "centerX": wordRect.midX, "centerY": wordRect.midY]
          }
          return ["text": text.string, "top": rect.minY, "height": rect.height,
                  "left": rect.minX, "right": rect.maxX, "tokens": tokens]
        }
        DispatchQueue.main.async { result(lines) }
      } catch {
        DispatchQueue.main.async { result(FlutterError(code: "recognition_failed", message: error.localizedDescription, details: nil)) }
      }
    }
  }
}
