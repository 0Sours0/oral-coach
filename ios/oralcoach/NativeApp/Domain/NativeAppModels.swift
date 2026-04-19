import Foundation

// Migration note:
// These structs mirror the current TypeScript shapes in `types/` and the
// persisted column layout in `storage/db.ts`. Keep them boring and explicit so
// the native migration can evolve without changing the app data contract.

typealias NativeAppID = String
typealias NativeAppTimestamp = Int64

enum SessionMode: String, Codable, CaseIterable, Identifiable {
  case realtimeCall = "realtime_call"
  case voiceMessage = "voice_message"

  var id: String { rawValue }
}

enum MessageRole: String, Codable, CaseIterable, Identifiable {
  case system
  case user
  case assistant

  var id: String { rawValue }
}

enum TeacherStyle: String, Codable, CaseIterable, Identifiable {
  case encouraging
  case strict
  case casual

  var id: String { rawValue }

  var title: String {
    switch self {
    case .encouraging:
      return "Encouraging"
    case .strict:
      return "Strict"
    case .casual:
      return "Casual"
    }
  }
}

enum CorrectionLevel: String, Codable, CaseIterable, Identifiable {
  case light
  case medium
  case heavy

  var id: String { rawValue }

  var title: String {
    switch self {
    case .light:
      return "Light"
    case .medium:
      return "Medium"
    case .heavy:
      return "Heavy"
    }
  }
}

enum ChineseRatio: String, Codable, CaseIterable, Identifiable {
  case none
  case some
  case frequent

  var id: String { rawValue }

  var title: String {
    switch self {
    case .none:
      return "None"
    case .some:
      return "Some"
    case .frequent:
      return "Frequent"
    }
  }
}

enum TtsVoice: String, Codable, CaseIterable, Identifiable {
  case alloy
  case echo
  case fable
  case onyx
  case nova
  case shimmer

  var id: String { rawValue }

  var title: String { rawValue.capitalized }
}

struct NativeAppSettings: Codable, Equatable {
  var teacherStyle: TeacherStyle
  var correctionLevel: CorrectionLevel
  var chineseRatio: ChineseRatio
  var ttsVoice: TtsVoice
  var recentMessageCount: Int

  static let defaults = NativeAppSettings(
    teacherStyle: .encouraging,
    correctionLevel: .medium,
    chineseRatio: .none,
    ttsVoice: .alloy,
    recentMessageCount: 6
  )
}

struct NativeMessageMetadata: Codable, Equatable {
  var correctionFeedback: String?
  var expressionText: String?
  var audioUri: String?

  init(
    correctionFeedback: String? = nil,
    expressionText: String? = nil,
    audioUri: String? = nil
  ) {
    self.correctionFeedback = correctionFeedback
    self.expressionText = expressionText
    self.audioUri = audioUri
  }
}

/// Mirrors `types/session.ts`.
struct Session: Identifiable, Codable, Equatable {
  var id: NativeAppID
  var title: String
  var mode: SessionMode
  var createdAt: NativeAppTimestamp
  var updatedAt: NativeAppTimestamp
}

/// Mirrors `types/message.ts`.
struct Message: Identifiable, Codable, Equatable {
  var id: NativeAppID
  var sessionId: NativeAppID
  var role: MessageRole
  var text: String
  var correctionFeedback: String?
  var expressionText: String?
  var audioUri: String?
  var createdAt: NativeAppTimestamp
}

/// Mirrors `types/persona.ts`.
/// SQLite stores the active flag as an integer, so keep the field as Int here.
struct PersonaProfile: Identifiable, Codable, Equatable {
  var id: NativeAppID
  var name: String
  var bio: String
  var personality: String
  var speakingStyle: String
  var teachingStyle: String
  var memoryPrompt: String
  var cognitionStyle: String
  var behaviorRules: String
  var sampleDialogues: String
  var isActive: Int
  var createdAt: NativeAppTimestamp
  var updatedAt: NativeAppTimestamp
}

/// Mirrors `types/persona.ts`.
struct RelationshipMemory: Identifiable, Codable, Equatable {
  var id: NativeAppID
  var personaId: NativeAppID
  var learnerProfile: String
  var speakingGoals: String
  var recurringMistakes: String
  var sharedFacts: String
  var relationshipNotes: String
  var updatedAt: NativeAppTimestamp
}

/// Mirrors `types/summary.ts`.
struct Summary: Identifiable, Codable, Equatable {
  var id: NativeAppID
  var sessionId: NativeAppID
  var summaryText: String
  var coveredUntilMessageId: NativeAppID
  var updatedAt: NativeAppTimestamp
}

/// Mirrors `types/learningRecord.ts`.
struct LearningRecord: Identifiable, Codable, Equatable {
  var id: NativeAppID
  var sessionId: NativeAppID
  var messageId: NativeAppID
  var expression: String
  var cnExplanation: String
  var scenario: String
  var userOriginal: String
  var assistantBetterExpression: String
  var createdAt: NativeAppTimestamp
}
