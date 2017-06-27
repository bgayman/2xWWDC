//
//  PersistenceManager.swift
//  2xWWDC
//
//  Created by B Gay on 6/20/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation
import CoreData

struct PersistenceManager
{
    static var sharedContainer: NSPersistentContainer!
    
    static func save(context: NSManagedObjectContext) throws
    {
        var ctx: NSManagedObjectContext? = context
        while ctx != nil
        {
            try ctx?.save()
            ctx = ctx?.parent
        }
    }
}
