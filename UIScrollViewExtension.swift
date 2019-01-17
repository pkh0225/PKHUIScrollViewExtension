//
//  UIScrollViewExtension.swift
//  WiggleSDK
//
//  Created by pkh on 2018. 5. 23..
//  Copyright © 2018년 mykim. All rights reserved.
//

import Foundation
import UIKit

public typealias ScrollViewClosure = (_ obj: UIScrollView, _ newValue: CGPoint, _ oldValue: CGPoint) -> Void

extension UIScrollView {
    private struct AssociatedKeys {
        static var headerView: UInt8 = 0
        static var footerView: UInt8 = 0
        static var topInsetView: UInt8 = 0
        static var headerViewIsSticky: UInt = 0
        static var kvoOffsetCallback: UInt = 0
        static var offsetObserver: UInt = 0
        static var insetObserver: UInt = 0
        static var contentSizeObserver: UInt = 0
        static var headerViewFrameObserver: UInt = 0
    }
    
    //MARK:- Observer를 중복으로 Add하는 방지를 위한 Bool 값들
    public var offsetObserver: NSKeyValueObservation? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.offsetObserver) as? NSKeyValueObservation
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.offsetObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    public var insetObserver: NSKeyValueObservation? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.insetObserver) as? NSKeyValueObservation
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.insetObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    public var contentSizeObserver: NSKeyValueObservation? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.contentSizeObserver) as? NSKeyValueObservation
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.contentSizeObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    public var headerViewFrameObserver: NSKeyValueObservation? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.headerViewFrameObserver) as? NSKeyValueObservation
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.headerViewFrameObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    //MARK:- Sticky Header
    public var headerViewIsSticky: Bool {
        get {
            if let result = objc_getAssociatedObject(self, &AssociatedKeys.headerViewIsSticky) as? Bool {
                return result
            }
            return false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.headerViewIsSticky, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    //MARK:- Custom Header & Mall Footer
    public var customHeaderView: UIView? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.headerView) as? UIView
        }
        set {
            addObserverOffset()
            addObserverInset()
            
            var beforeViewHeight:CGFloat = 0
            if let customHeaderView = self.customHeaderView {
                self.headerViewFrameObserver = nil
                beforeViewHeight = customHeaderView.frame.size.height
                customHeaderView.removeFromSuperview()
            }
            
            objc_setAssociatedObject(self, &AssociatedKeys.headerView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            guard let view = newValue else { return }
            view.autoresizingMask = .flexibleWidth
            view.frame.size.width = self.frame.size.width
            self.addSubview(view)

            self.contentInset = UIEdgeInsets(top: floor(self.contentInset.top + view.frame.size.height - beforeViewHeight), left: self.contentInset.left, bottom: self.contentInset.bottom, right: self.contentInset.right)
           
            addObserverHeaderViewFrame()
        }
    }
    
    public var customFooterView: UIView? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.footerView) as? UIView
        }
        set {
            addObserverInset()
            addObserverContentSize()
            
            var beforeViewHeight:CGFloat = 0
            if let customFooterView = self.customFooterView {
                beforeViewHeight = customFooterView.frame.size.height
                customFooterView.removeFromSuperview()
            }
            
            objc_setAssociatedObject(self, &AssociatedKeys.footerView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            guard let view = newValue else { return }
            view.frame.origin.x = 0
            view.frame.origin.y = self.contentSize.height
            view.frame.size.width = self.frame.size.width
            view.autoresizingMask = .flexibleWidth
            self.addSubview(view)
            
            self.contentInset = UIEdgeInsets(top: self.contentInset.top, left: self.contentInset.left, bottom: floor(self.contentInset.bottom + view.frame.size.height - beforeViewHeight), right: self.contentInset.right)
            
        }
    }
    
    //MARK:- Add Top Inset View
    public var topInsetView: UIView? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.topInsetView) as? UIView
        }
        set {
            if let topInsetView = self.topInsetView, newValue == nil {
                self.contentInset = UIEdgeInsets(top: self.contentInset.top - topInsetView.frame.size.height, left: self.contentInset.left, bottom: self.contentInset.bottom, right: self.contentInset.right)
                topInsetView.removeFromSuperview()
            }
            objc_setAssociatedObject(self, &AssociatedKeys.topInsetView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    public func addTopInset(color: UIColor, height: CGFloat) {
        addObserverInset()
        
        if let topInsetView = self.topInsetView {
            topInsetView.frame.size.height = height
            topInsetView.backgroundColor = color
        }
        else {
            topInsetView = UIView(frame: CGRect(x: 0, y: -self.contentInset.top, w: self.frame.size.width, h: height))
            topInsetView?.autoresizingMask = .flexibleWidth
            topInsetView!.backgroundColor = color
            self.addSubview(topInsetView!)
        }
        
        self.contentInset = UIEdgeInsets(top: height + self.contentInset.top, left: self.contentInset.left, bottom: self.contentInset.bottom, right: self.contentInset.bottom)
    }
    
    public func removeTopInset() {
        topInsetView = nil
    }
    
    //MARK:- Refresh Callback (Offset 값의 변화를 받은 뒤 처리)
    public func addKvoOffsetCallback(_ clousre: @escaping ScrollViewClosure) {
        self.addObserverOffset()
        if var clouserArray = objc_getAssociatedObject(self, &AssociatedKeys.kvoOffsetCallback) as? [ScrollViewClosure] {
            clouserArray.append(clousre)
            objc_setAssociatedObject(self, &AssociatedKeys.kvoOffsetCallback, clouserArray, .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        else {
            var clouserArray = [ScrollViewClosure]()
            clouserArray.append(clousre)
            objc_setAssociatedObject(self, &AssociatedKeys.kvoOffsetCallback, clouserArray, .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    //MARK:- Refresh Callback (Offset 값의 변화를 받은 뒤 처리)
    public var kvoOffsetCallbacks: [ScrollViewClosure]? {
        return objc_getAssociatedObject(self, &AssociatedKeys.kvoOffsetCallback) as? [ScrollViewClosure]
    }
    
    //MARK:- Inset Observer
    private func addObserverInset() {
        guard self.insetObserver == nil else { return }
        self.insetObserver = self.observe(\.contentInset, options: [.old, .new]) { [weak self] (obj, change) in
            guard let `self` = self else { return }
            if let headerView = self.customHeaderView {
                headerView.frame.origin.y = -headerView.frame.size.height
            }
            
            if let topInsetView = self.topInsetView {
                topInsetView.frame.origin.y = -self.contentInset.top
            }
            
            if let footerView = self.customFooterView {
                footerView.frame.origin.y = self.contentSize.height
            }
        }
    }
    
    //MARK:- Content Offset Observer
    private func addObserverOffset() {
        guard self.offsetObserver == nil else { return }
        self.offsetObserver = self.observe(\.contentOffset, options: [.old, .new]) { [weak self] (obj, change) in
            guard let `self` = self else { return }
            guard let newValue = change.newValue, let oldValue = change.oldValue else { return }
            
            if floor(newValue.y) != floor(oldValue.y) {
                if let kvoOffsetCallbacks = self.kvoOffsetCallbacks {
                    for clousre in kvoOffsetCallbacks {
                        clousre(obj, newValue, oldValue)
                    }
                }
                
            }
            
            guard let headerView = self.customHeaderView else { return }
            if self.headerViewIsSticky {
                let new = newValue.y
                //            let old = oldValue.cgPointValue.y
                if new > -self.contentInset.top {
                    headerView.frame.origin.y = new // sticky
                }
                else {
                    headerView.frame.origin.y = -headerView.frame.size.height
                }
            }
            else {
                headerView.frame.origin.y = -headerView.frame.size.height
            }
        }
        
    }
    
    
    //MARK:- Content Size Observer
    private func addObserverContentSize() {
        guard self.contentSizeObserver == nil else { return }
        self.contentSizeObserver = self.observe(\.contentSize, options: [.old, .new]) { [weak self] (obj, change) in
            guard let `self` = self else { return }
            guard let newValue = change.newValue, let oldValue = change.oldValue else { return }
            guard newValue != oldValue else { return }
            if let footerView = self.customFooterView {
                footerView.frame.origin.y = self.contentSize.height
                //                print("self.contentSize.height: \(self.contentSize.height)")
            }
        }
    }
    
    
    //MARK:- HeaderView Frame Observer
    private func addObserverHeaderViewFrame() {
        guard let headerView = self.customHeaderView else { return }
        guard self.headerViewFrameObserver == nil else { return }
        self.headerViewFrameObserver = headerView.observe(\.frame, options: [.old, .new]) { [weak self] (obj, change) in
            guard let `self` = self else { return }
            guard let newValue = change.newValue, let oldValue = change.oldValue else { return }
            guard floor(newValue.h) != floor(oldValue.h) else { return }
            self.contentInset = UIEdgeInsets(top: floor(self.contentInset.top + newValue.h - oldValue.h), left: self.contentInset.left, bottom: self.contentInset.bottom, right: self.contentInset.right)
        }
    }
    
    
    public func removeObserverAll() {
        self.insetObserver = nil
        self.offsetObserver = nil
        self.contentSizeObserver = nil
        self.headerViewFrameObserver = nil
    }
}
