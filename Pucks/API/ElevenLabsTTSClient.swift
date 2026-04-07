import AVFoundation
import Foundation
import os

class ElevenLabsTTSClient {
    static let shared = ElevenLabsTTSClient()

    /// Uses direct ElevenLabs API if key is set, otherwise falls back to proxy.
    private var useDirectAPI: Bool {
        APIKeyConfig.elevenLabsKey != nil
    }

    private let proxyURL = "https://clicky-proxy.farza-0cb.workers.dev/tts"
    private let directBaseURL = "https://api.elevenlabs.io/v1/text-to-speech"
    private let defaultVoiceId = "21m00Tcm4TlvDq8ikWAM" // Rachel
    private let modelId = "eleven_flash_v2_5"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pucks", category: "ElevenLabsTTS")

    var audioPlayer: AVAudioPlayer?

    /// Speaks text aloud via ElevenLabs TTS.
    /// Returns audio data. Also plays it immediately.
    func speak(text: String) async throws -> Data {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Data()
        }

        let audioData: Data

        if useDirectAPI, let apiKey = APIKeyConfig.elevenLabsKey {
            audioData = try await callDirectAPI(text: text, apiKey: apiKey)
        } else {
            audioData = try await callProxy(text: text)
        }

        // Play the audio
        try await MainActor.run {
            do {
                audioPlayer = try AVAudioPlayer(data: audioData)
                audioPlayer?.play()
                logger.info("ElevenLabs TTS: playing \(audioData.count) bytes")
            } catch {
                logger.error("ElevenLabs TTS error: \(error.localizedDescription)")
                throw error
            }
        }

        // Wait for playback to finish
        while await MainActor.run(body: { audioPlayer?.isPlaying == true }) {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        return audioData
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Direct API

    private func callDirectAPI(text: String, apiKey: String) async throws -> Data {
        let url = URL(string: "\(directBaseURL)/\(defaultVoiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "text": text,
            "model_id": modelId,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 429 || httpResponse.statusCode == 402 {
            throw NSError(domain: "ElevenLabsTTS", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "I'm all out of credits. Please DM Farza and tell him to bring me back to life."])
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("ElevenLabs TTS error: HTTP \(httpResponse.statusCode) \(errorText)")
            throw NSError(domain: "ElevenLabsTTS", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "TTS failed: \(errorText)"])
        }

        return data
    }

    // MARK: - Proxy

    private func callProxy(text: String) async throws -> Data {
        var request = URLRequest(url: URL(string: proxyURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "text": text,
            "model_id": modelId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("ElevenLabs TTS proxy error: HTTP \(statusCode) \(errorText)")
            throw NSError(domain: "ElevenLabsTTS", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "TTS proxy failed: \(errorText)"])
        }

        return data
    }
}
