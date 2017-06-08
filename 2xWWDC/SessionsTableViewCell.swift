//
//  SessionsTableViewCell.swift
//  2xWWDC
//
//  Created by B Gay on 6/1/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit

final class SessionsTableViewCell: UITableViewCell
{
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var sessionImageView: UIImageView!
    
    var session: Session?
    {
        didSet
        {
            self.titleLabel.text = session?.title
            self.subtitleLabel.text = session?.session
        }
    }
    
    override func prepareForReuse()
    {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        sessionImageView.image = nil
    }
}
