/// AccountStorage.swift saves ordinary paper-account data, never OAuth secrets. Actors keep file work away from screen rendering.
import Foundation

public protocol AccountStorage: Sendable {
  func read(_ key: String) async throws -> Data?
  func write(_ data: Data?, key: String) async throws
}

/// File I/O lives on this actor, never in a SwiftUI body. Tokens/passwords are not persisted.
public actor FileAccountStorage: AccountStorage {
  private let directory: URL
  public init(directory: URL) { self.directory = directory }

  private func url(_ key: String) -> URL {
    let name = Data(key.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
    return directory.appendingPathComponent(name).appendingPathExtension("json")
  }
  public func read(_ key: String) throws -> Data? {
    let file = url(key)
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    return try Data(contentsOf: file)
  }
  public func write(_ data: Data?, key: String) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = url(key)
    if let data {
      #if os(iOS)
        try data.write(
          to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
      #else
        try data.write(to: file, options: .atomic)
      #endif
      var resource = URLResourceValues()
      resource.isExcludedFromBackup = true
      var destination = file
      try destination.setResourceValues(resource)
    } else if FileManager.default.fileExists(atPath: file.path) {
      try FileManager.default.removeItem(at: file)
    }
  }
}

public actor MemoryAccountStorage: AccountStorage {
  private var values: [String: Data] = [:]
  public init() {}
  public func read(_ key: String) -> Data? { values[key] }
  public func write(_ data: Data?, key: String) { values[key] = data }
}

public actor DemoAccount {
  private let storage: any AccountStorage
  public init(storage: any AccountStorage) { self.storage = storage }
  public func load() async throws -> TradingLedger {
    if let data = try await storage.read("offline-ledger-v1") {
      return try JSONDecoder().decode(TradingLedger.self, from: data)
    }
    try await save(.demo)
    return .demo
  }
  public func save(_ ledger: TradingLedger) async throws {
    try await storage.write(JSONEncoder().encode(ledger), key: "offline-ledger-v1")
  }
}
