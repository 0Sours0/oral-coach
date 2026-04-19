import Foundation
import SwiftUI

@MainActor
final class ConversationFeatureViewModel: ObservableObject {
  @Published var activeMode: SessionMode = .voiceMessage {
    didSet {
      threadStore.updateMode(activeMode)
    }
  }

  @Published var loadState: ConversationFeatureLoadState = .idle
  @Published var isSending = false

  let dependencies: ConversationFeatureDependencies
  let threadStore: ConversationThreadStore
  let voiceMessageViewModel: VoiceMessageConversationViewModel
  let realtimeCallViewModel: RealtimeCallConversationViewModel

  init(
    dependencies: ConversationFeatureDependencies,
    threadStore: ConversationThreadStore,
    voiceMessageViewModel: VoiceMessageConversationViewModel? = nil,
    realtimeCallViewModel: RealtimeCallConversationViewModel? = nil
  ) {
    self.dependencies = dependencies
    self.threadStore = threadStore
    self.voiceMessageViewModel = voiceMessageViewModel ?? VoiceMessageConversationViewModel(
      threadStore: threadStore,
      dependencies: dependencies
    )
    self.realtimeCallViewModel = realtimeCallViewModel ?? RealtimeCallConversationViewModel(
      threadStore: threadStore,
      dependencies: dependencies
    )
  }

  convenience init() {
    self.init(dependencies: .preview, threadStore: ConversationThreadStore())
  }

  func loadIfNeeded() async {
    guard loadState != .loading else { return }
    loadState = .loading
    threadStore.setLoading()

    do {
      let snapshot = try await dependencies.backend.loadThread(for: activeMode)
      threadStore.apply(snapshot: snapshot)
      loadState = .loaded
    } catch {
      let message = error.localizedDescription
      loadState = .failed(message)
      threadStore.setFailed(message)
    }
  }

  func switchMode(_ mode: SessionMode) {
    guard activeMode != mode else { return }
    activeMode = mode
    threadStore.updateMode(mode)
  }

  func startNewConversation() async {
    threadStore.setLoading("Starting a fresh thread...")
    do {
      let snapshot = try await dependencies.backend.startNewSession(for: activeMode)
      threadStore.apply(snapshot: snapshot)
      loadState = .loaded
    } catch {
      let message = error.localizedDescription
      loadState = .failed(message)
      threadStore.setFailed(message)
    }
  }

  func submitCurrentDraft() async {
    isSending = true
    defer { isSending = false }

    switch activeMode {
    case .voiceMessage:
      await voiceMessageViewModel.submitDraft()
    case .realtimeCall:
      await realtimeCallViewModel.submitTurn()
    }
  }

  var isCallActive: Bool {
    switch realtimeCallViewModel.callState {
    case .connecting, .connected, .listening, .speaking:
      return true
    case .idle, .ended, .failed:
      return false
    }
  }

  var isCallConnecting: Bool {
    realtimeCallViewModel.callState == .connecting
  }

  func sendDraft() async {
    await submitCurrentDraft()
  }

  func micPressBegin() async {
    if activeMode != .voiceMessage {
      switchMode(.voiceMessage)
    }
    await voiceMessageViewModel.startRecording()
  }

  func micPressEnd() async {
    await voiceMessageViewModel.stopRecording()
  }

  func callButtonTapped() async {
    if isCallActive {
      await realtimeCallViewModel.endCall()
      switchMode(.voiceMessage)
    } else {
      switchMode(.realtimeCall)
      await realtimeCallViewModel.beginCall()
    }
  }
}
