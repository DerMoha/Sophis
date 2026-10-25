import Flutter
import FoundationModels
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
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterMethodNotImplemented)
      return
    }
    if call.method == "interpretLabel", let text = args["text"] as? String {
      interpretLabel(text: text, result: result)
      return
    }
    guard let path = args["path"] as? String else {
      result(FlutterMethodNotImplemented)
      return
    }
    switch call.method {
    case "recognize":
      recognizeLines(path: path, result: result)
    case "recognizeDocument":
      recognizeDocument(path: path, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Decodes the image and normalizes EXIF orientation, so coordinates match
  /// upright crop pixels.
  private static func uprightImage(path: String) throws -> CGImage {
    guard let input = UIImage(contentsOfFile: path) else {
      throw NSError(domain: "NutritionOCR", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode image"])
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let upright = UIGraphicsImageRenderer(size: input.size, format: format).image { _ in
      input.draw(in: CGRect(origin: .zero, size: input.size))
    }
    guard let image = upright.cgImage else {
      throw NSError(domain: "NutritionOCR", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot normalize image"])
    }
    return image
  }

  /// Reads tables as rows of cell transcripts (iOS 26+ document recognition).
  /// Cells are placed by their column index so merged or empty cells keep the
  /// remaining values in their columns.
  private func recognizeDocument(path: String, result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(FlutterError(code: "unsupported", message: "Document recognition needs iOS 26", details: nil))
      return
    }
    Task.detached(priority: .userInitiated) {
      do {
        let image = try Self.uprightImage(path: path)
        // Sideways photos often yield no table; retry turned a quarter each way.
        var observations: [DocumentObservation] = []
        for orientation in [nil, CGImagePropertyOrientation.right, .left] {
          observations = try await RecognizeDocumentsRequest().perform(on: image, orientation: orientation)
          if observations.contains(where: { !$0.document.tables.isEmpty }) { break }
        }
        let tables: [[[String]]] = observations.flatMap { observation in
          observation.document.tables.map { table in
            table.rows.map { cells in
              let width = (cells.map { $0.columnRange.upperBound }.max() ?? -1) + 1
              var row = Array(repeating: "", count: width)
              for cell in cells {
                row[cell.columnRange.lowerBound] = cell.content.text.transcript
              }
              return row
            }
          }
        }
        let text = observations.map { $0.document.text.transcript }.joined(separator: "\n")
        await MainActor.run { result(["tables": tables, "text": text]) }
      } catch {
        await MainActor.run {
          result(FlutterError(code: "recognition_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  /// Pairs nutrients with their per-100 values from OCR text using Apple's
  /// on-device language model (iOS 26+, Apple Intelligence). Nothing leaves
  /// the device. The caller must still check every number against the text.
  private func interpretLabel(text: String, result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(["status": "unavailable", "reason": "osVersion"])
      return
    }
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      break
    case .unavailable(let reason):
      result(["status": "unavailable", "reason": String(describing: reason)])
      return
    }
    Task.detached(priority: .userInitiated) {
      do {
        let session = LanguageModelSession(model: model, instructions: Self.labelInstructions)
        let response = try await session.respond(
          to: "OCR text of the nutrition label:\n\(text.prefix(6000))",
          generating: LabelFacts.self,
          options: GenerationOptions(samplingMode: .greedy)
        )
        let facts = response.content
        var values: [String: Any] = ["basis": facts.basis]
        if let v = facts.kcalPer100 { values["calories"] = v }
        if let v = facts.fatPer100 { values["fat"] = v }
        if let v = facts.carbohydratesPer100 { values["carbs"] = v }
        if let v = facts.fiberPer100 { values["fiber"] = v }
        if let v = facts.proteinPer100 { values["protein"] = v }
        if let v = facts.portionSize { values["serving"] = v }
        await MainActor.run { result(["status": "ok", "values": values]) }
      } catch {
        await MainActor.run {
          result(["status": "failed", "reason": error.localizedDescription])
        }
      }
    }
  }

  private static let labelInstructions = """
    You read food nutrition labels from OCR text. The text can be garbled, \
    in several languages, split across lines, or have a value on a different \
    line than its row name. Labels usually have a per 100 g or per 100 ml \
    column and sometimes a per portion column; always use the per 100 column. \
    Only return numbers that appear in the text. If a value is not printed, \
    leave it empty. Never estimate or calculate values.
    """

  private func recognizeLines(path: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let image = try Self.uprightImage(path: path)
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


@available(iOS 26.0, *)
@Generable
private struct LabelFacts {
  @Guide(description: "Basis of the per 100 column: g or ml")
  var basis: String
  @Guide(description: "Energy in kcal per 100 g or 100 ml, as printed")
  var kcalPer100: Double?
  @Guide(description: "Total fat per 100, not saturated fat")
  var fatPer100: Double?
  @Guide(description: "Total carbohydrates per 100, not sugars")
  var carbohydratesPer100: Double?
  @Guide(description: "Dietary fibre per 100")
  var fiberPer100: Double?
  @Guide(description: "Protein per 100")
  var proteinPer100: Double?
  @Guide(description: "Printed portion size in g or ml, if any")
  var portionSize: Double?
}
