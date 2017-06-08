//
//  SessionTranscript.swift
//  2xWWDC
//
//  Created by B Gay on 6/2/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

struct Transcript
{
    let sentences: [Sentence]
}

extension Transcript
{
    init(json: [JSONDictionary])
    {
        self.sentences = json.flatMap(Sentence.init).sorted()
    }
}

struct Sentence
{
    let text: String
    let startTime: TimeInterval
}

extension Sentence
{
    init?(json: JSONDictionary)
    {
        guard let text = json["text"] as? String,
              let startTimeString = json["startTime"] as? String,
              let startTime = TimeInterval(startTimeString) else { return nil }
        self.text = text
        self.startTime = startTime
    }
}

extension Sentence: Equatable, Comparable, Hashable
{
    static func ==(lhs: Sentence, rhs: Sentence) -> Bool
    {
        return lhs.text == rhs.text && lhs.startTime == rhs.startTime
    }
    
    static func <(lhs: Sentence, rhs: Sentence) -> Bool
    {
        return lhs.startTime < rhs.startTime
    }
    
    var hashValue: Int
    {
        return "\(text)\(startTime)".hashValue
    }
}
