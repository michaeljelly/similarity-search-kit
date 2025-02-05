////
////  WebEmbeddings.swift
////
////
////  Created by Michael Jelly on 28/11/23.
////
//

import Foundation
import SimilaritySearchKit


//
//@available(macOS 11.0, iOS 15.0, *)
//public
class WebEmbeddings: EmbeddingsProtocol {
  var tokenizer: SimilaritySearchKit.NativeEmbeddings.TokenizerType

  var model: SimilaritySearchKit.NativeEmbeddings.ModelType

  typealias TokenizerType = NativeEmbeddings.TokenizerType

  typealias ModelType = NativeEmbeddings.ModelType

  let url: String

  public init(url: String) {
    // for convenience innited these things so I didn't have to change the Protocol code
    self.tokenizer = NativeTokenizer()
    self.model = NativeEmbeddings().model
    self.url = url
  }

  // MARK: - Dense Embeddings

  func encode(sentence: String) async -> [Float]? {
    let embeddings: [Float]? = try? await withCheckedContinuation { continuation in
      getEmbedding(url: url, options: ["texts": sentence]) { (result) in
        if let error = result["error"] as? Never {
          print("Error encoding:", error.localizedDescription)
          continuation.resume(throwing: error)
          return
        }
        //                        if (sentence != "Test sentence"){
        // assumes the web embeddings can embed multiple sentences and thus returns an array of embeddings
        let arrayOfEmbeddings = result["data"] as? NSArray
        // assuming you've embedded one sentence and just once that, so gets the first array
        let firstEmbedding = arrayOfEmbeddings?[0] as? NSArray
        let floatArray: [Float]? = (firstEmbedding)?.compactMap {
          // Try to convert each element to Float
          if let number = $0 as? NSNumber {
            return number.floatValue
          } else if let string = $0 as? String, let floatValue = Float(string) {
            return floatValue
          }
          return nil
        }
        print(floatArray?.count ?? "No count", result)

        //                            }
        continuation.resume(returning: floatArray)
        //                        continuation.success(embeddings)
      }

    }
    return embeddings
  }
}

func getEmbedding(
  url: String, options: [String: Any]?, completion: @escaping (([String: Any]) -> Void)
) {

  let headers = [
    "Content-Type": "application/json",
    "Authorization": "Bearer token",  // Replace with the appropriate value
  ]

  let model = options?["model"] as? String
  func generateOptionString(options: [String: Any]?) -> String {
    guard let options = options else { return "" }
    return options.map { (key, value) in
      "&\(key)=\("\(value ?? "")".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")"
    }.joined()
  }
  do {
    let baseURL = url
    let url = baseURL + generateOptionString(options: options)
    print(url)
    var request = URLRequest(url: URL(string: url)!)
    var requestBody: Data? = nil
    if let requestBody = requestBody,
      let data = try? JSONSerialization.data(withJSONObject: requestBody, options: [])
    {

      request.httpBody = data
      request.httpMethod = "POST"

    } else {
      print("No request body", requestBody)
      request.httpMethod = "GET"
    }

    request.allHTTPHeaderFields = headers

    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
      guard let data = data, error == nil else {
        print("Error: \(error?.localizedDescription ?? "Unknown error")")
        return
      }
      // parse the result as JSON, since that's what the API provides
      do {

        if let json = try JSONSerialization.jsonObject(with: data, options: [])
          as? [String: Any]
        {
          if json["data"] == nil { print(json) }

          completion(json)

        } else {
          print("Unable to parse JSON,  \(error?.localizedDescription ?? "Unknown error")")

        }
      } catch let error {
        let responseString = String(data: data, encoding: .utf8)
        print("Error parsing JSON: \(error)\nJSON:\n\(responseString)")
        print(
          "URLSession response: \(String(data: data, encoding: .utf8) ?? "Unable to decode response")"
        )

      }
    }
    task.resume()
  }

}
