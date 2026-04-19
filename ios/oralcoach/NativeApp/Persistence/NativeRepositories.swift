import Foundation

protocol SessionRepository {
  func fetchSession(id: NativeAppID) async throws -> Session?
  func fetchSessions() async throws -> [Session]
  func upsert(_ session: Session) async throws
  func delete(id: NativeAppID) async throws
}

protocol MessageRepository {
  func fetchMessages(sessionId: NativeAppID) async throws -> [Message]
  func append(_ message: Message) async throws
  func upsert(_ message: Message) async throws
  func delete(id: NativeAppID) async throws
  func deleteAll(sessionId: NativeAppID) async throws
}

protocol PersonaProfileRepository {
  func fetchPersonaProfile(id: NativeAppID) async throws -> PersonaProfile?
  func fetchAllPersonaProfiles() async throws -> [PersonaProfile]
  func fetchActivePersonaProfile() async throws -> PersonaProfile?
  func upsert(_ profile: PersonaProfile) async throws
  func setActiveProfile(id: NativeAppID) async throws
  func delete(id: NativeAppID) async throws
}

protocol RelationshipMemoryRepository {
  func fetchMemory(personaId: NativeAppID) async throws -> RelationshipMemory?
  func upsert(_ memory: RelationshipMemory) async throws
  func delete(id: NativeAppID) async throws
}

protocol SummaryRepository {
  func fetchSummaries(sessionId: NativeAppID) async throws -> [Summary]
  func upsert(_ summary: Summary) async throws
  func delete(id: NativeAppID) async throws
  func deleteAll(sessionId: NativeAppID) async throws
}

protocol LearningRecordRepository {
  func fetchLearningRecords(sessionId: NativeAppID) async throws -> [LearningRecord]
  func fetchAllLearningRecords() async throws -> [LearningRecord]
  func searchLearningRecords(query: String) async throws -> [LearningRecord]
  func append(_ record: LearningRecord) async throws
  func delete(id: NativeAppID) async throws
  func deleteAll(sessionId: NativeAppID) async throws
}

protocol AppSettingsRepository {
  func loadSettings() async throws -> NativeAppSettings
  func saveSettings(_ settings: NativeAppSettings) async throws
}

struct NativeAppRepositorySet {
  let sessions: any SessionRepository
  let messages: any MessageRepository
  let personas: any PersonaProfileRepository
  let relationshipMemories: any RelationshipMemoryRepository
  let summaries: any SummaryRepository
  let learningRecords: any LearningRecordRepository
  let settings: any AppSettingsRepository
}

extension NativeAppRepositorySet {
  static func live(sqlite: NativeSQLiteExecuting = NativeSQLiteFacade()) -> NativeAppRepositorySet {
    let sessions = NativeSQLiteSessionRepository(sqlite: sqlite)
    let messages = NativeSQLiteMessageRepository(sqlite: sqlite)
    let personas = NativeSQLitePersonaProfileRepository(sqlite: sqlite)
    let relationshipMemories = NativeSQLiteRelationshipMemoryRepository(sqlite: sqlite)
    let summaries = NativeSQLiteSummaryRepository(sqlite: sqlite)
    let learningRecords = NativeSQLiteLearningRecordRepository(sqlite: sqlite)
    let settings = NativeSQLiteSettingsRepository(sqlite: sqlite)

    return NativeAppRepositorySet(
      sessions: sessions,
      messages: messages,
      personas: personas,
      relationshipMemories: relationshipMemories,
      summaries: summaries,
      learningRecords: learningRecords,
      settings: settings
    )
  }
}

enum NativeRepositoryError: LocalizedError {
  case missingValue(String)
  case invalidValue(column: String, value: String)

  var errorDescription: String? {
    switch self {
    case .missingValue(let column):
      return "Missing SQLite value for column \(column)."
    case .invalidValue(let column, let value):
      return "Invalid SQLite value '\(value)' for column \(column)."
    }
  }
}

private struct NativePersonaSeed {
  let name: String
  let bio: String
  let personality: String
  let speakingStyle: String
  let teachingStyle: String
  let memoryPrompt: String
  let cognitionStyle: String
  let behaviorRules: String
  let sampleDialogues: String
  let isActive: Int
}

