//
//  BaseOperation.swift
//  2xWWDC
//
//  Created by B Gay on 6/20/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

class BaseOperation: Operation
{
    override var isAsynchronous: Bool
    {
        return true
    }
    
    private var _executing = false
    {
        willSet
        {
            willChangeValue(forKey: "isExecuting")
        }
        didSet
        {
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override var isExecuting: Bool
    {
        return _executing
    }
    
    private var _finished = false
    {
        willSet
        {
            willChangeValue(forKey: "isFinished")
        }
        
        didSet
        {
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isFinished: Bool
    {
        return _finished
    }
    
    override func start()
    {
        _executing = true
        execute()
    }
    
    @objc func execute()
    {
        fatalError("Did not override `execute()`")
    }
    
    @objc func finish()
    {
        _executing = false
        _finished = true
    }
}
