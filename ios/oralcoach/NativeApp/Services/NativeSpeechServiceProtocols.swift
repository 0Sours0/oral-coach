import AVFoundation
import Foundation
import Speech
import SpeechEngineToB

enum NativeSpeechServiceError: LocalizedError {
  case notImplemented(String)
  case notConfigured(String)
  case invalidResponse(String)
  case requestFailed(String)
  case noAudioReceived
  case playbackFailed

  var errorDescription: String? {
    switch self {
    case .notImplemented(let name):
      return "\(name) is not implemented yet"
    case .notConfigured(let name):
      return "\(name) is not configured"
    case .invalidResponse(let message):
      return "Speech service returned an invalid response: \(message)"
    case .requestFailed(let message):
      return message
    case .noAudioReceived:
      return "Speech synthesis returned no audio."
    case .playbackFailed:
      return "Audio playback failed."
    }
  }
}

struct NativeRealtimeDialogConfiguration: Equatable {
  var appId: String
  var appKey: String
  var token: String
  var resourceId: String
  var uid: String
  var dialogAddress: String
  var dialogUri: String
  var requestHeaders: String?
}

struct NativeVolcengineASRConfiguration: Equatable {
  var appId: String
  var appKey: String
  var accessToken: String
  var resourceId: String
  var address: String
  var uri: String
  var requestHeaders: String?
}

struct NativeVolcengineTTSConfiguration: Equatable {
  var appId: String
  var appKey: String
  var accessToken: String
  var resourceId: String
  var address: String
  var uri: String
  var voice: String
  var requestHeaders: String?
}

protocol NativeASRTranscribing {
  func transcribe(audioURL: URL) async throws -> String
}

protocol NativeSpeechSynthesizing {
  func synthesize(text: String, voiceID: String) async throws -> URL
}

protocol NativeAudioRecording {
  func startRecording() async throws
  func stopRecording() async throws -> URL
}

@MainActor
protocol NativeTextSpeaking {
  func speak(text: String, voiceID: String) async throws
}

protocol NativeRealtimeDialogControlling {
  func configure(_ configuration: NativeRealtimeDialogConfiguration) async throws
  func startSession(botName: String, instruction: String) async throws
  func stopSession() async throws
  func sendTextQuery(_ text: String) async throws
  func sendRagEntries(_ entries: [NativePromptRagEntry]) async throws
  func destroy() async throws
}

extension Notification.Name {
  static let nativeRealtimeDialogEvent = Notification.Name("nativeRealtimeDialogEvent")
}

struct NativeRealtimeDialogEventPayload: Equatable {
  let name: String
  let type: Int
  let rawData: String
  let text: String
}

enum NativeVoiceCaptureError: LocalizedError {
  case microphonePermissionDenied
  case speechPermissionDenied
  case recorderUnavailable
  case recognizerUnavailable
  case noSpeechDetected

  var errorDescription: String? {
    switch self {
    case .microphonePermissionDenied:
      return "Microphone permission was denied."
    case .speechPermissionDenied:
      return "Speech recognition permission was denied."
    case .recorderUnavailable:
      return "Audio recorder is unavailable."
    case .recognizerUnavailable:
      return "Speech recognizer is unavailable."
    case .noSpeechDetected:
      return "No speech was detected in the recording."
    }
  }
}

final class NativeAVAudioRecorderService: NSObject, NativeAudioRecording {
  private var recorder: AVAudioRecorder?
  private var recordingURL: URL?

  func startRecording() async throws {
    let granted = await requestMicrophonePermission()
    guard granted else {
      throw NativeVoiceCaptureError.microphonePermissionDenied
    }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
    try session.setActive(true)

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("voice-\(UUID().uuidString)")
      .appendingPathExtension("wav")

    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 16_000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    let recorder = try AVAudioRecorder(url: url, settings: settings)
    recorder.prepareToRecord()
    guard recorder.record() else {
      throw NativeVoiceCaptureError.recorderUnavailable
    }

    self.recorder = recorder
    recordingURL = url
  }

  func stopRecording() async throws -> URL {
    guard let recorder, let recordingURL else {
      throw NativeVoiceCaptureError.recorderUnavailable
    }

    recorder.stop()
    self.recorder = nil
    self.recordingURL = nil
    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    return recordingURL
  }

