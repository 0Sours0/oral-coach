import Foundation

struct NativeDeepSeekClientConfiguration: Equatable {
  var apiKey: String
  var baseURL: URL
  var model: String
  var timeoutInterval: TimeInterval

  init(
    apiKey: String,
    baseURL: URL = URL(string: "https://api.deepseek.com/v1/chat/completions")!,
    model: String = "deepseek-chat",
    timeoutInterval: TimeInterval = 60
  ) {
    self.apiKey = apiKey
    self.baseURL = baseURL
    self.model = model
    self.timeoutInterval = timeoutInterval
  }
}

enum NativeDeepSeekClientError: LocalizedError {
  case missingAPIKey
  case invalidHTTPResponse
  case httpError(statusCode: Int, body: String)
  case invalidPayload(String)
  case emptyResponse

  var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      return "DeepSeek API key is missing"
    case .invalidHTTPResponse:
      return "DeepSeek returned an invalid HTTP response"
    case .httpError(let statusCode, let body):
      return "DeepSeek HTTP \(statusCode): \(body)"
    case .invalidPayload(let reason):
      return "DeepSeek payload is invalid: \(reason)"
    case .emptyResponse:
      return "DeepSeek returned an empty response"
    }
  }
}

protocol NativeDeepSeekClientProtocol {
  func sendChat(
    messages: [NativePromptMessage],
    temperature: Double
  ) async throws -> NativeDeepSeekReply

  func sendJSON<T: Decodable>(
    _ type: T.Type,
    messages: [NativePromptMessage],
    temperature: Double
  ) async throws -> T

  func streamChat(
    messages: [NativePromptMessage],
    temperature: Double,
    onDelta: @escaping (_ delta: String, _ fullText: String) -> Void
  ) async throws -> String
}

final class NativeDeepSeekClient: NativeDeepSeekClientProtocol {
  private struct RequestBody: Encodable {
    let model: String
    let messages: [NativePromptMessage]
    let temperature: Double
    let stream: Bool?
    let responseFormat: ResponseFormat?
    let streamOptions: StreamOptions?

    enum CodingKeys: String, CodingKey {
      case model
      case messages
      case temperature
      case stream
      case responseFormat = "response_format"
      case streamOptions = "stream_options"
    }
  }

  private struct ResponseFormat: Encodable {
    let type: String
  }

  private struct StreamOptions: Encodable {
    let includeUsage: Bool
  }

  private struct ChatEnvelope: Decodable {
    struct Choice: Decodable {
      struct Message: Decodable {
        let content: String?
      }

      let message: Message?
    }

    let choices: [Choice]?
  }

  private struct StreamEnvelope: Decodable {
    struct Choice: Decodable {
      struct Delta: Decodable {
        let content: String?
      }

      let delta: Delta?
    }

    let choices: [Choice]?
  }

  private let configuration: NativeDeepSeekClientConfiguration
  private let session: URLSession

  init(
    configuration: NativeDeepSeekClientConfiguration,
    session: URLSession = .shared
  ) {
    self.configuration = configuration
    self.session = session
  }

  func sendChat(
    messages: [NativePromptMessage],
    temperature: Double = 0.7
  ) async throws -> NativeDeepSeekReply {
    try await sendJSON(
      NativeDeepSeekReply.self,
      messages: messages,
      temperature: temperature
    )
  }

