//
//  UITableView+AnimatedUpdate.swift
//  2xWWDC
//
//  Created by B Gay on 6/6/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit

extension UITableView
{
    func animateUpdate<T: Hashable>(oldDataSource: [[T]], newDataSource: [[T]])
    {
        guard oldDataSource.count == newDataSource.count else
        {
            if oldDataSource.count == 0
            {
                self.beginUpdates()
                self.insertSections(IndexSet(Array(0 ..< newDataSource.count)), with: .top)
                self.endUpdates()
            }
            else if newDataSource.count == 0
            {
                self.beginUpdates()
                self.deleteSections(IndexSet(Array(0 ..< oldDataSource.count)), with: .automatic)
                self.endUpdates()
            }
            else
            {
                print("Can't perform complex section inserting deleting diffs")
                self.reloadData()
            }
            return
        }
        var removedIndexes = [IndexPath]()
        var insertedIndexes = [IndexPath]()
        var updatedIndexes = [IndexPath]()
        
        for i in 0 ..< oldDataSource.count
        {
            let oldArray = oldDataSource[i]
            let oldSet = Set(oldArray)
            let newArray = newDataSource[i]
            let newSet = Set(newArray)
            
            let removed = oldSet.subtracting(newSet)
            let inserted = newSet.subtracting(oldSet)
            let updated = newSet.intersection(oldSet)
            
            removedIndexes.append(contentsOf: removed.compactMap{ oldArray.firstIndex(of: $0) }.map{ IndexPath(row: $0, section: i) })
            insertedIndexes.append(contentsOf: inserted.compactMap{ newArray.firstIndex(of: $0) }.map{ IndexPath(row: $0, section: i) })
            updatedIndexes.append(contentsOf: updated.compactMap{ oldArray.firstIndex(of: $0) }.map{ IndexPath(row: $0, section: i) })
        }
        
        self.beginUpdates()
        self.reloadRows(at: updatedIndexes, with: .none)
        self.deleteRows(at: removedIndexes, with: .top)
        self.insertRows(at: insertedIndexes, with: .top)
        self.endUpdates()
    }
}
