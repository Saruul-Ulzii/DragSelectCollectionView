//
//  DragSelectionManager.swift
//  DragSelectionCollectionView
//
//  Created by Haskel Ash on 9/14/16.
//  Copyright © 2016 Haskel Ash. All rights reserved.
//

import UIKit

open class DragSelectionManager: NSObject, UICollectionViewDelegate {
    private var selectedIndices = [IndexPath]()
    private weak var collectionView: UICollectionView!

    /**
     Sets a maximum number of cells that may be selected. `nil` by default.
     Setting this value to a value of zero or lower effectively disables selection.
     Setting this value to `nil` removes any upper limit to selection.
     If when setting a new value, the selection manager already has a greater number
     of cells selected, then the apporpriate number of the most recently selected cells
     will automatically be deselected.
     */
    public var maxSelectionCount: Int? {
        didSet {
            guard let max = maxSelectionCount else { return }
            var count = selectedIndices.count
            while count > max {
                let path = selectedIndices.removeLast()
                collectionView.deselectItem(at: path, animated: true)
                collectionView.delegate?.collectionView?(collectionView, didDeselectItemAt: path)
                count -= 1
            }
        }
    }

    ///Initializes a `DragSelectionManager` with the provided `UICollectionView`.
    public init(collectionView: UICollectionView) {
        self.collectionView = collectionView
    }

