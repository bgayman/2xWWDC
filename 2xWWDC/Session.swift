//
//  Session.swift
//  2xWWDC
//
//  Created by B Gay on 6/1/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit
import MobileCoreServices

struct ImageCache
{
    static var cache = [URL: UIImage]()
}

struct Session
{
    static let customTypeIdentifier = "com.bradgayman.wwdcSession"
    
    let title: String
    let year: String
    let website: URL
    let videoURL: URL
    let session: String
    let description: String
    let imageLink: URL?
    
    var dictionaryRep: [String: Any]
    {
        var dict = ["title": title,
                    "year": year,
                    "website": website.absoluteString,
                    "videoURL": videoURL.absoluteString,
                    "session": session,
                    "description": description]
        if let imageLink = imageLink
        {
            dict["imageLink"] = imageLink.absoluteString
        }
        return dict
    }
    
    var id: Int
    {
        return videoURL.absoluteString.hashValue
    }
}

extension Session
{
    init?(json: JSONDictionary, year: String)
    {
        guard let title = json["title"] as? String,
            var websiteString = json["website"] as? String,
            let videoURLString = json["videoURL"] as? String,
            let videoURL = URL(string: videoURLString),
            let description = json["description"] as? String,
            let session = json["session"] as? String else { return nil }
        websiteString = websiteString.contains("https") ? websiteString : "https://developer.apple.com\(websiteString)"
        guard let website = URL(string: websiteString) else { return nil }
        self.year = year
        self.videoURL = videoURL
        self.title = title
        self.description = description
        self.session = session
        self.website = website
        if let imageLinkString = json["imageLink"] as? String,
            let imageLink = URL(string: imageLinkString)
        {
            self.imageLink = imageLink
        }
        else
        {
            self.imageLink = nil
        }
    }
    
    func fetchImage(completion: @escaping (UIImage?) -> ())
    {
        guard let imageLink = self.imageLink else
        {
            completion(nil)
            return
        }
        if let image = ImageCache.cache[imageLink]
        {
            completion(image)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async
        {
            var image: UIImage? = nil
            if let data = FileStorage.shared["image\(imageLink.hashValue)"]
            {
                image = UIImage(data: data, scale: UIScreen.main.scale)
            }
            else if let data = try? Data(contentsOf: imageLink)
            {
                image = UIImage(data: data, scale: UIScreen.main.scale)?.scaleImage(scaleFactor: 0.08)
                if let img = image
                {
                    FileStorage.shared["image\(imageLink.hashValue)"] = UIImageJPEGRepresentation(img, 1.0)
                }
            }
            
            DispatchQueue.main.async
            {
                ImageCache.cache[imageLink] = image
                completion(image)
            }
        }
    }
}

extension Session: Comparable, Equatable, Hashable
{
    var hashValue: Int
    {
        return (year + session).hashValue
    }
    
    static func <(lhs: Session, rhs: Session) -> Bool
    {
        return lhs.session + lhs.year < rhs.session + lhs.year
    }
    
    static func ==(lhs: Session, rhs: Session) -> Bool
    {
        return lhs.session + lhs.year == rhs.session + rhs.year
    }
    
    func contains(substring: String) -> Bool
    {
        return title.lowercased().contains(substring.lowercased()) || description.lowercased().contains(substring.lowercased())
    }
}

final class SessionClass: NSObject
{
    let session: Session
    
    private override init()
    {
        fatalError()
    }
    
    init(session: Session)
    {
        self.session = session
        super.init()
    }
}

extension SessionClass: NSItemProviderWriting
{
    static var writableTypeIdentifiersForItemProvider: [String]
    {
        return [kUTTypeURL as String, kUTTypeUTF8PlainText as String, Session.customTypeIdentifier]
    }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress?
    {
        if typeIdentifier == kUTTypeURL as String
        {
            completionHandler(self.session.website.dataRepresentation, nil)
        }
        else if typeIdentifier == kUTTypeUTF8PlainText as String
        {
            let string = "\(self.session.title), \(self.session.year), \(self.session.session)"
            completionHandler(string.data(using: .utf8), nil)
        }
        else if typeIdentifier == Session.customTypeIdentifier
        {
            let dict = self.session.dictionaryRep
            let data = try? JSONSerialization.data(withJSONObject: dict, options: [])
            completionHandler(data, nil)
        }
        return nil
    }
    
    
}

extension SessionClass: NSItemProviderReading
{
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> SessionClass
    {
        return try SessionClass(itemProviderData: data, typeIdentifier: typeIdentifier)
    }
    
    static var readableTypeIdentifiersForItemProvider: [String]
    {
        return [Session.customTypeIdentifier]
    }
    
    @objc convenience init(itemProviderData data: Data, typeIdentifier: String) throws
    {
        let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
        let emptySession = Session(title: "", year: "", website: URL(string:"http://apple.com")!, videoURL: URL(string:"http://apple.com")!, session: "", description: "", imageLink: nil)
        let session = Session.init(json: dict, year: dict["year"] as? String ?? "2017")
        self.init(session: session ?? emptySession)
    }
    
    
}

extension UIImage
{
    @objc func scaleImage(scaleFactor: CGFloat) -> UIImage
    {
        let size = self.size.applying(CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        let hasAlpha = false
        let scale: CGFloat = 0.0
        
        UIGraphicsBeginImageContextWithOptions(size, !hasAlpha, scale)
        self.draw(in: CGRect(origin: .zero, size: size))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaledImage!
    }
}

