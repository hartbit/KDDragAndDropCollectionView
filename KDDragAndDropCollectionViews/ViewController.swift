//
//  ViewController.swift
//  KDDragAndDropCollectionViews
//
//  Created by Michael Michailidis on 10/04/2015.
//  Copyright (c) 2015 Karmadust. All rights reserved.
//

import UIKit

class DataItem : Equatable {
	var indexes: String = ""
	var color: UIColor = .clear
	
	init(indexes: String, color: UIColor) {
		self.indexes = indexes
		self.color = color
	}
}

func ==(lhs: DataItem, rhs: DataItem) -> Bool {
	return lhs.indexes == rhs.indexes && lhs.color == rhs.color
}

class ViewController: UIViewController {
	@IBOutlet weak var firstCollectionView: UICollectionView!
	@IBOutlet weak var secondCollectionView: UICollectionView!
	@IBOutlet weak var thirdCollectionView: UICollectionView!
	var data: [[DataItem]] = [[DataItem]]()
	var dragAndDropManager: KDDragAndDropManager?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let colors: [UIColor] = [
			UIColor(red: 53.0/255.0, green: 102.0/255.0, blue: 149.0/255.0, alpha: 1.0),
			UIColor(red: 177.0/255.0, green: 88.0/255.0, blue: 39.0/255.0, alpha: 1.0),
			UIColor(red: 138.0/255.0, green: 149.0/255.0, blue: 86.0/255.0, alpha: 1.0)
		]
		
		for i in 0...2 {
			var items = [DataItem]()
			
			for j in 0...20 {
				let dataItem = DataItem(indexes: String(i) + ":" + String(j), color: colors[i])
				items.append(dataItem)
			}
			
			data.append(items)
		}
		
		self.dragAndDropManager = KDDragAndDropManager(canvas: self.view, collectionViews: [firstCollectionView, secondCollectionView, thirdCollectionView])
	}
}

extension ViewController : UICollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return data[collectionView.tag].count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! ColorCell
		let dataItem = data[collectionView.tag][indexPath.item]
		cell.label.text = String(indexPath.item) + "\n\n" + dataItem.indexes
		cell.backgroundColor = dataItem.color
		cell.isHidden = false
		
		if let collectionView = collectionView as? KDDragAndDropCollectionView,
			let indexPathOfDraggedItem = collectionView.indexPathOfDraggedItem,
			indexPathOfDraggedItem.item == indexPath.item
		{
			cell.isHidden = true
		}
		
		return cell
	}
}

extension ViewController : KDDragAndDropCollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, canDropAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	func collectionView(_ collectionView: UICollectionView, dataItemAt indexPath: IndexPath) -> Any? {
		return data[collectionView.tag][indexPath.item]
	}
	
	func collectionView(_ collectionView: UICollectionView, insertDataItem dataItem: Any, at indexPath: IndexPath) {
		if let di = dataItem as? DataItem {
			data[collectionView.tag].insert(di, at: indexPath.item)
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, deleteDataItemAt indexPath: IndexPath) {
		data[collectionView.tag].remove(at: indexPath.item)
	}
	
	func collectionView(_ collectionView: UICollectionView, moveDataItemFrom fromIndexPath: IndexPath, to toIndexPath: IndexPath) {
		let fromDataItem: DataItem = data[collectionView.tag][fromIndexPath.item]
		data[collectionView.tag].remove(at: fromIndexPath.item)
		data[collectionView.tag].insert(fromDataItem, at: toIndexPath.item)
	}
	
	func collectionView(_ collectionView: UICollectionView, indexPathForDataItem dataItem: Any) -> IndexPath? {
		if let candidate: DataItem = dataItem as? DataItem {
			for item: DataItem in data[collectionView.tag] {
				if candidate  == item {
					let position = data[collectionView.tag].index(of: item)! // ! if we are inside the condition we are guaranteed a position
					return IndexPath(item: position, section: 0)
				}
			}
		}
		
		return nil
	}
}

