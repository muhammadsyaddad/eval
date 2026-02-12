import Foundation
import CryptoKit

// MARK: - Security Service Protocol

/// Provides privacy and security utilities: FileVault detection, encryption,
/// and orchestrated data purge.
protocol SecurityServiceProtocol {
    /// Check whether FileVault (full-disk encryption) is enabled on the boot volume.
    func isFileVaultEnabled() -> Bool

    /// Encrypt data using AES-GCM with the provided key.
    func encrypt(data: Data, key: SymmetricKey) throws -> Data

    /// Decrypt AES-GCM encrypted data using the provided key.
    func decrypt(data: Data, key: SymmetricKey) throws -> Data

    /// Generate a new 256-bit symmetric key for app-level encryption.
    func generateEncryptionKey() -> SymmetricKey

    /// Delete all capture files from disk. Returns the number of bytes freed.
    func deleteAllCaptureFiles() throws -> UInt64
}

// MARK: - Security Error

enum SecurityError: LocalizedError {
    case encryptionFailed(String)
    case decryptionFailed(String)
    case fileVaultCheckFailed(String)
    case purgeIncomplete(String)
    case captureDirectoryNotAvailable

    var errorDescription: String? {
        switch self {
        case .encryptionFailed(let msg): return "Encryption failed: \(msg)"
        case .decryptionFailed(let msg): return "Decryption failed: \(msg)"
        case .fileVaultCheckFailed(let msg): return "FileVault check failed: \(msg)"
        case .purgeIncomplete(let msg): return "Data purge incomplete: \(msg)"
        case .captureDirectoryNotAvailable: return "Capture directory not available"
        }
    }
}

// MARK: - Security Service

final class SecurityService: SecurityServiceProtocol {

    private let fileManager = FileManager.default

    // MARK: - FileVault Detection

    /// Detects FileVault status by running `diskutil apfs list` and checking for encryption.
    /// Falls back to `fdesetup status` on non-APFS volumes.
    func isFileVaultEnabled() -> Bool {
        // Primary: use fdesetup status (most reliable, works on both APFS and CoreStorage)
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
        process.arguments = ["status"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // "FileVault is On." or "FileVault is Off."
            return output.lowercased().contains("filevault is on")
        } catch {
            // If we can't run the command, assume not enabled (safe default)
            return false
        }
    }

    // MARK: - AES-GCM Encryption

    func generateEncryptionKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw SecurityError.encryptionFailed("Failed to produce combined sealed box")
            }
            return combined
        } catch let error as SecurityError {
            throw error
        } catch {
            throw SecurityError.encryptionFailed(error.localizedDescription)
        }
    }

    func decrypt(data: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw SecurityError.decryptionFailed(error.localizedDescription)
        }
    }

    // MARK: - Capture File Purge

    /// Delete the entire Captures directory and all its contents.
    /// Returns the number of bytes freed.
    func deleteAllCaptureFiles() throws -> UInt64 {
        guard let capturesDir = CaptureStorageService.capturesDirectory else {
            throw SecurityError.captureDirectoryNotAvailable
        }

        guard fileManager.fileExists(atPath: capturesDir.path) else {
            return 0 // Nothing to delete
        }

        // Calculate size before deletion
        let bytesUsed = directorySize(at: capturesDir)

        // Remove the entire directory tree
        try fileManager.removeItem(at: capturesDir)

        // Recreate the empty directory for future use
        try fileManager.createDirectory(at: capturesDir, withIntermediateDirectories: true)

        return bytesUsed
    }

    // MARK: - Private

    private func directorySize(at url: URL) -> UInt64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }
}
