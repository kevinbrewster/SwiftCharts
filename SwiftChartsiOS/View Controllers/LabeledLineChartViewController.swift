//
//  ViewController.swift
//  SwiftChartsiOS
//
//  Created by Kevin Brewster on 1/12/15.
//  Copyright (c) 2015 KevinBrewster. All rights reserved.
//

import UIKit

class LabeledLineChartViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        if let lineChart = view.layer as? LineChart {
            lineChart.xAxis.labels = ["January", "February", "March", "April", "June", "July", "August", "September", "October", "November", "December"]
            
            var data: [CGFloat] = [0.003, 0.004, 0.009, 0.011, 0.013, 0.015, 0.004, 0.003, 0.009, 0.0075, 0.0061]
            lineChart.datasets += [ LineChart.Dataset(label: "My Data", data: data) ]
            
        }
    }
}

