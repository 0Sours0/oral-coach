import Foundation

protocol ConversationFeatureBackend {
  func loadThread(for mode: SessionMode) async throws -> ConversationThreadSnapshot
  func startNewSession(for mode: SessionMode) async throws -> ConversationThreadSnapshot
  func sendVoiceMessage(_ request: ConversationSendRequest) async throws -> ConversationSendResponse
  func sendRealtimeCallTurn(_ request: ConversationSendRequest) async throws -> ConversationSendResponse
  func beginRealtimeCall(mode: SessionMode) async throws
  func endRealtimeCall(mode: SessionMode) async throws
}

struct ConversationPersistedMessageResult: Equatable {
  var updatedSession: Session
  var message: Message
}

protocol RealtimeTranscriptPersisting {
  func persistRealtimeUserMessage(
    sessionId: NativeAppID?,
    text: String
  ) async throws -> ConversationPersistedMessageResult

  func persistRealtimeAssistantMessage(
    sessionId: NativeAppID?,
    userText: String,
    text: String
  ) async throws -> ConversationPersistedMessageResult
}

struct ConversationFeatureDependencies {
  var backend: any ConversationFeatureBackend
  var settingsStore: any AppSettingsRepository
  var audioRecorder: any NativeAudioRecording
  var speechTranscriber: any NativeASRTranscribing
  var textSpeaker: any NativeTextSpeaking

  @MainActor
  static var preview: ConversationFeatureDependencies {
    ConversationFeatureDependencies(
      backend: ConversationPreviewBackend(),
      settingsStore: NativePreviewSettingsStore(),
      audioRecorder: NativePreviewAudioRecorder(),
      speechTranscriber: NativePreviewSpeechTranscriber(),
      textSpeaker: NativePreviewTextSpeaker()
    )
  }
}

struct ConversationPreviewBackend: ConversationFeatureBackend {
  func loadThread(for mode: SessionMode) async throws -> ConversationThreadSnapshot {
    ConversationThreadSnapshot(
      session: Session(
        id: "preview-session",
        title: mode.conversationTitle,
        mode: mode,
        createdAt: 1_700_000_000_000,
        updatedAt: 1_700_000_000_000
      ),
      personaName: "Elon Musk",
      relationshipMemoryNote: "Prefers direct ideas and concise follow-up questions.",
      mode: mode,
      messages: [
        Message(
          id: "preview-user-1",
          sessionId: "preview-session",
          role: .user,
          text: "What's your job?",
          correctionFeedback: nil,
          expressionText: nil,
          audioUri: nil,
          createdAt: 1_700_000_001_000
        ),
        Message(
          id: "preview-assistant-1",
          sessionId: "preview-session",
          role: .assistant,
          text: "I run Tesla and SpaceX, and I stay interested in rockets, AI, and manufacturing.",
          correctionFeedback: "A more natural way to ask is, \"What do you do?\"",
          expressionText: "What do you do?",
          audioUri: nil,
          createdAt: 1_700_000_001_400
        )
      ]
    )
  }

  func startNewSession(for mode: SessionMode) async throws -> ConversationThreadSnapshot {
    ConversationThreadSnapshot(
      session: Session(
        id: "preview-session-\(UUID().uuidString)",
        title: mode == .voiceMessage ? "New conversation" : "Live call",
        mode: mode,
        createdAt: 1_700_000_000_000,
        updatedAt: 1_700_000_000_000
      ),
      personaName: "Elon Musk",
      relationshipMemoryNote: mode.conversationSubtitle,
      mode: mode,
      messages: []
    )
  }

  func sendVoiceMessage(_ request: ConversationSendRequest) async throws -> ConversationSendResponse {
    try await echoResponse(for: request, replyPrefix: "A more natural way to say that is")
  }

  func sendRealtimeCallTurn(_ request: ConversationSendRequest) async throws -> ConversationSendResponse {
    try await echoResponse(for: request, replyPrefix: "In a live call, I'd say")
  }

  func beginRealtimeCall(mode _: SessionMode) async throws {}

  func endRealtimeCall(mode _: SessionMode) async throws {}

