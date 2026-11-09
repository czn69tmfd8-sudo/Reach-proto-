import Security
import XCTest

final class KeychainAccessTests: XCTestCase {
    func testHostCanPersistReadAndDeletePrivateCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "REACH-unit-test-\(UUID().uuidString)",
            kSecAttrAccount as String: "ephemeral-test-account"
        ]
        let expected = Data("local-test-value".utf8)
        var insert = query
        insert[kSecValueData as String] = expected
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(insert as CFDictionary, nil)
        XCTAssertEqual(added, errSecSuccess, "Test host needs a signed application identifier/keychain entitlement, status \(added)")
        guard added == errSecSuccess else { return }
        defer { SecItemDelete(query as CFDictionary) }
        var read = query
        read[kSecReturnData as String] = true
        var result: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(read as CFDictionary, &result), errSecSuccess)
        XCTAssertEqual(result as? Data, expected)
        XCTAssertEqual(SecItemDelete(query as CFDictionary), errSecSuccess)
        XCTAssertEqual(SecItemCopyMatching(read as CFDictionary, &result), errSecItemNotFound)
    }
}
