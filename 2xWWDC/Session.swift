//
//  Session.swift
//  2xWWDC
//
//  Created by B Gay on 6/1/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit

struct ImageCache
{
    static var cache = [URL: UIImage]()
}

struct Session
{
    let title: String
    let year: String
    let website: URL
    let videoURL: URL
    let session: String
    let description: String
    let imageLink: URL?
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
            if let data = try? Data(contentsOf: imageLink)
            {
                image = UIImage(data: data)?.scaleImage(scaleFactor: 0.05)
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

extension UIImage
{
    func scaleImage(scaleFactor: CGFloat) -> UIImage
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

