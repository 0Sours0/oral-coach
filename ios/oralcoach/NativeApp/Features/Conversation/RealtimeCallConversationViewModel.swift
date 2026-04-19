import Foundation
import SwiftUI

@MainActor
final class RealtimeCallConversationViewModel: ObservableObject {
  enum CallState: String, Codable, CaseIterable, Identifiable {
    case idle
    case connecting
    case connected
    case speaking
    case listening
    case ended
    case failed

    var id: String { rawValue }
  }

  @Published var callState: CallState = .idle
  @Published var isMuted = false
  @Published var liveTranscript: String = ""
  @Published var promptText = "Realtime call mode keeps the exchange fast and interruptible."
  @Published var lastErrorText: String?

  let dependencies: ConversationFeatureDependencies
  let threadStore: ConversationThreadStore
  private var activeUserTempID: NativeAppID?
  private var activeAssistantTempID: NativeAppID?
  private var activeUserDraft = ""
  private var activeAssistantDraft = ""
  private var lastPersistedUserText = ""
  private var notificationToken: NSObjectProtocol?

  init(
    threadStore: ConversationThreadStore,
    dependencies: ConversationFeatureDependencies
  ) {
    self.threadStore = threadStore
    self.dependencies = dependencies
    notificationToken = NotificationCenter.default.addObserver(
      forName: .nativeRealtimeDialogEvent,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleRealtimeNotification(notification)
    }
  }

  deinit {
    if let notificationToken {
      NotificationCenter.default.removeObserver(notificationToken)
    }
  }

  func loadThread() async {
    threadStore.setLoading()
    do {
      let snapshot = try await dependencies.backend.loadThread(for: .realtimeCall)
      threadStore.apply(snapshot: snapshot)
      promptText = "Realtime call mode keeps the exchange fast and interruptible."
    } catch {
      threadStore.setFailed(error.localizedDescription)
      lastErrorText = error.localizedDescription
      callState = .failed
    }
  }

  func beginCall() async {
    callState = .connecting
    threadStore.statusText = "Starting realtime call..."
    do {
      try await dependencies.backend.beginRealtimeCall(mode: .realtimeCall)
      callState = .connected
      threadStore.statusText = "Realtime call connected."
      lastErrorText = nil
    } catch {
      callState = .failed
      let message = error.localizedDescription
      threadStore.setFailed(message)
      lastErrorText = message
    }
  }

  func endCall() async {
    do {
      try await dependencies.backend.endRealtimeCall(mode: .realtimeCall)
      callState = .ended
      threadStore.statusText = "Realtime call ended."
    } catch {
      callState = .failed
      let message = error.localizedDescription
      threadStore.setFailed(message)
      lastErrorText = message
    }
  }

  func submitTurn() async {
    let text = threadStore.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }

    callState = .speaking
    threadStore.statusText = "Sending turn..."

