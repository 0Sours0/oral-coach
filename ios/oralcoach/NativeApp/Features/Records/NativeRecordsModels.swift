import Foundation

protocol NativeRecordsRepository {
  func fetchLearningRecords(matching query: String) async throws -> [LearningRecord]
  func fetchLearningRecord(id: NativeAppID) async throws -> LearningRecord?
  func deleteLearningRecord(id: NativeAppID) async throws
}

extension LearningRecord {
  var nativeCreatedAtDate: Date {
    Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0)
  }

  var nativeSearchIndex: String {
    [
      expression,
      cnExplanation,
      scenario,
      userOriginal,
      assistantBetterExpression
    ]
    .joined(separator: " ")
    .lowercased()
  }
}

final class NativeRecordsPreviewRepository: NativeRecordsRepository {
  private var records: [LearningRecord] = [
    LearningRecord(
      id: "record-1",
      sessionId: "session-1",
      messageId: "message-1",
      expression: "What do you do?",
      cnExplanation: "问对方是做什么工作的，语气自然直接。",
      scenario: "job interview",
      userOriginal: "What's your job?",
      assistantBetterExpression: "What do you do?",
      createdAt: 1_710_000_000_000
    ),
    LearningRecord(
      id: "record-2",
      sessionId: "session-1",
      messageId: "message-2",
      expression: "I've been having a hard time concentrating lately.",
      cnExplanation: "描述最近很难专注。",
      scenario: "daily life",
      userOriginal: "I very hard to focus recently.",
      assistantBetterExpression: "I've been having a hard time concentrating lately.",
      createdAt: 1_710_003_600_000
    ),
    LearningRecord(
      id: "record-3",
      sessionId: "session-2",
      messageId: "message-4",
      expression: "Do you know what I like?",
      cnExplanation: "问对方是否知道你的喜好。",
      scenario: "conversation",
      userOriginal: "Do you know 我喜欢什么",
      assistantBetterExpression: "Do you know what I like?",
      createdAt: 1_710_007_200_000
    )
  ]

  func fetchLearningRecords(matching query: String) async throws -> [LearningRecord] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return records.sorted { $0.createdAt > $1.createdAt }
    }

    let lowercased = trimmed.lowercased()
    return records
      .filter { $0.nativeSearchIndex.contains(lowercased) }
      .sorted { $0.createdAt > $1.createdAt }
  }

  func fetchLearningRecord(id: NativeAppID) async throws -> LearningRecord? {
    records.first { $0.id == id }
  }

  func deleteLearningRecord(id: NativeAppID) async throws {
    records.removeAll { $0.id == id }
  }
}

final class NativeSQLiteRecordsRepository: NativeRecordsRepository {
  private let repository: any LearningRecordRepository

  init(repository: any LearningRecordRepository) {
    self.repository = repository
  }

  func fetchLearningRecords(matching query: String) async throws -> [LearningRecord] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return try await repository.fetchAllLearningRecords()
    }
    return try await repository.searchLearningRecords(query: trimmed)
  }

  func fetchLearningRecord(id: NativeAppID) async throws -> LearningRecord? {
    let records = try await repository.fetchAllLearningRecords()
    return records.first(where: { $0.id == id })
  }

  func deleteLearningRecord(id: NativeAppID) async throws {
    try await repository.delete(id: id)
  }
}