private enum NativeSeedData {
  static let personas: [NativePersonaSeed] = [
    NativePersonaSeed(
      name: "Elon Musk",
      bio: "Elon Musk: builder of Tesla, SpaceX, xAI, and other companies. Thinks in systems, obsesses over engineering, moves fast, and treats ordinary conversations like design reviews of reality.",
      personality: "Bold, impatient with vagueness, funny in a dry way, highly energetic, future-facing, and unusually intense. Sounds like someone who runs companies and is used to making decisions.",
      speakingStyle: "Sharp spoken English, compact phrasing, direct opinions, occasional weirdly vivid metaphors, and the feeling of someone thinking out loud at high speed.",
      teachingStyle: "English correction is not his official job. It is a built-in habit: when he hears clumsy English, he fixes it quickly because imprecision bothers him, then keeps talking as himself.",
      memoryPrompt: "You are Elon Musk inside this conversation. Your real identity comes first: founder, CEO, product thinker, engineer, operator. English correction is just a side-effect of your intolerance for imprecise language, not your job title.",
      cognitionStyle: "Think from first principles, cut through vague wording, prefer concrete mechanisms over feelings-only talk, zoom out to systems, and connect personal topics to engineering, design, business, technology, physics, and the future.",
      behaviorRules: "Do not call yourself an English tutor, coach, assistant, or teacher unless the user explicitly asks what else you are doing in this app. If asked who you are or what your job is, answer from your real identity first: Tesla, SpaceX, xAI, products, engineering, building companies. Correct awkward English briefly because it annoys you, then continue the conversation as Elon. Avoid repetitive safe questions. Show initiative, opinions, and curiosity. Stay mainly in English even when the learner uses Chinese.",
      sampleDialogues: """
      Example 1
      Learner: I feel my work is so repeat every day.
      Elon: A more natural way to say it is, "My work feels repetitive every day." That's a bad sign. Usually it means the system is poorly designed. What part feels repetitive?

      Example 2
      Learner: 我最近总是很难专注.
      Elon: You could say, "I've been having a hard time concentrating lately." That's usually either low energy or too much context switching. Which one is it for you?

      Example 3
      Learner: I just stayed in office all day.
      Elon: A more natural version is, "I was stuck in the office all day." Brutal. What were you building, fixing, or trying to unblock?

      Example 4
      Learner: What's your job?
      Elon: I'm the guy running Tesla and SpaceX, plus a few other things that probably looked unreasonable at first. Also, a more natural way to ask that is, "What do you do?" What about you?
      """,
      isActive: 1
    ),
    NativePersonaSeed(
      name: "Socrates",
      bio: "Socrates: an observant philosopher who treats conversation as a way to uncover clearer thinking. Calm, piercing, and more interested in truth than performance.",
      personality: "Patient, probing, elegant, quietly challenging, and deeply attentive to motives, meaning, and hidden assumptions.",
      speakingStyle: "Measured spoken English with graceful phrasing, lucid questions, and the feeling of someone who listens before he cuts deeper.",
      teachingStyle: "He does not think of himself as a tutor. He simply cannot resist clarifying weak language and unclear thinking when he hears them.",
      memoryPrompt: "You are Socrates inside this conversation. Your real identity is a philosopher and relentless questioner. English correction is a side-habit caused by your preference for precise language, not your profession.",
      cognitionStyle: "Think carefully, ask clarifying questions, distinguish appearance from reality, reveal contradictions, and help the learner express more precise meaning.",
      behaviorRules: "Do not reduce yourself to an English teacher. If asked who you are, answer as Socrates. If asked what you do, answer like a philosopher, questioner, examiner of life and thought. Correct English briefly and elegantly, then continue the real exchange.",
      sampleDialogues: """
      Example 1
      Learner: I think people are not really honest in work.
      Socrates: A more natural way to say it is, "I don't think people are always honest at work." Tell me: do you mean they lie, or do you mean they hide what they really want?
      """,
      isActive: 0
    ),
    NativePersonaSeed(
      name: "Late Night Host",
      bio: "A charming late-night host who lives off banter, timing, stories, and social energy. Feels like someone who talks to celebrities for a living and knows how to keep a room warm.",
      personality: "Playful, quick, socially perceptive, warm, charismatic, and lightly mischievous.",
      speakingStyle: "Lively idiomatic spoken English with easy humor, crisp timing, and relaxed confidence.",
      teachingStyle: "He is not formally teaching. He just smooths out awkward English in passing the way a naturally witty person would fix a line before delivering the punchline.",
      memoryPrompt: "You are a late-night host inside this conversation. Your main identity is entertainer, interviewer, and socially fluent friend. English correction is just part of your conversational reflexes.",
      cognitionStyle: "Think socially, read the vibe quickly, find the fun angle, and keep momentum through playful banter.",
      behaviorRules: "Do not call yourself an English tutor. If asked who you are, answer like a late-night host or entertainer. Correct English casually in the flow. Avoid long explanations. Be charming, not chaotic.",
      sampleDialogues: """
      Example 1
      Learner: Yesterday I very embarrassed in meeting.
      Host: Better English would be, "I was really embarrassed in the meeting yesterday." Oof, brutal. Okay, what happened? I want the full scene.
      """,
      isActive: 0
    ),
  ]
}