  private func echoResponse(for request: ConversationSendRequest, replyPrefix: String) async throws -> ConversationSendResponse {
    let sessionID = request.sessionId ?? "preview-session"
    let userMessage = Message(
      id: "user-\(UUID().uuidString)",
      sessionId: sessionID,
      role: .user,
      text: request.text,
      correctionFeedback: nil,
      expressionText: nil,
      audioUri: request.audioURI,
      createdAt: Int64(Date().timeIntervalSince1970 * 1_000)
    )

    let assistantText = "\(replyPrefix), \"\(request.text)\"."
    let assistantMessage = Message(
      id: "assistant-\(UUID().uuidString)",
      sessionId: sessionID,
      role: .assistant,
      text: assistantText,
      correctionFeedback: request.text.contains("我") ? "Keep the English form first, then continue naturally." : nil,
      expressionText: request.text.contains("我") ? request.text.replacingOccurrences(of: "我", with: "I") : nil,
      audioUri: nil,
      createdAt: Int64(Date().timeIntervalSince1970 * 1_000)
    )

    let updatedSession = Session(
      id: sessionID,
      title: request.mode.conversationTitle,
      mode: request.mode,
      createdAt: Int64(Date().timeIntervalSince1970 * 1_000),
      updatedAt: Int64(Date().timeIntervalSince1970 * 1_000)
    )

    return ConversationSendResponse(
      updatedSession: updatedSession,
      userMessage: userMessage,
      assistantMessage: assistantMessage
    )
  }
}

private final class NativePreviewSettingsStore: AppSettingsRepository {
  func loadSettings() async throws -> NativeAppSettings {
    .defaults
  }

  func saveSettings(_: NativeAppSettings) async throws {}
}

final class NativeConversationBackend: ConversationFeatureBackend, RealtimeTranscriptPersisting {
  private let repositories: NativeAppRepositorySet
  private let conversationService: any NativeConversationGenerating
  private let metadataExtractor: any NativeMetadataExtracting
  private let relationshipMemoryUpdater: any NativeRelationshipMemoryUpdating
  private let summaryGenerator: any NativeSummaryGenerating
  private let languagePolicyEnforcer: any NativeAssistantLanguagePolicyEnforcing
  private let realtimeController: (any NativeRealtimeDialogControlling)?
  private let realtimeConfiguration: NativeRealtimeDialogConfiguration?

  init(
    repositories: NativeAppRepositorySet,
    conversationService: any NativeConversationGenerating,
    metadataExtractor: any NativeMetadataExtracting,
    relationshipMemoryUpdater: any NativeRelationshipMemoryUpdating,
    summaryGenerator: any NativeSummaryGenerating,
    languagePolicyEnforcer: any NativeAssistantLanguagePolicyEnforcing,
    realtimeController: (any NativeRealtimeDialogControlling)? = nil,
    realtimeConfiguration: NativeRealtimeDialogConfiguration? = nil
  ) {
    self.repositories = repositories
    self.conversationService = conversationService
    self.metadataExtractor = metadataExtractor
    self.relationshipMemoryUpdater = relationshipMemoryUpdater
    self.summaryGenerator = summaryGenerator
    self.languagePolicyEnforcer = languagePolicyEnforcer
    self.realtimeController = realtimeController
    self.realtimeConfiguration = realtimeConfiguration
  }

  func loadThread(for mode: SessionMode) async throws -> ConversationThreadSnapshot {
    let session = try await latestSession(for: mode) ?? createSession(mode: mode)
    if try await repositories.sessions.fetchSession(id: session.id) == nil {
      try await repositories.sessions.upsert(session)
    }

    let messages = try await repositories.messages.fetchMessages(sessionId: session.id)
    let persona = try await currentPersona()
    let memory = try await loadRelationshipMemory(for: persona)

    return ConversationThreadSnapshot(
      session: session,
      personaName: persona?.name ?? "Persona",
      relationshipMemoryNote: memory?.relationshipNotes ?? mode.conversationSubtitle,
      mode: mode,
      messages: messages
    )
  }

  func startNewSession(for mode: SessionMode) async throws -> ConversationThreadSnapshot {
    let session = createSession(mode: mode)
    try await repositories.sessions.upsert(session)
    let persona = try await currentPersona()
    let memory = try await loadRelationshipMemory(for: persona)

    return ConversationThreadSnapshot(
      session: session,
      personaName: persona?.name ?? "Persona",
      relationshipMemoryNote: memory?.relationshipNotes ?? mode.conversationSubtitle,
      mode: mode,
      messages: []
    )
  }

