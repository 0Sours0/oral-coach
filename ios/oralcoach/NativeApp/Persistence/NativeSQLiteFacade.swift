import Foundation
import SQLite3

// Migration note:
// This file owns the raw SQLite3 boundary for the native app. The repository
// layer builds on top of this and keeps the SQL detail out of the feature code.

private let sqliteTransientDestructor = unsafeBitCast(
  OpaquePointer(bitPattern: -1),
  to: sqlite3_destructor_type.self
)

enum NativeSQLiteError: Error, LocalizedError, Equatable {
  case databaseNotOpen
  case databaseOpenFailed(path: String, message: String)
  case databaseCloseFailed(message: String)
  case databasePathResolutionFailed(message: String)
  case statementPreparationFailed(sql: String, message: String)
  case statementExecutionFailed(sql: String, message: String)
  case bindingFailed(sql: String, index: Int32, message: String)
  case filesystemFailed(message: String)

  var errorDescription: String? {
    switch self {
    case .databaseNotOpen:
      return "The native SQLite database is not open."
    case .databaseOpenFailed(let path, let message):
      return "Failed to open SQLite database at \(path): \(message)"
    case .databaseCloseFailed(let message):
      return "Failed to close SQLite database: \(message)"
    case .databasePathResolutionFailed(let message):
      return "Failed to resolve native SQLite path: \(message)"
    case .statementPreparationFailed(let sql, let message):
      return "Failed to prepare SQLite statement for '\(sql)': \(message)"
    case .statementExecutionFailed(let sql, let message):
      return "Failed to execute SQLite statement for '\(sql)': \(message)"
    case .bindingFailed(let sql, let index, let message):
      return "Failed to bind SQLite value at index \(index) for '\(sql)': \(message)"
    case .filesystemFailed(let message):
      return "Filesystem error while preparing SQLite database: \(message)"
    }
  }
}

enum NativeSQLiteValue: Equatable, Sendable {
  case null
  case string(String)
  case int64(Int64)
  case double(Double)
  case bool(Bool)
  case data(Data)
}

struct NativeSQLiteRow: Sendable {
  let values: [String: NativeSQLiteValue]

  subscript(_ key: String) -> NativeSQLiteValue? {
    values[key]
  }
}

protocol NativeSQLiteExecuting {
  var databasePath: String { get }
  var isOpen: Bool { get }

  func open() async throws
  func close() async throws
  func execute(_ sql: String, values: [NativeSQLiteValue]) async throws
  func fetch(_ sql: String, values: [NativeSQLiteValue]) async throws -> [[String: NativeSQLiteValue]]
}

private extension NSRecursiveLock {
  func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try body()
  }
}

final class NativeSQLiteFacade: NativeSQLiteExecuting {
  private let rawDatabasePath: String
  private let lock = NSRecursiveLock()
  private var database: OpaquePointer?
  private var resolvedDatabaseURL: URL?
  private(set) var isOpen: Bool = false

  var databasePath: String {
    resolvedDatabaseURL?.path ?? rawDatabasePath
  }

  init(databasePath: String = NativeAppSchema.databaseFilename) {
    self.rawDatabasePath = databasePath
  }

  func open() async throws {
    try lock.withLock {
      if isOpen {
        return
      }

      let url = try Self.resolveDatabaseURL(for: rawDatabasePath)
      if rawDatabasePath != ":memory:" {
        try Self.ensureParentDirectoryExists(for: url)
      }

      var db: OpaquePointer?
      let openFlags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
      let openResult = sqlite3_open_v2(url.path, &db, openFlags, nil)
      guard openResult == SQLITE_OK, let db else {
        if let db {
          sqlite3_close_v2(db)
        }
        throw NativeSQLiteError.databaseOpenFailed(
          path: url.path,
          message: Self.sqliteErrorMessage(code: openResult, database: db)
        )
      }

      database = db
      resolvedDatabaseURL = url
      isOpen = true

      do {
        try applyConnectionPragmasUnlocked()
        try bootstrapSchemaUnlocked()
      } catch {
        if let database {
          sqlite3_close_v2(database)
        }
        database = nil
        resolvedDatabaseURL = nil
        isOpen = false
        throw error
      }
    }
  }

