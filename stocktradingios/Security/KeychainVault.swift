/// KeychainVault.swift is the app's locked drawer. Unlike an ordinary JSON file,
/// Keychain items are encrypted and can be restricted to this unlocked device.
import Foundation
import NorthstarCore
import Security

/// This actor keeps OAuth credentials out of ordinary account files and backups.
actor KeychainVault: AccountStorage {
  private let service = (Bundle.main.bundleIdentifier ?? "Northstar") + ".identity"
  func read(_ key: String) throws -> Data? {
    var query = base(key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else { throw VaultError.failed }
    return data
  }
  /// Update in place; deleting before replacing could lose a rotated refresh token.
  func write(_ data: Data?, key: String) throws {
    let query = base(key)
    guard let data else {
      let status = SecItemDelete(query as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultError.failed }
      return
    }
    let status = SecItemUpdate(
      query as CFDictionary,
      [
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
      ] as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
      guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw VaultError.failed }
    } else if status != errSecSuccess {
      throw VaultError.failed
    }
  }
  private func base(_ key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: key, kSecAttrSynchronizable as String: false,
    ]
  }
}

/// The UI gets a safe explanation, never an OS diagnostic containing private data.
enum VaultError: LocalizedError {
  case failed
  var errorDescription: String? {
    "Secure device storage is unavailable. Unlock your device and try again."
  }
}