  func sendJSON<T: Decodable>(
    _ type: T.Type,
    messages: [NativePromptMessage],
    temperature: Double = 0.2
  ) async throws -> T {
    let content = try await sendRawContent(
      messages: messages,
      temperature: temperature,
      responseFormat: ResponseFormat(type: "json_object"),
      stream: false
    )

    let payload = sanitizeJSONObjectString(content)
    guard let data = payload.data(using: .utf8) else {
      throw NativeDeepSeekClientError.invalidPayload("Unable to encode JSON string as UTF-8")
    }

    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw NativeDeepSeekClientError.invalidPayload(String(describing: error))
    }
  }

  func streamChat(
    messages: [NativePromptMessage],
    temperature: Double = 0.7,
    onDelta: @escaping (_ delta: String, _ fullText: String) -> Void
  ) async throws -> String {
    let request = try buildRequest(
      messages: messages,
      temperature: temperature,
      responseFormat: nil,
      stream: true,
      streamOptions: StreamOptions(includeUsage: true)
    )

    let (bytes, response) = try await session.bytes(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NativeDeepSeekClientError.invalidHTTPResponse
    }
    guard 200..<300 ~= httpResponse.statusCode else {
      throw NativeDeepSeekClientError.httpError(
        statusCode: httpResponse.statusCode,
        body: "HTTP \(httpResponse.statusCode)"
      )
    }

    var fullText = ""
    var eventLines: [String] = []

    func flushEventLines() throws {
      guard !eventLines.isEmpty else { return }
      let payloads = eventLines.compactMap { line -> String? in
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
      }

      eventLines.removeAll(keepingCapacity: true)

      for payload in payloads {
        if payload.isEmpty || payload == "[DONE]" {
          continue
        }

        guard let data = payload.data(using: .utf8) else {
          throw NativeDeepSeekClientError.invalidPayload("Unable to decode SSE payload")
        }

        let chunk: StreamEnvelope
        do {
          chunk = try JSONDecoder().decode(StreamEnvelope.self, from: data)
        } catch {
          throw NativeDeepSeekClientError.invalidPayload(String(describing: error))
        }

        let delta = chunk.choices?.first?.delta?.content ?? ""
        guard !delta.isEmpty else { continue }

        fullText += delta
        onDelta(delta, fullText)
      }
    }

    for try await line in bytes.lines {
      if line.isEmpty {
        try flushEventLines()
        continue
      }

      if line.hasPrefix(":") {
        continue
      }

      eventLines.append(line)
    }

    try flushEventLines()

    return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func sendRawContent(
    messages: [NativePromptMessage],
    temperature: Double,
    responseFormat: ResponseFormat?,
    stream: Bool,
    streamOptions: StreamOptions? = nil
  ) async throws -> String {
    let request = try buildRequest(
      messages: messages,
      temperature: temperature,
      responseFormat: responseFormat,
      stream: stream,
      streamOptions: streamOptions
    )

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NativeDeepSeekClientError.invalidHTTPResponse
    }
    guard 200..<300 ~= httpResponse.statusCode else {
      let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
      throw NativeDeepSeekClientError.httpError(statusCode: httpResponse.statusCode, body: body)
    }

    let envelope: ChatEnvelope
    do {
      envelope = try JSONDecoder().decode(ChatEnvelope.self, from: data)
    } catch {
      throw NativeDeepSeekClientError.invalidPayload(String(describing: error))
    }

    let content = envelope.choices?.first?.message?.content ?? ""
    guard !content.isEmpty else {
      throw NativeDeepSeekClientError.emptyResponse
    }
    return content
  }

  private func buildRequest(
    messages: [NativePromptMessage],
    temperature: Double,
    responseFormat: ResponseFormat?,
    stream: Bool,
    streamOptions: StreamOptions?
  ) throws -> URLRequest {
    guard !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw NativeDeepSeekClientError.missingAPIKey
    }

    var request = URLRequest(url: configuration.baseURL)
    request.httpMethod = "POST"
    request.timeoutInterval = configuration.timeoutInterval
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

    let body = RequestBody(
      model: configuration.model,
      messages: messages,
      temperature: temperature,
      stream: stream,
      responseFormat: responseFormat,
      streamOptions: streamOptions
    )

    do {
      request.httpBody = try JSONEncoder().encode(body)
    } catch {
      throw NativeDeepSeekClientError.invalidPayload(String(describing: error))
    }

    return request
  }

  private func sanitizeJSONObjectString(_ content: String) -> String {
    var result = content.trimmingCharacters(in: .whitespacesAndNewlines)

    if result.hasPrefix("```") {
      result = result.replacingOccurrences(of: "```json", with: "")
      result = result.replacingOccurrences(of: "```JSON", with: "")
      result = result.replacingOccurrences(of: "```", with: "")
      result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if let start = result.firstIndex(of: "{"), let end = result.lastIndex(of: "}") {
      result = String(result[start...end])
    }

    return result
  }
}
