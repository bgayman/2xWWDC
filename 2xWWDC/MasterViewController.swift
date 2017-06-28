//
//  MasterViewController.swift
//  2xWWDC
//
//  Created by B Gay on 6/1/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit

// MARK: - MasterViewControllerActionDelegate
protocol MasterViewControllerActionDelegate: class
{
    func didSelection(session: Session, in masterViewController: MasterViewController)
    func didForceTouch(session: Session, in masterViewController: MasterViewController) -> UIViewController?
    func didCommitPreview(context: UIViewControllerPreviewing, viewControllerToCommit: UIViewController, in masterViewController: MasterViewController)
}

final class MasterViewController: UITableViewController, StoryboardInitializable
{
    // MARK: - Types
    enum SearchState
    {
        case normal
        case searching
    }
    
    // MARK: - Computed Properties
    override var canBecomeFirstResponder: Bool
    {
        return true
    }
    
    override var keyCommands: [UIKeyCommand]?
    {
        let search = UIKeyCommand(input: "f", modifierFlags: .command, action: #selector(self.didPressFind), discoverabilityTitle: "Search")
        
        let done = UIKeyCommand(input: "d", modifierFlags: .command, action: #selector(self.didPressDone), discoverabilityTitle: "Done")
        
        let open1 = UIKeyCommand(input: "1", modifierFlags: .command, action: #selector(self.didPressOpen(keyCommand:)), discoverabilityTitle: "Open First Session")
        let open2 = UIKeyCommand(input: "2", modifierFlags: .command, action: #selector(self.didPressOpen(keyCommand:)), discoverabilityTitle: "Open Second Session")
        let open3 = UIKeyCommand(input: "3", modifierFlags: .command, action: #selector(self.didPressOpen(keyCommand:)), discoverabilityTitle: "Open Third Session")
        let open4 = UIKeyCommand(input: "4", modifierFlags: .command, action: #selector(self.didPressOpen(keyCommand:)), discoverabilityTitle: "Open Fourth Session")
        let open5 = UIKeyCommand(input: "5", modifierFlags: .command, action: #selector(self.didPressOpen(keyCommand:)), discoverabilityTitle: "Open Fifth Session")
        let open6 = UIKeyCommand(input: "6", modifierFlags: .command, action: #selector(self.didPressOpen(keyCommand:)), discoverabilityTitle: "Open Sixth Session")
        let open7 = UIKeyCommand(input: "7", modifierFlags: .command, action: #selector(self.didPressOpen(keyCommand:)), discoverabilityTitle: "Open Seventh Session")
        let open8 = UIKeyCommand(input: "8", modifierFlags: .command, action: #selector(self.didPressOpen(keyCommand:)), discoverabilityTitle: "Open Eighth Session")
        let open9 = UIKeyCommand(input: "9", modifierFlags: .command, action: #selector(self.didPressOpen(keyCommand:)), discoverabilityTitle: "Open Ninth Session")
        
        var commands = [search,
                        open1,
                        open2,
                        open3,
                        open4,
                        open5,
                        open6,
                        open7,
                        open8,
                        open9]
        
        if searchState == .searching
        {
            commands.append(done)
        }
        
        return commands
    }
    
    var searchState: SearchState
    {
        if searchController.isActive && !searchString.isEmpty
        {
            return .searching
        }
        return .normal
    }
    
    var searchResults: [Year]
    {
        guard searchState == .searching else { return [] }
        var searchYears = [Year]()
        for year in years
        {
            let filteredSessions = year.sessions.filter { $0.contains(substring: searchString) }
            let searchYear = Year(year: year.year, sessions: filteredSessions)
            guard !searchYear.sessions.isEmpty else { continue }
            searchYears.append(searchYear)
        }
        return searchYears
    }
    
    // MARK: - Properties
    var years = [Year]()
    {
        didSet
        {
            let oldYears = oldValue.map { $0.sessions }
            let newYears = years.map { $0.sessions }
            tableView.animateUpdate(oldDataSource: oldYears, newDataSource: newYears)
        }
    }
    
    weak var actionDelegate: MasterViewControllerActionDelegate?
    
    var searchString = ""
    
    // MARK: - Lazy Init
    lazy var searchController: UISearchController =
    {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.searchBar.barTintColor = UIColor(white: 0.95, alpha: 1.0)
        searchController.searchBar.tintColor = .black
        searchController.dimsBackgroundDuringPresentation = false
        return searchController
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad()
    {
        super.viewDidLoad()
        title = "Sessions"
        // Commented out for Xcode 8
//        if #available(iOS 11.0, *)
//        {
//            navigationController?.navigationBar.prefersLargeTitles = true
//            navigationItem.largeTitleDisplayMode = .always
//            navigationItem.searchController = searchController
//        }
//        else
//        {
            tableView.tableHeaderView = searchController.searchBar
//        }
        tableView.estimatedRowHeight = 50.0
        tableView.rowHeight = UITableViewAutomaticDimension
        definesPresentationContext = true
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(self.fetchSessions), for: .valueChanged)
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        setupNotifications()
        fetchSessions()
        
        if self.traitCollection.forceTouchCapability == .available
        {
            self.registerForPreviewing(with: self, sourceView: tableView)
        }
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notifications
    func setupNotifications()
    {
        NotificationCenter.default.addObserver(for: sessionDidFinishingWatching, object: nil, queue: nil)
        { [weak self] (payload) in
            guard let strongSelf = self else { return }
            strongSelf.tableView?.reloadData()
        }
        
        NotificationCenter.default.addObserver(for: sessionDidFinishingDownloading, object: nil, queue: .main)
        { [weak self] (payload) in
            for (index, year) in (self?.years.enumerated() ?? [Year]().enumerated())
            {
                guard let session = year.sessions.first(where: { $0.id  == payload.sessionID }),
                      let sessionIndex = year.sessions.index(of: session) else { continue }
                let indexPath = IndexPath(row: sessionIndex, section: index)
                if self?.view.window != nil
                {
                    self?.tableView.reloadRows(at: [indexPath], with: .automatic)
                }
                return
            }
        }
    }
    
    // MARK: - Networking
    func fetchSessions()
    {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        CachedWebservice.load(Year.all)
        { (response) in
            DispatchQueue.main.async
            {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.refreshControl?.endRefreshing()
                switch response
                {
                case .success(let returnYears):
                    if let returnYears = returnYears
                    {
                        self.years = returnYears
                    }
                case .error(let error):
                    print(error)
                }
            }
        }
    }
    
    // MARK: - Actions
    func didPressFind()
    {
        searchController.searchBar.becomeFirstResponder()
    }
    
    func didPressOpen(keyCommand: UIKeyCommand)
    {
        guard let index = Int(keyCommand.input) else { return }
        
        let session: Session?
        switch searchState
        {
        case .normal:
            session = years.first?.sessions[index]
        case .searching:
            session = searchResults.first?.sessions[index]
        }
        if let sess = session
        {
            actionDelegate?.didSelection(session: sess, in: self)
        }
    }
    
    func didPressDone()
    {
        searchController.isActive = false
    }
    
    // MARK: - UITableViewDataSource, UITableViewDelegate
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        switch searchState
        {
        case .normal:
            return years.count
        case .searching:
            return searchResults.count
        }
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        switch searchState
        {
        case .normal:
            return years[section].sessions.count
        case .searching:
            return searchResults[section].sessions.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        switch searchState
        {
        case .normal:
            return years[section].year
        case .searching:
            return searchResults[section].year
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let session: Session
        let cell = tableView.dequeueReusableCell(withIdentifier: "\(UITableViewCell.self)", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.lineBreakMode = .byWordWrapping
        
        switch searchState
        {
        case .normal:
            session = self.years[indexPath.section].sessions[indexPath.row]
            cell.textLabel?.text = session.title
            cell.detailTextLabel?.text = session.session

        case .searching:
            session = self.searchResults[indexPath.section].sessions[indexPath.row]
            let attribTitle = NSMutableAttributedString(string: session.title, attributes: [NSForegroundColorAttributeName: UIColor.black])
            let range = (session.title.lowercased() as NSString).range(of: searchString.lowercased())
            attribTitle.addAttributes([NSForegroundColorAttributeName: UIColor.orange], range: range)
            cell.textLabel?.attributedText = attribTitle
            
            if session.description.lowercased().contains(searchString.lowercased())
            {
                let range = (session.description.lowercased() as NSString).range(of: searchString.lowercased())
                let substring = "...\((session.description as NSString).substring(from: range.location))"
                let attribDescription = NSMutableAttributedString(string: substring, attributes: [NSForegroundColorAttributeName: UIColor.black])
                let newRange = (substring.lowercased() as NSString).range(of: searchString.lowercased())
                attribDescription.addAttributes([NSForegroundColorAttributeName: UIColor.orange], range: newRange)
                cell.detailTextLabel?.attributedText = attribDescription
            }
            else
            {
                cell.detailTextLabel?.text = session.session
            }
        }
        
        cell.accessoryType = UserDefaults.standard.hasSeen(session) ? .checkmark : .disclosureIndicator
        cell.imageView?.image = session.imageLink != nil ? ImageCache.cache[session.imageLink!] ?? #imageLiteral(resourceName: "white_background") : nil
        session.fetchImage
        { [weak self] (image) in
            guard let strongSelf = self else { return }
            switch strongSelf.searchState
            {
            case .normal:
                if cell === tableView.cellForRow(at: indexPath) || tableView.cellForRow(at: indexPath) == nil
                {
                    cell.imageView?.image = image
                }
            case .searching:
                cell.imageView?.image = image
            }
            
        }
        cell.layoutIfNeeded()
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        switch searchState
        {
        case .normal:
            let session = years[indexPath.section].sessions[indexPath.row]
            tableView.deselectRow(at: indexPath, animated: true)
            actionDelegate?.didSelection(session: session, in: self)
        case .searching:
            let session = searchResults[indexPath.section].sessions[indexPath.row]
            searchController.searchBar.resignFirstResponder()
            actionDelegate?.didSelection(session: session, in: self)
        }
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
    {
        let session = self.years[indexPath.section].sessions[indexPath.row]
        
        
        let mark = UITableViewRowAction(style: .normal, title: "Mark as Viewed")
        { (_, _) in
            UserDefaults.standard.setHasSeen(session)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
        
        let unmark = UITableViewRowAction(style: .normal, title: "Unmark as Viewed")
        { (_, _) in
            
            UserDefaults.standard.setHasSeen(session, hasSeen: false)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
        
        mark.backgroundColor = .black
        unmark.backgroundColor = .black
        return UserDefaults.standard.hasSeen(session)
               ? [unmark]
               : [mark]
    }
}

// MARK: - UIViewControllerPreviewingDelegate
extension MasterViewController: UIViewControllerPreviewingDelegate
{
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard let indexPath = tableView.indexPathForRow(at: location) else { return nil }
        let session: Session
        switch searchState
        {
        case .normal:
            session = years[indexPath.section].sessions[indexPath.row]
        case .searching:
            session = searchResults[indexPath.section].sessions[indexPath.row]
        }
        let vc = actionDelegate?.didForceTouch(session: session, in: self)
        return vc
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        actionDelegate?.didCommitPreview(context: previewingContext, viewControllerToCommit: viewControllerToCommit, in: self)
    }
}

// MARK: - UISearchResultsUpdating
extension MasterViewController: UISearchResultsUpdating
{
    func updateSearchResults(for searchController: UISearchController)
    {
        guard let text = searchController.searchBar.text else { return }
        searchString = text
        tableView.reloadData()
    }
}