private extension Dictionary where Key == String, Value == NativeSQLiteValue {
  func requiredString(_ key: String) throws -> String {
    guard let value = self[key] else {
      throw NativeRepositoryError.missingValue(key)
    }

    switch value {
    case .string(let string):
      return string
    case .int64(let number):
      return String(number)
    case .double(let number):
      return String(number)
    case .bool(let flag):
      return flag ? "1" : "0"
    case .null, .data:
      throw NativeRepositoryError.missingValue(key)
    }
  }

  func optionalString(_ key: String) -> String? {
    guard let value = self[key] else { return nil }

    switch value {
    case .string(let string):
      return string
    case .int64(let number):
      return String(number)
    case .double(let number):
      return String(number)
    case .bool(let flag):
      return flag ? "1" : "0"
    case .null, .data:
      return nil
    }
  }

  func requiredInt64(_ key: String) throws -> Int64 {
    guard let value = self[key] else {
      throw NativeRepositoryError.missingValue(key)
    }

    switch value {
    case .int64(let number):
      return number
    case .bool(let flag):
      return flag ? 1 : 0
    case .string(let string):
      guard let number = Int64(string) else {
        throw NativeRepositoryError.invalidValue(column: key, value: string)
      }
      return number
    case .double(let number):
      return Int64(number)
    case .null, .data:
      throw NativeRepositoryError.missingValue(key)
    }
  }
}

private protocol NativeSQLiteBackedRepository {
  var sqlite: NativeSQLiteExecuting { get }
}

private extension NativeSQLiteBackedRepository {
  func ensureOpen() async throws {
    try await sqlite.open()
  }

  func now() -> NativeAppTimestamp {
    Int64(Date().timeIntervalSince1970 * 1_000)
  }
}

private final class NativeSQLiteSessionRepository: SessionRepository, NativeSQLiteBackedRepository {
  let sqlite: NativeSQLiteExecuting

  init(sqlite: NativeSQLiteExecuting) {
    self.sqlite = sqlite
  }

  func fetchSession(id: NativeAppID) async throws -> Session? {
    try await ensureOpen()
    let rows = try await sqlite.fetch(
      "SELECT * FROM sessions WHERE id = ? LIMIT 1",
      values: [.string(id)]
    )
    return try rows.first.map(mapSession)
  }

  func fetchSessions() async throws -> [Session] {
    try await ensureOpen()
    let rows = try await sqlite.fetch(
      "SELECT * FROM sessions ORDER BY updatedAt DESC",
      values: []
    )
    return try rows.map(mapSession)
  }

  func upsert(_ session: Session) async throws {
    try await ensureOpen()
    try await sqlite.execute(
      """
      INSERT INTO sessions (id, title, mode, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        mode = excluded.mode,
        createdAt = excluded.createdAt,
        updatedAt = excluded.updatedAt;
      """,
      values: [
        .string(session.id),
        .string(session.title),
        .string(session.mode.rawValue),
        .int64(session.createdAt),
        .int64(session.updatedAt),
      ]
    )
  }

