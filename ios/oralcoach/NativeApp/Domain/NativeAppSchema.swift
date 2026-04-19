import Foundation

// Migration note:
// This schema mirrors the current RN SQLite tables from `storage/db.ts`.
// It is intentionally declarative so the Swift layer can bootstrap the same
// persistence contract later without reshaping the data model.

enum NativeAppSchema {
  static let databaseFilename = "oralcoach.db"
  static let journalMode = "WAL"

  static let sessionsTable = "sessions"
  static let messagesTable = "messages"
  static let learningRecordsTable = "learning_records"
  static let summariesTable = "summaries"
  static let personasTable = "personas"
  static let relationshipMemoriesTable = "relationship_memories"
  static let settingsTable = "settings"

  static let bootstrapStatements: [String] = [
    "PRAGMA journal_mode = WAL;",
    """
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      mode TEXT NOT NULL DEFAULT 'realtime_call',
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      sessionId TEXT NOT NULL,
      role TEXT NOT NULL,
      text TEXT NOT NULL,
      correctionFeedback TEXT,
      expressionText TEXT,
      audioUri TEXT,
      createdAt INTEGER NOT NULL,
      FOREIGN KEY (sessionId) REFERENCES sessions(id)
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS learning_records (
      id TEXT PRIMARY KEY,
      sessionId TEXT NOT NULL,
      messageId TEXT NOT NULL,
      expression TEXT NOT NULL,
      cnExplanation TEXT NOT NULL,
      scenario TEXT NOT NULL,
      userOriginal TEXT NOT NULL,
      assistantBetterExpression TEXT NOT NULL,
      createdAt INTEGER NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS summaries (
      id TEXT PRIMARY KEY,
      sessionId TEXT NOT NULL,
      summaryText TEXT NOT NULL,
      coveredUntilMessageId TEXT NOT NULL,
      updatedAt INTEGER NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS personas (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      bio TEXT NOT NULL,
      personality TEXT NOT NULL,
      speakingStyle TEXT NOT NULL,
      teachingStyle TEXT NOT NULL,
      memoryPrompt TEXT NOT NULL,
      cognitionStyle TEXT NOT NULL DEFAULT '',
      behaviorRules TEXT NOT NULL DEFAULT '',
      sampleDialogues TEXT NOT NULL DEFAULT '',
      isActive INTEGER NOT NULL DEFAULT 0,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS relationship_memories (
      id TEXT PRIMARY KEY,
      personaId TEXT NOT NULL,
      learnerProfile TEXT NOT NULL DEFAULT '',
      speakingGoals TEXT NOT NULL DEFAULT '',
      recurringMistakes TEXT NOT NULL DEFAULT '',
      sharedFacts TEXT NOT NULL DEFAULT '',
      relationshipNotes TEXT NOT NULL DEFAULT '',
      updatedAt INTEGER NOT NULL,
      FOREIGN KEY (personaId) REFERENCES personas(id)
    );
    """,
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_relationship_memories_personaId ON relationship_memories(personaId);",
    """
    CREATE TABLE IF NOT EXISTS settings (
      id TEXT PRIMARY KEY,
      teacherStyle TEXT NOT NULL,
      correctionLevel TEXT NOT NULL,
      chineseRatio TEXT NOT NULL,
      ttsVoice TEXT NOT NULL,
      recentMessageCount INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_sessions_updatedAt ON sessions(updatedAt);",
    "CREATE INDEX IF NOT EXISTS idx_messages_sessionId_createdAt ON messages(sessionId, createdAt);",
    "CREATE INDEX IF NOT EXISTS idx_learning_records_sessionId_createdAt ON learning_records(sessionId, createdAt);",
    "CREATE INDEX IF NOT EXISTS idx_summaries_sessionId_updatedAt ON summaries(sessionId, updatedAt);"
  ]

  static let bestEffortMigrationStatements: [String] = [
    "ALTER TABLE sessions ADD COLUMN mode TEXT NOT NULL DEFAULT 'realtime_call';",
    "ALTER TABLE messages ADD COLUMN expressionText TEXT;",
    "ALTER TABLE personas ADD COLUMN cognitionStyle TEXT NOT NULL DEFAULT '';",
    "ALTER TABLE personas ADD COLUMN behaviorRules TEXT NOT NULL DEFAULT '';",
    "ALTER TABLE personas ADD COLUMN sampleDialogues TEXT NOT NULL DEFAULT '';"
  ]
}
