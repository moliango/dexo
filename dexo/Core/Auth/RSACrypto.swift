import Foundation
import Security

enum RSACrypto {

    struct AuthPayload: Decodable {
        let key: String
        let nonce: String
    }

    static func decryptPayload(_ encodedPayload: String, with privateKey: SecKey) throws -> AuthPayload {
        // Discourse returns standard base64 with newlines.
        // Strip whitespace/newlines before decoding.
        let cleaned = encodedPayload
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard let encryptedData = Data(base64Encoded: cleaned) else {
            throw RSACryptoError.invalidBase64
        }

        // RSA 2048 can only encrypt up to 256 bytes at a time.
        // Discourse may chunk the encrypted data into 256-byte blocks.
        let blockSize = SecKeyGetBlockSize(privateKey)
        var decryptedData = Data()

        let chunks = stride(from: 0, to: encryptedData.count, by: blockSize).map {
            encryptedData[$0 ..< min($0 + blockSize, encryptedData.count)]
        }

        for chunk in chunks {
            var error: Unmanaged<CFError>?
            guard let decryptedChunk = SecKeyCreateDecryptedData(
                privateKey,
                .rsaEncryptionPKCS1,
                chunk as CFData,
                &error
            ) as Data? else {
                throw error!.takeRetainedValue() as Error
            }
            decryptedData.append(decryptedChunk)
        }

        return try JSONDecoder().decode(AuthPayload.self, from: decryptedData)
    }
}

enum RSACryptoError: Error, LocalizedError {
    case invalidBase64

    var errorDescription: String? {
        switch self {
        case .invalidBase64:
            return "Invalid base64url-encoded payload"
        }
    }
}