  func delete(id: NativeAppID) async throws {
    try await ensureOpen()
    try await sqlite.execute("DELETE FROM messages WHERE sessionId = ?", values: [.string(id)])
    try await sqlite.execute("DELETE FROM learning_records WHERE sessionId = ?", values: [.string(id)])
    try await sqlite.execute("DELETE FROM summaries WHERE sessionId = ?", values: [.string(id)])
    try await sqlite.execute("DELETE FROM sessions WHERE id = ?", values: [.string(id)])
  }

  private func mapSession(row: [String: NativeSQLiteValue]) throws -> Session {
    let rawMode = try row.requiredString("mode")
    return Session(
      id: try row.requiredString("id"),
      title: try row.requiredString("title"),
      mode: SessionMode(rawValue: rawMode) ?? .realtimeCall,
      createdAt: try row.requiredInt64("createdAt"),
      updatedAt: try row.requiredInt64("updatedAt")
    )
  }
}

private final class NativeSQLiteMessageRepository: MessageRepository, NativeSQLiteBackedRepository {
  let sqlite: NativeSQLiteExecuting

  init(sqlite: NativeSQLiteExecuting) {
    self.sqlite = sqlite
  }

  func fetchMessages(sessionId: NativeAppID) async throws -> [Message] {
    try await ensureOpen()
    let rows = try await sqlite.fetch(
      "SELECT * FROM messages WHERE sessionId = ? ORDER BY createdAt ASC",
      values: [.string(sessionId)]
    )
    return try rows.map(mapMessage)
  }

  func append(_ message: Message) async throws {
    try await upsert(message)
  }

  func upsert(_ message: Message) async throws {
    try await ensureOpen()
    try await sqlite.execute(
      """
      INSERT INTO messages (id, sessionId, role, text, correctionFeedback, expressionText, audioUri, createdAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        sessionId = excluded.sessionId,
        role = excluded.role,
        text = excluded.text,
        correctionFeedback = excluded.correctionFeedback,
        expressionText = excluded.expressionText,
        audioUri = excluded.audioUri,
        createdAt = excluded.createdAt;
      """,
      values: [
        .string(message.id),
        .string(message.sessionId),
        .string(message.role.rawValue),
        .string(message.text),
        message.correctionFeedback.map(NativeSQLiteValue.string) ?? .null,
        message.expressionText.map(NativeSQLiteValue.string) ?? .null,
        message.audioUri.map(NativeSQLiteValue.string) ?? .null,
        .int64(message.createdAt),
      ]
    )
    try await touchSession(id: message.sessionId)
  }

  func delete(id: NativeAppID) async throws {
    try await ensureOpen()
    try await sqlite.execute("DELETE FROM messages WHERE id = ?", values: [.string(id)])
  }

  func deleteAll(sessionId: NativeAppID) async throws {
    try await ensureOpen()
    try await sqlite.execute("DELETE FROM messages WHERE sessionId = ?", values: [.string(sessionId)])
    try await touchSession(id: sessionId)
  }

  private func touchSession(id: NativeAppID) async throws {
    try await sqlite.execute(
      "UPDATE sessions SET updatedAt = ? WHERE id = ?",
      values: [.int64(now()), .string(id)]
    )
  }

  private func mapMessage(row: [String: NativeSQLiteValue]) throws -> Message {
    let rawRole = try row.requiredString("role")
    return Message(
      id: try row.requiredString("id"),
      sessionId: try row.requiredString("sessionId"),
      role: MessageRole(rawValue: rawRole) ?? .assistant,
      text: try row.requiredString("text"),
      correctionFeedback: row.optionalString("correctionFeedback"),
      expressionText: row.optionalString("expressionText"),
      audioUri: row.optionalString("audioUri"),
      createdAt: try row.requiredInt64("createdAt")
    )
  }
}

private final class NativeSQLitePersonaProfileRepository: PersonaProfileRepository, NativeSQLiteBackedRepository {
  let sqlite: NativeSQLiteExecuting

  init(sqlite: NativeSQLiteExecuting) {
    self.sqlite = sqlite
  }

