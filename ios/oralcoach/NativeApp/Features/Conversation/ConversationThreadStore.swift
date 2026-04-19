import Foundation
import SwiftUI

@MainActor
final class ConversationThreadStore: ObservableObject {
  @Published var loadState: ConversationFeatureLoadState = .idle
  @Published var activeMode: SessionMode = .voiceMessage
  @Published var session: Session?
  @Published var personaName: String = "Elon Musk"
  @Published var relationshipMemoryNote: String = ""
  @Published var messages: [Message] = []
  @Published var draftText: String = ""
  @Published var statusText: String = "Ready"
  @Published var errorText: String?
  @Published var lastUpdatedAt: Date = .now

  var threadTitle: String {
    session?.title ?? activeMode.conversationTitle
  }

  var threadSubtitle: String {
    if relationshipMemoryNote.isEmpty {
      return activeMode.conversationSubtitle
    }
    return relationshipMemoryNote
  }

  var lastMessageID: NativeAppID? {
    messages.last?.id
  }

  func apply(snapshot: ConversationThreadSnapshot) {
    loadState = .loaded
    activeMode = snapshot.mode
    session = snapshot.session
    personaName = snapshot.personaName
    relationshipMemoryNote = snapshot.relationshipMemoryNote
    messages = snapshot.messages
    draftText = ""
    statusText = snapshot.mode.conversationSubtitle
    errorText = nil
    lastUpdatedAt = .now
  }

  func setLoading(_ message: String = "Loading conversation...") {
    loadState = .loading
    statusText = message
    errorText = nil
  }

  func setFailed(_ message: String) {
    loadState = .failed(message)
    statusText = message
    errorText = message
  }

  func updateMode(_ mode: SessionMode) {
    activeMode = mode
    statusText = mode.conversationSubtitle
    lastUpdatedAt = .now
  }

  func append(_ message: Message) {
    messages.append(message)
    lastUpdatedAt = .now
  }

  func replaceMessage(_ message: Message) {
    guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
      append(message)
      return
    }
    messages[index] = message
    lastUpdatedAt = .now
  }

  func replaceMessage(existingID: NativeAppID, with message: Message) {
    guard let index = messages.firstIndex(where: { $0.id == existingID }) else {
      append(message)
      return
    }
    messages[index] = message
    lastUpdatedAt = .now
  }

  func clearDraft() {
    draftText = ""
  }

  func resetThread() {
    session = nil
    messages = []
    draftText = ""
    statusText = activeMode.conversationSubtitle
    errorText = nil
    lastUpdatedAt = .now
  }
}
