//
//  ViewController.swift
//  SensorTagMac
//
//  Created by Kevin Brewster on 1/12/15.
//  Copyright (c) 2015 KevinBrewster. All rights reserved.
//

import Cocoa

class MultiAxisLineChartViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
                    
        if let lineChart = view.layer as? LineChart {
            var data1: [CGFloat] = [3.0, 4.0, 9.0, 11.0, 13.0, 15.0]
            lineChart.datasets += [ LineChart.Dataset(label: "One", data: data1) ]
            
            var axis2 = LineChart.Axis(alignment: .Right)
            var data2: [CGFloat] = [504040.0, 201050.0, 303001.0, 130049.0, 170021.0, 202003.0]
            lineChart.datasets += [ LineChart.Dataset(label: "Two", data: data2, yAxis: axis2) ]
            
            var axis3 = LineChart.Axis(alignment: .Right)
            var data3: [CGFloat] = [0.0021, 0.0056, 0.001, 0.003, 0.005, 0.002];
            lineChart.datasets += [ LineChart.Dataset(label: "Three", data: data3, yAxis: axis3) ]
        }
    }
}

