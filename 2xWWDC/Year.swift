//
//  Year.swift
//  2xWWDC
//
//  Created by B Gay on 6/1/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

struct Year
{
    let year: String
    let sessions: [Session]
}

extension Year
{
    init?(json: JSONDictionary)
    {
        guard let year = json.keys.first,
            let sessionsJSON = json[year] as? [JSONDictionary] else { return nil }
        self.year = year
        self.sessions = sessionsJSON.flatMap { Session(json: $0, year: year) }.sorted()
    }
}

extension Year
{
    static let allSessionsURL = URL(string: "https://bradgayman.com/videos/all.json")!
    static let sessions2017URL = URL(string: "https://wwdcvideos-multivalued-undernsong.mybluemix.net/year/2017")!
    
    static let all = Resource<[Year]>(url: Year.allSessionsURL)
    { json in
        guard let dictionary = json as? JSONDictionary else { return nil }
        var years = [Year]()
        for (key, value) in dictionary
        {
            var dict = JSONDictionary()
            dict[key] = value
            if let year = Year(json: dict)
            {
                years.append(year)
            }
        }
        years = years.sorted { $0.year > $1.year }
        return years
    }
}
