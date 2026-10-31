/// AppAccess.swift is a local door lock, not a server login. iOS checks the face,
/// fingerprint or device passcode; our app never receives biometric measurements.
import Combine
import Foundation
import LocalAuthentication
import Security

/// One shared lock owns the app's access state. Views and account actions use the
/// same instance, preventing navigation or a background refresh from bypassing it.
@MainActor
final class AppAccess: ObservableObject {
  @Published private(set) var enabled = false
  @Published private(set) var locked = false
  @Published private(set) var authenticating = false
  @Published var error: String?
  private let service = (Bundle.main.bundleIdentifier ?? "Northstar") + ".app-lock"
  private var generation = 0
  var biometricName: String {
    let context = LAContext()
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    switch context.biometryType {
    case .faceID: return "Face ID"
    case .touchID: return "Touch ID"
    default: return "Biometrics"
    }
  }
  var biometricAvailable: Bool {
    LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
  }
  init(ignoresKeychainForTests: Bool = false, lockedForTests: Bool = false) {
    #if DEBUG
      if ignoresKeychainForTests || ProcessInfo.processInfo.arguments.contains("--ui-testing") {
        enabled = lockedForTests
        locked = lockedForTests
        return
      }
    #endif
    var query = base
    query[kSecReturnAttributes as String] = true
    query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
    var metadata: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &metadata)
    enabled = status != errSecItemNotFound
    locked = enabled
    if ![errSecSuccess, errSecItemNotFound, errSecInteractionNotAllowed].contains(status) {
      error = "The app lock could not be checked. Unlock your device and try again."
    }
  }
  /// Lock on background, not every inactive event: a biometric system sheet also
  /// makes a scene inactive and must not trigger an endless unlock loop.
  func lock() {
    generation += 1
    if enabled { locked = true }
  }
  func enable() async {
    guard !authenticating, biometricAvailable else {
      error = "Enroll Face ID or Touch ID in device Settings first."
      return
    }
    authenticating = true
    defer { authenticating = false }
    let context = LAContext()
    let attempt = generation
    do {
      guard
        try await context.evaluatePolicy(
          .deviceOwnerAuthentication,
          localizedReason: "Protect access to your Northstar paper account.")
      else { return }
      var accessError: Unmanaged<CFError>?
      guard
        let control = SecAccessControlCreateWithFlags(
          nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, &accessError)
      else { throw VaultError.failed }
      var bytes = [UInt8](repeating: 0, count: 32)
      guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
        throw VaultError.failed
      }
      var item = base
      item[kSecAttrAccessControl as String] = control
      item[kSecValueData as String] = Data(bytes)
      let status = SecItemAdd(item as CFDictionary, nil)
      guard status == errSecSuccess || status == errSecDuplicateItem else {
        throw VaultError.failed
      }
      enabled = true
      locked = generation != attempt
      error = nil
    } catch { self.error = "App lock was not enabled. Authenticate on your device and try again." }
  }
  func unlock() async {
    guard enabled, locked, !authenticating else { return }
    authenticating = true
    defer { authenticating = false }
    let attempt = generation
    let context = LAContext()
    do {
      guard
        try await context.evaluatePolicy(
          .deviceOwnerAuthentication,
          localizedReason: "Unlock Northstar to view your paper account.")
      else { return }
      var query = base
      query[kSecReturnData as String] = true
      query[kSecUseAuthenticationContext as String] = context
      query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
      var result: CFTypeRef?
      guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
        (result as? Data) != nil
      else { throw VaultError.failed }
      guard generation == attempt else { return }  // Backgrounding cancels the result's authority.
      locked = false
      error = nil
    } catch {
      self.error = "Unlock was not completed. Try biometrics or your device passcode again."
    }
  }
  /// Disabling protection always requires device-owner authentication.
  func disable() async {
    guard enabled, !locked, !authenticating else { return }
    authenticating = true
    defer { authenticating = false }
    let context = LAContext()
    let attempt = generation
    do {
      guard
        try await context.evaluatePolicy(
          .deviceOwnerAuthentication, localizedReason: "Turn off Northstar app lock.")
      else { return }
      guard generation == attempt, !locked else { return }
      let status = SecItemDelete(base as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultError.failed }
      enabled = false
      locked = false
      error = nil
    } catch { self.error = "App lock remains enabled." }
  }
  private var base: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: "device-owner-lock", kSecAttrSynchronizable as String: false,
    ]
  }
}
