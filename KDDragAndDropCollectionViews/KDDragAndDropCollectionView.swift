//
//  KDDragAndDropCollectionView.swift
//  KDDragAndDropCollectionViews
//
//  Created by Michael Michailidis on 10/04/2015.
//  Copyright (c) 2015 Karmadust. All rights reserved.
//

import UIKit

@objc public protocol KDDragAndDropCollectionViewDataSource : UICollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, indexPathForDataItem dataItem: Any) -> IndexPath?
	func collectionView(_ collectionView: UICollectionView, dataItemAt indexPath: IndexPath) -> Any?
	func collectionView(_ collectionView: UICollectionView, moveDataItemFrom fromIndexPath: IndexPath, to toIndexPath: IndexPath)
	func collectionView(_ collectionView: UICollectionView, insertDataItem dataItem: Any, at indexPath: IndexPath)
	func collectionView(_ collectionView: UICollectionView, deleteDataItemAt indexPath: IndexPath)
	func collectionView(_ collectionView: UICollectionView, canDropAt indexPath: IndexPath) -> Bool
}

public class KDDragAndDropCollectionView: UICollectionView {
	public var indexPathOfDraggedItem: IndexPath?
	fileprivate var currentItem: Any?
	fileprivate var currentRect: CGRect?
	fileprivate var timer: CADisplayLink?
	fileprivate var isAnimating: Bool = false
	fileprivate var currentInRect: CGRect?
	
	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	override public func awakeFromNib() {
		super.awakeFromNib()
	}
	
	override public init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
		super.init(frame: frame, collectionViewLayout: layout)
	}
}

extension KDDragAndDropCollectionView : KDDraggable {
	public var dragSourceRect: CGRect {
		guard let indexPathOfDraggedItem = indexPathOfDraggedItem,
			let cell = cellForItem(at: indexPathOfDraggedItem)
		else {
			return .zero
		}
		
		return cell.frame
	}
	
	public func canDrag(at point: CGPoint) -> Bool {
		return dataSource is KDDragAndDropCollectionViewDataSource &&
			indexPathForItem(at: point) != nil
	}
	
	public func representationImage(at point: CGPoint) -> UIView? {
		guard let indexPath = indexPathForItem(at: point),
			let cell = self.cellForItem(at: indexPath)
		else {
			return nil
		}
		
		cell.isHighlighted = true
		UIGraphicsBeginImageContextWithOptions(cell.bounds.size, cell.isOpaque, 0)
		cell.layer.render(in: UIGraphicsGetCurrentContext()!)
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		cell.isHighlighted = false
		
		let imageView = UIImageView(image: image)
		imageView.frame = cell.frame
		return imageView
	}
	
	public func dataItem(at point: CGPoint) -> Any? {
		guard let dataSource = dataSource as? KDDragAndDropCollectionViewDataSource,
			let indexPath = indexPathForItem(at: point)
		else {
			return nil
		}
		
		return dataSource.collectionView(self, dataItemAt: indexPath)
	}
	
	public func dragDataItem(_ dataItem: Any) {
		guard let dataSource = dataSource as? KDDragAndDropCollectionViewDataSource,
			let indexPath = dataSource.collectionView(self, indexPathForDataItem: dataSource)
		else {
			return
		}

		dataSource.collectionView(self, deleteDataItemAt: indexPath)
		
		isAnimating = true
		performBatchUpdates({ [weak self] in
			self?.deleteItems(at: [indexPath])
		}, completion: { [weak self] _ in
			self?.isAnimating = false
			self?.reloadData()
		})
	}
	
	public func startDragging(at point: CGPoint) {
		indexPathOfDraggedItem = indexPathForItem(at: point)
		reloadData()
	}
	
	public func willStopDragging() {
		stopTimer()
	}
	
	public func didStopDragging() {
		if let indexPathOfDraggedItem = indexPathOfDraggedItem,
			let cell = cellForItem(at: indexPathOfDraggedItem)
		{
			cell.isHidden = false
		}
		
		indexPathOfDraggedItem = nil
		reloadData()
	}
}

