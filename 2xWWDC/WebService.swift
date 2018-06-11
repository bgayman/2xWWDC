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
    init(url: URL, method: HttpMethod<Any> = .get, parseJSON: @escaping (Any) -> A?)
    {
        self.url = url
        self.method = method.map { json in
            try! JSONSerialization.data(withJSONObject: json, options: [])
        }
        self.parse = { data in
            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            return json.flatMap(parseJSON)
        }
    }
    
    var cacheKey: String
    {
        return "cache" + String(url.hashValue)
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
        let request = URLRequest(resource: resource)
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

final class CachedWebservice
{
    static let cache = Cache()
    
    static func load<A>(_ resource: Resource<A>, update: @escaping (WebServiceResponse<A>) -> ())
    {
        if let result = cache.load(resource)
        {
            update(.success(result))
        }
        let dataResource = Resource<Data>(url: resource.url, method: resource.method, parse: { $0 })
        Webservice.load(resource: dataResource)
        { (result) in
            switch result
            {
            case let .error(error):
                update(.error(error))
            case let .success(data):
                guard let data = data else
                {
                    update(.error("No Data" as! Error))
                    return
                }
                CachedWebservice.cache.save(data, for: resource)
                update(.success(resource.parse(data)))
            }
        }
    }
}


