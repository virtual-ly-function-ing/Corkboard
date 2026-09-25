import Foundation
import Testing
@testable import corkboard_lib

@Suite("Argon2PasswordHasher")
struct Argon2PasswordHasherTests {

    @Test("A password verifies against its own hash")
    func hashThenVerifySucceeds() async throws {
        let hasher = NativeArgon2PasswordHasher()
        let hash = try await hasher.hash(password: "correct horse battery staple")
        #expect(try await hasher.verify(password: "correct horse battery staple", against: hash))
    }

    @Test("The wrong password fails verification")
    func wrongPasswordFailsVerification() async throws {
        let hasher = NativeArgon2PasswordHasher()
        let hash = try await hasher.hash(password: "correct horse battery staple")
        let result = try await hasher.verify(password: "wrong password", against: hash)
        #expect(result == false)
    }

    @Test("Hashing the same password twice produces different output because the salt is random")
    func hashingIsSalted() async throws {
        let hasher = NativeArgon2PasswordHasher()
        let hashA = try await hasher.hash(password: "same password")
        let hashB = try await hasher.hash(password: "same password")
        #expect(hashA != hashB)
    }

    @Test("Encoded hash uses the argon2id PHC prefix")
    func hashHasExpectedFormat() async throws {
        let hasher = NativeArgon2PasswordHasher()
        let hash = try await hasher.hash(password: "whatever")
        #expect(hash.hasPrefix("$argon2id$"))
    }

    @Test("Verifying against a malformed hash throws rather than crashing")
    func verifyAgainstMalformedHashThrows() async {
        let hasher = NativeArgon2PasswordHasher()
        await #expect(throws: Argon2Error.self) {
            _ = try await hasher.verify(password: "anything", against: "not-a-real-hash")
        }
    }

    @Test("Hashing still round-trips correctly with non-default, larger parameters")
    func hashRoundTripsWithLargerParameters() async throws {
        let hasher = NativeArgon2PasswordHasher(
            timeCost: 2, memoryCost: 19456, parallelism: 1, hashLength: 128)
        let hash = try await hasher.hash(password: "a reasonably long passphrase")
        #expect(try await hasher.verify(password: "a reasonably long passphrase", against: hash))
    }
    
}