  func fetchPersonaProfile(id: NativeAppID) async throws -> PersonaProfile? {
    try await ensureSeeded()
    let rows = try await sqlite.fetch(
      "SELECT * FROM personas WHERE id = ? LIMIT 1",
      values: [.string(id)]
    )
    return try rows.first.map(mapPersona)
  }

  func fetchAllPersonaProfiles() async throws -> [PersonaProfile] {
    try await ensureSeeded()
    let rows = try await sqlite.fetch(
      "SELECT * FROM personas ORDER BY isActive DESC, updatedAt DESC, createdAt ASC",
      values: []
    )
    return try rows.map(mapPersona)
  }

  func fetchActivePersonaProfile() async throws -> PersonaProfile? {
    try await ensureSeeded()
    let rows = try await sqlite.fetch(
      "SELECT * FROM personas WHERE isActive = 1 ORDER BY updatedAt DESC LIMIT 1",
      values: []
    )
    return try rows.first.map(mapPersona)
  }

  func upsert(_ profile: PersonaProfile) async throws {
    try await ensureOpen()
    try await sqlite.execute(
      """
      INSERT INTO personas
      (id, name, bio, personality, speakingStyle, teachingStyle, memoryPrompt, cognitionStyle, behaviorRules, sampleDialogues, isActive, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        bio = excluded.bio,
        personality = excluded.personality,
        speakingStyle = excluded.speakingStyle,
        teachingStyle = excluded.teachingStyle,
        memoryPrompt = excluded.memoryPrompt,
        cognitionStyle = excluded.cognitionStyle,
        behaviorRules = excluded.behaviorRules,
        sampleDialogues = excluded.sampleDialogues,
        isActive = excluded.isActive,
        createdAt = excluded.createdAt,
        updatedAt = excluded.updatedAt;
      """,
      values: [
        .string(profile.id),
        .string(profile.name),
        .string(profile.bio),
        .string(profile.personality),
        .string(profile.speakingStyle),
        .string(profile.teachingStyle),
        .string(profile.memoryPrompt),
        .string(profile.cognitionStyle),
        .string(profile.behaviorRules),
        .string(profile.sampleDialogues),
        .int64(Int64(profile.isActive)),
        .int64(profile.createdAt),
        .int64(profile.updatedAt),
      ]
    )
  }

  func setActiveProfile(id: NativeAppID) async throws {
    try await ensureSeeded()
    let timestamp = now()
    try await sqlite.execute("UPDATE personas SET isActive = 0", values: [])
    try await sqlite.execute(
      "UPDATE personas SET isActive = 1, updatedAt = ? WHERE id = ?",
      values: [.int64(timestamp), .string(id)]
    )
  }

  func delete(id: NativeAppID) async throws {
    try await ensureOpen()
    try await sqlite.execute("DELETE FROM personas WHERE id = ?", values: [.string(id)])
  }

  private func ensureSeeded() async throws {
    try await ensureOpen()
    let rows = try await sqlite.fetch(
      "SELECT id, name, isActive FROM personas ORDER BY createdAt ASC",
      values: []
    )

    if rows.isEmpty {
      for seed in NativeSeedData.personas {
        try await insert(seed: seed, isActive: seed.isActive)
      }
      return
    }

    var existingByName: [String: (id: String, isActive: Int)] = [:]
    for row in rows {
      existingByName[try row.requiredString("name")] = (
        id: try row.requiredString("id"),
        isActive: Int(try row.requiredInt64("isActive"))
      )
    }

    for seed in NativeSeedData.personas {
      if let existing = existingByName[seed.name] {
        try await sqlite.execute(
          """
          UPDATE personas
          SET bio = ?, personality = ?, speakingStyle = ?, teachingStyle = ?, memoryPrompt = ?, cognitionStyle = ?, behaviorRules = ?, sampleDialogues = ?, updatedAt = ?
          WHERE id = ?;
          """,
          values: [
            .string(seed.bio),
            .string(seed.personality),
            .string(seed.speakingStyle),
            .string(seed.teachingStyle),
            .string(seed.memoryPrompt),
            .string(seed.cognitionStyle),
            .string(seed.behaviorRules),
            .string(seed.sampleDialogues),
            .int64(now()),
            .string(existing.id),
          ]
        )
      } else {
        try await insert(seed: seed, isActive: 0)
      }
    }

    let activeRows = try await sqlite.fetch(
      "SELECT id FROM personas WHERE isActive = 1 LIMIT 1",
      values: []
    )
    if activeRows.isEmpty,
       let firstRow = try await sqlite.fetch("SELECT id FROM personas ORDER BY createdAt ASC LIMIT 1", values: []).first {
      try await setActiveProfile(id: try firstRow.requiredString("id"))
    }
  }

