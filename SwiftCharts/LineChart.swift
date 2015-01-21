///
//  LineChart.swift
//  SensorTag
//
//  Created by Kevin Brewster on 1/7/15.
//  Copyright (c) 2015 KevinBrewster. All rights reserved.
//



import QuartzCore
#if os(iOS)
    
    // Mark:
    @objc protocol LineChartTooltip  {
        var point: LineChart.Point? { get set }
    }

    
    import UIKit
    
    class LineChartView: UIView {
        override class func layerClass() -> AnyClass { return LineChart.self }
        var lineChart: LineChart { return layer as LineChart }
        var popoverController: UIPopoverController?
        var popoverPoint: LineChart.Point?
        
        
        required init(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            popoverController = UIPopoverController(contentViewController: SimpleLineChartTooltop(nibName: nil, bundle: nil))

            lineChart.contentsScale = UIScreen.mainScreen().scale
        }
        
        override func layoutSubviews() {
            println("layoutSubviews")
            lineChart.frame = self.bounds
        }
        override func awakeFromNib() {
            println("Awake from nib")
            addGestureRecognizer( UIPanGestureRecognizer(target: self, action: Selector("pan:")) )
        }
        func pan(recognizer: UIPanGestureRecognizer) {
            if popoverController != nil {
                if recognizer.state == UIGestureRecognizerState.Began {
                    popoverController!.passthroughViews = [self] // add this view as a passthroughViews so pan gesture will continue working while popover is displayed
            
                } else if recognizer.state == UIGestureRecognizerState.Changed {
                    var touchLocation = lineChart.convertPoint(recognizer.locationInView(self), toLayer: lineChart.datasets.first)
                    if let point = lineChart.closestPointTo(touchLocation) {
                        if popoverPoint == nil || popoverPoint! != point {
                            if popoverPoint != nil {
                                popoverPoint!.highlighted = false // un-highlight the previously highlighted point
                            }
                            popoverPoint = point
                            if popoverController!.popoverVisible {
                                popoverController!.dismissPopoverAnimated(false)
                            }
                            if let vc = popoverController!.contentViewController as? LineChartTooltip {
                                // set the point of the popover contentViewController so it can update it's view
                                vc.point = point
                            }
                            point.highlighted = true
                            let rect = CGRect(origin: lineChart.convertPoint(point.position, fromLayer: lineChart.datasets.first), size: CGSize(width: 1.0, height: 1.0))
                            popoverController!.presentPopoverFromRect(rect, inView: self, permittedArrowDirections: UIPopoverArrowDirection.Any, animated: false)
                        }
                    }
                } else if recognizer.state == UIGestureRecognizerState.Ended {
                    popoverController!.passthroughViews = []
                    if popoverController!.popoverVisible {
                        popoverPoint!.highlighted = false // un-highlight the previously highlighted point
                        popoverController!.dismissPopoverAnimated(true)
                    }
                }
            }
        }
    }
    class SimpleLineChartTooltop : UIViewController, LineChartTooltip {
        // a very simple tooltip view controller to be presented by popover controller
        let lineLabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 20.0))
        let valueLabel = UILabel(frame: CGRect(x: 0.0, y: 20.0, width: 100.0, height: 20.0))
        var point: LineChart.Point? {
            didSet {
                valueLabel.text = point == nil ? "" : point!.value.description
                lineLabel.text = point == nil || point!.dataset == nil ? "" : point!.dataset!.label
            }
        }
        override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
            super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
            view.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 45.0)
            preferredContentSize = view.frame.size
            lineLabel.textAlignment = NSTextAlignment.Center
            view.addSubview(lineLabel)
            valueLabel.textAlignment = NSTextAlignment.Center
            view.addSubview(valueLabel)
        }
        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
