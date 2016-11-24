//
//  KDDragAndDropManager.swift
//  KDDragAndDropCollectionViews
//
//  Created by Michael Michailidis on 10/04/2015.
//  Copyright (c) 2015 Karmadust. All rights reserved.
//

import UIKit

@objc public protocol KDDraggable {
	func canDragAtPoint(point: CGPoint) -> Bool
	func representationImageAtPoint(point: CGPoint) -> UIView?
	func dataItemAtPoint(point: CGPoint) -> AnyObject?
	func dragDataItem(item: AnyObject) -> Void
	func dragSourceRect() -> CGRect
	optional func startDraggingAtPoint(point: CGPoint) -> Void
	optional func stopDragging() -> Void
	optional func willStopDragging() -> Void
}

@objc public protocol KDDroppable {
	func canDropAtRect(rect: CGRect) -> Bool
	func willMoveItem(item: AnyObject, inRect rect: CGRect) -> Void
	func didMoveItem(item: AnyObject, inRect rect: CGRect) -> Void
	func didMoveOutItem(item: AnyObject) -> Void
	func dropDataItem(item: AnyObject, atRect: CGRect) -> Void
}


public protocol KDDragAndDropManagerDelegate: class {
	func didStartDragging(manager: KDDragAndDropManager)
	func didEndDragging(manager: KDDragAndDropManager)
}

public class KDDragAndDropManager: NSObject, UIGestureRecognizerDelegate {
	struct Bundle {
		var offset: CGPoint = CGPointZero
		var sourceDraggableView: UIView
		var overDroppableView: UIView?
		var representationImageView: UIView
		var dataItem: AnyObject
	}
	
	public weak var delegate: KDDragAndDropManagerDelegate?
	internal var bundle: Bundle?
	private weak var canvas: UIView! = UIView()
	private var views: [UIView] = []
	private var longPressGestureRecogniser = UILongPressGestureRecognizer()
	private var dragInProgress: Bool = false
	
	public init(canvas: UIView, collectionViews: [UIView]) {
		super.init()
		
		self.canvas = canvas
		self.views = collectionViews
		
		longPressGestureRecogniser.delegate = self
		longPressGestureRecogniser.minimumPressDuration = 0.3
		longPressGestureRecogniser.addTarget(self, action: #selector(KDDragAndDropManager.updateForLongPress(_:)))
		canvas.addGestureRecognizer(self.longPressGestureRecogniser)
	}
	
	public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
		for view in self.views.filter({ v -> Bool in v is KDDraggable})  {
			let draggable = view as! KDDraggable
			let touchPointInView = touch.locationInView(view)
				
			if draggable.canDragAtPoint(touchPointInView) == true {
				if let representation = draggable.representationImageAtPoint(touchPointInView) {
					representation.frame = self.canvas.convertRect(representation.frame, fromView: view)

					let pointOnCanvas = touch.locationInView(self.canvas)
					let offset = CGPointMake(pointOnCanvas.x - representation.center.x, pointOnCanvas.y - representation.center.y)
						
					if let dataItem: AnyObject = draggable.dataItemAtPoint(touchPointInView) where !dragInProgress {
						self.bundle = Bundle(
							offset: offset,
							sourceDraggableView: view,
							overDroppableView: view is KDDroppable ? view : nil,
							representationImageView: representation,
							dataItem: dataItem
						)
							
						return true
					}
				}
			}
		}
		
		return false
	}
	