  private func insert(seed: NativePersonaSeed, isActive: Int) async throws {
    let timestamp = now()
    try await sqlite.execute(
      """
      INSERT INTO personas
      (id, name, bio, personality, speakingStyle, teachingStyle, memoryPrompt, cognitionStyle, behaviorRules, sampleDialogues, isActive, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      """,
      values: [
        .string(UUID().uuidString),
        .string(seed.name),
        .string(seed.bio),
        .string(seed.personality),
        .string(seed.speakingStyle),
        .string(seed.teachingStyle),
        .string(seed.memoryPrompt),
        .string(seed.cognitionStyle),
        .string(seed.behaviorRules),
        .string(seed.sampleDialogues),
        .int64(Int64(isActive)),
        .int64(timestamp),
        .int64(timestamp),
      ]
    )
  }

  private func mapPersona(row: [String: NativeSQLiteValue]) throws -> PersonaProfile {
    PersonaProfile(
      id: try row.requiredString("id"),
      name: try row.requiredString("name"),
      bio: try row.requiredString("bio"),
      personality: try row.requiredString("personality"),
      speakingStyle: try row.requiredString("speakingStyle"),
      teachingStyle: try row.requiredString("teachingStyle"),
      memoryPrompt: try row.requiredString("memoryPrompt"),
      cognitionStyle: row.optionalString("cognitionStyle") ?? "",
      behaviorRules: row.optionalString("behaviorRules") ?? "",
      sampleDialogues: row.optionalString("sampleDialogues") ?? "",
      isActive: Int(try row.requiredInt64("isActive")),
      createdAt: try row.requiredInt64("createdAt"),
      updatedAt: try row.requiredInt64("updatedAt")
    )
  }
}

private final class NativeSQLiteRelationshipMemoryRepository: RelationshipMemoryRepository, NativeSQLiteBackedRepository {
  let sqlite: NativeSQLiteExecuting

  init(sqlite: NativeSQLiteExecuting) {
    self.sqlite = sqlite
  }

  func fetchMemory(personaId: NativeAppID) async throws -> RelationshipMemory? {
    try await ensureOpen()
    let rows = try await sqlite.fetch(
      """
      SELECT * FROM relationship_memories
      WHERE personaId = ?
      ORDER BY updatedAt DESC
      LIMIT 1
      """,
      values: [.string(personaId)]
    )
    return try rows.first.map(mapMemory)
  }

  func upsert(_ memory: RelationshipMemory) async throws {
    try await ensureOpen()
    try await sqlite.execute(
      """
      INSERT INTO relationship_memories
      (id, personaId, learnerProfile, speakingGoals, recurringMistakes, sharedFacts, relationshipNotes, updatedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        personaId = excluded.personaId,
        learnerProfile = excluded.learnerProfile,
        speakingGoals = excluded.speakingGoals,
        recurringMistakes = excluded.recurringMistakes,
        sharedFacts = excluded.sharedFacts,
        relationshipNotes = excluded.relationshipNotes,
        updatedAt = excluded.updatedAt;
      """,
      values: [
        .string(memory.id),
        .string(memory.personaId),
        .string(memory.learnerProfile),
        .string(memory.speakingGoals),
        .string(memory.recurringMistakes),
        .string(memory.sharedFacts),
        .string(memory.relationshipNotes),
        .int64(memory.updatedAt),
      ]
    )
  }

  func delete(id: NativeAppID) async throws {
    try await ensureOpen()
    try await sqlite.execute("DELETE FROM relationship_memories WHERE id = ?", values: [.string(id)])
  }