  private func requestMicrophonePermission() async -> Bool {
    await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }
}

final class NativeAppleSpeechTranscriber: NativeASRTranscribing {
  private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

  func transcribe(audioURL: URL) async throws -> String {
    let permission = await requestSpeechPermission()
    guard permission else {
      throw NativeVoiceCaptureError.speechPermissionDenied
    }
    guard let recognizer else {
      throw NativeVoiceCaptureError.recognizerUnavailable
    }

    let request = SFSpeechURLRecognitionRequest(url: audioURL)
    request.shouldReportPartialResults = false
    request.requiresOnDeviceRecognition = false

    return try await withCheckedThrowingContinuation { continuation in
      var completed = false
      recognizer.recognitionTask(with: request) { result, error in
        guard !completed else { return }

        if let error {
          completed = true
          continuation.resume(throwing: error)
          return
        }

        guard let result, result.isFinal else { return }
        completed = true
        let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        if transcript.isEmpty {
          continuation.resume(throwing: NativeVoiceCaptureError.noSpeechDetected)
        } else {
          continuation.resume(returning: transcript)
        }
      }
    }
  }

  private func requestSpeechPermission() async -> Bool {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status == .authorized)
      }
    }
  }
}

final class NativeVolcengineASRTranscriber: NSObject, NativeASRTranscribing, SpeechEngineDelegate {
  private let configuration: NativeVolcengineASRConfiguration
  private var engine: SpeechEngine?
  private var continuation: CheckedContinuation<String, Error>?
  private var hasCompleted = false
  private var preparedAudioURL: URL?

  init(configuration: NativeVolcengineASRConfiguration) {
    self.configuration = configuration
  }

  deinit {
    cleanupEngine()
  }

