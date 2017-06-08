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
    
    func setHasSeen(_ session: Session)
    {
        self.set(true, forKey: "\(session.year)\(session.session)")
        NSUbiquitousKeyValueStore.default().set(true, forKey: "\(session.year)\(session.session)")
    }
}