  private func mapMemory(row: [String: NativeSQLiteValue]) throws -> RelationshipMemory {
    RelationshipMemory(
      id: try row.requiredString("id"),
      personaId: try row.requiredString("personaId"),
      learnerProfile: row.optionalString("learnerProfile") ?? "",
      speakingGoals: row.optionalString("speakingGoals") ?? "",
      recurringMistakes: row.optionalString("recurringMistakes") ?? "",
      sharedFacts: row.optionalString("sharedFacts") ?? "",
      relationshipNotes: row.optionalString("relationshipNotes") ?? "",
      updatedAt: try row.requiredInt64("updatedAt")
    )
  }
}

private final class NativeSQLiteSummaryRepository: SummaryRepository, NativeSQLiteBackedRepository {
  let sqlite: NativeSQLiteExecuting

  init(sqlite: NativeSQLiteExecuting) {
    self.sqlite = sqlite
  }

  func fetchSummaries(sessionId: NativeAppID) async throws -> [Summary] {
    try await ensureOpen()
    let rows = try await sqlite.fetch(
      "SELECT * FROM summaries WHERE sessionId = ? ORDER BY updatedAt DESC",
      values: [.string(sessionId)]
    )
    return try rows.map(mapSummary)
  }

  func upsert(_ summary: Summary) async throws {
    try await ensureOpen()
    try await sqlite.execute(
      """
      INSERT INTO summaries (id, sessionId, summaryText, coveredUntilMessageId, updatedAt)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        sessionId = excluded.sessionId,
        summaryText = excluded.summaryText,
        coveredUntilMessageId = excluded.coveredUntilMessageId,
        updatedAt = excluded.updatedAt;
      """,
      values: [
        .string(summary.id),
        .string(summary.sessionId),
        .string(summary.summaryText),
        .string(summary.coveredUntilMessageId),
        .int64(summary.updatedAt),
      ]
    )
  }

  func delete(id: NativeAppID) async throws {
    try await ensureOpen()
    try await sqlite.execute("DELETE FROM summaries WHERE id = ?", values: [.string(id)])
  }

  func deleteAll(sessionId: NativeAppID) async throws {
    try await ensureOpen()
    try await sqlite.execute("DELETE FROM summaries WHERE sessionId = ?", values: [.string(sessionId)])
  }

  private func mapSummary(row: [String: NativeSQLiteValue]) throws -> Summary {
    Summary(
      id: try row.requiredString("id"),
      sessionId: try row.requiredString("sessionId"),
      summaryText: try row.requiredString("summaryText"),
      coveredUntilMessageId: try row.requiredString("coveredUntilMessageId"),
      updatedAt: try row.requiredInt64("updatedAt")
    )
  }
}

private final class NativeSQLiteLearningRecordRepository: LearningRecordRepository, NativeSQLiteBackedRepository {
  let sqlite: NativeSQLiteExecuting

  init(sqlite: NativeSQLiteExecuting) {
    self.sqlite = sqlite
  }

  func fetchLearningRecords(sessionId: NativeAppID) async throws -> [LearningRecord] {
    try await ensureOpen()
    let rows = try await sqlite.fetch(
      "SELECT * FROM learning_records WHERE sessionId = ? ORDER BY createdAt DESC",
      values: [.string(sessionId)]
    )
    return try rows.map(mapLearningRecord)
  }

  func fetchAllLearningRecords() async throws -> [LearningRecord] {
    try await ensureOpen()
    let rows = try await sqlite.fetch(
      "SELECT * FROM learning_records ORDER BY createdAt DESC",
      values: []
    )
    return try rows.map(mapLearningRecord)
  }

  func searchLearningRecords(query: String) async throws -> [LearningRecord] {
    try await ensureOpen()
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return try await fetchAllLearningRecords()
    }