#else
    import AppKit
    
    class LineChartView: NSView {
        // A simple NSView which "hosts" a LineChart as it's layer 
        // It does a couple nice things on top of the core LineChart functionality:
        //   1) Auto-resizes the LineChart layer when view is resized
        //   2) Tracks mouse movement and displays a tooltip at the closest point
        
        let popover = NSPopover()
        var popoverPoint: LineChart.Point?
        var lineChart: LineChart { return layer as LineChart }
        var trackingArea: NSTrackingArea!
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.layer = LineChart() as LineChart
            self.layer!.autoresizingMask = CAAutoresizingMask.LayerWidthSizable | CAAutoresizingMask.LayerHeightSizable
            self.layer!.needsDisplayOnBoundsChange = true
            self.wantsLayer = true
            
            popover.contentViewController = SimpleLineChartTooltop(nibName: nil, bundle: nil)
            updateTrackingAreas()
        }
        func layoutSubviews() {
            lineChart.frame = self.bounds
        }
        override func viewDidChangeBackingProperties() {
            println("viewDidChangeBackingProperties, new scale = \(window!.backingScaleFactor)")
            lineChart.contentsScale = window!.backingScaleFactor
        }
        
        // Mark: Mouse Tracking
        override func updateTrackingAreas() {
            if trackingArea != nil {
                removeTrackingArea(trackingArea)
            }
            // only track the mouse inside the actual graph, not when over the axis labels or legend e.g.
            let trackingRect = CGRect(x: lineChart.graphInsets.left, y: lineChart.graphInsets.bottom, width: bounds.width - lineChart.graphInsets.left - lineChart.graphInsets.right, height: bounds.height - lineChart.graphInsets.bottom - lineChart.graphInsets.top)
            trackingArea = NSTrackingArea(rect: trackingRect, options: NSTrackingAreaOptions.ActiveAlways | NSTrackingAreaOptions.MouseEnteredAndExited | NSTrackingAreaOptions.MouseMoved, owner: self, userInfo: nil)
            addTrackingArea(trackingArea)
        }
        override func mouseEntered(theEvent: NSEvent) {
            //println("mouseEntered")
        }
        override func mouseExited(theEvent: NSEvent) {
            if popoverPoint != nil {
                popoverPoint!.highlighted = false // un-highlight the previously highlighted point
                popoverPoint = nil
            }
            if popover.shown {
                popover.close()
            }
        }
        override func mouseMoved(theEvent: NSEvent) {
            //var mouseLocation = convertPoint(theEvent.locationInWindow, fromView: nil)
            var mouseLocation = lineChart.convertPoint(theEvent.locationInWindow, toLayer: lineChart.datasets.first)
            
            if let point = lineChart.closestPointTo(mouseLocation) {
                if popoverPoint == nil || popoverPoint! != point {
                    if popoverPoint != nil {
                        popoverPoint!.highlighted = false // un-highlight the previously highlighted point
                    }
                    popoverPoint = point

                    popover.contentViewController!.representedObject = point
                    point.highlighted = true
                    popover.contentSize = NSSize(width: 100.0, height: 45.0)
                    
                    let rect = CGRect(origin: lineChart.convertPoint(point.position, fromLayer: lineChart.datasets.first), size: CGSize(width: 1.0, height: 1.0))
                    popover.showRelativeToRect(rect, ofView: self, preferredEdge: NSMaxYEdge)
                    popover.contentViewController!.view.window!.ignoresMouseEvents = true // to prevent mouseExited from triggering when mouse over popover
                }
            }
            
        }
    }
    
    class SimpleLineChartTooltop : NSViewController {
        // a very simple tooltip view controller to be presented by popover controller
        let lineLabel = NSTextField(frame: CGRect(x: 0.0, y: 20.0, width: 100.0, height: 20.0))
        let valueLabel = NSTextField(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 20.0))
        /*var point: LineChart.Point? {
            didSet {
                valueLabel.stringValue = point == nil ? "" : point!.value.shortFormatted
                lineLabel.stringValue = point == nil || point!.line == nil ? "" : point!.line!.label
            }
        }*/
        override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
            super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
            self.view = NSView(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 45.0))
            
            for label in [lineLabel, valueLabel] {
                label.editable = false
                label.selectable = false
                label.bordered = false
                label.alignment = NSTextAlignment.CenterTextAlignment
                label.backgroundColor = NSColor.clearColor()
                view.addSubview(label)
            }
        }
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        override var representedObject: AnyObject? {
            didSet {
                if let point = representedObject as? LineChart.Point {
                    valueLabel.stringValue = "\(point.value)"
                    lineLabel.stringValue = point.dataset!.label
                }
            }
        }
    }
    
#endif







class LineChart: CALayer {
    let defaultColors = [0x1f77b4, 0xff7f0e, 0x2ca02c, 0xd62728, 0x9467bd, 0x8c564b, 0xe377c2, 0x7f7f7f, 0xbcbd22, 0x17becf].map { CGColorCreateFromHex($0) }
    
