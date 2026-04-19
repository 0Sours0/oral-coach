import Foundation

enum NativePromptRole: String, Codable {
  case system
  case user
  case assistant
}

struct NativePromptMessage: Codable, Equatable {
  var role: NativePromptRole
  var content: String

  static func system(_ content: String) -> NativePromptMessage {
    NativePromptMessage(role: .system, content: content)
  }

  static func user(_ content: String) -> NativePromptMessage {
    NativePromptMessage(role: .user, content: content)
  }

  static func assistant(_ content: String) -> NativePromptMessage {
    NativePromptMessage(role: .assistant, content: content)
  }
}

struct NativeLearningExpression: Codable, Equatable {
  var text: String
  var cnExplanation: String
  var scenario: String
}

struct NativeDeepSeekReply: Codable, Equatable {
  var reply: String
  var correctedSentence: String
  var expression: NativeLearningExpression?
}

struct NativeLearningMetadata: Codable, Equatable {
  var correctedSentence: String
  var expression: NativeLearningExpression?
}

struct NativeRelationshipMemoryDraft: Codable, Equatable {
  var learnerProfile: String
  var speakingGoals: String
  var recurringMistakes: String
  var sharedFacts: String
  var relationshipNotes: String
}

struct NativeSummaryPayload: Codable, Equatable {
  var summaryText: String
}

struct NativePromptRagEntry: Codable, Equatable, Identifiable {
  var title: String
  var content: String

  var id: String { title }
}