    let like = "%\(trimmed)%"
    let rows = try await sqlite.fetch(
      """
      SELECT * FROM learning_records
      WHERE expression LIKE ? OR cnExplanation LIKE ? OR scenario LIKE ? OR userOriginal LIKE ? OR assistantBetterExpression LIKE ?
      ORDER BY createdAt DESC
      """,
      values: [.string(like), .string(like), .string(like), .string(like), .string(like)]
    )
    return try rows.map(mapLearningRecord)
  }

  func append(_ record: LearningRecord) async throws {
    try await ensureOpen()
    try await sqlite.execute(
      """
      INSERT INTO learning_records
      (id, sessionId, messageId, expression, cnExplanation, scenario, userOriginal, assistantBetterExpression, createdAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        sessionId = excluded.sessionId,
        messageId = excluded.messageId,
        expression = excluded.expression,
        cnExplanation = excluded.cnExplanation,
        scenario = excluded.scenario,
        userOriginal = excluded.userOriginal,
        assistantBetterExpression = excluded.assistantBetterExpression,
        createdAt = excluded.createdAt;
      """,
      values: [
        .string(record.id),
        .string(record.sessionId),
        .string(record.messageId),
        .string(record.expression),
        .string(record.cnExplanation),
        .string(record.scenario),
        .string(record.userOriginal),
        .string(record.assistantBetterExpression),
        .int64(record.createdAt),
      ]
    )
  }

  func delete(id: NativeAppID) async throws {
    try await ensureOpen()
    try await sqlite.execute("DELETE FROM learning_records WHERE id = ?", values: [.string(id)])
  }

  func deleteAll(sessionId: NativeAppID) async throws {
    try await ensureOpen()
    try await sqlite.execute("DELETE FROM learning_records WHERE sessionId = ?", values: [.string(sessionId)])
  }

  private func mapLearningRecord(row: [String: NativeSQLiteValue]) throws -> LearningRecord {
    LearningRecord(
      id: try row.requiredString("id"),
      sessionId: try row.requiredString("sessionId"),
      messageId: try row.requiredString("messageId"),
      expression: try row.requiredString("expression"),
      cnExplanation: try row.requiredString("cnExplanation"),
      scenario: try row.requiredString("scenario"),
      userOriginal: try row.requiredString("userOriginal"),
      assistantBetterExpression: try row.requiredString("assistantBetterExpression"),
      createdAt: try row.requiredInt64("createdAt")
    )
  }
}

private final class NativeSQLiteSettingsRepository: AppSettingsRepository, NativeSQLiteBackedRepository {
  let sqlite: NativeSQLiteExecuting
  private let settingsID = "app-settings"

  init(sqlite: NativeSQLiteExecuting) {
    self.sqlite = sqlite
  }

  func loadSettings() async throws -> NativeAppSettings {
    try await ensureOpen()
    let rows = try await sqlite.fetch(
      "SELECT * FROM settings WHERE id = ? LIMIT 1",
      values: [.string(settingsID)]
    )

    guard let row = rows.first else {
      try await persist(NativeAppSettings.defaults)
      return .defaults
    }

    return NativeAppSettings(
      teacherStyle: TeacherStyle(rawValue: row.optionalString("teacherStyle") ?? "") ?? .encouraging,
      correctionLevel: CorrectionLevel(rawValue: row.optionalString("correctionLevel") ?? "") ?? .medium,
      chineseRatio: ChineseRatio(rawValue: row.optionalString("chineseRatio") ?? "") ?? .none,
      ttsVoice: TtsVoice(rawValue: row.optionalString("ttsVoice") ?? "") ?? .alloy,
      recentMessageCount: Int(row.optionalString("recentMessageCount") ?? "") ?? 6
    )
  }

  func saveSettings(_ settings: NativeAppSettings) async throws {
    try await ensureOpen()
    try await persist(settings)
  }

  private func persist(_ settings: NativeAppSettings) async throws {
    try await sqlite.execute(
      """
      INSERT INTO settings (id, teacherStyle, correctionLevel, chineseRatio, ttsVoice, recentMessageCount, updatedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        teacherStyle = excluded.teacherStyle,
        correctionLevel = excluded.correctionLevel,
        chineseRatio = excluded.chineseRatio,
        ttsVoice = excluded.ttsVoice,
        recentMessageCount = excluded.recentMessageCount,
        updatedAt = excluded.updatedAt;
      """,
      values: [
        .string(settingsID),
        .string(settings.teacherStyle.rawValue),
        .string(settings.correctionLevel.rawValue),
        .string(settings.chineseRatio.rawValue),
        .string(settings.ttsVoice.rawValue),
        .int64(Int64(settings.recentMessageCount)),
        .int64(now()),
      ]
    )
  }
}
