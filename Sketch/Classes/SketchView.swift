//
//  SketchToolType.swift
//  Sketch
//
//  Created by daihase on 04/06/2018.
//  Copyright (c) 2018 daihase. All rights reserved.
//

import UIKit

public enum SketchToolType {
    case pen
    case eraser
    case stamp
    case line
    case arrow
    case rectangleStroke
    case rectangleFill
    case ellipseStroke
    case ellipseFill
    case star
    case fill
}

public enum ImageRenderingMode {
    case scale
    case original
    case aspectFit

}

@objc public protocol SketchViewDelegate: NSObjectProtocol  {
    @objc optional func drawView(_ view: SketchView, willBeginDrawUsingTool tool: AnyObject?)
    @objc optional func drawView(_ view: SketchView, didEndDrawUsingTool tool: AnyObject?)
}

public class SketchView: UIView {
    private var maskLayer: CALayer?

    // should use in viewDidAppear
    public var maskImage: UIImage? {
        didSet {
            if let maskImage:UIImage=maskImage{
            maskLayer = CALayer()
            let ratio = UIImage.bs_aspectFitSize(imageSize:maskImage.size, frameSize: self.bounds.size)
            let rect = CGRect.init(origin:CGPoint.init(x:self.bounds.midX-(ratio.width/2), y:self.bounds.midY-(ratio.height/2)), size: ratio)
            maskLayer?.frame = rect
            maskLayer?.contents = maskImage.cgImage
            self.layer.mask = maskLayer
            }else{
                self.layer.mask=nil
            }
        }
    }
    public var lineColor = UIColor.black
    public var lineWidth = CGFloat(10)
    public var lineAlpha = CGFloat(1)
    public var stampImage: UIImage?
    public var drawTool: SketchToolType = .pen
    public var drawingPenType: PenType = .normal
    public var sketchViewDelegate: SketchViewDelegate?
    private var currentTool: SketchTool?
    private let pathArray: NSMutableArray = NSMutableArray()
    private let bufferArray: NSMutableArray = NSMutableArray()
    private var currentPoint: CGPoint?
    private var previousPoint1: CGPoint?
    private var previousPoint2: CGPoint?
    private var image: UIImage?
    private var backgroundImage: UIImage?
    private var drawMode: ImageRenderingMode = .original

    public override init(frame: CGRect) {
        super.init(frame: frame)
        prepareForInitial()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        prepareForInitial()
    }

    private func prepareForInitial() {
        backgroundColor = UIColor.clear
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)

        switch drawMode {
        case .original:
            image?.draw(at: CGPoint.zero)
            break
        case .scale:
            image?.draw(in:self.bounds);

            break
        case .aspectFit:
            let ratio = UIImage.bs_aspectFitSize(imageSize: self.image?.size ?? CGSize.zero, frameSize: self.bounds.size)
            let rect = CGRect.init(origin:CGPoint.init(x:self.bounds.midX-(ratio.width/2), y:self.bounds.midY-(ratio.height/2)), size: ratio)
            image?.draw(in:rect)
        }