    /**
     Tells the selection manager to set the cell at `indexPath` to `selected`.

     If `collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath)`
     return `false` for this `indexPath`, and `selected` is `true`, this method does nothing.

     If `collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath)`
     return `false` for this `indexPath`, and `selected` is `false`, this method does nothing.
     - Parameter indexPath: the index path to select / deselect.
     - Parameter selected: `true` to select, `false` to deselect.
     */
    final func setSelected(_ selected: Bool, for indexPath: IndexPath) {
        if (!collectionView(collectionView, shouldSelectItemAt: indexPath) && selected)
        || (!collectionView(collectionView, shouldDeselectItemAt: indexPath) && !selected) {
            return
        }

        if selected {
            if !selectedIndices.contains(indexPath) &&
                (maxSelectionCount == nil || selectedIndices.count < maxSelectionCount!) {

                selectedIndices.append(indexPath)
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
                collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: indexPath)
            }
        } else if let i = selectedIndices.index(of: indexPath) {
            selectedIndices.remove(at: i)
            collectionView.deselectItem(at: indexPath, animated: true)
            collectionView.delegate?.collectionView?(collectionView, didDeselectItemAt: indexPath)
        }
    }

    /**
     Changes the selected state of the cell at `indexPath`.

     If `collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath)`
     return `false` for this `indexPath`, and the cell is currently deselected, this method does nothing.

     If `collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath)`
     return `false` for this `indexPath`, and the cell is currently selected, this method does nothing.
     - Parameter indexPath: the index path of the cell to toggle.
     - Returns: the new selected state of the cell at `indexPath`.
     `true` for selected, `false` for deselected.
     */
    final func toggleSelected(indexPath: IndexPath) -> Bool {
        if let i = selectedIndices.index(of:indexPath) {
            if collectionView(collectionView, shouldDeselectItemAt: indexPath) {
                selectedIndices.remove(at: i)
                collectionView.deselectItem(at: indexPath, animated: true)
                collectionView.delegate?.collectionView?(collectionView, didDeselectItemAt: indexPath)
                return false
            } else { return true }
        } else {
            if collectionView(collectionView, shouldSelectItemAt: indexPath) &&
            (maxSelectionCount == nil || selectedIndices.count < maxSelectionCount!) {
                selectedIndices.append(indexPath)
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
                collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: indexPath)
                return true
            } else { return false }
        }
    }

    private func iterate(start: IndexPath, end: IndexPath, closed: Bool, block:(_ indexPath: IndexPath)->()) {
        var current = start
        var last = end
        if !closed {
            if last.item > 0 {
                last = IndexPath(item: last.item-1, section: last.section)
            } else {
                let itemsInPrevious = collectionView.numberOfItems(inSection: last.section-1)
                //TODO: what if number of items are 3, 0, 3 - i.e. going back a section has 0 items but going back 2 is ok?
                last = IndexPath(item: itemsInPrevious-1, section: last.section-1)
            }
        }
        while current.compare(last) != .orderedDescending {
            block(current)
            if collectionView.numberOfItems(inSection: current.section) > current.item + 1 {
                current = IndexPath(item: current.item+1, section: current.section)
            } else {
                current = IndexPath(item: 0, section: current.section+1)
            }
        }
    }

    private let nilPath = IndexPath(item: -1, section: -1)

    final func selectRange(from: IndexPath, to: IndexPath, min: IndexPath, max: IndexPath) {
        if from == to {
            // Finger is back on the initial item, unselect everything else
            iterate(start: min, end: max, closed: true, block: { indexPath in
                if indexPath != from {
                    self.setSelected(false, for: indexPath)
                }
            })
//            for i in min...max {
//                if i == from { continue }
//                setSelected(i, selected: false)
//            }
      //      fireSelectionListener()
            return
        }

        if to.compare(from) == .orderedAscending {
            // When selecting from one to previous items
            iterate(start: to, end: from, closed: true, block: { indexPath in
                self.setSelected(true, for: indexPath)
            })
            if min != nilPath && min.compare(to) == .orderedAscending {
                // Unselect items that were selected during this drag but no longer are
                iterate(start: min, end: to, closed: false, block: { indexPath in
                    if indexPath != from {
                        self.setSelected(false, for: indexPath)
                    }
                })
            }
            if max != nilPath && from.compare(max) == .orderedAscending {
                iterate(start: from, end: max, closed: true, block: { indexPath in
                    self.setSelected(false, for: indexPath)

                })
            }
        } else {// When selecting from one to next items
            iterate(start: from, end: to, closed: true, block: { indexPath in
                self.setSelected(true, for: indexPath)
            })
            if max != nilPath && max.compare(to) == .orderedDescending {
                // Unselect items that were selected during this drag but no longer are
                var afterTo: IndexPath!
                if to.item + 1 < collectionView.numberOfItems(inSection: to.section) {
                    afterTo = IndexPath(item: to.item+1, section: to.section)
                } else {
                    afterTo = IndexPath(item: 0, section: to.section+1)
                }
                iterate(start: afterTo, end: max, closed: true, block: { indexPath in
                    if indexPath != from {
                        self.setSelected(false, for: indexPath)
                    }
                })
            }
            if min != nilPath && min.compare(from) == .orderedAscending {
                iterate(start: min, end: from, closed: false, block: { indexPath in
                    self.setSelected(false, for: indexPath)
                })
            }
        }
    //    fireSelectionListener()
    }

    final func selectAll() {
        selectedIndices.removeAll()

        //TODO: check 0 sections, or 0 items in section
        let sections = collectionView.numberOfSections
        for section in 0 ..< sections  {
            guard let items = collectionView?.numberOfItems(inSection: section) else { continue }
            for item in 0 ..< items {
                let path = IndexPath(item: item, section: section)
                if collectionView(collectionView, shouldSelectItemAt: path) {
                    selectedIndices.append(path)
                    collectionView?.selectItem(at: path, animated: true, scrollPosition: [])
                    collectionView?.delegate?.collectionView?(collectionView, didSelectItemAt: path)
                }
            }
        }
        //  notifyDataSetChanged()
        //  fireSelectionListener()
    }

    final func clearSelected() {
        selectedIndices.removeAll()
    //    notifyDataSetChanged()
    //    fireSelectionListener()
    }

    final func getSelectedCount() -> Int {
        return selectedIndices.count
    }

    final func getSelectedIndices() -> [IndexPath] {
        return selectedIndices
        //TODO make sure this is actually pass by value
    }

    public final func isIndexSelected(_ indexPath: IndexPath) -> Bool {
        return selectedIndices.contains(indexPath)
    }


    open func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    open func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        setSelected(true, for: indexPath)
    }

    open func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        setSelected(false, for: indexPath)
    }

}
