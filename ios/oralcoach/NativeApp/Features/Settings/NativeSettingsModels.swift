import Foundation

typealias NativeTeacherStyle = TeacherStyle
typealias NativeCorrectionLevel = CorrectionLevel
typealias NativeChineseRatio = ChineseRatio
typealias NativeTTSVoice = TtsVoice
typealias NativeLearningSettings = NativeAppSettings

protocol NativeSettingsRepository {
  func loadSettings() async throws -> NativeLearningSettings
  func saveSettings(_ settings: NativeLearningSettings) async throws
  func fetchPersonaProfiles() async throws -> [PersonaProfile]
  func setActivePersona(id: NativeAppID) async throws
}

final class NativeSettingsPreviewRepository: NativeSettingsRepository {
  private var settings = NativeAppSettings.defaults
  private var personas: [PersonaProfile] = {
    let now = Date().timeIntervalSince1970 * 1000
    return [
      PersonaProfile(
        id: "persona-elon",
        name: "Elon Musk",
        bio: "Founder and operator of Tesla, SpaceX, xAI, and several other ventures.",
        personality: "Sharp, direct, high-agency, and often impatient with vague thinking.",
        speakingStyle: "Compact, energetic English with a strong bias toward concrete ideas.",
        teachingStyle: "English correction is a side habit, not the identity.",
        memoryPrompt: "Remember the learner's goals, prior topics, and recurring expression gaps.",
        cognitionStyle: "First-principles, systems-oriented, and engineering-minded.",
        behaviorRules: "Answer identity questions as Elon Musk first. Keep the correction secondary.",
        sampleDialogues: "Example: What's your job? -> I run Tesla and SpaceX, and a few other things.",
        isActive: 1,
        createdAt: Int64(now),
        updatedAt: Int64(now)
      ),
      PersonaProfile(
        id: "persona-socrates",
        name: "Socrates",
        bio: "A calm philosopher who uses questions to uncover sharper thinking.",
        personality: "Patient, probing, elegant, and quietly challenging.",
        speakingStyle: "Measured and lucid English with precise questions.",
        teachingStyle: "Clarifies language when it hides weak thought.",
        memoryPrompt: "Keep track of the user's ideas and gently expose assumptions.",
        cognitionStyle: "Investigative, Socratic, and definition-focused.",
        behaviorRules: "Never collapse into a generic tutor. Stay in character.",
        sampleDialogues: "Example: I think people are not really honest in work. -> A more natural way to say it is...",
        isActive: 0,
        createdAt: Int64(now),
        updatedAt: Int64(now)
      )
    ]
  }()

  func loadSettings() async throws -> NativeLearningSettings {
    settings
  }

  func saveSettings(_ settings: NativeLearningSettings) async throws {
    self.settings = settings
  }

  func fetchPersonaProfiles() async throws -> [PersonaProfile] {
    personas
  }

  func setActivePersona(id: NativeAppID) async throws {
    personas = personas.map { persona in
      var updated = persona
      updated.isActive = persona.id == id ? 1 : 0
      updated.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
      return updated
    }
  }
}

final class NativeSQLiteSettingsFeatureRepository: NativeSettingsRepository {
  private let settingsRepository: any AppSettingsRepository
  private let personaRepository: any PersonaProfileRepository

  init(
    settingsRepository: any AppSettingsRepository,
    personaRepository: any PersonaProfileRepository
  ) {
    self.settingsRepository = settingsRepository
    self.personaRepository = personaRepository
  }

  func loadSettings() async throws -> NativeLearningSettings {
    try await settingsRepository.loadSettings()
  }

  func saveSettings(_ settings: NativeLearningSettings) async throws {
    try await settingsRepository.saveSettings(settings)
  }

  func fetchPersonaProfiles() async throws -> [PersonaProfile] {
    try await personaRepository.fetchAllPersonaProfiles()
  }

  func setActivePersona(id: NativeAppID) async throws {
    try await personaRepository.setActiveProfile(id: id)
  }
}
