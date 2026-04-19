import Foundation
import SwiftUI

enum NativeAppTab: String, CaseIterable, Identifiable {
  case conversation
  case records
  case settings

  var id: String { rawValue }
}

@MainActor
final class NativeAppShellState: ObservableObject {
  @Published var selectedTab: NativeAppTab = .conversation
}

@MainActor
enum NativeAppDependencies {
  static let shared = NativeAppDependencyContainer.live()
}

@MainActor
final class NativeAppDependencyContainer: ObservableObject {
  let repositories: NativeAppRepositorySet
  let conversationFeatureDependencies: ConversationFeatureDependencies
  let recordsRepository: any NativeRecordsRepository
  let settingsRepository: any NativeSettingsRepository

  private init(
    repositories: NativeAppRepositorySet,
    conversationFeatureDependencies: ConversationFeatureDependencies,
    recordsRepository: any NativeRecordsRepository,
    settingsRepository: any NativeSettingsRepository
  ) {
    self.repositories = repositories
    self.conversationFeatureDependencies = conversationFeatureDependencies
    self.recordsRepository = recordsRepository
    self.settingsRepository = settingsRepository
  }

  static func live() -> NativeAppDependencyContainer {
    let repositories = NativeAppRepositorySet.live()
    let runtime = NativeRuntimeEnvironment.load()
    let deepSeekClient = NativeDeepSeekClient(
      configuration: NativeDeepSeekClientConfiguration(
        apiKey: runtime.deepSeekAPIKey
      )
    )
    let audioRecorder = NativeAVAudioRecorderService()
    let speechTranscriber: any NativeASRTranscribing = runtime.voiceMessageASRConfiguration.map {
      NativeVolcengineASRTranscriber(configuration: $0)
    } ?? NativeAppleSpeechTranscriber()
    let textSpeaker: any NativeTextSpeaking = runtime.voiceMessageTTSConfiguration.map {
      NativeVolcengineSpeechSpeaker(configuration: $0)
    } ?? NativeSpeechSynthesizerSpeaker()
    let realtimeController = NativeVolcengineRealtimeDialogController()

    let conversationService = NativeDeepSeekConversationService(client: deepSeekClient)
    let metadataExtractor = NativeMetadataExtractionService(client: deepSeekClient)
    let relationshipMemoryUpdater = NativeRelationshipMemoryService(client: deepSeekClient)
    let summaryGenerator = NativeSummaryGenerationService(client: deepSeekClient)
    let languagePolicyEnforcer = NativeAssistantLanguagePolicyService(client: deepSeekClient)

    let conversationBackend = NativeConversationBackend(
      repositories: repositories,
      conversationService: conversationService,
      metadataExtractor: metadataExtractor,
      relationshipMemoryUpdater: relationshipMemoryUpdater,
      summaryGenerator: summaryGenerator,
      languagePolicyEnforcer: languagePolicyEnforcer,
      realtimeController: realtimeController,
      realtimeConfiguration: runtime.realtimeDialogConfiguration
    )

    let recordsRepository = NativeSQLiteRecordsRepository(repository: repositories.learningRecords)
    let settingsRepository = NativeSQLiteSettingsFeatureRepository(
      settingsRepository: repositories.settings,
      personaRepository: repositories.personas
    )

    return NativeAppDependencyContainer(
      repositories: repositories,
      conversationFeatureDependencies: ConversationFeatureDependencies(
        backend: conversationBackend,
        settingsStore: repositories.settings,
        audioRecorder: audioRecorder,
        speechTranscriber: speechTranscriber,
        textSpeaker: textSpeaker
      ),
      recordsRepository: recordsRepository,
      settingsRepository: settingsRepository
    )
  }
}

private struct NativeRuntimeEnvironment {
  let deepSeekAPIKey: String
  let volcengineAppID: String
  let volcengineAppKey: String
  let volcengineAccessToken: String
  let volcengineDialogAddress: String
  let volcengineDialogURI: String
  let volcengineDialogResourceID: String
  let volcengineRequestHeaders: String
  let volcengineASRAddress: String
  let volcengineASRURI: String
  let volcengineASRResourceID: String
  let volcengineTTSAddress: String
  let volcengineTTSURI: String
  let volcengineTTSResourceID: String
  let volcengineTTSVoice: String

  var realtimeDialogConfiguration: NativeRealtimeDialogConfiguration? {
    guard !volcengineAppID.isEmpty, !volcengineAccessToken.isEmpty else {
      return nil
    }

    return NativeRealtimeDialogConfiguration(
      appId: volcengineAppID,
      appKey: volcengineAppKey,
      token: volcengineAccessToken,
      resourceId: volcengineDialogResourceID.isEmpty ? "volc.speech.dialog" : volcengineDialogResourceID,
      uid: "native-oral-coach-user",
      dialogAddress: volcengineDialogAddress.isEmpty ? "wss://openspeech.bytedance.com" : volcengineDialogAddress,
      dialogUri: volcengineDialogURI.isEmpty ? "/api/v3/realtime/dialogue" : volcengineDialogURI,
      requestHeaders: volcengineRequestHeaders.isEmpty ? nil : volcengineRequestHeaders
    )
  }

  var voiceMessageASRConfiguration: NativeVolcengineASRConfiguration? {
    guard !volcengineAppID.isEmpty, !volcengineAccessToken.isEmpty else {
      return nil
    }

    return NativeVolcengineASRConfiguration(
      appId: volcengineAppID,
      appKey: volcengineAppKey,
      accessToken: volcengineAccessToken,
      resourceId: volcengineASRResourceID.isEmpty ? "volc.seedasr.sauc.duration" : volcengineASRResourceID,
      address: volcengineASRAddress.isEmpty ? "wss://openspeech.bytedance.com" : volcengineASRAddress,
      uri: volcengineASRURI.isEmpty ? "/api/v3/sauc/bigmodel" : volcengineASRURI,
      requestHeaders: resolvedSpeechHeaders(resourceId: volcengineASRResourceID.isEmpty ? "volc.seedasr.sauc.duration" : volcengineASRResourceID)
    )
  }

