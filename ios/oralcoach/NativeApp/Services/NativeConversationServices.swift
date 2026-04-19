import Foundation

protocol NativeConversationGenerating {
  func sendReply(
    settings: Settings,
    messages: [Message],
    summary: Summary?,
    persona: PersonaProfile?,
    relationshipMemory: RelationshipMemory?,
    systemPromptOverride: String?,
    temperature: Double
  ) async throws -> NativeDeepSeekReply

  func streamReply(
    settings: Settings,
    messages: [Message],
    summary: Summary?,
    persona: PersonaProfile?,
    relationshipMemory: RelationshipMemory?,
    systemPromptOverride: String?,
    temperature: Double,
    onDelta: @escaping (_ delta: String, _ fullText: String) -> Void
  ) async throws -> String
}

final class NativeDeepSeekConversationService: NativeConversationGenerating {
  private let client: NativeDeepSeekClientProtocol

  init(client: NativeDeepSeekClientProtocol) {
    self.client = client
  }

  func sendReply(
    settings: Settings,
    messages: [Message],
    summary: Summary?,
    persona: PersonaProfile?,
    relationshipMemory: RelationshipMemory?,
    systemPromptOverride: String? = nil,
    temperature: Double = 0.7
  ) async throws -> NativeDeepSeekReply {
    let prompt = NativePromptBuilder.buildConversationPromptContext(
      settings: settings,
      allMessages: messages,
      summary: summary,
      systemPromptOverride: systemPromptOverride ?? NativePromptBuilder.buildSystemPrompt(settings),
      persona: persona,
      relationshipMemory: relationshipMemory
    )
    return try await client.sendChat(messages: prompt, temperature: temperature)
  }

  func streamReply(
    settings: Settings,
    messages: [Message],
    summary: Summary?,
    persona: PersonaProfile?,
    relationshipMemory: RelationshipMemory?,
    systemPromptOverride: String? = nil,
    temperature: Double = 0.7,
    onDelta: @escaping (_ delta: String, _ fullText: String) -> Void
  ) async throws -> String {
    let prompt = NativePromptBuilder.buildConversationPromptContext(
      settings: settings,
      allMessages: messages,
      summary: summary,
      systemPromptOverride: systemPromptOverride ?? NativePromptBuilder.buildVoiceMessageSystemPrompt(settings),
      persona: persona,
      relationshipMemory: relationshipMemory
    )
    return try await client.streamChat(messages: prompt, temperature: temperature, onDelta: onDelta)
  }
}

protocol NativeMetadataExtracting {
  func extractMetadata(
    settings: Settings,
    userText: String,
    assistantReply: String
  ) async throws -> NativeLearningMetadata
}

final class NativeMetadataExtractionService: NativeMetadataExtracting {
  private let client: NativeDeepSeekClientProtocol

  init(client: NativeDeepSeekClientProtocol) {
    self.client = client
  }

  func extractMetadata(
    settings: Settings,
    userText: String,
    assistantReply: String
  ) async throws -> NativeLearningMetadata {
    let prompt = [
      NativePromptMessage.system(NativePromptBuilder.buildMetadataExtractionPrompt(settings)),
      NativePromptMessage.user("User original:\n\(userText)\n\nAssistant reply:\n\(assistantReply)"),
    ]

    return try await client.sendJSON(NativeLearningMetadata.self, messages: prompt, temperature: 0.2)
  }
}

protocol NativeRelationshipMemoryUpdating {
  func updateRelationshipMemory(
    existingMemory: RelationshipMemory?,
    userText: String,
    assistantReply: String
  ) async throws -> NativeRelationshipMemoryDraft
}

final class NativeRelationshipMemoryService: NativeRelationshipMemoryUpdating {
  private let client: NativeDeepSeekClientProtocol

  init(client: NativeDeepSeekClientProtocol) {
    self.client = client
  }

  func updateRelationshipMemory(
    existingMemory: RelationshipMemory?,
    userText: String,
    assistantReply: String
  ) async throws -> NativeRelationshipMemoryDraft {
    let existingMemoryJSON = prettyJSONString(from: existingMemory) ?? "{}"
    let prompt = [
      NativePromptMessage.system(NativePromptBuilder.buildRelationshipMemoryUpdatePrompt()),
      NativePromptMessage.user(
        "Existing memory:\n\(existingMemoryJSON)\n\nLatest user message:\n\(userText)\n\nLatest assistant reply:\n\(assistantReply)"
      ),
    ]

    return try await client.sendJSON(NativeRelationshipMemoryDraft.self, messages: prompt, temperature: 0.2)
  }
}

protocol NativeSummaryGenerating {
  func generateSummary(messages: [Message]) async throws -> String
}

final class NativeSummaryGenerationService: NativeSummaryGenerating {
  private let client: NativeDeepSeekClientProtocol

  init(client: NativeDeepSeekClientProtocol) {
    self.client = client
  }

  func generateSummary(messages: [Message]) async throws -> String {
    let prompt = NativePromptBuilder.buildSummaryGenerationMessages(messages: messages)
    let payload = try await client.sendJSON(NativeSummaryPayload.self, messages: prompt, temperature: 0.5)
    return payload.summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

protocol NativeAssistantLanguagePolicyEnforcing {
  func enforceLanguagePolicy(
    settings: Settings,
    userText: String,
    assistantReply: String
  ) async throws -> String
}

final class NativeAssistantLanguagePolicyService: NativeAssistantLanguagePolicyEnforcing {
  private let client: NativeDeepSeekClientProtocol

  init(client: NativeDeepSeekClientProtocol) {
    self.client = client
  }

  func enforceLanguagePolicy(
    settings: Settings,
    userText: String,
    assistantReply: String
  ) async throws -> String {
    let trimmed = assistantReply.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return trimmed }
    guard settings.chineseRatio != .frequent else { return trimmed }
    guard containsChinese(trimmed) else { return trimmed }
    guard !userExplicitlyAskedForChineseMeaning(userText) else { return trimmed }

    let prompt = [
      NativePromptMessage.system(
        "Rewrite the assistant reply into natural spoken English only. Keep the same meaning and teaching intent. Remove all Chinese characters unless the user explicitly asked for Chinese meaning. Return plain text only."
      ),
      NativePromptMessage.user("User message:\n\(userText)\n\nAssistant reply:\n\(trimmed)"),
    ]

    let rewritten = try await client.streamChat(messages: prompt, temperature: 0.2) { _, _ in }
    let finalText = rewritten.trimmingCharacters(in: .whitespacesAndNewlines)
    return finalText.isEmpty ? trimmed : finalText
  }
}

private func containsChinese(_ text: String) -> Bool {
  text.range(of: #"\p{Han}"#, options: .regularExpression) != nil
}

private func userExplicitlyAskedForChineseMeaning(_ userText: String) -> Bool {
  let normalized = userText.lowercased()
  return userText.contains("中文")
    || userText.contains("翻译")
    || userText.contains("什么意思")
    || userText.contains("怎么说")
    || normalized.contains("translate")
    || normalized.contains("chinese meaning")
    || normalized.contains("mean in chinese")
}

private func prettyJSONString<T: Encodable>(from value: T?) -> String? {
  guard let value else { return nil }

  do {
    let data = try JSONEncoder().encode(value)
    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
    let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
    return String(data: prettyData, encoding: .utf8)
  } catch {
    return nil
  }
}
