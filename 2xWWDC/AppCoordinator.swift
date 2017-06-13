//
//  AppCoordinator.swift
//  2xWWDC
//
//  Created by App Partner on 6/5/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit
import AVKit

final class AppCoordinator: MasterViewControllerActionDelegate
{
    let splitViewController: UISplitViewController
    
    init(splitViewController: UISplitViewController)
    {
        self.splitViewController = splitViewController
        start()
    }
    
    func start()
    {
        guard let navigationController = splitViewController.viewControllers.first as? UINavigationController, let masterViewController = navigationController.topViewController as? MasterViewController else { return }
        masterViewController.actionDelegate = self
    }
    
    func didSelection(session: Session, in masterViewController: MasterViewController)
    {
        let detail = DetailViewController.makeFromStoryboard()
        detail.session = session
        let nav = UINavigationController(rootViewController: detail)
        splitViewController.showDetailViewController(nav, sender: self)
    }
    
    func didForceTouch(session: Session, in masterViewController: MasterViewController) -> UIViewController?
    {
        let detail = DetailViewController.makeFromStoryboard()
        detail.session = session
        return detail
    }
    
    func didCommitPreview(context: UIViewControllerPreviewing, viewControllerToCommit: UIViewController, in masterViewController: MasterViewController)
    {
        let nav = UINavigationController(rootViewController: viewControllerToCommit)
        splitViewController.showDetailViewController(nav, sender: self)
    }
}

