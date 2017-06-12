//
//  HairlineView.swift
//  2xWWDC
//
//  Created by B Gay on 6/11/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit

final class HairlineView: UIView
{
    override func draw(_ rect: CGRect)
    {
        super.draw(rect)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        
        path.lineWidth = 1.0 / UIScreen.main.scale
        UIColor(white: 0.0, alpha: 0.75).setStroke()
        path.stroke()
    }
}
