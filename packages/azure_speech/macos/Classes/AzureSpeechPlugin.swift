import Cocoa
import FlutterMacOS
import MicrosoftCognitiveServicesSpeech

public class AzureSpeechPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "azure_speech",
      binaryMessenger: registrar.messenger)
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "Expected map", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let payload: String
          switch call.method {
          case "assess":
            payload = try Self.performAssessment(args: args)
          case "transcribe":
            payload = try Self.performTranscription(args: args)
          case "synthesize":
            payload = try Self.performSynthesis(args: args)
          default:
            DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
            return
          }
          DispatchQueue.main.async { result(payload) }
        } catch let e as NSError where e.domain == "AzureSpeech" {
          let code = e.code == 1 ? "no_speech" : "azure_speech_error"
          DispatchQueue.main.async {
            result(FlutterError(code: code, message: e.localizedDescription, details: nil))
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "azure_speech_error", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  private static func performAssessment(args: [String: Any]) throws -> String {
    let audioPath = args["audioPath"] as! String
    let referenceText = args["referenceText"] as! String
    let language = args["language"] as! String
    let token = args["token"] as? String
    let subscriptionKey = args["subscriptionKey"] as? String
    let region = args["region"] as! String
    let enableProsody = (args["enableProsody"] as? Bool) ?? true
    let enableMiscue = (args["enableMiscue"] as? Bool) ?? true
    let nbestPhonemeCount = (args["nbestPhonemeCount"] as? Int) ?? 1
    let phonemeAlphabet = (args["phonemeAlphabet"] as? String) ?? "IPA"
    let granularityStr = (args["granularity"] as? String) ?? "Phoneme"

    let granularity: SPXPronunciationAssessmentGranularity
    switch granularityStr {
    case "Word": granularity = .word
    case "FullText": granularity = .fullText
    default: granularity = .phoneme
    }

    let speechConfig: SPXSpeechConfiguration
    if let key = subscriptionKey, !key.isEmpty {
      speechConfig = try SPXSpeechConfiguration(subscription: key, region: region)
    } else {
      speechConfig = try SPXSpeechConfiguration(authorizationToken: token!, region: region)
    }
    speechConfig.speechRecognitionLanguage = language

    guard let audioConfig = SPXAudioConfiguration(wavFileInput: audioPath) else {
      throw NSError(
        domain: "AzureSpeech", code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Could not open audio file"])
    }

    let pronunciationConfig = try SPXPronunciationAssessmentConfiguration(
      referenceText,
      gradingSystem: .hundredMark,
      granularity: granularity,
      enableMiscue: enableMiscue)
    if enableProsody {
      pronunciationConfig.enableProsodyAssessment()
    }
    pronunciationConfig.phonemeAlphabet = phonemeAlphabet
    pronunciationConfig.nbestPhonemeCount = nbestPhonemeCount

    let speechRecognizer = try SPXSpeechRecognizer(
      speechConfiguration: speechConfig, audioConfiguration: audioConfig)

    try pronunciationConfig.apply(to: speechRecognizer)

    let semaphore = DispatchSemaphore(value: 0)
    var jsonOut: String?
    var errOut: NSError?

    try speechRecognizer.recognizeOnceAsync { recognitionResult in
      if recognitionResult.reason == SPXResultReason.recognizedSpeech {
        jsonOut = recognitionResult.properties?.getPropertyBy(
          SPXPropertyId.speechServiceResponseJsonResult)
        if jsonOut == nil || jsonOut!.isEmpty {
          errOut = NSError(
            domain: "AzureSpeech", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Empty JsonResult"])
        }
      } else if recognitionResult.reason == SPXResultReason.noMatch {
        errOut = NSError(
          domain: "AzureSpeech", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "No speech detected"])
      } else if recognitionResult.reason == SPXResultReason.canceled {
        let cancellationDetails = try? SPXCancellationDetails(
          fromCanceledRecognitionResult: recognitionResult)
        let msg = "\(String(describing: cancellationDetails?.reason)): \(cancellationDetails?.errorDetails ?? "")"
        errOut = NSError(
          domain: "AzureSpeech", code: 3,
          userInfo: [NSLocalizedDescriptionKey: msg])
      } else {
        errOut = NSError(
          domain: "AzureSpeech", code: 3,
          userInfo: [NSLocalizedDescriptionKey: "Unexpected result reason"])
      }
      semaphore.signal()
    }

    semaphore.wait()

    if let e = errOut { throw e }
    guard let json = jsonOut, !json.isEmpty else {
      throw NSError(
        domain: "AzureSpeech", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "No assessment JSON"])
    }
    return json
  }

  private static func performTranscription(args: [String: Any]) throws -> String {
    let audioPath = args["audioPath"] as! String
    let language = args["language"] as! String
    let subscriptionKey = args["subscriptionKey"] as! String
    let region = args["region"] as! String

    let speechConfig = try SPXSpeechConfiguration(subscription: subscriptionKey, region: region)
    speechConfig.speechRecognitionLanguage = language

    guard let audioConfig = SPXAudioConfiguration(wavFileInput: audioPath) else {
      throw NSError(
        domain: "AzureSpeech", code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Could not open audio file"])
    }

    let speechRecognizer = try SPXSpeechRecognizer(
      speechConfiguration: speechConfig, audioConfiguration: audioConfig)

    let semaphore = DispatchSemaphore(value: 0)
    var textOut: String?
    var errOut: NSError?

    try speechRecognizer.recognizeOnceAsync { recognitionResult in
      if recognitionResult.reason == SPXResultReason.recognizedSpeech {
        let text = recognitionResult.text ?? ""
        if text.isEmpty {
          errOut = NSError(
            domain: "AzureSpeech", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Empty transcription text"])
        } else {
          textOut = text
        }
      } else if recognitionResult.reason == SPXResultReason.noMatch {
        errOut = NSError(
          domain: "AzureSpeech", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "No speech detected"])
      } else if recognitionResult.reason == SPXResultReason.canceled {
        let cancellationDetails = try? SPXCancellationDetails(
          fromCanceledRecognitionResult: recognitionResult)
        let msg = "\(String(describing: cancellationDetails?.reason)): \(cancellationDetails?.errorDetails ?? "")"
        errOut = NSError(
          domain: "AzureSpeech", code: 3,
          userInfo: [NSLocalizedDescriptionKey: msg])
      } else {
        errOut = NSError(
          domain: "AzureSpeech", code: 3,
          userInfo: [NSLocalizedDescriptionKey: "Unexpected result reason"])
      }
      semaphore.signal()
    }

    semaphore.wait()

    if let e = errOut { throw e }
    guard let text = textOut, !text.isEmpty else {
      throw NSError(
        domain: "AzureSpeech", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "No transcription text"])
    }
    return text
  }

  private static func performSynthesis(args: [String: Any]) throws -> String {
    let text = args["text"] as! String
    let language = args["language"] as! String
    let token = args["token"] as? String
    let subscriptionKey = args["subscriptionKey"] as? String
    let region = args["region"] as! String
    let voice = args["voice"] as? String

    let speechConfig: SPXSpeechConfiguration
    if let key = subscriptionKey, !key.isEmpty {
      speechConfig = try SPXSpeechConfiguration(subscription: key, region: region)
    } else if let authToken = token, !authToken.isEmpty {
      speechConfig = try SPXSpeechConfiguration(authorizationToken: authToken, region: region)
    } else {
      throw NSError(
        domain: "AzureSpeech", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Either subscriptionKey or token is required"])
    }
    speechConfig.speechSynthesisLanguage = language
    if let voice = voice, !voice.isEmpty {
      speechConfig.speechSynthesisVoiceName = voice
    }

    // Collect word boundary events for transcript timing. The Azure Speech
    // SDK fires these on a background thread during speakText; append to the
    // captured array and emit them in the JSON response so the Dart side can
    // build a timed transcript (mirrors the Android/Windows plugins).
    var wordBoundaries: [[String: Any]] = []

    let synthesizer = try SPXSpeechSynthesizer(
      speechConfiguration: speechConfig, audioConfiguration: nil)

    // Register before speakText so events during synthesis are captured.
    // `duration` is an NSTimeInterval in seconds on the ObjC binding (unlike
    // Java/C++ which report ticks/ms), so convert to 100-ns ticks here to
    // match the method-channel contract the Dart parser expects.
    synthesizer.addSynthesisWordBoundaryEventHandler { _, eventArgs in
      wordBoundaries.append([
        "text": eventArgs.text,
        "audioOffset": eventArgs.audioOffset,
        "duration": Int(eventArgs.duration * 10_000_000),
      ])
    }

    let result = try synthesizer.speakText(text)
    if result.reason == SPXResultReason.synthesizingAudioCompleted {
      guard let audio = result.audioData, !audio.isEmpty else {
        throw NSError(
          domain: "AzureSpeech", code: 2,
          userInfo: [NSLocalizedDescriptionKey: "Empty synthesis audio"])
      }
      let audioB64 = audio.base64EncodedString()
      let jsonResponse: [String: Any] = [
        "audio": audioB64,
        "wordBoundaries": wordBoundaries,
      ]
      let jsonData = try JSONSerialization.data(withJSONObject: jsonResponse)
      return String(data: jsonData, encoding: .utf8) ?? audioB64
    }

    if result.reason == SPXResultReason.canceled {
      let cancellationDetails = try? SPXSpeechSynthesisCancellationDetails(
        fromCanceledSynthesisResult: result)
      let msg = "\(String(describing: cancellationDetails?.reason)): \(cancellationDetails?.errorDetails ?? "")"
      throw NSError(
        domain: "AzureSpeech", code: 3,
        userInfo: [NSLocalizedDescriptionKey: msg])
    }

    throw NSError(
      domain: "AzureSpeech", code: 3,
      userInfo: [NSLocalizedDescriptionKey: "Unexpected synthesis result reason"])
  }
}
