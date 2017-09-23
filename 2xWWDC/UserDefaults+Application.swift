//
//  UserDefaults+Application.swift
//  2xWWDC
//
//  Created by B Gay on 6/5/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

extension UserDefaults
{
    func hasSeen(_ session: Session) -> Bool
    {
        return self.bool(forKey: "\(session.year)\(session.session)")
    }
    
    func setHasSeen(_ session: Session, hasSeen: Bool = true)
    {
        self.set(hasSeen, forKey: "\(session.year)\(session.session)")
        NSUbiquitousKeyValueStore.default.set(true, forKey: "\(session.year)\(session.session)")
    }
    
    func progress(_ session: Session?) -> Double
    {
        guard let session = session else { return 0.0 }
        return self.double(forKey: "progress\(session.year)\(session.session)")
    }
    
    func setVideoProgress(_ session: Session?, progress: Double)
    {
        guard let session = session else { return }
        self.set(progress, forKey: "progress\(session.year)\(session.session)")
        NSUbiquitousKeyValueStore.default.set(progress, forKey: "progress\(session.year)\(session.session)")
    }
}
