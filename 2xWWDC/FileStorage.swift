//
//  FileStorage.swift
//  2xWWDC
//
//  Created by B Gay on 6/7/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

struct FileStorage
{
    let baseURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    
    subscript(key: String) -> Data?
    {
        get
        {
            let url = baseURL.appendingPathComponent(key)
            return try? Data(contentsOf: url)
        }
        
        set
        {
            let url = baseURL.appendingPathComponent(key)
            _ = try? newValue?.write(to: url)
        }
    }
}
