//
//  KDDragAndDropManager.swift
//  KDDragAndDropCollectionViews
//
//  Created by Michael Michailidis on 10/04/2015.
//  Copyright (c) 2015 Karmadust. All rights reserved.
//

import UIKit

@objc public protocol KDDraggable {
	var dragSourceRect: CGRect { get }
	func canDrag(at point: CGPoint) -> Bool
	func representationImage(at point: CGPoint) -> UIView?
	func dataItem(at point: CGPoint) -> Any?
	func dragDataItem(_ dataItem: Any)
	@objc optional func startDragging(at point: CGPoint)
	@objc optional func willStopDragging()
	@objc optional func didStopDragging()
}

@objc public protocol KDDroppable {
	func canDrop(at rect: CGRect) -> Bool
	func willMoveDataItem(_ item: Any, in rect: CGRect)
	func didMoveDataItem(_ item: Any, in rect: CGRect)
	func didMoveOutDataItem(_ item: Any)
	func dropDataItem(_ item: Any, at rect: CGRect)
}

public protocol KDDragAndDropManagerDelegate: class {
	func didStartDragging(_ manager: KDDragAndDropManager)
	func didEndDragging(_ manager: KDDragAndDropManager)
}

public class KDDragAndDropManager: NSObject, UIGestureRecognizerDelegate {
	fileprivate struct Bundle {
		var offset: CGPoint = .zero
		var sourceDraggableView: UIView
		var overDroppableView: UIView?
		var representationImageView: UIView
		var dataItem: Any
	}
	
	public weak var delegate: KDDragAndDropManagerDelegate?
	fileprivate var bundle: Bundle?
	fileprivate weak var canvas: UIView! = UIView()
	fileprivate var views: [UIView] = []
	fileprivate var longPressGestureRecogniser = UILongPressGestureRecognizer()
	fileprivate var dragInProgress: Bool = false
	
	public init(canvas: UIView, views: [UIView]) {
		super.init()
		
		self.canvas = canvas
		self.views = views
		
		longPressGestureRecogniser.delegate = self
		longPressGestureRecogniser.minimumPressDuration = 0.3
		longPressGestureRecogniser.addTarget(self, action: #selector(KDDragAndDropManager.handleLongPress(_:)))
		canvas.addGestureRecognizer(longPressGestureRecogniser)
	}
	
	public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		for view in views where view is KDDraggable {
			let draggable = view as! KDDraggable
			let locationInView = touch.location(in: view)
			
			guard draggable.canDrag(at: locationInView),
				let representation = draggable.representationImage(at: locationInView) else
			{
				continue
			}

			representation.frame = canvas.convert(representation.frame, from: view)
			
			let locationInCanvas = touch.location(in: canvas)
			let offset = locationInCanvas - representation.center
			
			if !dragInProgress, let item = draggable.dataItem(at: locationInView) {
				bundle = Bundle(
					offset: offset,
					sourceDraggableView: view,
					overDroppableView: view is KDDroppable ? view : nil,
					representationImageView: representation,
					dataItem: item)
				return true
			}
		}
		
		return false
	}
}

fileprivate extension KDDragAndDropManager {
	@objc func handleLongPress(_ recogniser: UILongPressGestureRecognizer) -> Void {
		guard let bundle = bundle else {
			return
		}
		
		let locationInCanvas = recogniser.location(in: recogniser.view)
		let sourceDraggable: KDDraggable = bundle.sourceDraggableView as! KDDraggable
		let pointOnSourceDraggable = recogniser.location(in: bundle.sourceDraggableView)

		switch recogniser.state {
		case .began:
			dragInProgress = true
			canvas.addSubview(bundle.representationImageView)
			UIView.animate(withDuration: 0.2, animations: {
				let oldCenter = bundle.representationImageView.center
				let newFrame = bundle.representationImageView.frame.applying(CGAffineTransform(scaleX: 1.31, y: 1.31))
				bundle.representationImageView.frame = newFrame
				bundle.representationImageView.center = oldCenter
			})
				
			sourceDraggable.startDragging?(at: pointOnSourceDraggable)
			delegate?.didStartDragging(self)

		case .changed:
			// Update the frame of the representation image
			bundle.representationImageView.center = locationInCanvas - bundle.offset

			var overlappingArea: CGFloat = 0.0
			var mainOverView: UIView?
				
			for view in views where view is KDDroppable {
				let viewFrameOnCanvas = convertToCanvas(rect: view.frame, from: view)
				let intersectionNew = bundle.representationImageView.frame.intersection(viewFrameOnCanvas).size

				if (intersectionNew.width * intersectionNew.height) > overlappingArea {
					overlappingArea = intersectionNew.width * intersectionNew.width
					mainOverView = view
				}
			}
				
			if !(mainOverView is KDDroppable) {
				mainOverView = bundle.sourceDraggableView
			}
				
			if let droppable = mainOverView as? KDDroppable {
				let rect = self.canvas.convert(bundle.representationImageView.frame, to: mainOverView)

				if droppable.canDrop(at: rect) {
					if mainOverView != bundle.overDroppableView { // if it is the first time we are entering
						(bundle.overDroppableView as? KDDroppable)?.didMoveOutDataItem(bundle.dataItem)
						droppable.willMoveDataItem(bundle.dataItem, in: rect)
					}
						
					// set the view the dragged element is over
					self.bundle!.overDroppableView = mainOverView
					droppable.didMoveDataItem(bundle.dataItem, in: rect)
				}
			}
			   
		case .ended, .cancelled:
			dragInProgress = false
				
			var dropRect: CGRect?
			if bundle.sourceDraggableView != bundle.overDroppableView { // if we are actually dropping over a new view.
				if let droppable = bundle.overDroppableView as? KDDroppable {
					sourceDraggable.dragDataItem(bundle.dataItem)
					let rect = self.canvas.convert(bundle.representationImageView.frame, to: bundle.overDroppableView)
					droppable.dropDataItem(bundle.dataItem, at: rect)
					dropRect = findDropRect()
				}
			}
				
			if dropRect == nil {
				dropRect = sourceDraggable.dragSourceRect
				dropRect = canvas.convert(dropRect!, from: (sourceDraggable as! UIView))
			}
				
			sourceDraggable.willStopDragging?()
			UIView.animate(withDuration: 0.3, animations: {
				bundle.representationImageView.frame = dropRect!
			}, completion: { [weak self] (_) in
				guard let `self` = self else { return }
				bundle.representationImageView.removeFromSuperview()
				sourceDraggable.didStopDragging?()
				self.delegate?.didEndDragging(self)
				self.bundle = nil
			})
				
		default:
			break
		}
	}
	
	func findDropRect() -> CGRect? {
		guard let bundle = bundle, let targetView = bundle.overDroppableView else {
			return nil
		}
		
		let reprRect = canvas.convert(bundle.representationImageView.frame, to: targetView)
		let targetRect = targetView.bounds
		var common = reprRect.intersection(targetRect)
		common = targetView.convert(common, to: canvas)
		return CGRect(x: common.midX, y: common.midY, width: 0, height: 0)
	}

	func convertToCanvas(rect: CGRect, from view: UIView) -> CGRect {
		var r: CGRect = rect
		var v = view
		
		while v != canvas {
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

func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
	return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}
