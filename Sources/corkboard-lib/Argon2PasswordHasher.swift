import Foundation
import argon2

enum Argon2Error: Error {
    case hashingFailed(code: Int32)
    case verificationFailed(code: Int32)
}

struct NativeArgon2PasswordHasher: PasswordHasher {
    private let timeCost: UInt32
    private let memoryCost: UInt32
    private let parallelism: UInt32
    private let hashLength: Int

    init(
        timeCost: UInt32 = 3, memoryCost: UInt32 = 65536, parallelism: UInt32 = 4,
        hashLength: Int = 32
    ) {
        self.timeCost = timeCost
        self.memoryCost = memoryCost
        self.parallelism = parallelism
        self.hashLength = hashLength
    }

    func hash(password: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try self.hashSync(password: password)
        }.value
    }

    func verify(password: String, against encoded: String) async throws -> Bool {
        try await Task.detached(priority: .userInitiated) {
            try self.verifySync(password: password, against: encoded)
        }.value
    }

    private func hashSync(password: String) throws -> String {
        let passwordBytes = Array(password.utf8)
        let salt = randomSalt()
        var encodedBuffer = [Int8](repeating: 0, count: 256)

        let result = argon2id_hash_encoded(
            timeCost, memoryCost, parallelism,
            passwordBytes, passwordBytes.count,
            salt, salt.count,
            hashLength, &encodedBuffer, encodedBuffer.count
        )

        guard result == ARGON2_OK.rawValue else {
            throw Argon2Error.hashingFailed(code: result)
        }
        let nullIndex = encodedBuffer.firstIndex(of: 0) ?? encodedBuffer.count
        let bytes = encodedBuffer[..<nullIndex].map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func verifySync(password: String, against encoded: String) throws -> Bool {
        let passwordBytes = Array(password.utf8)
        let result = argon2id_verify(encoded, passwordBytes, passwordBytes.count)

        if result == ARGON2_OK.rawValue { return true }
        if result == ARGON2_VERIFY_MISMATCH.rawValue { return false }
        throw Argon2Error.verificationFailed(code: result)
    }

    private func randomSalt(byteCount: Int = 16) -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        var bytes = [UInt8](repeating: 0, count: byteCount)
        for i in bytes.indices {
            bytes[i] = UInt8.random(in: 0...255, using: &generator)
        }
        return bytes
    }
}