  func sendVoiceMessage(_ request: ConversationSendRequest) async throws -> ConversationSendResponse {
    try await processTurn(request, mode: .voiceMessage)
  }

  func sendRealtimeCallTurn(_ request: ConversationSendRequest) async throws -> ConversationSendResponse {
    try await processTurn(
      request,
      mode: .realtimeCall,
      systemPromptBuilder: { NativePromptBuilder.buildReplyOnlySystemPrompt($0) },
      temperature: 0.55
    )
  }

  func beginRealtimeCall(mode: SessionMode) async throws {
    guard mode == .realtimeCall else { return }
    guard let realtimeController, let realtimeConfiguration else { return }

    let settings = try await repositories.settings.loadSettings()
    let session = try await latestSession(for: .realtimeCall) ?? createSession(mode: .realtimeCall)
    if try await repositories.sessions.fetchSession(id: session.id) == nil {
      try await repositories.sessions.upsert(session)
    }
    let messages = try await repositories.messages.fetchMessages(sessionId: session.id)
    let summary = try await repositories.summaries.fetchSummaries(sessionId: session.id).first
    let persona = try await currentPersona()
    let memory = try await loadRelationshipMemory(for: persona)

    let instruction = [
      NativePromptBuilder.buildPersonaConversationContract(),
      persona.map { NativePromptBuilder.buildRealtimePersonaInstruction($0, relationshipMemory: memory) } ?? "",
      NativePromptBuilder.buildRealtimeTeacherInstruction(settings),
      NativePromptBuilder.buildRealtimeDialogContextBlock(
        messages: messages,
        summary: summary,
        recentMessageCount: max(3, settings.recentMessageCount)
      ),
    ]
    .filter { !$0.isEmpty }
    .joined(separator: "\n\n")

    try await realtimeController.configure(realtimeConfiguration)
    try await realtimeController.startSession(
      botName: persona?.name ?? "Conversation Partner",
      instruction: instruction
    )
  }

  func endRealtimeCall(mode: SessionMode) async throws {
    guard mode == .realtimeCall else { return }
    try await realtimeController?.stopSession()
  }

  private func processTurn(
    _ request: ConversationSendRequest,
    mode: SessionMode,
    systemPromptBuilder: ((Settings) -> String)? = nil,
    temperature: Double = 0.7
  ) async throws -> ConversationSendResponse {
    let session = try await resolveSession(for: request, mode: mode)
    let timestamp = currentTimestamp()

    let userMessage = Message(
      id: UUID().uuidString,
      sessionId: session.id,
      role: .user,
      text: request.text,
      correctionFeedback: nil,
      expressionText: nil,
      audioUri: request.audioURI,
      createdAt: timestamp
    )
    try await repositories.messages.append(userMessage)

    let settings = try await repositories.settings.loadSettings()
    let persona = try await currentPersona()
    let relationshipMemory = try await loadRelationshipMemory(for: persona)
    let summary = try await repositories.summaries.fetchSummaries(sessionId: session.id).first
    let messages = try await repositories.messages.fetchMessages(sessionId: session.id)

    let replyText = try await conversationService.streamReply(
      settings: settings,
      messages: messages,
      summary: summary,
      persona: persona,
      relationshipMemory: relationshipMemory,
      systemPromptOverride: systemPromptBuilder?(settings),
      temperature: temperature
    ) { _, _ in }

    let sanitizedReply = try await languagePolicyEnforcer.enforceLanguagePolicy(
      settings: settings,
      userText: request.text,
      assistantReply: replyText
    )

    let assistantTimestamp = currentTimestamp()
    var assistantMessage = Message(
      id: UUID().uuidString,
      sessionId: session.id,
      role: .assistant,
      text: sanitizedReply,
      correctionFeedback: nil,
      expressionText: nil,
      audioUri: nil,
      createdAt: assistantTimestamp
    )
    try await repositories.messages.append(assistantMessage)

    let metadata = try await metadataExtractor.extractMetadata(
      settings: settings,
      userText: request.text,
      assistantReply: sanitizedReply
    )

    assistantMessage.correctionFeedback = metadata.correctedSentence.isEmpty ? nil : metadata.correctedSentence
    assistantMessage.expressionText = metadata.expression?.text
    try await repositories.messages.upsert(assistantMessage)

    if let expression = metadata.expression {
      let record = LearningRecord(
        id: UUID().uuidString,
        sessionId: session.id,
        messageId: assistantMessage.id,
        expression: expression.text,
        cnExplanation: expression.cnExplanation,
        scenario: expression.scenario,
        userOriginal: request.text,
        assistantBetterExpression: expression.text,
        createdAt: currentTimestamp()
      )
      try await repositories.learningRecords.append(record)
    }

    if let persona {
      let nextMemory = try await relationshipMemoryUpdater.updateRelationshipMemory(
        existingMemory: relationshipMemory,
        userText: request.text,
        assistantReply: sanitizedReply
      )
      let persistedMemory = RelationshipMemory(
        id: relationshipMemory?.id ?? UUID().uuidString,
        personaId: persona.id,
        learnerProfile: nextMemory.learnerProfile,
        speakingGoals: nextMemory.speakingGoals,
        recurringMistakes: nextMemory.recurringMistakes,
        sharedFacts: nextMemory.sharedFacts,
        relationshipNotes: nextMemory.relationshipNotes,
        updatedAt: currentTimestamp()
      )
      try await repositories.relationshipMemories.upsert(persistedMemory)
    }

    let updatedMessages = try await repositories.messages.fetchMessages(sessionId: session.id)
    try await maybeUpdateSummary(sessionId: session.id, messages: updatedMessages)
    let persistedSession = Session(
      id: session.id,
      title: session.title,
      mode: mode,
      createdAt: session.createdAt,
      updatedAt: currentTimestamp()
    )
    try await repositories.sessions.upsert(persistedSession)

    return ConversationSendResponse(
      updatedSession: persistedSession,
      userMessage: userMessage,
      assistantMessage: assistantMessage
    )
  }

