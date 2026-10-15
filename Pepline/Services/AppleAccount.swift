import AuthenticationServices
import Foundation
import Security
import UIKit

/// Optional Sign in with Apple. Its only job is to tie Pepline Pro to the
/// Apple ID (RevenueCat app user ID = Apple's opaque user identifier), so the
/// subscription follows the user to another iPhone. The journal never leaves
/// the device.
///
/// Because an account can be created, App Review 5.1.1(v) requires deleting
/// it from the app, which for Sign in with Apple means revoking the token:
/// done by the stateless function in server/ (it holds the private key that
/// the app must not ship).
@MainActor
final class AppleAccount: NSObject, ObservableObject {
    static let shared = AppleAccount()

    /// Token revocation endpoint (server/api/apple/revoke.ts on Vercel).
    static let revokeURL = URL(string: "https://pepline-api.vercel.app/api/apple/revoke")!

    @Published private(set) var userID: String?
    var isSignedIn: Bool { userID != nil }

    private static let keychainAccount = "appleUserID"
    private var reauthContinuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    private override init() {
        super.init()
        userID = Keychain.read(Self.keychainAccount)
    }

    /// Result of the SignInWithAppleButton.
    func handle(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            Keychain.write(credential.user, for: Self.keychainAccount)
            userID = credential.user
            await SubscriptionManager.shared.logIn(appUserID: credential.user)
            Analytics.track(.appleSignIn, ["result": "success"])
        case .failure(let error):
            let cancelled = (error as? ASAuthorizationError)?.code == .canceled
            Analytics.track(.appleSignIn, ["result": cancelled ? "cancelled" : "failed"])
        }
    }

    /// On launch: if the user revoked Pepline in Settings > Apple ID, sign out.
    func checkCredentialState() async {
        guard let userID else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
        if state == .revoked || state == .notFound {
            await signOutLocally()
        }
    }

    enum DeletionError: Error { case noCode, server(Int) }

    /// 5.1.1(v): re-authenticate for a fresh authorization code, have the
    /// server revoke it at Apple, then forget the account locally.
    func deleteAccount() async throws {
        let credential = try await reauthenticate()
        guard let codeData = credential.authorizationCode, let code = String(data: codeData, encoding: .utf8) else {
            throw DeletionError.noCode
        }
        var request = URLRequest(url: Self.revokeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["code": code])
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw DeletionError.server(status) }
        await signOutLocally()
    }

    private func signOutLocally() async {
        Keychain.delete(Self.keychainAccount)
        userID = nil
        await SubscriptionManager.shared.logOut()
    }

    private func reauthenticate() async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            reauthContinuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension AppleAccount: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        Task { @MainActor in
            if let credential {
                reauthContinuation?.resume(returning: credential)
            } else {
                reauthContinuation?.resume(throwing: DeletionError.noCode)
            }
            reauthContinuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            reauthContinuation?.resume(throwing: error)
            reauthContinuation = nil
        }
    }
}

extension AppleAccount: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

/// Minimal generic-password Keychain storage for the Apple user identifier.
enum Keychain {
    private static let service = "com.awdia.pepline"

    static func read(_ account: String) -> String? {
        var item: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account, kSecReturnData as String: true]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, for account: String) {
        delete(account)
        let item: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                   kSecAttrAccount as String: account, kSecValueData as String: Data(value.utf8),
                                   kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}