  func transcribe(audioURL: URL) async throws -> String {
    guard !configuration.appId.isEmpty, !configuration.accessToken.isEmpty else {
      throw NativeSpeechServiceError.notConfigured("Volcengine BigASR")
    }

    print("[BigASR] transcribe() start — appId=\(configuration.appId) resourceId=\(configuration.resourceId) address=\(configuration.address) uri=\(configuration.uri)")
    print("[BigASR] audio file: \(audioURL.path)")

    cleanupEngine()
    hasCompleted = false
    preparedAudioURL = try prepareAudioFileIfNeeded(audioURL)
    let resolvedAudioURL = preparedAudioURL ?? audioURL
    print("[BigASR] resolved audio: \(resolvedAudioURL.path) exists=\(FileManager.default.fileExists(atPath: resolvedAudioURL.path))")

    _ = SpeechEngine.prepareEnvironment()
    let engine = SpeechEngine()
    guard engine.createEngine(with: self) else {
      print("[BigASR] ❌ createEngine failed")
      throw NativeSpeechServiceError.requestFailed("BigASR engine create failed")
    }
    self.engine = engine
    print("[BigASR] ✅ createEngine OK")

    configureEngine(engine)
    let initResult = engine.initEngine()
    print("[BigASR] initEngine result: \(initResult.rawValue)")
    guard initResult == SENoError else {
      cleanupEngine()
      throw NativeSpeechServiceError.requestFailed("BigASR init failed: \(initResult.rawValue)")
    }
    print("[BigASR] ✅ initEngine OK")

    engine.setStringParam(resolvedAudioURL.path, forKey: SE_PARAMS_KEY_RECORDER_FILE_STRING)
    _ = engine.send(SEDirectiveSyncStopEngine)

    let startResult = engine.send(SEDirectiveStartEngine)
    print("[BigASR] SEDirectiveStartEngine result: \(startResult.rawValue)")
    guard startResult == SENoError else {
      cleanupEngine()
      throw NativeSpeechServiceError.requestFailed("BigASR start failed: \(startResult.rawValue)")
    }
    print("[BigASR] waiting for result...")

    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
    }
  }

  func onMessage(with type: SEMessageType, andData data: Data) {
    let dataStr = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
    print("[BigASR] onMessage type=\(type.rawValue) data=\(dataStr)")
    switch type {
    case SEFinalResult:
      let transcript = parseTranscript(from: data)
      print("[BigASR] ✅ final result: \(transcript)")
      finish(with: transcript)
    case SEEngineError:
      let errorText = String(data: data, encoding: .utf8) ?? "Unknown BigASR error"
      print("[BigASR] ❌ error: \(errorText)")
      fail(NativeSpeechServiceError.requestFailed(errorText))
    case SEEngineStart:
      print("[BigASR] engine started")
    case SEEngineStop:
      print("[BigASR] engine stopped")
    default:
      break
    }
  }

  private func configureEngine(_ engine: SpeechEngine) {
    let debugPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
    let requestHeaders = normalizedRequestHeaders(configuration.requestHeaders)
    engine.setStringParam(SE_ASR_ENGINE, forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
    engine.setStringParam(debugPath, forKey: SE_PARAMS_KEY_DEBUG_PATH_STRING)
    engine.setStringParam(SE_LOG_LEVEL_DEBUG, forKey: SE_PARAMS_KEY_LOG_LEVEL_STRING)
    engine.setStringParam("native-oral-coach-user", forKey: SE_PARAMS_KEY_UID_STRING)
    engine.setStringParam(SE_RECORDER_TYPE_FILE, forKey: SE_PARAMS_KEY_RECORDER_TYPE_STRING)
    engine.setStringParam(configuration.address, forKey: SE_PARAMS_KEY_ASR_ADDRESS_STRING)
    engine.setStringParam(configuration.uri, forKey: SE_PARAMS_KEY_ASR_URI_STRING)
    engine.setStringParam(configuration.appId, forKey: SE_PARAMS_KEY_APP_ID_STRING)
    if !configuration.appKey.isEmpty {
      engine.setStringParam(configuration.appKey, forKey: SE_PARAMS_KEY_APP_KEY_STRING)
    }
    engine.setStringParam(configuration.accessToken, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
    engine.setStringParam(configuration.resourceId, forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)
    engine.setIntParam(Int(SEProtocolTypeSeed.rawValue), forKey: SE_PARAMS_KEY_PROTOCOL_TYPE_INT)
    engine.setIntParam(16_000, forKey: SE_PARAMS_KEY_SAMPLE_RATE_INT)
    engine.setIntParam(1, forKey: SE_PARAMS_KEY_CHANNEL_NUM_INT)
    engine.setIntParam(1, forKey: SE_PARAMS_KEY_UP_CHANNEL_NUM_INT)
    engine.setBoolParam(true, forKey: SE_PARAMS_KEY_ASR_ENABLE_ITN_BOOL)
    engine.setBoolParam(true, forKey: SE_PARAMS_KEY_ASR_SHOW_PUNC_BOOL)
    engine.setStringParam(asrRequestParams, forKey: SE_PARAMS_KEY_ASR_REQ_PARAMS_STRING)
    engine.setStringParam(requestHeaders, forKey: SE_PARAMS_KEY_REQUEST_HEADERS_STRING)
  }

  private func parseTranscript(from data: Data) -> String {
    if
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let result = json["result"] as? [String: Any],
      let text = result["text"] as? String,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return text
    }

    let rawText = String(data: data, encoding: .utf8) ?? ""
    return rawText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func normalizedRequestHeaders(_ headers: String?) -> String {
    let trimmed = (headers ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "{}" : trimmed
  }

  private var asrRequestParams: String {
    #"{"model_name":"bigmodel"}"#
  }

  private func finish(with text: String) {
    guard !hasCompleted else { return }
    hasCompleted = true
    continuation?.resume(returning: text)
    continuation = nil
    _ = engine?.send(SEDirectiveStopEngine)
    cleanupEngine()
  }

  private func fail(_ error: Error) {
    guard !hasCompleted else { return }
    hasCompleted = true
    continuation?.resume(throwing: error)
    continuation = nil
    _ = engine?.send(SEDirectiveStopEngine)
    cleanupEngine()
  }

  private func cleanupEngine() {
    engine?.destroy()
    engine = nil
    if let preparedAudioURL, preparedAudioURL.pathExtension.lowercased() == "pcm" {
      try? FileManager.default.removeItem(at: preparedAudioURL)
    }
    preparedAudioURL = nil
  }

  private func prepareAudioFileIfNeeded(_ audioURL: URL) throws -> URL {
    let data = try Data(contentsOf: audioURL)
    guard let pcmData = extractPCMDataFromWAV(data) else {
      return audioURL
    }

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("voice-\(UUID().uuidString)")
      .appendingPathExtension("pcm")
    try pcmData.write(to: outputURL, options: .atomic)
    return outputURL
  }

  private func extractPCMDataFromWAV(_ data: Data) -> Data? {
    guard data.count > 44 else { return nil }
    guard String(data: data.prefix(4), encoding: .ascii) == "RIFF" else { return nil }
    guard String(data: data.subdata(in: 8 ..< 12), encoding: .ascii) == "WAVE" else { return nil }

    var offset = 12
    while offset + 8 <= data.count {
      let chunkIDData = data.subdata(in: offset ..< offset + 4)
      let chunkSizeData = data.subdata(in: offset + 4 ..< offset + 8)
      let chunkID = String(data: chunkIDData, encoding: .ascii) ?? ""
      let chunkSize = Int(chunkSizeData.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian)
      let chunkDataStart = offset + 8
      let chunkDataEnd = chunkDataStart + chunkSize

      guard chunkDataEnd <= data.count else { return nil }
      if chunkID == "data" {
        return data.subdata(in: chunkDataStart ..< chunkDataEnd)
      }

      offset = chunkDataEnd + (chunkSize % 2)
    }

    return nil
  }
}

@MainActor
final class NativeSpeechSynthesizerSpeaker: NSObject, NativeTextSpeaking {
  private let synthesizer = AVSpeechSynthesizer()

  func speak(text: String, voiceID _: String) async throws {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    if synthesizer.isSpeaking {
      synthesizer.stopSpeaking(at: .immediate)
    }

    let utterance = AVSpeechUtterance(string: trimmed)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
    utterance.pitchMultiplier = 1.0
    utterance.postUtteranceDelay = 0.05
    synthesizer.speak(utterance)
  }
}

final class NativeVolcengineSpeechSynthesizer: NativeSpeechSynthesizing {
  private let configuration: NativeVolcengineTTSConfiguration

  init(configuration: NativeVolcengineTTSConfiguration) {
    self.configuration = configuration
  }

  func synthesize(text _: String, voiceID _: String) async throws -> URL {
    throw NativeSpeechServiceError.notImplemented("NativeVolcengineSpeechSynthesizer file output")
  }
}

final class NativeVolcengineSpeechSpeaker: NSObject, NativeTextSpeaking, SpeechEngineDelegate {
  private let configuration: NativeVolcengineTTSConfiguration
  private var engine: SpeechEngine?
  private var continuation: CheckedContinuation<Void, Error>?
  private var pendingText = ""
  private var activeVoice = ""
  private var hasCompleted = false

  init(configuration: NativeVolcengineTTSConfiguration) {
    self.configuration = configuration
  }

  @MainActor
  func speak(text: String, voiceID: String) async throws {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard !configuration.appId.isEmpty, !configuration.accessToken.isEmpty else {
      throw NativeSpeechServiceError.notConfigured("Volcengine BiTTS")
    }

    print("[BiTTS] speak() start — appId=\(configuration.appId) resourceId=\(configuration.resourceId) voice=\(resolveVoice(voiceID)) address=\(configuration.address) uri=\(configuration.uri)")

    pendingText = trimmed
    activeVoice = resolveVoice(voiceID)
    hasCompleted = false

    cleanupEngine()
    _ = SpeechEngine.prepareEnvironment()
    let engine = SpeechEngine()
    guard engine.createEngine(with: self) else {
      print("[BiTTS] ❌ createEngine failed")
      throw NativeSpeechServiceError.requestFailed("BiTTS engine create failed")
    }
    self.engine = engine
    print("[BiTTS] ✅ createEngine OK")

    configureEngine(engine)
    let initResult = engine.initEngine()
    print("[BiTTS] initEngine result: \(initResult.rawValue)")
    guard initResult == SENoError else {
      cleanupEngine()
      throw NativeSpeechServiceError.requestFailed("BiTTS init failed: \(initResult.rawValue)")
    }
    print("[BiTTS] ✅ initEngine OK")

    _ = engine.send(SEDirectiveSyncStopEngine)

    let startPayload = """
    {"req_params":{"speaker":"\(activeVoice)","audio_params":{"format":"mp3","sample_rate":24000,"bit_rate":128000}}}
    """
    print("[BiTTS] sending SEDirectiveStartEngine payload: \(startPayload)")
    let startResult = engine.send(SEDirectiveStartEngine, data: startPayload)
    print("[BiTTS] SEDirectiveStartEngine result: \(startResult.rawValue)")
    guard startResult == SENoError else {
      cleanupEngine()
      throw NativeSpeechServiceError.requestFailed("BiTTS start failed: \(startResult.rawValue)")
    }

    print("[BiTTS] waiting for engine started callback...")
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
    }
  }

  func onMessage(with type: SEMessageType, andData data: Data) {
    let dataStr = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
    print("[BiTTS] onMessage type=\(type.rawValue) data=\(dataStr)")
    switch type {
    case SEEngineStart:
      print("[BiTTS] ✅ engine started, sending session...")
      startSession()
    case SEEventSessionFailed, SEEngineError:
      let errorText = String(data: data, encoding: .utf8) ?? "Unknown BiTTS error"
      print("[BiTTS] ❌ error: \(errorText)")
      fail(NativeSpeechServiceError.requestFailed(errorText))
    case SEEngineStop:
      print("[BiTTS] engine stopped")
    case SEPlayerFinishPlayAudio:
      print("[BiTTS] ✅ playback finished")
      finish()
    default:
      break
    }
  }

  private func configureEngine(_ engine: SpeechEngine) {
    let debugPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
    let requestHeaders = normalizedRequestHeaders(configuration.requestHeaders)
    engine.setStringParam(SE_BITTS_ENGINE, forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
    engine.setStringParam(debugPath, forKey: SE_PARAMS_KEY_DEBUG_PATH_STRING)
    engine.setStringParam(SE_LOG_LEVEL_DEBUG, forKey: SE_PARAMS_KEY_LOG_LEVEL_STRING)
    engine.setStringParam("native-oral-coach-user", forKey: SE_PARAMS_KEY_UID_STRING)
    engine.setStringParam(configuration.appId, forKey: SE_PARAMS_KEY_APP_ID_STRING)
    if !configuration.appKey.isEmpty {
      engine.setStringParam(configuration.appKey, forKey: SE_PARAMS_KEY_APP_KEY_STRING)
    }
    engine.setStringParam(configuration.accessToken, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
    engine.setStringParam(configuration.address, forKey: SE_PARAMS_KEY_TTS_ADDRESS_STRING)
    engine.setStringParam(configuration.uri, forKey: SE_PARAMS_KEY_TTS_URI_STRING)
    engine.setStringParam(configuration.resourceId, forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)
    engine.setBoolParam(true, forKey: SE_PARAMS_KEY_TTS_ENABLE_PLAYER_BOOL)
    engine.setBoolParam(false, forKey: SE_PARAMS_KEY_ENABLE_PLAYER_AUDIO_CALLBACK_BOOL)
    engine.setIntParam(10_000, forKey: SE_PARAMS_KEY_TTS_CONN_TIMEOUT_INT)
    engine.setStringParam(requestHeaders, forKey: SE_PARAMS_KEY_REQUEST_HEADERS_STRING)
  }

  private func startSession() {
    guard let engine else { return }
    let startSessionResult = engine.send(SEDirectiveEventStartSession, data: "")
    guard startSessionResult == SENoError else {
      fail(NativeSpeechServiceError.requestFailed("BiTTS start session failed: \(startSessionResult)"))
      return
    }

    let escapedText = escapeJSONString(pendingText)
    let taskPayload = #"{"req_params":{"text":"\#(escapedText)"}}"#
    let taskResult = engine.send(SEDirectiveEventTaskRequest, data: taskPayload)
    guard taskResult == SENoError else {
      fail(NativeSpeechServiceError.requestFailed("BiTTS task request failed: \(taskResult)"))
      return
    }

    let finishResult = engine.send(SEDirectiveEventFinishSession, data: "")
    guard finishResult == SENoError else {
      fail(NativeSpeechServiceError.requestFailed("BiTTS finish session failed: \(finishResult)"))
      return
    }
  }

  private func resolveVoice(_ voiceID: String) -> String {
    // voiceID from settings uses OpenAI names (alloy, shimmer, etc.) — always use the Volcengine voice
    return configuration.voice
  }

  private func escapeJSONString(_ text: String) -> String {
    text
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "")
  }

  private func finish() {
    guard !hasCompleted else { return }
    hasCompleted = true
    continuation?.resume()
    continuation = nil
    _ = engine?.send(SEDirectiveStopEngine)
    cleanupEngine()
  }

  private func fail(_ error: Error) {
    guard !hasCompleted else { return }
    hasCompleted = true
    continuation?.resume(throwing: error)
    continuation = nil
    _ = engine?.send(SEDirectiveStopEngine)
    cleanupEngine()
  }

  private func cleanupEngine() {
    engine?.destroy()
    engine = nil
  }

  private func normalizedRequestHeaders(_ headers: String?) -> String {
    let trimmed = (headers ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "{}" : trimmed
  }
}

final class NativePreviewAudioRecorder: NativeAudioRecording {
  func startRecording() async throws {}

  func stopRecording() async throws -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("preview.m4a")
  }
}

final class NativePreviewSpeechTranscriber: NativeASRTranscribing {
  func transcribe(audioURL _: URL) async throws -> String {
    "I have been feeling stuck at work lately."
  }
}

@MainActor
final class NativePreviewTextSpeaker: NativeTextSpeaking {
  func speak(text _: String, voiceID _: String) async throws {}
}

final class NativeVolcengineRealtimeDialogController: NSObject, NativeRealtimeDialogControlling, SpeechEngineDelegate {
  private var engine: SpeechEngine?
  private var configured = false

  func configure(_ configuration: NativeRealtimeDialogConfiguration) async throws {
    ensureEngine(with: configuration)
    _ = engine?.initEngine()
    configured = true
  }

  func startSession(botName: String, instruction: String) async throws {
    guard configured else {
      throw NativeSpeechServiceError.notImplemented("Realtime dialog is not configured")
    }

    let dialogPayload = [
      "bot_name": botName,
      "instruction": instruction,
      "prompt": instruction,
      "system_prompt": instruction,
    ]
    let payload = try jsonString(from: ["dialog": dialogPayload])
    _ = engine?.send(SEDirectiveSyncStopEngine)
    _ = engine?.send(SEDirectiveStartEngine, data: payload)
  }

  func stopSession() async throws {
    _ = engine?.send(SEDirectiveSyncStopEngine)
  }

  func sendTextQuery(_ text: String) async throws {
    guard configured else {
      throw NativeSpeechServiceError.notImplemented("Realtime dialog is not configured")
    }

    let payload = try jsonString(from: ["content": text])
    _ = engine?.send(SEDirectiveEventChatTextQuery, data: payload)
  }

  func sendRagEntries(_ entries: [NativePromptRagEntry]) async throws {
    guard configured else {
      throw NativeSpeechServiceError.notImplemented("Realtime dialog is not configured")
    }

    let entryArray = entries.map { ["title": $0.title, "content": $0.content] }
    let externalRAG = try jsonString(from: entryArray)
    let payload = try jsonString(from: ["external_rag": externalRAG])
    _ = engine?.send(SEDirectiveEventChatRagText, data: payload)
  }

  func destroy() async throws {
    _ = engine?.send(SEDirectiveSyncStopEngine)
    engine?.destroy()
    engine = nil
    configured = false
  }

  func onMessage(with type: SEMessageType, andData data: Data) {
    guard let eventName = eventName(for: type) else { return }

    let payload = NativeRealtimeDialogEventPayload(
      name: eventName,
      type: Int(type.rawValue),
      rawData: string(from: data),
      text: text(for: type, data: data)
    )

    NotificationCenter.default.post(
      name: .nativeRealtimeDialogEvent,
      object: self,
      userInfo: [
        "name": payload.name,
        "type": payload.type,
        "rawData": payload.rawData,
        "text": payload.text,
      ]
    )
  }

  private func ensureEngine(with configuration: NativeRealtimeDialogConfiguration) {
    if engine == nil {
      _ = SpeechEngine.prepareEnvironment()
      let createdEngine = SpeechEngine()
      _ = createdEngine.createEngine(with: self)
      engine = createdEngine
    }

    guard let engine else { return }

    engine.setStringParam(configuration.appId, forKey: SE_PARAMS_KEY_APP_ID_STRING)
    if !configuration.appKey.isEmpty {
      engine.setStringParam(configuration.appKey, forKey: SE_PARAMS_KEY_APP_KEY_STRING)
    }
    engine.setStringParam(configuration.token, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
    engine.setStringParam(configuration.resourceId, forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)
    engine.setStringParam(configuration.uid, forKey: SE_PARAMS_KEY_UID_STRING)
    engine.setStringParam(configuration.dialogAddress, forKey: SE_PARAMS_KEY_DIALOG_ADDRESS_STRING)
    engine.setStringParam(configuration.dialogUri, forKey: SE_PARAMS_KEY_DIALOG_URI_STRING)
    engine.setStringParam(
      NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "",
      forKey: SE_PARAMS_KEY_DEBUG_PATH_STRING
    )
    engine.setStringParam(SE_LOG_LEVEL_TRACE, forKey: SE_PARAMS_KEY_LOG_LEVEL_STRING)
    engine.setStringParam(SE_RECORDER_TYPE_RECORDER, forKey: SE_PARAMS_KEY_RECORDER_TYPE_STRING)
    engine.setBoolParam(true, forKey: SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL)
    engine.setBoolParam(false, forKey: SE_PARAMS_KEY_DIALOG_ENABLE_RECORDER_AUDIO_CALLBACK_BOOL)
    engine.setBoolParam(false, forKey: SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_AUDIO_CALLBACK_BOOL)
    engine.setBoolParam(false, forKey: SE_PARAMS_KEY_DIALOG_ENABLE_DECODER_AUDIO_CALLBACK_BOOL)
    engine.setStringParam(configuration.requestHeaders ?? "", forKey: SE_PARAMS_KEY_REQUEST_HEADERS_STRING)
    engine.setBoolParam(true, forKey: SE_PARAMS_KEY_ENABLE_AEC_BOOL)
    if let aecPath = Bundle.main.path(forResource: "aec", ofType: "model") {
      engine.setStringParam(aecPath, forKey: SE_PARAMS_KEY_AEC_MODEL_PATH_STRING)
    }
    engine.setStringParam(SE_DIALOG_ENGINE, forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
  }

  private func string(from data: Data?) -> String {
    guard let data else { return "" }
    return String(data: data, encoding: .utf8) ?? ""
  }

  private func jsonObject(from data: Data?) -> Any? {
    guard let data else { return nil }
    return try? JSONSerialization.jsonObject(with: data)
  }

  private func asrText(from data: Data?) -> String {
    guard
      let json = jsonObject(from: data) as? [String: Any],
      let results = json["results"] as? [[String: Any]],
      let first = results.first,
      let text = first["text"] as? String
    else {
      return ""
    }
    return text
  }

  private func chatText(from data: Data?) -> String {
    guard
      let json = jsonObject(from: data) as? [String: Any],
      let text = json["content"] as? String
    else {
      return ""
    }
    return text
  }

  private func text(for type: SEMessageType, data: Data?) -> String {
    switch type {
    case SEEventASRResponse:
      return asrText(from: data)
    case SEEventChatResponse:
      return chatText(from: data)
    default:
      return string(from: data)
    }
  }

  private func eventName(for type: SEMessageType) -> String? {
    switch type {
    case SEEngineStart:
      return "engine_started"
    case SEEngineStop:
      return "engine_stopped"
    case SEEngineError, SEEventSessionFailed:
      return "error"
    case SEEventASRInfo:
      return "asr_info"
    case SEEventASRResponse:
      return "asr_response"
    case SEEventASREnded:
      return "asr_ended"
    case SEEventChatResponse:
      return "chat_response"
    case SEEventChatEnded:
      return "chat_ended"
    default:
      return nil
    }
  }

  private func jsonString(from object: Any) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object)
    return String(data: data, encoding: .utf8) ?? "{}"
  }
}
