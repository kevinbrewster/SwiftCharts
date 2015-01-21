//
//  ViewController.swift
//  SensorTagMac
//
//  Created by Kevin Brewster on 1/12/15.
//  Copyright (c) 2015 KevinBrewster. All rights reserved.
//

import Cocoa

class SimpleLineChartViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let lineChart = view.layer as? LineChart {
            let data: [CGFloat] = [3.0, 4.0, 9.0, 11.0, 13.0, 15.0]
            lineChart.datasets += [ LineChart.Dataset(label: "My Data", data: data) ]
        }
    }
}

