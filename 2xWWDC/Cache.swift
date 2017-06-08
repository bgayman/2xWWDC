//
//  Cache.swift
//  2xWWDC
//
//  Created by B Gay on 6/7/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

final class Cache
{
    var storage = FileStorage()
    
    func load<A>(_ resource: Resource<A>) -> A?
    {
        guard case .get = resource.method else { return nil }
        let data = storage[resource.cacheKey]
        return data.flatMap(resource.parse)
    }
    
    func save<A>(_ data: Data, for resource: Resource<A>)
    {
        guard case .get = resource.method else { return }
        storage[resource.cacheKey] = data
    }
}