  func persistRealtimeUserMessage(
    sessionId: NativeAppID?,
    text: String
  ) async throws -> ConversationPersistedMessageResult {
    let session = try await resolveRealtimeSession(sessionId: sessionId)
    let message = Message(
      id: UUID().uuidString,
      sessionId: session.id,
      role: .user,
      text: text,
      correctionFeedback: nil,
      expressionText: nil,
      audioUri: nil,
      createdAt: currentTimestamp()
    )
    try await repositories.messages.append(message)

    let updatedSession = Session(
      id: session.id,
      title: session.title,
      mode: .realtimeCall,
      createdAt: session.createdAt,
      updatedAt: currentTimestamp()
    )
    try await repositories.sessions.upsert(updatedSession)
    return ConversationPersistedMessageResult(updatedSession: updatedSession, message: message)
  }

  func persistRealtimeAssistantMessage(
    sessionId: NativeAppID?,
    userText: String,
    text: String
  ) async throws -> ConversationPersistedMessageResult {
    let session = try await resolveRealtimeSession(sessionId: sessionId)
    let settings = try await repositories.settings.loadSettings()
    let persona = try await currentPersona()
    let relationshipMemory = try await loadRelationshipMemory(for: persona)

    var assistantMessage = Message(
      id: UUID().uuidString,
      sessionId: session.id,
      role: .assistant,
      text: text,
      correctionFeedback: nil,
      expressionText: nil,
      audioUri: nil,
      createdAt: currentTimestamp()
    )
    try await repositories.messages.append(assistantMessage)

    let metadata = try await metadataExtractor.extractMetadata(
      settings: settings,
      userText: userText,
      assistantReply: text
    )
    assistantMessage.correctionFeedback = metadata.correctedSentence.isEmpty ? nil : metadata.correctedSentence
    assistantMessage.expressionText = metadata.expression?.text
    try await repositories.messages.upsert(assistantMessage)

    if let expression = metadata.expression {
      try await repositories.learningRecords.append(
        LearningRecord(
          id: UUID().uuidString,
          sessionId: session.id,
          messageId: assistantMessage.id,
          expression: expression.text,
          cnExplanation: expression.cnExplanation,
          scenario: expression.scenario,
          userOriginal: userText,
          assistantBetterExpression: expression.text,
          createdAt: currentTimestamp()
        )
      )
    }

    if let persona {
      let nextMemory = try await relationshipMemoryUpdater.updateRelationshipMemory(
        existingMemory: relationshipMemory,
        userText: userText,
        assistantReply: text
      )
      try await repositories.relationshipMemories.upsert(
        RelationshipMemory(
          id: relationshipMemory?.id ?? UUID().uuidString,
          personaId: persona.id,
          learnerProfile: nextMemory.learnerProfile,
          speakingGoals: nextMemory.speakingGoals,
          recurringMistakes: nextMemory.recurringMistakes,
          sharedFacts: nextMemory.sharedFacts,
          relationshipNotes: nextMemory.relationshipNotes,
          updatedAt: currentTimestamp()
        )
      )
    }

    let messages = try await repositories.messages.fetchMessages(sessionId: session.id)
    try await maybeUpdateSummary(sessionId: session.id, messages: messages)

    let updatedSession = Session(
      id: session.id,
      title: session.title,
      mode: .realtimeCall,
      createdAt: session.createdAt,
      updatedAt: currentTimestamp()
    )
    try await repositories.sessions.upsert(updatedSession)
    return ConversationPersistedMessageResult(updatedSession: updatedSession, message: assistantMessage)
  }

