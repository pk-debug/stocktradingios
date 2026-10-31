/// BrowserSignIn.swift opens the identity provider's trusted system browser sheet.
/// The provider owns password, SMS-code and social-account entry, not this app.
import AuthenticationServices
import CryptoKit
import Foundation
import NorthstarCore
import Security
import UIKit

/// Retain one browser session until it finishes. A second tap cannot start an
/// overlapping flow. An ephemeral browser avoids silently reusing someone else's login.
@MainActor
final class BrowserSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
  private var browser: ASWebAuthenticationSession?
  func signIn(
    configuration: IdentityConfiguration, connection: String?, signup: Bool,
    session: IdentitySession
  ) async throws -> String {
    guard browser == nil else { throw TradingFailure.busy }
    let verifier = try random()
    let state = try random()
    let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
    let attempt = AuthorizationAttempt(
      configuration: configuration, verifier: verifier, state: state)
    let url = try attempt.authorizationURL(
      challenge: challenge, connection: connection, signup: signup)
    let callback: URL = try await withCheckedThrowingContinuation { continuation in
      let browser = ASWebAuthenticationSession(
        url: url, callbackURLScheme: URL(string: configuration.redirectURI)?.scheme
      ) { [weak self] callback, error in
        Task { @MainActor in
          self?.browser = nil
          if let callback {
            continuation.resume(returning: callback)
          } else {
            if let cancellation = error as? ASWebAuthenticationSessionError, cancellation.code == .canceledLogin {
                  continuation.resume(throwing: CancellationError())
                } else {
                  continuation.resume(throwing: error ?? CancellationError())
                }
          }
        }
      }
      browser.presentationContextProvider = self
      browser.prefersEphemeralWebBrowserSession = true
      self.browser = browser
      if !browser.start() {
        self.browser = nil
        continuation.resume(
          throwing: TradingFailure.validation("The secure sign-in window could not open."))
      }
    }
    return try await session.exchange(code: attempt.code(from: callback), verifier: verifier)
  }
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
  }
  private func random() throws -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      throw VaultError.failed
    }
    return Data(bytes).base64URL
  }
}

extension Data {
  fileprivate var base64URL: String {
    base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(
      of: "/", with: "_"
    ).replacingOccurrences(of: "=", with: "")
  }
}