extension KDDragAndDropCollectionView : KDDroppable {
	public func canDrop(at rect: CGRect) -> Bool {
		if bounds.contains(rect.center),
			let dataSource = dataSource as? KDDragAndDropCollectionViewDataSource,
			let indexPath = targetIndexPath(for: rect)
		{
			return dataSource.collectionView(self, canDropAt: indexPath)
		} else {
			return false
		}
	}
	
	public func willMoveDataItem(_ item: Any, in rect: CGRect) {
		guard let dataSource = self.dataSource as? KDDragAndDropCollectionViewDataSource,
			dataSource.collectionView(self, indexPathForDataItem: item) == nil else
		{
			return
		}
		
		if let indexPath = targetIndexPath(for: rect) {
			dataSource.collectionView(self, insertDataItem: item, at: indexPath)
			
			indexPathOfDraggedItem = indexPath
			isAnimating = true
			
			performBatchUpdates({ [weak self] in
				self?.insertItems(at: [indexPath])
			}, completion: { [weak self] _ in
				self?.isAnimating = false
				if self?.indexPathOfDraggedItem == nil {
					self?.reloadData()
				}
			})
		}
		
		currentInRect = rect
	}
	
	public func didMoveDataItem(_ item: Any, in rect: CGRect) {
		moveDataItem(item, at: rect)
		
		currentRect = rect
		currentItem = item
		
		var normalizedRect = rect
		normalizedRect.origin.x -= contentOffset.x
		normalizedRect.origin.y -= contentOffset.y
		currentInRect = normalizedRect
		
		checkForEdge(in: rect)
	}
	
	public func didMoveOutDataItem(_ item: Any) {
		stopTimer()
		
		guard let dataSource = self.dataSource as? KDDragAndDropCollectionViewDataSource,
			let existingIndexPath = dataSource.collectionView(self, indexPathForDataItem: item) else
		{
			return
		}
		
		dataSource.collectionView(self, deleteDataItemAt: existingIndexPath)
		
		isAnimating = true
		performBatchUpdates({ [weak self] in
			self?.deleteItems(at: [existingIndexPath])
		}, completion: { [weak self] _ in
			self?.isAnimating = false
			self?.reloadData()
		})
		
		if let indexPathOfDraggedItem = indexPathOfDraggedItem,
			let cell = cellForItem(at: indexPathOfDraggedItem)
		{
			cell.isHidden = false
		}
		
		indexPathOfDraggedItem = nil
		currentInRect = nil
	}
	
	public func dropDataItem(_ item: Any, at rect: CGRect) {
		stopTimer()
		
		// show hidden cell
		if let indexPathOfDraggedItem = indexPathOfDraggedItem,
			let cell = cellForItem(at: indexPathOfDraggedItem),
			cell.isHidden
		{
			cell.alpha = 1
			cell.isHidden = false
		}
		
		currentInRect = nil
		indexPathOfDraggedItem = nil
		reloadData()
	}

}

