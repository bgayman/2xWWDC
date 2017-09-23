//
//  SessionResource.swift
//  2xWWDC
//
//  Created by B Gay on 6/2/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

struct SessionResource
{
    let title: String
    let link: URL
    
    var isRelativePath: Bool
    {
        return (link.scheme?.hasPrefix("http") ?? false) == false 
    }
}

extension SessionResource
{
    init?(json: JSONDictionary)
    {
        guard let title = json["title"] as? String,
              let linkString = json["href"] as? String,
              let link = URL(string: linkString) else { return nil }
        self.title = title
        self.link = link
    }
}

struct SessionResources
{
    let sessionResources: [SessionResource]
    let downloads: [SessionResource]
    let videos: [SessionResource]
    let documents: [SessionResource]
    let transcript: Transcript
}

extension SessionResource: Equatable, Hashable
{
    static func ==(lhs: SessionResource, rhs: SessionResource) -> Bool
    {
        return lhs.title == rhs.title && lhs.link == rhs.link
    }
    
    var hashValue: Int
    {
        return link.hashValue
    }
    
}

extension SessionResources
{
    init?(json: JSONDictionary)
    {
        guard let resourceDicts = json["resources"] as? [JSONDictionary],
              let transcriptArray = json["transcript"] as? [JSONDictionary],
              let downloadDicts = json["downloads"] as? [JSONDictionary],
              let documentDicts = json["documents"] as? [JSONDictionary],
              let videoDicts = json["videos"] as? [JSONDictionary] else { return nil }
        self.sessionResources = resourceDicts.flatMap(SessionResource.init)
        self.transcript = Transcript(json: transcriptArray)
        self.downloads = downloadDicts.flatMap(SessionResource.init)
        self.videos = videoDicts.flatMap(SessionResource.init)
        self.documents = documentDicts.flatMap(SessionResource.init)
    }
}

extension SessionResource
{
    private static let sessionResourceBaseURL = "https://wwdcvideos-multivalued-undernsong.mybluemix.net/session/"
    
    private static func sessionURL(for session: Session) -> URL?
    {
        guard let sessionString = session.website.absoluteString.addingPercentEncoding(withAllowedCharacters: CharacterSet.illegalCharacters) else { return nil }
        return URL(string: "\(SessionResource.sessionResourceBaseURL)\(sessionString)")
    }
    
    static func resource(for session: Session) -> Resource<SessionResources>?
    {
        guard let url = SessionResource.sessionURL(for: session) else { return nil }
        let webResource = Resource<SessionResources>(url: url)
        { json in
            guard let dictionary = json as? JSONDictionary else { return nil }
            return SessionResources(json: dictionary)
        }
        return webResource
    }
}