    var datasets: [Dataset] = [Dataset]() {
        didSet {
            for dataset in oldValue {
                dataset.removeFromSuperlayer()
                dataset.legendElement.removeFromSuperlayer()
            }
            for dataset in datasets {
                if dataset.xAxis == nil {
                    dataset.xAxis = xAxis
                }
                if dataset.yAxis == nil {
                    dataset.yAxis = self.yAxes.first!
                }
                if !contains(yAxes, dataset.yAxis) {
                    yAxes += [dataset.yAxis]
                }
                if dataset.strokeColor == nil {
                    let colorIndex = (datasets.count - 1) % 5
                    dataset.color = defaultColors[colorIndex]
                }
                dataset.delegate = self
                addSublayer(dataset)
                legend.addSublayer(dataset.legendElement)
            }
            updateXAxis()
            updateLegend()
        }
    }
    
    
    private(set) var xAxis: Axis = Axis(alignment: .Right, transform: CATransform3DMakeRotation(CGFloat(M_PI) / -2.0, 0.0, 0.0, 1.0))
    var yAxes: [Axis] = [Axis(alignment: .Left)] {
        didSet {
            for axis in oldValue {
                axis.removeFromSuperlayer()
            }
            for axis in yAxes {
                axis.delegate = self
                addSublayer(axis)
            }
        }
    }
    var graphInsets: (left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) = (0.0, 0.0, 0.0, 0.0) {
        didSet {
            //println("Graph insets did set")
        }
    }
    
    var title: CATextLayer = CATextLayer(autoScale: true)
    var legend = CALayer()
    
    var legendEnabled: Bool = false {
        didSet {
            if legendEnabled {
                graphInsets.top = 60.0 // todo: calculate this value
                addSublayer(legend)
            } else {
                graphInsets.top = 10.0
                legend.removeFromSuperlayer()
            }
        }
    }
    
    var animationDurations =  CATransaction.animationDuration() // can't call it "animationDuration" or swift compile error - no idea why
    var animationTimingFunction = CATransaction.animationTimingFunction()
    
    /*override init!(layer: AnyObject!) {
        super.init(layer: layer)
    }*/
    override init() {
        super.init()
        postInit()
    }
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        postInit()
    }
    override init!(layer: AnyObject!) {
        super.init(layer: layer)
    }
    func postInit() {
        geometryFlipped = true
        delegate = self
        legend.delegate = self
        
        xAxis.delegate = self
        addSublayer(xAxis)
        
        yAxes.first!.delegate = self
        addSublayer(yAxes.first!)
        legendEnabled = true
    }
    func updateXAxis() {
        // X-Axis
        let minXTickValue: CGFloat = 0.0 // x-axis always starts at zero
        let maxXTickValue = CGFloat( datasets.reduce(0, {$0 > $1.data.count ? $0 : $1.data.count }) - 1 )
        xAxis.range = (minXTickValue, maxXTickValue, interval: 1.0)
        xAxis.size = CGSize(width: 40.0, height: 0.0)
        graphInsets.bottom = xAxis.size.width
    }
    func updateLegend() {
        //legend.sublayers = nil
        var lastLegendElementOrigin = CGPointZero
        for dataset in datasets {
            //legend.addSublayer(legendEl)
            dataset.legendElement.frame = CGRect(origin: lastLegendElementOrigin, size:dataset.legendElement.frame.size)
            lastLegendElementOrigin = CGPoint(x: lastLegendElementOrigin.x + dataset.legendElement.frame.width + 20.0, y: 0.0)
        }
        legend.bounds = CGRect(origin: CGPointZero, size: CGSize(width: lastLegendElementOrigin.x, height: 20.0))
    }
    override func layoutSublayers() {
        if datasets.count == 0 {
            return
        }

        // 1) Estimate Y-axis widths so we know graph width
        var estimatedYAxisWidths = 50.0 * CGFloat(yAxes.count)
        
        // 2) Knowing graph width, figure out X-axis height
        let maxTickLabelWidth: CGFloat = xAxis.ticks.reduce(0.0, { max($0, $1.labelLayer.bounds.width) })
        let tickIntervalWidth = (bounds.width - estimatedYAxisWidths) / CGFloat(xAxis.ticks.count)
        if maxTickLabelWidth > tickIntervalWidth {
            // we need to rotate x-axis tick labels so they are not overlapping
            xAxis.labelRotation = -acos(tickIntervalWidth * 0.9 / maxTickLabelWidth)
        } else {
            xAxis.labelRotation = 0.0
        }
        let maxTickLabelHeight: CGFloat = xAxis.ticks.reduce(0.0, { max($0, $1.labelLayer.frame.width) })
        xAxis.size = CGSize(width: 12.0 + maxTickLabelHeight + 16.0, height: 0.0)
        graphInsets.bottom = xAxis.size.width
        graphInsets.right = (xAxis.ticks.last!.labelLayer.frame.height / 2.0) + 8.0 // half the label will stick out a bit on the right, so leave a little room
        
        
        // 3) Knowing x-axis height and title, we know graph height and can figure out a "nice" amount of y-axis ticks
        graphInsets.left = 0.0
        
        for yAxis in yAxes {
            let datasetsForAxis = datasets.filter { $0.yAxis == yAxis }
            
            // figure out how many Y-Axis tick marks look best and at what interval
            let minYValue = datasetsForAxis.reduce(CGFloat.max, { min($0, minElement($1.data)) })
            let maxYValue = datasetsForAxis.reduce(CGFloat.min, { max($0, maxElement($1.data)) })
            let yTickInterval = yAxis.optimalInterval(minYValue, max: maxYValue)
            
            var minYTickValue = minYValue - (yTickInterval / 4.0) // we want the bottom of graph to be at least quarter-step below minY
            minYTickValue = floor(minYTickValue / yTickInterval) * yTickInterval
            if minYValue > 0.0 && minYTickValue < 0.0 {
                minYTickValue = 0.0 // silly to show negative numbers when all numbers are positive
            }
            
            var maxYTickValue = maxYValue + (yTickInterval / 4.0) // we want the bottom of graph to be at least quarter-step below minY
            maxYTickValue = ceil(maxYTickValue / yTickInterval) * yTickInterval
            yAxis.range = (minYTickValue, maxYTickValue, yTickInterval)
            
            let maxTickWidth: CGFloat = yAxis.ticks.reduce(0.0, { max($0, $1.width) })
            let axisWidth = maxTickWidth + 16.0
            yAxis.size = CGSize(width: axisWidth, height: bounds.height - graphInsets.top - graphInsets.bottom)
            
            if yAxis.alignment == .Left {
                graphInsets.left += yAxis.size.width
            } else {
                graphInsets.right += yAxis.size.width
                yAxis.position = CGPoint(x: bounds.width - graphInsets.left - graphInsets.right, y: 0.0)
            }
        }
        yAxes.first!.showGrid(bounds.width - graphInsets.left - graphInsets.right)
        
        
        // 4) Knowing the exact y-axes widths, we can layout the x-axis
        xAxis.size = CGSize(width: xAxis.bounds.height, height: bounds.width - graphInsets.left - graphInsets.right)
        xAxis.layoutSublayers()
        //xAxis.gridWidth = bounds.height - graphInsets.top - graphInsets.bottom
        //xAxis.showGrid(bounds.height - graphInsets.top - graphInsets.bottom)
        
        
        // 5) Configure layer so coordinate system starts in lower left with (0,0) pixel point at origin of graph
        sublayerTransform = CATransform3DMakeAffineTransform(CGAffineTransformMakeTranslation(graphInsets.left, graphInsets.bottom))
        
        // 6) Update legend position
        legend.position = CGPoint(x: self.bounds.width - graphInsets.left - legend.bounds.width, y: self.bounds.height - graphInsets.bottom - 40.0)
        
        // 7) Refresh the individual datasets
        for dataset in datasets {
            dataset.layoutSublayers()
        }
    }
    
    // Provide smooth animation for both path and position
    override func actionForLayer(layer: CALayer!, forKey event: String!) -> CAAction! {
        if event == "path" || event == "position" {
            let animation = CABasicAnimation(keyPath: event)
            animation.duration = animationDurations
            animation.timingFunction = animationTimingFunction
            return animation
        }
        return nil
    }
    #if os(OSX)
    override func layer(layer: CALayer, shouldInheritContentsScale newScale: CGFloat, fromWindow window: NSWindow) -> Bool {
        return true
    }
    #endif
}





