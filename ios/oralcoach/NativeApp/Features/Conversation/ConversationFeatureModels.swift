import Foundation
import SwiftUI

extension SessionMode {
  var conversationTitle: String {
    switch self {
    case .realtimeCall:
      return "Live call"
    case .voiceMessage:
      return "Voice message"
    }
  }

  var conversationSubtitle: String {
    switch self {
    case .realtimeCall:
      return "Fast, interruptible, and conversational."
    case .voiceMessage:
      return "Slower, deeper, and easier to review."
    }
  }

  var conversationSystemImage: String {
    switch self {
    case .realtimeCall:
      return "phone.fill"
    case .voiceMessage:
      return "mic.fill"
    }
  }
}

extension MessageRole {
  var conversationAlignment: HorizontalAlignment {
    switch self {
    case .user:
      return .trailing
    case .assistant, .system:
      return .leading
    }
  }

  var conversationBubbleColor: Color {
    switch self {
    case .user:
      return Color.blue.opacity(0.9)
    case .assistant:
      return Color(.secondarySystemBackground)
    case .system:
      return Color.orange.opacity(0.18)
    }
  }

  var conversationTextColor: Color {
    switch self {
    case .user:
      return .white
    case .assistant, .system:
      return .primary
    }
  }
}

extension Message {
  var isUserMessage: Bool {
    role == .user
  }

  var isAssistantMessage: Bool {
    role == .assistant
  }

  var conversationSubtitle: String? {
    if let correctionFeedback, !correctionFeedback.isEmpty {
      return correctionFeedback
    }
    return expressionText
  }
}

struct ConversationThreadSnapshot: Equatable {
  var session: Session?
  var personaName: String
  var relationshipMemoryNote: String
  var mode: SessionMode
  var messages: [Message]
}

struct ConversationSendRequest: Equatable {
  var sessionId: NativeAppID?
  var mode: SessionMode
  var text: String
  var audioURI: String?
}

struct ConversationSendResponse: Equatable {
  var updatedSession: Session?
  var userMessage: Message
  var assistantMessage: Message
}

enum ConversationFeatureLoadState: Equatable {
  case idle
  case loading
  case loaded
  case failed(String)
}

