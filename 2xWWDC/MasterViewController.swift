//
//  MasterViewController.swift
//  2xWWDC
//
//  Created by B Gay on 6/1/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit

protocol MasterViewControllerActionDelegate: class
{
    func didSelectionSession(masterViewController: MasterViewController, session: Session)
}

final class MasterViewController: UITableViewController, StoryboardInitializable
{
    enum SearchState
    {
        case normal
        case searching
    }
    
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
    
    lazy var searchController: UISearchController =
    {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.searchBar.barTintColor = UIColor(white: 0.95, alpha: 1.0)
        searchController.searchBar.tintColor = .black
        searchController.dimsBackgroundDuringPresentation = false
        return searchController
    }()
    
    var searchString = ""
    
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
    
    var searchState: SearchState
    {
        if searchController.isActive && !searchString.isEmpty
        {
            return .searching
        }
        return .normal
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        title = "Sessions"
        tableView.estimatedRowHeight = 50.0
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.tableHeaderView = searchController.searchBar
        definesPresentationContext = true
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(self.fetchSessions), for: .valueChanged)
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        fetchSessions()
    }
    
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
            actionDelegate?.didSelectionSession(masterViewController: self, session: session)
        case .searching:
            let session = searchResults[indexPath.section].sessions[indexPath.row]
            searchController.searchBar.resignFirstResponder()
            actionDelegate?.didSelectionSession(masterViewController: self, session: session)
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
        return UserDefaults.standard.hasSeen(session) ? [unmark] : [mark]
    }
}

extension MasterViewController: UISearchResultsUpdating
{
    func updateSearchResults(for searchController: UISearchController)
    {
        guard let text = searchController.searchBar.text else { return }
        searchString = text
        tableView.reloadData()
    }
}