// Mark: Other Classes

extension LineChart {
    enum Alignment { case Left, Right}
    
    class Axis : CALayer {
        var label: String?
        var ticks: [Tick] = [Tick]()
        var size: CGSize!
        var gridWidth: CGFloat?
        var alignment: Alignment
        var axisLine = CAShapeLayer()
        var labels: [String]?
        var labelRotation: CGFloat = 0.0 {
            didSet {
                var correctedRotation = labelRotation
                if let axisRotation = valueForKeyPath("transform.rotation.z") as? CGFloat {
                    // if the axis has been rotated, we need to rotate the text so it's right-side up
                    correctedRotation -= axisRotation
                }
                for tick in ticks {
                    var transform = CATransform3DIdentity
                    tick.labelLayer.transform = CATransform3DRotate(transform, correctedRotation, 0.0, 0.0, 1.0)
                    tick.updateLabelPosition()
                }
            }
        }
        
        var range: (min: CGFloat, max: CGFloat, interval: CGFloat?)! {
            didSet {
                if range.interval == nil {
                    range.interval = 1.0
                }
                for tick in ticks {
                    tick.removeFromSuperlayer()
                }
                let extra = range.interval! / 2.0 // // the "extra" craziness is to make sure the final condition evaluates as true if float values are very, very close but not equal (i.e. sometimes 1.0 != 1.0)
                var newTicks = [Tick]()
                var index = 0
                for var value = range.min; value <= range.max + extra; value += range.interval!, index++ {
                    let tick = index < ticks.count ? ticks[index] : Tick(value: value, alignment: alignment, major: true)
                    tick.delegate = delegate
                    tick.value = value
                    
                    if labels != nil && index < labels!.count {
                        tick.label = labels![index]
                    }                    
                    
                    addSublayer(tick)
                    newTicks += [tick]
                    
                   
                }
                ticks = newTicks
            }
        }
        override weak var delegate: AnyObject! {
            didSet { axisLine.delegate = delegate }
        }
        