fileprivate extension KDDragAndDropCollectionView {
	var isHorizontal: Bool {
		return (self.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection == .horizontal
	}
	
	func checkForEdge(in rect: CGRect) {
		if distance(to: rect) > 0.2 {
			startTimer()
		} else {
			stopTimer()
		}
	}
	
	func distance(to rect: CGRect) -> CGFloat {
		var bounds = self.bounds
		bounds.origin = .zero
		var outside: CGFloat = 0
		var translatedRect = rect
		translatedRect.origin.x -= contentOffset.x
		translatedRect.origin.y -= contentOffset.y
		
		if isHorizontal {
			let rightOutside =  translatedRect.maxX - bounds.width
			outside = max(-translatedRect.minX, rightOutside) / translatedRect.width
		} else {
			outside = max(-translatedRect.minY, translatedRect.maxY - bounds.height) / translatedRect.height
		}
		
		if outside > 1 {
			outside = 1
		}
		
		return outside
	}
	
	@objc func actionTimer() {
		let step = timerStepOffset()
		
		var nextOffset = contentOffset
		nextOffset.x += step.x
		nextOffset.y += step.y
		
		if nextOffset.x < 0 ||
			nextOffset.x + frame.width > contentSize.width ||
			nextOffset.y < 0 ||
			nextOffset.y + frame.height > contentSize.height
		{
			stopTimer()
			return
		}
		
		setContentOffset(nextOffset, animated: false)
		currentRect?.origin.x += step.x
		currentRect?.origin.y += step.y
		setNeedsDisplay()
		
		if let currentItem = currentItem, let currentRect = currentRect {
			moveDataItem(currentItem, at: currentRect)
			indexPathOfDraggedItem = targetIndexPath(for: currentRect)
		}
	}
	
	func timerStepOffset() -> CGPoint {
		guard let currentRect = currentRect else {
			return .zero
		}
		
		var stepX: CGFloat = 0
		var stepY: CGFloat = 0
		let stepSize: CGFloat = 15 * distance(to: currentRect)
		let rect = superview!.convert(currentRect, from: self)
		
		if isHorizontal {
			if (rect.minX < frame.minX) {
				stepX = -stepSize
			}
			
			if rect.maxX > frame.maxX {
				stepX = stepSize
			}
		} else {
			if rect.minY < frame.minY {
				stepY = -stepSize
			}
			
			if rect.maxY > frame.maxY {
				stepY = stepSize
			}
		}
		
		return CGPoint(x: stepX, y: stepY)
	}
	
	func startTimer() {
		guard timer == nil  else {
			return
		}
		
		timer = CADisplayLink(target: self, selector: #selector(actionTimer))
		timer!.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
	}
	
	func stopTimer() {
		guard let timer = timer else {
			return
		}
		
		timer.invalidate()
		self.timer = nil
	}
	
	func targetIndexPath(for rect: CGRect) -> IndexPath? {
		if totalNumberOfItems > 0 {
			return nearestDropableIndexPath(indexPathOfNearestVisibleCell(from: rect))
		} else {
			 return IndexPath(item: 0, section: 0)
		}
	}
	
	func indexPathOfNearestVisibleCell(from rect: CGRect) -> IndexPath? {
		let origin = CGPoint(x: rect.midX, y: rect.midY)
		return
			visibleCells
			.filter { cell in
				let superviewFrame = superview!.convert(cell.frame, from: self)
				let intersection = superviewFrame.intersection(rect)
				return intersection.area >= cell.frame.area / 3
			}
			.map { (cell: $0, distance: $0.center.distance(from: origin)) }
			.sorted(by: { $0.distance < $1.distance })
			.first
			.flatMap { indexPath(for: $0.cell)! }
	}
	
	func nearestDropableIndexPath(_ indexPath: IndexPath?) -> IndexPath? {
		guard let dataSource = self.dataSource as? KDDragAndDropCollectionViewDataSource,
			let indexPath = indexPath else
		{
			return nil
		}
		
		var result = indexPath
		while !dataSource.collectionView(self, canDropAt: result) {
			result = IndexPath(item: result.item - 1, section: 0)
			if result.item < 0 {
				return nil
			}
		}
		
		return result
	}
	
	func moveDataItem(_ item: Any, at rect: CGRect) {
		guard let dataSource = dataSource as? KDDragAndDropCollectionViewDataSource,
			let existingIndexPath = dataSource.collectionView(self, indexPathForDataItem: item),
			let indexPath = targetIndexPath(for: rect),
			indexPath.item != existingIndexPath.item else
		{
			return
		}
		
		dataSource.collectionView(self, moveDataItemFrom: existingIndexPath, to: indexPath)
		
		isAnimating = true
		indexPathOfDraggedItem = indexPath
		
		performBatchUpdates({ [weak self] in
			self?.moveItem(at: existingIndexPath, to: indexPath)
		}, completion: { [weak self] _ in
			self?.isAnimating = false
		})
	}
}

extension UICollectionView {
	var totalNumberOfItems: Int {
		return (0..<numberOfSections)
			.map { self.numberOfItems(inSection: $0) }
			.reduce(0, +)
	}
}

extension CGRect {
	var area: CGFloat {
		return width * height
	}
	
	var center: CGPoint {
		return CGPoint(x: midX, y: midY)
	}
}

extension CGPoint {
	func distance(from point: CGPoint) -> CGFloat {
		return CGFloat(sqrt(pow(x - point.x, 2) + pow(y - point.y, 2)))
	}
}
