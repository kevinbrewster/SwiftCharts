//
//  ViewController.swift
//  SwiftChartsiOS
//
//  Created by Kevin Brewster on 1/12/15.
//  Copyright (c) 2015 KevinBrewster. All rights reserved.
//

import UIKit

class AdvancedLineChartViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let lineChart = view.layer as? LineChart {

            let dataset1 = LineChart.Dataset(label: "Data 1", data: [65.0, 59.0, 80.0, 81.0, 56.0, 55.0, 40.0])
            dataset1.color = UIColor.redColor().CGColor
            dataset1.fillColor = nil
            dataset1.curve = .Bezier(0.3)
            
            let dataset2 = LineChart.Dataset(label: "Data 2", data: [28.0, 48.0, 40.0, 19.0, 86.0, 27.0, 90.0])
            dataset2.color = UIColor.blueColor().CGColor
            dataset2.defaultPoint.path = CGPath.Rect(CGRect(x: -5.0, y: -5.0, width: 10.0, height: 10.0)) // use squares as the points
            dataset2.curve = .Bezier(0.3)
            
            lineChart.legendEnabled = false
            lineChart.datasets = [ dataset1, dataset2 ]
        }
    }
}