        init(alignment: Alignment = .Left, transform: CATransform3D = CATransform3DIdentity) {
            self.alignment = alignment
            super.init()
            self.transform = transform
            
            
            axisLine.strokeColor = CGColorCreateCopyWithAlpha(CGColorCreateFromHex(0x000000), 0.4)
            addSublayer(axisLine)
        }
        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        override init!(layer: AnyObject!) {
            self.alignment = .Left
            super.init(layer: layer)
        }
        
        override func layoutSublayers() {
            if size == nil {
                return
            }
            axisLine.path = CGPath.Dataset(CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height))
            
            let scaleFactor = size.height / (range.max - range.min)
            for tick in ticks {
                let y = (tick.value - range.min) * scaleFactor
                tick.position = CGPoint(x: 0.0, y: y)
            }
        }
        
        func optimalInterval(min: CGFloat, max: CGFloat) -> CGFloat {
            let maxInterval: CGFloat = 15.0 // todo: calc based on label font height
            let minInterval = (max - min) / 0.9 / maxInterval // if we used the max amount of steps, each step would have represent at least this many units
            // divide by 0.9 because we want all the data points to only take up ~90% of the available vertical space. the leftover is to provide some extra space below the min point and above the max point
            var magnitude = pow(10.0, round( log10(minInterval) ))
            
            // in order for the ticks to be "pretty" or intuitive, make them in multiples of either (100, 10, 1, .1, etc) or (50, 5, .5, .05) or (20, 2, .2, .02, etc)
            var stepBase: CGFloat = 0.0
            if minInterval <= 1.0 * magnitude {
                stepBase = 1.0
            } else if minInterval <= 2.0 * magnitude {
                stepBase = 2.0
            } else {
                stepBase = 5.0
            }
            return stepBase * magnitude
        }
        func showGrid(width: CGFloat) {
            for tick in ticks {
                if tick.major {
                    let xStart = alignment == .Left ? -6.0 : 6.0
                    let xEnd = alignment == .Left ? width : -width
                    tick.lineLayer.path = CGPath.Dataset(CGPoint(x: xStart, y: 0), end: CGPoint(x: xEnd, y: 0))
                }
            }
        }
    }
    class Tick : CALayer {
        var major = true
        var alignment: Alignment!
        var labelLayer = CATextLayer(autoScale: true)
        var lineLayer = CAShapeLayer()
        var width: CGFloat { return 12.0 + labelLayer.frame.size.width }
        var value: CGFloat! {
            didSet { label = value.shortFormatted }
        }
        let labelSpacing: CGFloat = 12.0

        var label: String {
            get { return labelLayer.string as String }
            set {
                labelLayer.string = newValue
                labelLayer.sizeToFit()
                updateLabelPosition()
                
            }
        }
        override weak var delegate: AnyObject! {
            didSet {
                labelLayer.delegate = delegate // so it can get contentsScale
            }
        }
        
        func updateLabelPosition() {
            if alignment == .Left {
                labelLayer.position = CGPoint(x: -labelSpacing - (labelLayer.frame.width / 2.0), y: 0.0)
                labelLayer.alignmentMode = kCAAlignmentRight
            } else {
                labelLayer.position = CGPoint(x: labelSpacing + (labelLayer.frame.width / 2.0), y: 0.0)
                labelLayer.alignmentMode = kCAAlignmentLeft
            }
        }
        init(value: CGFloat, alignment: Alignment, major: Bool) {
            self.value = value
            self.alignment = alignment
            self.major = major
            super.init()
            
            // Tick / Grid
            var xStart: CGFloat
            var xEnd: CGFloat
            
            if major {
                xStart = alignment == .Left ? -6.0 : 6.0
                xEnd = alignment == .Left ? 6.0 : -6.0
            } else {
                xStart = -3.0
                xEnd = 3.0
            }
            lineLayer.path = CGPath.Dataset(CGPoint(x: xStart, y: 0), end: CGPoint(x: xEnd, y: 0))
            lineLayer.strokeColor = CGColorCreateCopyWithAlpha(CGColorCreateFromHex(0x000000), 0.2)
            addSublayer(lineLayer)
            
            // Label
            labelLayer.fontSize = 12.0
            labelLayer.foregroundColor = CGColorCreateFromHex(0x444444)
            addSublayer(labelLayer)
        }
        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        override init!(layer: AnyObject!) {
            super.init(layer: layer)
        }
    }
    enum Curve {
        case Bezier(CGFloat)
    }
    class Dataset : CAShapeLayer {
        
        var xAxis: Axis!
        var yAxis: Axis!
        var label = ""
        var data: [CGFloat] = [CGFloat]() {
            didSet {
                updatePoints()

                if let delegate = delegate as? LineChart {
                    delegate.updateXAxis()
                    delegate.setNeedsLayout()
                }
            }
        }
        private let fillLayer = CAShapeLayer()
        
        var curve: Curve?
        let defaultPoint = CAShapeLayer()
        var points = [Point]()
        
        override weak var delegate: AnyObject! {
            didSet {
                legendLabel.delegate = delegate
                fillLayer.delegate = delegate
                for point in points { point.delegate = delegate }
            }
        }
        lazy var legendMarker: CAShapeLayer = {
            let legendMarker = CAShapeLayer()
            legendMarker.path = CGPath.Rect(CGRect(x: 0.0, y: 0.0, width: 20.0, height: 15.0))
            legendMarker.fillColor = self.strokeColor
            return legendMarker
        }()
        lazy var legendLabel: CATextLayer = {
            let legendLabel = CATextLayer(autoScale: true)
            //legendLabel.contentsScale = UIScreen.mainScreen().scale
            legendLabel.fontSize = 12.0
            legendLabel.string = self.label
            legendLabel.foregroundColor = CGColorCreateFromHex(0x000000)
            legendLabel.position = CGPoint(x: 14.0, y:0.0)
            legendLabel.alignmentMode = kCAAlignmentLeft
            legendLabel.sizeToFit()
            legendLabel.frame = CGRect(origin: CGPoint(x: 28.0, y: 0.0), size: legendLabel.frame.size)
            return legendLabel
        }()
        lazy var legendElement: CALayer = {
            let legendEl = CALayer()
            legendEl.addSublayer(self.legendMarker)
            legendEl.frame = CGRect(origin: CGPointZero, size: CGSize(width: self.legendLabel.frame.origin.x + self.legendLabel.frame.width, height: 15.0))
            legendEl.addSublayer(self.legendLabel)
            return legendEl
        }()
        override var path: CGPath! {
            didSet {
                let fillPath = CGPathCreateMutable()
                
                // We need to use this special ordering of points so the animated transition/morphing looks correct
                let lastPoint = CGPathGetCurrentPoint(path)
                let start = oldValue != nil ? CGPathGetCurrentPoint(oldValue) : lastPoint
                CGPathMoveToPoint(fillPath, nil, start.x, 0)
                CGPathAddLineToPoint(fillPath, nil, 0, 0)
                CGPathAddLineToPoint(fillPath, nil, points.first!.position.x, points.first!.position.y)
                CGPathAddPath(fillPath, nil, path)
                CGPathAddLineToPoint(fillPath, nil, lastPoint.x, lastPoint.y) // duplicate point important
                CGPathAddLineToPoint(fillPath, nil, lastPoint.x, 0)
                CGPathAddLineToPoint(fillPath, nil, start.x, 0)
                CGPathCloseSubpath(fillPath)
                fillLayer.path = fillPath
            }
        }
        override var fillColor: CGColorRef! {
            get { return nil }
            set {
                super.fillColor = nil
                fillLayer.fillColor = newValue
            }
        }
        
        convenience init(label: String, data: [CGFloat], yAxis: Axis) {
            self.init(label: label, data: data)
            self.yAxis = yAxis
        }
        init(label: String, data: [CGFloat]) {
            self.label = label
            self.data = data
            
            
            defaultPoint.path = CGPath.Circle(10.0)
            defaultPoint.strokeColor = CGColorCreateFromHex(0xFFFFFF)
            
            super.init()
            updatePoints()
            
            lineWidth = 2.0
            
            defaultPoint.addObserver(self, forKeyPath: "strokeColor", options: NSKeyValueObservingOptions.allZeros, context: nil)
            defaultPoint.addObserver(self, forKeyPath: "fillColor", options: NSKeyValueObservingOptions.allZeros, context: nil)
            defaultPoint.addObserver(self, forKeyPath: "path", options: NSKeyValueObservingOptions.allZeros, context: nil)
            
            addSublayer(fillLayer)
            //updatePoints();
        }
        override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
            for point in points {
                point.setValue(defaultPoint.valueForKeyPath(keyPath), forKeyPath: keyPath)
            }
        }
        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        override init!(layer: AnyObject!) {
            super.init(layer: layer)
        }
        func updatePoints() {
            for point in points {
                point.removeFromSuperlayer()
            }
            var newPoints = [Point]()
            for var i = 0; i < data.count; i++ {
                let point = i < points.count ? points[i] : Point(layer: defaultPoint)
                point.dataset = self
                point.delegate = delegate
                point.value = data[i]
                point.highlighted = false
                addSublayer(point)
                newPoints += [point]
            }
            points = newPoints
        }
        var color: CGColorRef! {
            get { return strokeColor }
            set {
                strokeColor = newValue
                fillColor = CGColorCreateCopyWithAlpha(newValue, 0.3)
                defaultPoint.fillColor = newValue
                legendMarker.fillColor = newValue
            }
        }
        override func layoutSublayers() {
            var x: CGFloat = 0
            let yScaleFactor = yAxis.size.height / (yAxis.range.max - yAxis.range.min)
            let xIntervalWidth = xAxis.size.height / (xAxis.range.max - xAxis.range.min)
            
            for point in points {
                let y = (point.value - yAxis.range.min) * yScaleFactor
                point.position = CGPoint(x: x, y: y)
                x += xIntervalWidth
            }
            let positions = points.map { $0.position }
            
            if curve != nil {
                switch curve! {
                    case .Bezier(let tension):
                        path = CGPath.SplineCurve(positions, tension: tension)
                }
            } else {
                path = CGPath.Polyline(positions)
            }            
        }
    }
    class Point : CAShapeLayer {
        var value: CGFloat!
        weak var dataset: Dataset?
        
        override init!(layer: AnyObject!) {
            super.init(layer: layer)
            path = layer.path
            strokeColor = layer.strokeColor
            fillColor = layer.fillColor
        }
        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        var highlighted: Bool = false {
            didSet {
                if highlighted {
                    transform = CATransform3DMakeAffineTransform( CGAffineTransformMakeScale(2.0, 2.0) )
                } else {
                    transform = CATransform3DMakeAffineTransform( CGAffineTransformMakeScale(1.0, 1.0) )
                }
            }
        }
    }
}


