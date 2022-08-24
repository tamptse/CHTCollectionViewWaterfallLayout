//
//  CHTCollectionViewWaterfallLayout.swift
//  PinterestSwift
//
//  Created by Nicholas Tau on 6/30/14.
//  Copyright (c) 2014 Nicholas Tau. All rights reserved.
//
import UIKit
import VOCommon

private func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (lVal?, rVal?):
        return lVal < rVal
    case (nil, _?):
        return true
    default:
        return false
    }
}

private func > <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (lVal?, rVal?):
        return lVal > rVal
    default:
        return rhs < lhs
    }
}

protocol CHTCollectionViewDelegateWaterfallLayout: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        heightForHeaderIn section: Int) -> CGFloat

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        heightForFooterIn section: Int) -> CGFloat

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetsFor section: Int) -> UIEdgeInsets

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingFor section: Int) -> CGFloat

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        columnCountFor section: Int) -> Int
}

extension CHTCollectionViewDelegateWaterfallLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        heightForHeaderIn section: Int) -> CGFloat { 0 }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        heightForFooterIn section: Int) -> CGFloat { 0 }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetsFor section: Int) -> UIEdgeInsets { .zero }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingFor section: Int) -> CGFloat { 0 }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        columnCountFor section: Int) -> Int { 0 }
}

extension CHTCollectionViewWaterfallLayout {
    public enum ItemRenderDirection: Int {
        case shortestFirst
        case leftToRight
        case rightToLeft
    }
}

final class CHTCollectionViewWaterfallLayout: UICollectionViewFlowLayout {
    public var columnCount: Int = 2 {
        didSet {
            invalidateLayout()
        }
    }

    public var minimumColumnSpacing: CGFloat = 10 {
        didSet {
            invalidateLayout()
        }
    }

    public override var minimumInteritemSpacing: CGFloat {
        didSet {
            invalidateLayout()
        }
    }

    public var headerHeight: CGFloat = 0 {
        didSet {
            invalidateLayout()
        }
    }

    public var footerHeight: CGFloat = 0 {
        didSet {
            invalidateLayout()
        }
    }

    public override var sectionInset: UIEdgeInsets {
        didSet {
            invalidateLayout()
        }
    }

    public var itemRenderDirection: ItemRenderDirection = .shortestFirst {
        didSet {
            invalidateLayout()
        }
    }

    public override var sectionInsetReference: SectionInsetReference {
        didSet {
            invalidateLayout()
        }
    }

    public weak var delegate: CHTCollectionViewDelegateWaterfallLayout?

    public func itemWidth(inSection section: Int) -> CGFloat {
        let columnCount = self.columnCount(forSection: section)
        let spaceColumCount = CGFloat(columnCount - 1)
        let width = collectionViewContentWidth(ofSection: section)
        return floor((width - (spaceColumCount * minimumColumnSpacing)) / CGFloat(columnCount))
    }

    // swiftlint:disable all
    override public func prepare() {
        super.prepare()

        guard let collectionView = self.collectionView, collectionView.numberOfSections != 0 else {
            return
        }

        let numberOfSections = collectionView.numberOfSections

        headersAttributes = [:]
        footersAttributes = [:]
        unionRects = []
        allItemAttributes = []
        sectionItemAttributes = []
        columnHeights = (0 ..< numberOfSections).map { section in
            let columnCount = self.columnCount(forSection: section)
            let sectionColumnHeights = (0 ..< columnCount).map { CGFloat($0) }
            return sectionColumnHeights
        }

        var top: CGFloat = 0.0
        var attributes = UICollectionViewLayoutAttributes()

        for section in 0 ..< numberOfSections {
            // MARK: 1. Get section-specific metrics (minimumInteritemSpacing, sectionInset)
            let minimumInteritemSpacing = delegate?.collectionView(collectionView,
                                                                   layout: self,
                                                                   minimumInteritemSpacingFor: section) ?? self.minimumInteritemSpacing
            let sectionInsets = delegate?.collectionView(collectionView,
                                                         layout: self,
                                                         insetsFor: section) ?? self.sectionInset
            let columnCount = columnHeights[section].count
            let itemWidth = self.itemWidth(inSection: section)

            // MARK: 2. Section header
            let heightHeader = delegate?.collectionView(collectionView,
                                                        layout: self,
                                                        heightForHeaderIn: section) ?? self.headerHeight
            if heightHeader > 0 {
                attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, with: IndexPath(row: 0, section: section))
                attributes.frame = CGRect(x: 0, y: top, width: collectionView.bounds.size.width, height: heightHeader)
                attributes.zIndex = 2
                headersAttributes[section] = attributes
                allItemAttributes.append(attributes)

                top = attributes.frame.maxY
            }
            top += sectionInsets.top
            columnHeights[section] = [CGFloat](repeating: top, count: columnCount)

            // MARK: 3. Section items
            let itemCount = collectionView.numberOfItems(inSection: section)
            var itemAttributes: [UICollectionViewLayoutAttributes] = []

            // Item will be put into shortest column.
            for idx in 0 ..< itemCount {
                autoreleasepool {
                    let indexPath = IndexPath(item: idx, section: section)
                    
                    let columnIndex = nextColumnIndexForItem(idx, inSection: section)
                    let xOffset = sectionInsets.left + (itemWidth + minimumColumnSpacing) * CGFloat(columnIndex)
                    
                    let yOffset = columnHeights[section][columnIndex]
                    var itemHeight: CGFloat = 0.0
                    if let itemSize = delegate?.collectionView(collectionView,
                                                               layout: self,
                                                               sizeForItemAt: indexPath),
                       itemSize.height > 0 {
                        itemHeight = itemSize.height
                        if itemSize.width > 0 {
                            itemHeight = floor(itemHeight * itemWidth / itemSize.width)
                        } // else use default item width based on other parameters
                    }
                    
                    attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                    attributes.frame = CGRect(x: xOffset, y: yOffset, width: itemWidth, height: itemHeight)
                    itemAttributes.append(attributes)
                    allItemAttributes.append(attributes)
                    columnHeights[section][columnIndex] = attributes.frame.maxY + minimumInteritemSpacing
                }
            }
            sectionItemAttributes.append(itemAttributes)

            // MARK: 4. Section footer
            let columnIndex  = longestColumnIndex(inSection: section)
            top = columnHeights[section][columnIndex] - minimumInteritemSpacing + sectionInsets.bottom
            let footerHeight = delegate?.collectionView(collectionView,
                                                        layout: self,
                                                        heightForFooterIn: section) ?? self.footerHeight

            if footerHeight > 0 {
                attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, with: IndexPath(item: 0, section: section))
                attributes.frame = CGRect(x: 0, y: top, width: collectionView.bounds.size.width, height: footerHeight)
                footersAttributes[section] = attributes
                allItemAttributes.append(attributes)
                top = attributes.frame.maxY
            }

