//
//  DownloadManager.swift
//  2xWWDC
//
//  Created by B Gay on 6/7/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

final class DownloadManager: NSObject, URLSessionDelegate, URLSessionDownloadDelegate
{
    static var shared = DownloadManager()
    
    typealias ProgressHandler = (Float) -> ()
    
    var onProgress: ProgressHandler?
    {
        didSet
        {
            if onProgress != nil
            {
                activate()
            }
        }
    }
    
    override private init()
    {
        super.init()
    }
    
    @discardableResult
    func activate() -> URLSession
    {
        let config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background")
        return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }
    
    private func calculateProgress(session: URLSession, completionHandler: @escaping (Float) -> ())
    {
        session.getTasksWithCompletionHandler
        { (tasks, uploads, downloads) in
            let progress: [Float] = downloads.map
            { (task) in
                if task.countOfBytesExpectedToReceive > 0
                {
                    return Float(task.countOfBytesReceived) / Float(task.countOfBytesExpectedToReceive)
                }
                else
                {
                    return 0.0
                }
            }
            completionHandler(progress.reduce(0.0, +))
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    {
        if totalBytesExpectedToWrite > 0
        {
            if let onProgress = onProgress
            {
                calculateProgress(session: session, completionHandler: onProgress)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
    {
        guard let url = downloadTask.originalRequest?.url else { return }
        let newURL = FileStorage().url(for: url)
        try? FileManager.default.moveItem(at: location, to: newURL)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        debugPrint("Task completed: \(task), error: \(String(describing: error))")
    }
}