// Mark: User Interaction

extension LineChart {
    func closestPointTo(refPoint: CGPoint) -> Point? {
        var min: (point: Point, xDist: CGFloat, yDist: CGFloat)?
        for dataset in datasets {
            for point in dataset.points {
                let xDist = abs(refPoint.x - point.position.x)
                let yDist = abs(refPoint.y - point.position.y)
                
                if min == nil || xDist < min!.xDist || (xDist == min!.xDist && yDist < min!.yDist) {
                    min = (point, xDist, yDist)
                }
            }
        }
        return (min == nil) ? nil : min!.point
    }
}


// Mark: Helpers

func CGColorCreateFromHex(rgb: UInt) -> CGColor {
    return CGColorCreate(CGColorSpaceCreateDeviceRGB(), [CGFloat((rgb & 0xFF0000) >> 16) / 255.0, CGFloat((rgb & 0x00FF00) >> 8) / 255.0, CGFloat(rgb & 0x0000FF) / 255.0, 1.0])
}
extension CGFloat {
    var shortFormatted: String {
        if self == 0.0 {
            return "0"
        }
        let exponent = floor(log10(self))
        let formatter = NSNumberFormatter()
        
        let prefixes = [3:"k", 6:"M"]

        if exponent > 3 && exponent < 6 && self % 100 == 0 {
            formatter.maximumSignificantDigits = 3
            return formatter.stringFromNumber(self / 1000)! + "k"
        } else if exponent >= 6 && exponent < 9 && self % 100000 == 0 {
            formatter.maximumSignificantDigits = 3
            return formatter.stringFromNumber(self / 1000000)! + "M"
        }
        if exponent > 4 || exponent < -4 {
            formatter.numberStyle = NSNumberFormatterStyle.ScientificStyle
            formatter.maximumSignificantDigits = 5            
        } else {
            formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
            formatter.maximumSignificantDigits = 5
        }
        return formatter.stringFromNumber(self)!
    }
}