            columnHeights[section] = [CGFloat](repeating: top, count: columnCount)
        }

        var idx = 0
        let itemCounts = allItemAttributes.count
        while idx < itemCounts {
            autoreleasepool {
                let rect1 = allItemAttributes[idx].frame
                idx = min(idx + unionSize, itemCounts) - 1
                let rect2 = allItemAttributes[idx].frame
                unionRects.append(rect1.union(rect2))
                idx += 1
            }
        }
    }
    // swiftlint:enable all

    override public var collectionViewContentSize: CGSize {
        guard let collectionView = self.collectionView, collectionView.numberOfSections != 0 else {
            return .zero
        }

        var contentSize = collectionView.bounds.size
        contentSize.width = collectionViewContentWidth

        if let height = columnHeights.last?.first {
            contentSize.height = height
            return contentSize
        }
        return .zero
    }

    override public func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if indexPath.section >= sectionItemAttributes.count {
            return nil
        }
        let list = sectionItemAttributes[indexPath.section]
        if indexPath.item >= list.count {
            return nil
        }
        return list[indexPath.item]
    }

    override public func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let collectionView = collectionView else {
            return nil
        }

        var attribute: UICollectionViewLayoutAttributes?
        if elementKind == UICollectionView.elementKindSectionHeader {
            attribute = headersAttributes[indexPath.section]
        } else if elementKind == UICollectionView.elementKindSectionFooter {
            attribute = footersAttributes[indexPath.section]
        }
        guard let layoutAttributes = attribute,
              elementKind == UICollectionView.elementKindSectionHeader,
              sectionHeadersPinToVisibleBounds else {
            return attribute
        }

        // support stick header section
        let boundaries = boundaries(forSection: indexPath.section)

        let contentOffsetY = collectionView.contentOffset.y
        var frameForSupplementaryView = layoutAttributes.frame

        let minimum = boundaries.minimum - frameForSupplementaryView.height
        let maximum = boundaries.maximum - frameForSupplementaryView.height

        if contentOffsetY < minimum {
            frameForSupplementaryView.origin.y = minimum
        } else if contentOffsetY > maximum {
            frameForSupplementaryView.origin.y = maximum
        } else {
            frameForSupplementaryView.origin.y = contentOffsetY
        }

        layoutAttributes.frame = frameForSupplementaryView

        return layoutAttributes
    }

    override public func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var begin = 0, end = unionRects.count

        if let i = unionRects.firstIndex(where: { rect.intersects($0) }) {
            begin = i * unionSize
        }
        if let i = unionRects.lastIndex(where: { rect.intersects($0) }) {
            end = min((i + 1) * unionSize, allItemAttributes.count)
        }
        let layoutAttributes = allItemAttributes[begin..<end].filter { rect.intersects($0.frame) }

        guard sectionHeadersPinToVisibleBounds else {
            return layoutAttributes
        }

        // support stick header section
        let sectionAttributes = layoutAttributes
            .filter { $0.representedElementCategory != .decorationView }
            .map({ $0.indexPath.section })
            .unique()
            .compactMap { [weak self] section -> UICollectionViewLayoutAttributes? in
                self?.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: section))
            }
        return layoutAttributes + sectionAttributes
    }

    override public func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        if sectionHeadersPinToVisibleBounds {
            return true
        }
        let oldBounds = collectionView?.bounds ?? .zero
        return oldBounds.width != newBounds.width || oldBounds.height != newBounds.height
    }

    override public func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        guard let collectionView = collectionView else {
            assertionFailure("CollectionView is not set.")
            return super.invalidationContext(forBoundsChange: newBounds)
        }

        let oldBounds = collectionView.bounds
        let sizeChanged = oldBounds.width != newBounds.width || oldBounds.height != newBounds.height

        let context = super.invalidationContext(forBoundsChange: newBounds)

        if !sizeChanged, sectionHeadersPinToVisibleBounds {
            let indexPaths = headersAttributes.keys.sorted(by: <).map { IndexPath(item: 0, section: $0) }
            context.invalidateSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader, at: indexPaths)
        }
        return context
    }

    private var columnHeights: [[CGFloat]] = []
    private var sectionItemAttributes: [[UICollectionViewLayoutAttributes]] = []
    private var allItemAttributes: [UICollectionViewLayoutAttributes] = []
    private var headersAttributes: [Int: UICollectionViewLayoutAttributes] = [:]
    private var footersAttributes: [Int: UICollectionViewLayoutAttributes] = [:]
    private var unionRects: [CGRect] = []
    private let unionSize = 20
}