        currentTool?.draw()
    }

    private func updateCacheImage(_ isUpdate: Bool) {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)

        if isUpdate {
            image = nil
            switch drawMode {
            case .original:
                if let backgroundImage = backgroundImage  {
                    (backgroundImage.copy() as? UIImage)?.draw(at: CGPoint.zero)
                }
                break
            case .scale:
                (backgroundImage?.copy() as? UIImage)?.draw(in:self.bounds)
                break
            case .aspectFit:
                if let backgroundImage:UIImage = self.backgroundImage{
                let ratio = UIImage.bs_aspectFitSize(imageSize:backgroundImage.size, frameSize: self.bounds.size)
                let rect = CGRect.init(origin:CGPoint.init(x:self.bounds.midX-(ratio.width/2), y:self.bounds.midY-(ratio.height/2)), size: ratio)
                (backgroundImage.copy() as? UIImage)?.draw(in:rect)
                }
                break;
            }

            for obj in pathArray {
                if let tool = obj as? SketchTool {
                    tool.draw()
                }
            }
        } else {
            switch drawMode {
            case .original:
                image?.draw(at: .zero)
              case .scale:
                image?.draw(in:self.bounds)
                break
            case .aspectFit:
                if let image:UIImage = self.image{
                let ratio = UIImage.bs_aspectFitSize(imageSize:image.size, frameSize: self.bounds.size)
                let rect = CGRect.init(origin:CGPoint.init(x:self.bounds.midX-(ratio.width/2), y:self.bounds.midY-(ratio.height/2)), size: ratio)
                image.draw(in:rect)
                }
                break
            }
            currentTool?.draw()
        }

        image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }

    private func toolWithCurrentSettings() -> SketchTool? {
        switch drawTool {
        case .pen:
            return PenTool()
        case .eraser:
            return EraserTool()
        case .stamp:
            return StampTool()
        case .line:
            return LineTool()
        case .arrow:
            return ArrowTool()
        case .rectangleStroke:
            let rectTool = RectTool()
            rectTool.isFill = false
            return rectTool
        case .rectangleFill:
            let rectTool = RectTool()
            rectTool.isFill = true
            return rectTool
        case .ellipseStroke:
            let ellipseTool = EllipseTool()
            ellipseTool.isFill = false
            return ellipseTool
        case .ellipseFill:
            let ellipseTool = EllipseTool()
            ellipseTool.isFill = true
            return ellipseTool
        case .star:
            return StarTool()
        case .fill:
            return FillTool()
        }
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        if currentTool != nil {
            finishDrawing()
        }

        previousPoint1 = touch.previousLocation(in: self)
        currentPoint = touch.location(in: self)
        currentTool = toolWithCurrentSettings()
        currentTool?.lineWidth = lineWidth
        currentTool?.lineColor = lineColor
        currentTool?.lineAlpha = lineAlpha

        sketchViewDelegate?.drawView?(self, willBeginDrawUsingTool: currentTool as AnyObject)
        
        switch currentTool! {
        case is PenTool:
            guard let penTool = currentTool as? PenTool else { return }
            pathArray.add(penTool)
            penTool.drawingPenType = drawingPenType
            penTool.setInitialPoint(currentPoint!)
        case is StampTool:
            guard let stampTool = currentTool as? StampTool else { return }
            pathArray.add(stampTool)
            stampTool.setStampImage(image: stampImage)
            stampTool.setInitialPoint(currentPoint!)
        default:
            guard let currentTool = currentTool else { return }
            pathArray.add(currentTool)
            currentTool.setInitialPoint(currentPoint!)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        previousPoint2 = previousPoint1
        previousPoint1 = touch.previousLocation(in: self)
        currentPoint = touch.location(in: self)

        if let penTool = currentTool as? PenTool,
            let previousPoint2:CGPoint=previousPoint2,
            let previousPoint1:CGPoint=previousPoint1,
            let currentPoint:CGPoint=currentPoint{
            let renderingBox = penTool.createBezierRenderingBox(previousPoint2, widhPreviousPoint: previousPoint1, withCurrentPoint: currentPoint)

            setNeedsDisplay(renderingBox)
        } else
        if let previousPoint1:CGPoint = previousPoint1,
           let currentPoint:CGPoint=currentPoint{
            currentTool?.moveFromPoint(previousPoint1, toPoint: currentPoint)
            setNeedsDisplay()
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesMoved(touches, with: event)
        finishDrawing()
    }

    fileprivate func finishDrawing() {
        updateCacheImage(false)
        bufferArray.removeAllObjects()
        sketchViewDelegate?.drawView?(self, didEndDrawUsingTool: currentTool as AnyObject)
        currentTool = nil
    }

    private func resetTool() {
        currentTool = nil
    }

    public func clear() {
        resetTool()
        bufferArray.removeAllObjects()
        pathArray.removeAllObjects()
        updateCacheImage(true)

        setNeedsDisplay()
    }

    func pinch() {
        resetTool()
        guard let tool = pathArray.lastObject as? SketchTool else { return }
        bufferArray.add(tool)
        pathArray.removeLastObject()
        updateCacheImage(true)

        setNeedsDisplay()
    }

    public func loadImage(image: UIImage, drawMode: ImageRenderingMode = .original) {
        self.image = image
        self.drawMode = drawMode
        backgroundImage =  image.copy() as? UIImage
        bufferArray.removeAllObjects()
        pathArray.removeAllObjects()
        updateCacheImage(true)

        setNeedsDisplay()
    }

    public func undo() {
        if canUndo() {
            self.sketchViewDelegate?.drawView?(self, willBeginDrawUsingTool: self)
            guard let tool = pathArray.lastObject as? SketchTool else { return }
            resetTool()
            bufferArray.add(tool)
            pathArray.removeLastObject()
            updateCacheImage(true)

            setNeedsDisplay()
            self.sketchViewDelegate?.drawView?(self, didEndDrawUsingTool: self);
        }
    }

    public func redo() {
        if canRedo() {
            self.sketchViewDelegate?.drawView?(self, willBeginDrawUsingTool: self)
            guard let tool = bufferArray.lastObject as? SketchTool else { return }
            resetTool()
            pathArray.add(tool)
            bufferArray.removeLastObject()
            updateCacheImage(true)

            setNeedsDisplay()
            self.sketchViewDelegate?.drawView?(self, didEndDrawUsingTool: self);
        }
    }

    public func canUndo() -> Bool {
        return pathArray.count > 0
    }

    public func canRedo() -> Bool {
        return bufferArray.count > 0
    }
    public func removeImage(){
         self.image = nil
         backgroundImage = nil
         updateCacheImage(true)
         setNeedsDisplay()
     }
}
extension UIImage{
    class public func bs_aspectFitSize(imageSize:CGSize,frameSize:CGSize)->CGSize{
    let aspect = ((imageSize.width) / (imageSize.height))
    if ((frameSize.width / aspect) <= frameSize.height)
      {
        return CGSize.init(width: frameSize.width, height: frameSize.width/aspect)
      } else {
        return CGSize.init(width: frameSize.height * aspect, height:frameSize.height)
      }
 }
}