extension CGPath {
    class func Dataset(start: CGPoint, end: CGPoint) -> CGPath {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, start.x, start.y)
        CGPathAddLineToPoint(path, nil, end.x, end.y)

        return CGPathCreateCopy(path)
    }
    class func Polyline(points:[CGPoint]) -> CGPath {
        var path = CGPathCreateMutable()
        for point in points {
            if point == points.first {
                CGPathMoveToPoint(path, nil, point.x, point.y)
            } else {
                CGPathAddLineToPoint(path, nil, point.x, point.y)
            }
        }
        return path
    }
    class func Circle(radius: CGFloat) -> CGPath {
        return CGPathCreateWithEllipseInRect(CGRect(x: (radius / -2.0), y: (radius / -2.0), width: radius, height: radius), nil)
    }
    class func Rect(rect: CGRect) -> CGPath {
        return CGPathCreateWithRect(rect, nil)        
    }
    class func SplineCurve(points: [CGPoint], tension: CGFloat = 0.3, minY: CGFloat = CGFloat.min, maxY: CGFloat = CGFloat.max) -> CGPath {
        func controlPoints(t: CGPoint, i: CGPoint, e: CGPoint, s: CGFloat) -> (inner: CGPoint, outer: CGPoint) {
            // adapted from chart.js helper library
            // calculates the control points for bezier curve for a dataset
            var n = sqrt(pow(i.x - t.x, 2) + pow(i.y - t.y, 2));
            var o = sqrt(pow(e.x - i.x, 2) + pow(e.y - i.y, 2))
            var a = s * n / (n + o)
            var h = s * o / (n + o)
            var inner = CGPoint(x: i.x - a * (e.x - t.x), y: i.y - a * (e.y - t.y))
            var outer = CGPoint(x: i.x + h * (e.x - t.x), y: i.y + h * (e.y - t.y))
            return (inner, outer)
        }
        
        var path = CGPathCreateMutable()
        var prevControlPoints: (inner: CGPoint, outer: CGPoint)?
        
        for var i = 0; i < points.count; i++ {
            let point = points[i]
            
            // bezier curve control point calculations
            let pTension: CGFloat = i > 0 && i < points.count - 1 ? tension : 0.0
            let prevPoint = i > 0 ? points[i-1] : CGPointZero
            let nextPoint = i < points.count - 1 ? points[i+1] : CGPointZero
            var controlPoints = controlPoints(prevPoint, point, nextPoint, pTension)
            
            // if it doesn't make sense for data to ever go below or above a certain value, then we can cap it off
            controlPoints = ( CGPoint(x: controlPoints.inner.x, y: max(min(controlPoints.inner.y, maxY), minY)),
                CGPoint(x: controlPoints.outer.x, y: max(min(controlPoints.outer.y, maxY), minY)) )
            
            if i == 0 {
                CGPathMoveToPoint(path, nil, point.x, point.y)
            } else {
                CGPathAddCurveToPoint(path, nil, prevControlPoints!.outer.x, prevControlPoints!.outer.y, controlPoints.inner.x, controlPoints.inner.y, point.x, point.y)
            }
            prevControlPoints = controlPoints
        }
        return path
        
        
    }

}
extension CGAffineTransform {
    init(verticalFlipWithHeight height: CGFloat) {
        var t = CGAffineTransformMakeScale(1.0, -1.0)
        //CGAffineTransformTranslate(t, 0.0, -height)
        self.init(a: t.a, b:t.b, c:t.c, d:t.d, tx:t.tx, ty:t.ty)
    }
}
extension CATextLayer {
    convenience init(autoScale: Bool) {
        self.init()
        if autoScale {
            #if os(iOS)
            contentsScale = UIScreen.mainScreen().scale
            #else
            contentsScale = NSScreen.mainScreen()!.backingScaleFactor
            #endif
        }
    }
    // Helper function - It's nice to have access to an NSAttributedString because you can use the attributedString.size property to determine the correct frame for the layer
    var attributedString : NSAttributedString {
        if let attString = string as? NSAttributedString  {
            return attString
        } else if let string = string as? NSString {
            var layerFont: CTFontRef?
            
            if let fontName = font as? NSString {
                //layerFont = UIFont(name: fontName, size: fontSize)
                layerFont = CTFontCreateWithName(fontName, fontSize, nil);
            } else {
                let ftypeid = CFGetTypeID(font)
                if ftypeid == CTFontGetTypeID() {
                    let fontName = CTFontCopyPostScriptName(font as CTFont)
                    //layerFont = UIFont(name: fontName, size: fontSize)
                    layerFont = CTFontCreateWithName(fontName, fontSize, nil);
                } else if ftypeid == CGFontGetTypeID() {
                    let fontName = CGFontCopyPostScriptName(font as CGFont)
                    //layerFont = UIFont(name: fontName, size: fontSize)
                    layerFont = CTFontCreateWithName(fontName, fontSize, nil);
                }
            }            
            if layerFont == nil {
                //layerFont = UIFont.systemFontOfSize(fontSize)
                layerFont = CTFontCreateUIFontForLanguage(CTFontUIFontType.UIFontSystem, fontSize, nil)
            }
            //return NSAttributedString(string: string as NSString, attributes: [NSFontAttributeName: layerFont!])
            return NSAttributedString(string: string as NSString, attributes: [kCTFontAttributeName: layerFont!])
        } else {
            return NSAttributedString(string: "")
        }
    }
    func sizeToFit() {
        #if os(iOS)
        bounds = CGRect(origin: CGPointZero, size: self.attributedString.size())
        #else
        bounds = CGRect(origin: CGPointZero, size: self.attributedString.size)
        #endif
    }
}