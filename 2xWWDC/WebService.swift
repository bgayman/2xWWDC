//
//  WebService.swift
//  2xWWDC
//
//  Created by B Gay on 6/1/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

typealias JSONDictionary = [String: Any]

enum WebServiceResponse<T>
{
    case error(Error)
    case success(T?)
}

enum HttpMethod<Body>
{
    case get
    case post(Body)
}

extension HttpMethod
{
    var method: String
    {
        switch self
        {
        case .get:
            return "GET"
        case .post:
            return "POST"
        }
    }
    
    func map<B>(f: (Body) -> B) -> HttpMethod<B>
    {
        switch self
        {
        case .get:
            return .get
        case .post(let body):
            return .post(f(body))
        }
    }
}

struct Resource<A>
{
    let url: URL
    let method: HttpMethod<Data>
    let parse: (Data) -> A?
}

extension Resource
{
    init(url: URL, httpMethod: HttpMethod<JSONDictionary> = .get, parseJSON: @escaping (Any) -> A?)
    {
        self.url = url
        self.method = httpMethod.map
        { json in
            let data : Data = Resource.query(json).data(using: .utf8, allowLossyConversion: false)!
            return data
        }
        self.parse =
        { data in
            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            return json.flatMap(parseJSON)
        }
    }
    
    var cacheKey: String
    {
        return "cache" + String(url.hashValue)
    }
    
    static private func queryComponents(fromKey key: String, value: Any) -> [(String, String)]
    {
        var components: [(String, String)] = []
        
        if let dictionary = value as? [String: Any]
        {
            for (nestedKey, value) in dictionary
            {
                components += queryComponents(fromKey: "\(key)[\(nestedKey)]", value: value)
            }
        }
        else if let array = value as? [Any]
        {
            for value in array
            {
                components += queryComponents(fromKey: "\(key)[]", value: value)
            }
        }
        else if let value = value as? NSNumber
        {
            components.append((escape(key), escape("\(value)")))
        }
        else if let bool = value as? Bool
        {
            components.append((escape(key), escape((bool ? "1" : "0"))))
        }
        else
        {
            components.append((escape(key), escape("\(value)")))
        }
        
        return components
    }
    
    
    static private func escape(_ string: String) -> String
    {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        
        var escaped = ""
        escaped = string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? string
        return escaped
    }
    
    static private func query(_ parameters: [String: Any]) -> String {
        var components: [(String, String)] = []
        
        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += queryComponents(fromKey: key, value: value)
        }
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
}

extension URLRequest
{
    init<A>(resource: Resource<A>)
    {
        self.init(url: resource.url)
        self.httpMethod = resource.method.method
        if case let .post(data) = resource.method
        {
            self.httpBody = data
        }
    }
}

final class Webservice
{
    static func load<A>(resource: Resource<A>, completion: @escaping (WebServiceResponse<A>) -> ())
    {
        var request = URLRequest(resource: resource)
        request.setValue("Bearer \(YelpToken.instance?.token ?? "")", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request)
        { (data, _, error) in
            if let error = error
            {
                completion(.error(error))
            }
            else
            {
                completion(.success(data.flatMap(resource.parse)))
            }
        }.resume()
    }
}