  var voiceMessageTTSConfiguration: NativeVolcengineTTSConfiguration? {
    guard !volcengineAppID.isEmpty, !volcengineAccessToken.isEmpty else {
      return nil
    }

    let voice = volcengineTTSVoice.isEmpty ? "zh_female_yingyujiaoxue_uranus_bigtts" : volcengineTTSVoice
    return NativeVolcengineTTSConfiguration(
      appId: volcengineAppID,
      appKey: volcengineAppKey,
      accessToken: volcengineAccessToken,
      resourceId: volcengineTTSResourceID.isEmpty ? defaultTTSResourceID(for: voice) : volcengineTTSResourceID,
      address: volcengineTTSAddress.isEmpty ? "wss://openspeech.bytedance.com" : volcengineTTSAddress,
      uri: volcengineTTSURI.isEmpty ? "/api/v3/tts/bidirection" : volcengineTTSURI,
      voice: voice,
      requestHeaders: resolvedSpeechHeaders(resourceId: volcengineTTSResourceID.isEmpty ? defaultTTSResourceID(for: voice) : volcengineTTSResourceID)
    )
  }

  static func load() -> NativeRuntimeEnvironment {
    NativeRuntimeEnvironment(
      deepSeekAPIKey: value(infoKey: "NativeDeepSeekAPIKey", envKey: "EXPO_PUBLIC_DEEPSEEK_API_KEY"),
      volcengineAppID: value(infoKey: "NativeVolcengineAppID", envKey: "EXPO_PUBLIC_VOLCENGINE_APP_ID"),
      volcengineAppKey: value(infoKey: "NativeVolcengineAppKey", envKey: "EXPO_PUBLIC_VOLCENGINE_APP_KEY"),
      volcengineAccessToken: value(infoKey: "NativeVolcengineAccessToken", envKey: "EXPO_PUBLIC_VOLCENGINE_ACCESS_TOKEN"),
      volcengineDialogAddress: value(infoKey: "NativeVolcengineDialogAddress", envKey: "EXPO_PUBLIC_VOLCENGINE_DIALOG_ADDRESS"),
      volcengineDialogURI: value(infoKey: "NativeVolcengineDialogURI", envKey: "EXPO_PUBLIC_VOLCENGINE_DIALOG_URI"),
      volcengineDialogResourceID: value(infoKey: "NativeVolcengineDialogResourceID", envKey: "EXPO_PUBLIC_VOLCENGINE_DIALOG_RESOURCE_ID"),
      volcengineRequestHeaders: value(infoKey: "NativeVolcengineRequestHeaders", envKey: "EXPO_PUBLIC_VOLCENGINE_REQUEST_HEADERS"),
      volcengineASRAddress: value(infoKey: "NativeVolcengineASRAddress", envKey: "EXPO_PUBLIC_VOLCENGINE_ASR_ADDRESS"),
      volcengineASRURI: value(infoKey: "NativeVolcengineASRURI", envKey: "EXPO_PUBLIC_VOLCENGINE_ASR_URI"),
      volcengineASRResourceID: value(infoKey: "NativeVolcengineASRResourceID", envKey: "EXPO_PUBLIC_VOLCENGINE_ASR_RESOURCE_ID"),
      volcengineTTSAddress: value(infoKey: "NativeVolcengineTTSAddress", envKey: "EXPO_PUBLIC_VOLCENGINE_TTS_ADDRESS"),
      volcengineTTSURI: value(infoKey: "NativeVolcengineTTSURI", envKey: "EXPO_PUBLIC_VOLCENGINE_TTS_URI"),
      volcengineTTSResourceID: value(infoKey: "NativeVolcengineTTSResourceID", envKey: "EXPO_PUBLIC_VOLCENGINE_TTS_RESOURCE_ID"),
      volcengineTTSVoice: value(infoKey: "NativeVolcengineTTSVoice", envKey: "EXPO_PUBLIC_VOLCENGINE_TTS_VOICE")
    )
  }

  private static func value(infoKey: String, envKey: String) -> String {
    if let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
       !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return value
    }

    let envValue = ProcessInfo.processInfo.environment[envKey] ?? ""
    return envValue.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func resolvedSpeechHeaders(resourceId: String) -> String? {
    let custom = volcengineRequestHeaders.trimmingCharacters(in: .whitespacesAndNewlines)
    if !custom.isEmpty {
      return custom
    }

    let connectID = UUID().uuidString
    let escapedResourceID = escapedJSON(resourceId)
    let escapedConnectID = escapedJSON(connectID)

    if !volcengineAppKey.isEmpty {
      return """
      {"X-Api-Key":"\(escapedJSON(volcengineAppKey))","X-Api-Resource-Id":"\(escapedResourceID)","X-Api-Connect-Id":"\(escapedConnectID)"}
      """
    }

    if !volcengineAppID.isEmpty, !volcengineAccessToken.isEmpty {
      return """
      {"X-Api-App-Key":"\(escapedJSON(volcengineAppID))","X-Api-Access-Key":"\(escapedJSON(volcengineAccessToken))","X-Api-Resource-Id":"\(escapedResourceID)","X-Api-Connect-Id":"\(escapedConnectID)"}
      """
    }

    return "{}"
  }

  private func defaultTTSResourceID(for voice: String) -> String {
    let trimmed = voice.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasPrefix("S_") ? "volc.megatts.default" : "volc.service_type.10029"
  }

  private func escapedJSON(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "")
  }
}