  func close() async throws {
    try lock.withLock {
      guard isOpen, let database else {
        isOpen = false
        resolvedDatabaseURL = nil
        return
      }

      let closeResult = sqlite3_close_v2(database)
      guard closeResult == SQLITE_OK else {
        throw NativeSQLiteError.databaseCloseFailed(
          message: Self.sqliteErrorMessage(code: closeResult, database: database)
        )
      }

      self.database = nil
      resolvedDatabaseURL = nil
      isOpen = false
    }
  }

  func execute(_ sql: String, values: [NativeSQLiteValue] = []) async throws {
    try lock.withLock {
      try executeUnlocked(sql, values: values)
    }
  }

  func fetch(_ sql: String, values: [NativeSQLiteValue] = []) async throws -> [[String: NativeSQLiteValue]] {
    try lock.withLock {
      try fetchUnlocked(sql, values: values)
    }
  }

  private func bootstrapSchemaUnlocked() throws {
    for statement in NativeAppSchema.bootstrapStatements {
      try executeUnlocked(statement, values: [])
    }

    for statement in NativeAppSchema.bestEffortMigrationStatements {
      do {
        try executeUnlocked(statement, values: [])
      } catch {
        continue
      }
    }
  }

  private func applyConnectionPragmasUnlocked() throws {
    try executeUnlocked("PRAGMA foreign_keys = ON;", values: [])
    try executeUnlocked("PRAGMA busy_timeout = 5000;", values: [])
  }

  private func executeUnlocked(_ sql: String, values: [NativeSQLiteValue]) throws {
    try withDatabase { db in
      let statement = try prepareStatement(sql, database: db)
      defer { sqlite3_finalize(statement) }

      try bind(values, to: statement, sql: sql)

      while true {
        let stepResult = sqlite3_step(statement)
        switch stepResult {
        case SQLITE_ROW:
          continue
        case SQLITE_DONE:
          return
        default:
          throw NativeSQLiteError.statementExecutionFailed(
            sql: sql,
            message: Self.sqliteErrorMessage(code: stepResult, database: db)
          )
        }
      }
    }
  }

  private func fetchUnlocked(_ sql: String, values: [NativeSQLiteValue]) throws -> [[String: NativeSQLiteValue]] {
    try withDatabase { db in
      let statement = try prepareStatement(sql, database: db)
      defer { sqlite3_finalize(statement) }

      try bind(values, to: statement, sql: sql)

      var rows: [[String: NativeSQLiteValue]] = []
      while true {
        let stepResult = sqlite3_step(statement)
        switch stepResult {
        case SQLITE_ROW:
          rows.append(Self.makeRow(from: statement))
        case SQLITE_DONE:
          return rows
        default:
          throw NativeSQLiteError.statementExecutionFailed(
            sql: sql,
            message: Self.sqliteErrorMessage(code: stepResult, database: db)
          )
        }
      }
    }
  }