  private func currentPersona() async throws -> PersonaProfile? {
    if let active = try await repositories.personas.fetchActivePersonaProfile() {
      return active
    }
    return try await repositories.personas.fetchAllPersonaProfiles().first
  }

  private func loadRelationshipMemory(for persona: PersonaProfile?) async throws -> RelationshipMemory? {
    guard let persona else { return nil }
    return try await repositories.relationshipMemories.fetchMemory(personaId: persona.id)
  }

  private func latestSession(for mode: SessionMode) async throws -> Session? {
    try await repositories.sessions.fetchSessions().first(where: { $0.mode == mode })
  }

  private func resolveSession(for request: ConversationSendRequest, mode: SessionMode) async throws -> Session {
    if let sessionId = request.sessionId,
       let session = try await repositories.sessions.fetchSession(id: sessionId) {
      return session
    }

    if let existing = try await latestSession(for: mode) {
      return existing
    }

    let session = createSession(mode: mode)
    try await repositories.sessions.upsert(session)
    return session
  }

  private func resolveRealtimeSession(sessionId: NativeAppID?) async throws -> Session {
    if let sessionId,
       let existing = try await repositories.sessions.fetchSession(id: sessionId) {
      return existing
    }
    if let existing = try await latestSession(for: .realtimeCall) {
      return existing
    }
    let session = createSession(mode: .realtimeCall)
    try await repositories.sessions.upsert(session)
    return session
  }

  private func createSession(mode: SessionMode) -> Session {
    let timestamp = currentTimestamp()
    return Session(
      id: UUID().uuidString,
      title: mode == .voiceMessage ? "New conversation" : "Live call",
      mode: mode,
      createdAt: timestamp,
      updatedAt: timestamp
    )
  }

  private func maybeUpdateSummary(sessionId: NativeAppID, messages: [Message]) async throws {
    let currentSummary = try await repositories.summaries.fetchSummaries(sessionId: sessionId).first
    guard shouldTriggerSummary(messages: messages, coveredUntilMessageID: currentSummary?.coveredUntilMessageId) else {
      return
    }

    guard let lastMessage = messages.last else { return }
    let summaryText = try await summaryGenerator.generateSummary(messages: messages)
    let summary = Summary(
      id: currentSummary?.id ?? UUID().uuidString,
      sessionId: sessionId,
      summaryText: summaryText,
      coveredUntilMessageId: lastMessage.id,
      updatedAt: currentTimestamp()
    )
    try await repositories.summaries.upsert(summary)
  }

  private func shouldTriggerSummary(
    messages: [Message],
    coveredUntilMessageID: NativeAppID?
  ) -> Bool {
    let nonSystem = messages.filter { $0.role != .system }
    if let coveredUntilMessageID,
       let index = nonSystem.firstIndex(where: { $0.id == coveredUntilMessageID }) {
      return nonSystem.count - (index + 1) > 20
    }
    return nonSystem.count > 20
  }

  private func currentTimestamp() -> NativeAppTimestamp {
    Int64(Date().timeIntervalSince1970 * 1_000)
  }
}
