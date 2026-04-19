import Foundation
import SwiftUI

@MainActor
final class NativeSettingsFeatureViewModel: ObservableObject {
  @Published var settings = NativeAppSettings.defaults
  @Published var personas: [PersonaProfile] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var expandedPersonaID: NativeAppID?

  private let repository: any NativeSettingsRepository

  init(repository: any NativeSettingsRepository) {
    self.repository = repository
  }

  convenience init() {
    self.init(repository: NativeAppDependencies.shared.settingsRepository)
  }

  @MainActor
  func load() async {
    isLoading = true
    errorMessage = nil

    do {
      async let loadedSettings = repository.loadSettings()
      async let loadedPersonas = repository.fetchPersonaProfiles()
      settings = try await loadedSettings
      personas = try await loadedPersonas
      if expandedPersonaID == nil {
        expandedPersonaID = personas.first(where: { $0.isActive == 1 })?.id ?? personas.first?.id
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  @MainActor
  func reload() async {
    await load()
  }

  @MainActor
  func togglePersonaExpansion(id: NativeAppID) {
    expandedPersonaID = expandedPersonaID == id ? nil : id
  }

  @MainActor
  func selectPersona(id: NativeAppID) async {
    do {
      try await repository.setActivePersona(id: id)
      personas = personas.map { persona in
        var updated = persona
        updated.isActive = persona.id == id ? 1 : 0
        updated.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        return updated
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  func updateTeacherStyle(_ value: NativeTeacherStyle) {
    settings.teacherStyle = value
    persistSettings()
  }

  @MainActor
  func updateCorrectionLevel(_ value: NativeCorrectionLevel) {
    settings.correctionLevel = value
    persistSettings()
  }

  @MainActor
  func updateChineseRatio(_ value: NativeChineseRatio) {
    settings.chineseRatio = value
    persistSettings()
  }

  @MainActor
  func updateTTSVoice(_ value: NativeTTSVoice) {
    settings.ttsVoice = value
    persistSettings()
  }

  @MainActor
  func updateRecentMessageCount(_ value: Int) {
    settings.recentMessageCount = value
    persistSettings()
  }

  private func persistSettings() {
    let snapshot = settings
    Task {
      do {
        try await repository.saveSettings(snapshot)
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
        }
      }
    }
  }

  var activePersona: PersonaProfile? {
    personas.first(where: { $0.isActive == 1 }) ?? personas.first
  }
}