  private func withDatabase<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
    try lock.withLock {
      guard isOpen, let database else {
        throw NativeSQLiteError.databaseNotOpen
      }
      return try body(database)
    }
  }

  private func prepareStatement(_ sql: String, database: OpaquePointer) throws -> OpaquePointer {
    var statement: OpaquePointer?
    let result = sql.withCString { pointer in
      sqlite3_prepare_v2(database, pointer, -1, &statement, nil)
    }

    guard result == SQLITE_OK, let statement else {
      throw NativeSQLiteError.statementPreparationFailed(
        sql: sql,
        message: Self.sqliteErrorMessage(code: result, database: database)
      )
    }

    return statement
  }

  private func bind(_ values: [NativeSQLiteValue], to statement: OpaquePointer, sql: String) throws {
    for (index, value) in values.enumerated() {
      let bindIndex = Int32(index + 1)
      let result: Int32

      switch value {
      case .null:
        result = sqlite3_bind_null(statement, bindIndex)
      case .string(let string):
        result = string.withCString { pointer in
          sqlite3_bind_text(statement, bindIndex, pointer, -1, sqliteTransientDestructor)
        }
      case .int64(let number):
        result = sqlite3_bind_int64(statement, bindIndex, number)
      case .double(let number):
        result = sqlite3_bind_double(statement, bindIndex, number)
      case .bool(let flag):
        result = sqlite3_bind_int64(statement, bindIndex, flag ? 1 : 0)
      case .data(let data):
        result = data.withUnsafeBytes { buffer in
          sqlite3_bind_blob(statement, bindIndex, buffer.baseAddress, Int32(buffer.count), sqliteTransientDestructor)
        }
      }

      guard result == SQLITE_OK else {
        throw NativeSQLiteError.bindingFailed(
          sql: sql,
          index: bindIndex,
          message: Self.sqliteErrorMessage(code: result, database: nil)
        )
      }
    }
  }

  private static func makeRow(from statement: OpaquePointer) -> [String: NativeSQLiteValue] {
    let columnCount = sqlite3_column_count(statement)
    var row: [String: NativeSQLiteValue] = [:]

    for index in 0..<columnCount {
      guard let columnNamePointer = sqlite3_column_name(statement, index) else {
        continue
      }

      let columnName = String(cString: columnNamePointer)
      let value: NativeSQLiteValue

      switch sqlite3_column_type(statement, index) {
      case SQLITE_INTEGER:
        value = .int64(sqlite3_column_int64(statement, index))
      case SQLITE_FLOAT:
        value = .double(sqlite3_column_double(statement, index))
      case SQLITE_TEXT:
        if let textPointer = sqlite3_column_text(statement, index) {
          let length = Int(sqlite3_column_bytes(statement, index))
          let buffer = UnsafeBufferPointer(start: textPointer, count: length)
          value = .string(String(decoding: buffer, as: UTF8.self))
        } else {
          value = .null
        }
      case SQLITE_BLOB:
        if let blobPointer = sqlite3_column_blob(statement, index) {
          let length = Int(sqlite3_column_bytes(statement, index))
          value = .data(Data(bytes: blobPointer, count: length))
        } else {
          value = .data(Data())
        }
      case SQLITE_NULL:
        value = .null
      default:
        value = .null
      }

      row[columnName] = value
    }

    return row
  }

  private static func sqliteErrorMessage(code: Int32, database: OpaquePointer?) -> String {
    if let database {
      return String(cString: sqlite3_errmsg(database))
    }
    return String(cString: sqlite3_errstr(code))
  }

  private static func resolveDatabaseURL(for rawPath: String) throws -> URL {
    if rawPath == ":memory:" {
      return URL(fileURLWithPath: rawPath)
    }

    if rawPath.hasPrefix("/") {
      return URL(fileURLWithPath: rawPath)
    }

    let fileManager = FileManager.default
    let documentsURL: URL

    do {
      documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    } catch {
      throw NativeSQLiteError.databasePathResolutionFailed(message: error.localizedDescription)
    }

    let sqliteDirectory = documentsURL.appendingPathComponent("SQLite", isDirectory: true)
    let finalURL = sqliteDirectory.appendingPathComponent(rawPath)
    return finalURL
  }

  private static func ensureParentDirectoryExists(for url: URL) throws {
    let directoryURL = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
  }
}

extension NativeAppSchema {
  /// Executes the current bootstrap SQL in order.
  /// This keeps the schema contract close to the TypeScript implementation.
  static func bootstrap(using executor: NativeSQLiteExecuting) async throws {
    for statement in bootstrapStatements {
      try await executor.execute(statement, values: [])
    }

    for statement in bestEffortMigrationStatements {
      do {
        try await executor.execute(statement, values: [])
      } catch {
        continue
      }
    }
  }
}