	func updateForLongPress(recogniser: UILongPressGestureRecognizer) -> Void {
		if let bundle = bundle {
			let pointOnCanvas = recogniser.locationInView(recogniser.view)
			let sourceDraggable: KDDraggable = bundle.sourceDraggableView as! KDDraggable
			let pointOnSourceDraggable = recogniser.locationInView(bundle.sourceDraggableView)
			
			switch recogniser.state {
			case .Began:
				dragInProgress = true
				canvas.addSubview(bundle.representationImageView)
				UIView.animateWithDuration(0.2, animations: {
					let oldCenter = bundle.representationImageView.center
					let newFrame = CGRectApplyAffineTransform(bundle.representationImageView.frame, CGAffineTransformMakeScale(1.31, 1.31))
					bundle.representationImageView.frame = newFrame
					bundle.representationImageView.center = oldCenter
				})
				
				sourceDraggable.startDraggingAtPoint?(pointOnSourceDraggable)
				delegate?.didStartDragging(self)

			case .Changed:
				// Update the frame of the representation image
				bundle.representationImageView.center = CGPointMake(pointOnCanvas.x - bundle.offset.x, pointOnCanvas.y - bundle.offset.y)

				var overlappingArea: CGFloat = 0.0
				var mainOverView: UIView?
				
				for view in views.filter({ v -> Bool in v is KDDroppable }) {
					let viewFrameOnCanvas = self.convertRectToCanvas(view.frame, fromView: view)
					let intersectionNew = CGRectIntersection(bundle.representationImageView.frame, viewFrameOnCanvas).size

					if (intersectionNew.width * intersectionNew.height) > overlappingArea {
						overlappingArea = intersectionNew.width * intersectionNew.width
						mainOverView = view
					}
				}
				
				if !(mainOverView is KDDroppable) {
					mainOverView = bundle.sourceDraggableView
				}
				
				if let droppable = mainOverView as? KDDroppable {
					let rect = self.canvas.convertRect(bundle.representationImageView.frame, toView: mainOverView)

					if droppable.canDropAtRect(rect) {
						if mainOverView != bundle.overDroppableView { // if it is the first time we are entering
							(bundle.overDroppableView as? KDDroppable)?.didMoveOutItem(bundle.dataItem)
							droppable.willMoveItem(bundle.dataItem, inRect: rect)
						}
						
						// set the view the dragged element is over
						self.bundle!.overDroppableView = mainOverView
						droppable.didMoveItem(bundle.dataItem, inRect: rect)
					}
				}
			   
			case .Ended, .Cancelled:
				dragInProgress = false
				
				var dropRect: CGRect?
				if bundle.sourceDraggableView != bundle.overDroppableView { // if we are actually dropping over a new view.
					if let droppable = bundle.overDroppableView as? KDDroppable {
						sourceDraggable.dragDataItem(bundle.dataItem)
						let rect = self.canvas.convertRect(bundle.representationImageView.frame, toView: bundle.overDroppableView)
						droppable.dropDataItem(bundle.dataItem, atRect: rect)
						dropRect = findDropRect()
					}
				}
				
				if dropRect == nil {
					dropRect = sourceDraggable.dragSourceRect()
					dropRect = canvas.convertRect(dropRect!, fromView: (sourceDraggable as! UIView))
				}
				
				sourceDraggable.willStopDragging?()
				UIView.animateWithDuration(0.3, animations: {
					bundle.representationImageView.frame = dropRect!
				}, completion: { [weak self] (_) in
					bundle.representationImageView.removeFromSuperview()
					sourceDraggable.stopDragging?()
					if let _self = self {
						_self.delegate?.didEndDragging(_self)
						_self.bundle = nil
					}
				})
				
			default:
				break
			}
		}
	}
	
	private func findDropRect() -> CGRect? {
		guard let bundle = bundle, let targetView = bundle.overDroppableView else {
			return nil
		}
		
		let reprRect = self.canvas.convertRect(bundle.representationImageView.frame, toView: targetView)
		let targetRect = targetView.bounds
		var common = CGRectIntersection(reprRect, targetRect)
		common = targetView.convertRect(common, toView: canvas)
		return CGRect(x: common.midX, y: common.midY, width: 0, height: 0)
	}
	
	// MARK: Helper Methods 
	func convertRectToCanvas(rect: CGRect, fromView view: UIView) -> CGRect {
		var r: CGRect = rect
		var v = view
		
		while v != self.canvas {
			if let sv = v.superview {
				r.origin.x += sv.frame.origin.x
				r.origin.y += sv.frame.origin.y
				v = sv
				continue
			}
			break
		}
		
		return r
	}
}