extension CHTCollectionViewWaterfallLayout {
    private func columnCount(forSection section: Int) -> Int {
        guard let collectionView = self.collectionView else {
            return columnCount
        }

        return delegate?.collectionView(collectionView,
                                        layout: self,
                                        columnCountFor: section) ?? columnCount
    }

    private var collectionViewContentWidth: CGFloat {
        guard let collectionView = self.collectionView else {
            return 0
        }

        let insets: UIEdgeInsets
        switch sectionInsetReference {
        case .fromContentInset:
            insets = collectionView.contentInset
        case .fromSafeArea:
            insets = collectionView.safeAreaInsets
        case .fromLayoutMargins:
            insets = collectionView.layoutMargins
        }
        return collectionView.bounds.size.width - insets.left - insets.right
    }

    private func collectionViewContentWidth(ofSection section: Int) -> CGFloat {
        guard let collectionView = self.collectionView else {
            return 0
        }

        let insets = delegate?.collectionView(collectionView,
                                              layout: self,
                                              insetsFor: section) ?? sectionInset
        return collectionViewContentWidth - insets.left - insets.right
    }

    /// Find the shortest column.
    ///
    /// - Returns: index for the shortest column
    private func shortestColumnIndex(inSection section: Int) -> Int {
        return columnHeights[section].enumerated()
            .min(by: { $0.element < $1.element })?
            .offset ?? 0
    }

    /// Find the longest column.
    ///
    /// - Returns: index for the longest column
    private func longestColumnIndex(inSection section: Int) -> Int {
        return columnHeights[section].enumerated()
            .max(by: { $0.element < $1.element })?
            .offset ?? 0
    }

    /// Find the index for the next column.
    ///
    /// - Returns: index for the next column
    private func nextColumnIndexForItem(_ item: Int, inSection section: Int) -> Int {
        var index = 0
        let columnCount = self.columnCount(forSection: section)
        switch itemRenderDirection {
        case .shortestFirst :
            index = shortestColumnIndex(inSection: section)
        case .leftToRight :
            index = item % columnCount
        case .rightToLeft:
            index = (columnCount - 1) - (item % columnCount)
        }
        return index
    }

    private func boundaries(forSection section: Int) -> (minimum: CGFloat, maximum: CGFloat) {
        var result = (minimum: CGFloat(0.0), maximum: CGFloat(0.0))

        guard let collectionView = collectionView else { return result }
        let numberOfItems = collectionView.numberOfItems(inSection: section)
        guard numberOfItems > 0 else { return result }

        if let firstItem = layoutAttributesForItem(at: IndexPath(item: 0, section: section)),
           let lastItem = layoutAttributesForItem(at: IndexPath(item: (numberOfItems - 1), section: section)) {
            result.minimum = firstItem.frame.minY
            result.maximum = lastItem.frame.maxY

            // Take Header Size Into Account
            result.minimum -= headerReferenceSize.height
            result.maximum -= headerReferenceSize.height

            // Take Section Inset Into Account
            let sectionInset = delegate?.collectionView(collectionView,
                                                        layout: self,
                                                        insetsFor: section) ?? self.sectionInset
            result.minimum -= sectionInset.top
            result.maximum += (sectionInset.top + sectionInset.bottom)
        }

        return result
    }
}
