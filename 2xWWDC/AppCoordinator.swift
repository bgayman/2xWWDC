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
    
    func didSelectionSession(masterViewController: MasterViewController, session: Session)
    {
        let detail = DetailViewController.makeFromStoryboard()
        detail.session = session
        let nav = UINavigationController(rootViewController: detail)
        splitViewController.showDetailViewController(nav, sender: self)
    }
}