    do {
      let response = try await dependencies.backend.sendRealtimeCallTurn(
        ConversationSendRequest(
          sessionId: threadStore.session?.id,
          mode: .realtimeCall,
          text: text,
          audioURI: nil
        )
      )
      threadStore.session = response.updatedSession ?? threadStore.session
      threadStore.append(response.userMessage)
      threadStore.append(response.assistantMessage)
      threadStore.clearDraft()
      callState = .listening
      promptText = response.assistantMessage.conversationSubtitle ?? "Realtime turn sent."
      lastErrorText = nil
    } catch {
      callState = .failed
      let message = error.localizedDescription
      threadStore.setFailed(message)
      lastErrorText = message
    }
  }

  func toggleMute() {
    isMuted.toggle()
  }

  private func handleRealtimeNotification(_ notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let name = userInfo["name"] as? String
    else {
      return
    }

    let text = (userInfo["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    switch name {
    case "engine_started":
      callState = .listening
      threadStore.statusText = "Realtime call connected."
    case "engine_stopped":
      callState = .ended
      threadStore.statusText = "Realtime call ended."
    case "asr_info":
      callState = .listening
      ensureUserDraftMessage()
    case "asr_response":
      ensureUserDraftMessage()
      guard let activeUserTempID, !text.isEmpty else { return }
      activeUserDraft = text
      threadStore.replaceMessage(
        Message(
          id: activeUserTempID,
          sessionId: threadStore.session?.id ?? "realtime-session",
          role: .user,
          text: activeUserDraft,
          correctionFeedback: nil,
          expressionText: nil,
          audioUri: nil,
          createdAt: Int64(Date().timeIntervalSince1970 * 1_000)
        )
      )
    case "asr_ended":
      finalizeRealtimeUserDraft()
    case "chat_response":
      callState = .speaking
      ensureAssistantDraftMessage()
      guard let activeAssistantTempID, !text.isEmpty else { return }
      activeAssistantDraft = mergeStreamingText(previous: activeAssistantDraft, incoming: text)
      threadStore.replaceMessage(
        Message(
          id: activeAssistantTempID,
          sessionId: threadStore.session?.id ?? "realtime-session",
          role: .assistant,
          text: activeAssistantDraft,
          correctionFeedback: nil,
          expressionText: nil,
          audioUri: nil,
          createdAt: Int64(Date().timeIntervalSince1970 * 1_000)
        )
      )
    case "chat_ended":
      finalizeRealtimeAssistantDraft()
    case "error":
      callState = .failed
      lastErrorText = (userInfo["rawData"] as? String) ?? "Realtime dialog error"
      threadStore.setFailed(lastErrorText ?? "Realtime dialog error")
    default:
      break
    }
  }

  private func ensureUserDraftMessage() {
    guard activeUserTempID == nil else { return }
    let id = "realtime-user-\(UUID().uuidString)"
    activeUserTempID = id
    threadStore.append(
      Message(
        id: id,
        sessionId: threadStore.session?.id ?? "realtime-session",
        role: .user,
        text: "",
        correctionFeedback: nil,
        expressionText: nil,
        audioUri: nil,
        createdAt: Int64(Date().timeIntervalSince1970 * 1_000)
      )
    )
  }

  private func ensureAssistantDraftMessage() {
    guard activeAssistantTempID == nil else { return }
    let id = "realtime-assistant-\(UUID().uuidString)"
    activeAssistantTempID = id
    threadStore.append(
      Message(
        id: id,
        sessionId: threadStore.session?.id ?? "realtime-session",
        role: .assistant,
        text: "",
        correctionFeedback: nil,
        expressionText: nil,
        audioUri: nil,
        createdAt: Int64(Date().timeIntervalSince1970 * 1_000)
      )
    )
  }

  private func mergeStreamingText(previous: String, incoming: String) -> String {
    let trimmed = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return previous }
    if previous.isEmpty { return trimmed }
    if trimmed.hasPrefix(previous) { return trimmed }
    if previous.hasPrefix(trimmed) { return previous }
    if previous.hasSuffix(trimmed) { return previous }
    return previous + incoming
  }

  private func finalizeRealtimeUserDraft() {
    let finalText = activeUserDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !finalText.isEmpty else {
      activeUserTempID = nil
      activeUserDraft = ""
      return
    }

    if let persistor = dependencies.backend as? RealtimeTranscriptPersisting {
      let tempID = activeUserTempID
      Task {
        do {
          let result = try await persistor.persistRealtimeUserMessage(
            sessionId: threadStore.session?.id,
            text: finalText
          )
          threadStore.session = result.updatedSession
          if let tempID {
            threadStore.replaceMessage(existingID: tempID, with: result.message)
          }
          lastPersistedUserText = finalText
        } catch {
          lastErrorText = error.localizedDescription
        }
      }
    } else {
      lastPersistedUserText = finalText
    }

    activeUserTempID = nil
    activeUserDraft = ""
  }

  private func finalizeRealtimeAssistantDraft() {
    callState = .listening
    let finalText = activeAssistantDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !finalText.isEmpty else {
      activeAssistantTempID = nil
      activeAssistantDraft = ""
      return
    }

    if let persistor = dependencies.backend as? RealtimeTranscriptPersisting {
      let tempID = activeAssistantTempID
      let userText = lastPersistedUserText
      Task {
        do {
          let result = try await persistor.persistRealtimeAssistantMessage(
            sessionId: threadStore.session?.id,
            userText: userText,
            text: finalText
          )
          threadStore.session = result.updatedSession
          if let tempID {
            threadStore.replaceMessage(existingID: tempID, with: result.message)
          }
        } catch {
          lastErrorText = error.localizedDescription
        }
      }
    }

    activeAssistantTempID = nil
    activeAssistantDraft = ""
  }
}
