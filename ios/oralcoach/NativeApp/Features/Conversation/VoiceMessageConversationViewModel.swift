import Foundation
import SwiftUI

@MainActor
final class VoiceMessageConversationViewModel: ObservableObject {
  @Published var isRecording = false
  @Published var isPreparingAudio = false
  @Published var isSubmitting = false
  @Published var promptText = "Voice message mode keeps replies slower and deeper."
  @Published var lastTranscription: String?
  @Published var lastErrorText: String?

  let dependencies: ConversationFeatureDependencies
  let threadStore: ConversationThreadStore
  private var lastRecordedAudioURL: URL?

  init(
    threadStore: ConversationThreadStore,
    dependencies: ConversationFeatureDependencies
  ) {
    self.threadStore = threadStore
    self.dependencies = dependencies
  }

  func loadThread() async {
    threadStore.setLoading()
    do {
      let snapshot = try await dependencies.backend.loadThread(for: .voiceMessage)
      threadStore.apply(snapshot: snapshot)
      promptText = "Voice message mode keeps replies slower and deeper."
    } catch {
      threadStore.setFailed(error.localizedDescription)
      lastErrorText = error.localizedDescription
    }
  }

  func startRecording() async {
    do {
      try await dependencies.audioRecorder.startRecording()
      isRecording = true
      isPreparingAudio = false
      threadStore.statusText = "Recording voice note..."
      lastErrorText = nil
    } catch {
      isRecording = false
      isPreparingAudio = false
      let message = error.localizedDescription
      threadStore.setFailed(message)
      lastErrorText = message
    }
  }

  func stopRecording() async {
    guard isRecording else { return }

    isRecording = false
    isPreparingAudio = true
    threadStore.statusText = "Transcribing voice message..."

    defer { isPreparingAudio = false }

    do {
      let audioURL = try await dependencies.audioRecorder.stopRecording()
      lastRecordedAudioURL = audioURL
      let transcript = try await dependencies.speechTranscriber.transcribe(audioURL: audioURL)
      receiveTranscription(transcript)
      lastErrorText = nil
      await submitDraft()
    } catch {
      let message = error.localizedDescription
      threadStore.setFailed(message)
      lastErrorText = message
    }
  }

  func submitDraft() async {
    let text = threadStore.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }

    isSubmitting = true
    threadStore.clearDraft()
    threadStore.statusText = "Waiting for reply..."

    // Optimistic: show user message immediately before waiting for server
    let optimisticID = "optimistic-\(UUID().uuidString)"
    let optimisticUserMessage = Message(
      id: optimisticID,
      sessionId: threadStore.session?.id ?? "",
      role: .user,
      text: text,
      correctionFeedback: nil,
      expressionText: nil,
      audioUri: nil,
      createdAt: Int64(Date().timeIntervalSince1970 * 1000)
    )
    threadStore.append(optimisticUserMessage)

    defer { isSubmitting = false }

    do {
      let response = try await dependencies.backend.sendVoiceMessage(
        ConversationSendRequest(
          sessionId: threadStore.session?.id,
          mode: .voiceMessage,
          text: text,
          audioURI: nil
        )
      )
      threadStore.session = response.updatedSession ?? threadStore.session
      threadStore.replaceMessage(existingID: optimisticID, with: response.userMessage)
      threadStore.append(response.assistantMessage)
      promptText = response.assistantMessage.conversationSubtitle ?? "Voice message sent."
      lastTranscription = text
      lastErrorText = nil

      let settings = try await dependencies.settingsStore.loadSettings()
      try await dependencies.textSpeaker.speak(
        text: response.assistantMessage.text,
        voiceID: settings.ttsVoice.rawValue
      )

      if let lastRecordedAudioURL {
        try? FileManager.default.removeItem(at: lastRecordedAudioURL)
        self.lastRecordedAudioURL = nil
      }
    } catch {
      // Remove optimistic message on failure so the user can retry
      threadStore.messages.removeAll { $0.id == optimisticID }
      threadStore.draftText = text
      let message = error.localizedDescription
      threadStore.setFailed(message)
      lastErrorText = message
    }
  }

  func receiveTranscription(_ transcript: String) {
    lastTranscription = transcript
    threadStore.draftText = transcript
    threadStore.statusText = "Ready to send the voice message."
  }
}
