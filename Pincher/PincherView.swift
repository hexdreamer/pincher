// Pincher
// PincherView.swift
// Copyright(c) 2016 Kenny Leung
// This code is PUBLIC DOMAIN

import UIKit
import hexdreamsCocoa

class PincherView: UIView {
    
    override var bounds :CGRect {
        willSet(newBounds) {
            oldBounds = self.bounds
        } didSet {
            self.imageLayer!.position = self.bounds.center
            self._adjustScaleForBoundsChange()
        }
    }
    var oldBounds :CGRect?
    
    var touch1  :UITouch?
    var touch2  :UITouch?
    var p1      :CGPoint?  // point 1 in image coordiate system
    var p2      :CGPoint?  // point 2 in image coordinate system
    var p1p     :CGPoint?  // point 1 in view coordinate system
    var p2p     :CGPoint?  // point 2 in view coordinate system
    var image   :UIImage? {
        didSet {self.reset()}
    }
    var imageLayer :CALayer? {
        didSet {self.reset()}
    }
    var imageTransform :CGAffineTransform? {
        didSet {
            self.backTransform = CGAffineTransformInvert(self.imageTransform!)
            self.imageLayer!.transform = CATransform3DMakeAffineTransform(self.imageTransform!)
        }
    }
    var backTransform  :CGAffineTransform?
    var solutionMatrix :HXMatrix?
    
    var touchesUpdated : ((PincherView) -> Void)! {
        didSet {
            if self.touchesUpdated != nil {
                self.touchesUpdated(self)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        let layer = CALayer();

        self.imageLayer = layer
        super.init(coder: aDecoder)
        self.multipleTouchEnabled = true
        self.layer.addSublayer(layer)
    }
    
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if touch1 != nil && touch2 != nil {
            return
        }
        
        for obj in touches {
            let touch :UITouch = obj 
            let touchLoc = touch.locationInView(self)
            
            if self.touch1 == nil {
                self.touch1 = touch
                self.p1p = CGPointApplyAffineTransform(touchLoc, self._backNormalizeTransform())
                self.p1 = CGPointApplyAffineTransform(self.p1p!, self.backTransform!)
                continue
            }
            if self.touch2 == nil {
                self.touch2 = touch
                self.p2p = CGPointApplyAffineTransform(touchLoc, self._backNormalizeTransform())
                self.p2 = CGPointApplyAffineTransform(self.p2p!, self.backTransform!)
                continue
            }
        }
        
        self._computeSolutionMatrix()
        if ( self.touchesUpdated != nil ) {
            self.touchesUpdated(self)
        }
    }
    
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for obj in touches {
            let touch :UITouch = obj 
            
            if self.touch1 == touch {
                p1p = CGPointApplyAffineTransform(touch.locationInView(self), self._backNormalizeTransform())
            }
            if self.touch2 == touch {
                p2p = CGPointApplyAffineTransform(touch.locationInView(self), self._backNormalizeTransform())
            }
        }
        
        CATransaction.begin()
        CATransaction.setValue(true, forKey:kCATransactionDisableActions)
        self.imageTransform = self._computeCurrentTransform()
        CATransaction.commit()
        
        if ( self.touchesUpdated != nil ) {
            self.touchesUpdated(self)
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if self.touch1 != nil && touches.contains(self.touch1!) {
            self.touch1 = nil
            self.p1 = nil
            self.p1p = nil
        }
        if self.touch2 != nil && touches.contains(self.touch2!) {
            self.touch2 = nil
            self.p2 = nil
            self.p2p = nil
        }
        
        self._computeSolutionMatrix()
        if ( self.touchesUpdated != nil ) {
            self.touchesUpdated(self)
        }
    }
    
    func reset() {
        if !(self.image != nil && self.imageLayer != nil) {
            return
        }
        
        let cgimage = self.image!.CGImage
        let r = CGRectMake(0, 0, CGFloat(CGImageGetWidth(cgimage)), CGFloat(CGImageGetHeight(cgimage)))
        self.imageLayer!.contents = cgimage;
        self.imageLayer!.bounds = r
        self.imageLayer!.position = self.bounds.center
        self.imageTransform = self._initialTransform()
    }
    
    private func _normalizeTransform() -> CGAffineTransform {
        let center = self.bounds.center
        
        return CGAffineTransformMakeTranslation(center.x, center.y)
    }
    
    private func _backNormalizeTransform() -> CGAffineTransform {
        return CGAffineTransformInvert(self._normalizeTransform());
    }
    
    private func _initialTransform() -> CGAffineTransform {
        if self.image == nil {
            return CGAffineTransformIdentity;
        }
        
        let cgimage = self.image!.CGImage
        let r = CGRectMake(0, 0, CGFloat(CGImageGetWidth(cgimage)), CGFloat(CGImageGetHeight(cgimage)))
        let s = r.scaleIn(self.bounds)
        
        return CGAffineTransformMakeScale(s, s)
    }
    
    private func _adjustScaleForBoundsChange() {
        let cgimage = self.image!.CGImage
        let r = CGRectMake(0, 0, CGFloat(CGImageGetWidth(cgimage)), CGFloat(CGImageGetHeight(cgimage)))
        let oldIdeal = r.scaleAndCenterIn(self.oldBounds!)
        let newIdeal = r.scaleAndCenterIn(self.bounds)
        let s = newIdeal.height / oldIdeal.height
        
        self.imageTransform = CGAffineTransformScale(self.imageTransform!, s, s)
    }
    
    private func _computeSolutionMatrix() {
        var q1  :CGPoint!
        var q1p :CGPoint!
        var q2  :CGPoint!
        
        if self.touch1 != nil && self.touch2 != nil {
            q1 = self.p1
            q2 = self.p2
        } else if self.touch1 != nil {
            q1 = self.p1
            q1p = self.p1p
        } else if self.touch2 != nil {
            q1 = self.p2
            q1p = self.p2p
        } else {
            return
        }
        
        if q2 == nil {
            q2 = CGPointMake(q1p.x + 10, q1p.y + 10)
            q2 = CGPointApplyAffineTransform(q2, self.backTransform!)
        }
        
        let x1 = Double(q1.x)
        let y1 = Double(q1.y)
        let x2 = Double(q2.x)
        let y2 = Double(q2.y)
        let A = HXMatrix(rows: 4, columns: 4, values:[
            x1, -y1, 1, 0,
            y1,  x1, 0, 1,
            x2, -y2, 1, 0,
            y2,  x2, 0, 1
            ])
        let B = A.inverse()
        self.solutionMatrix = B
    }
    
    private func _computeCurrentTransform() -> CGAffineTransform {
        var q1p :CGPoint!
        var q2p :CGPoint!
        
        if ( self.p1p != nil && self.p2p != nil ) {
            q1p = self.p1p
            q2p = self.p2p
        } else if self.p1p != nil {
            q1p = self.p1p
        } else if self.p2p != nil {
            q1p = self.p2p
        } else {
            return CGAffineTransformIdentity
        }
        
        if ( q2p == nil ) {
            q2p = CGPoint(x:q1p.x + 10, y:q1p.y + 10)
        }
        
        let x1p = Double(q1p.x)
        let y1p = Double(q1p.y)
        let x2p = Double(q2p.x)
        let y2p = Double(q2p.y)
        let B = HXMatrix(rows: 4, columns: 1, values: [
            x1p,
            y1p,
            x2p,
            y2p
            ])
        let C = self.solutionMatrix! ⋅ B
        
        var t :CGAffineTransform = CGAffineTransformIdentity
        let U = CGFloat(C[0,0])
        let V = CGFloat(C[1,0])
        let tx = CGFloat(C[2,0])
        let ty = CGFloat(C[3,0])
        
        t.a  =  U; t.b  = V
        t.c  = -V; t.d  = U
        t.tx = tx; t.ty = ty
        
        return t
    }
}

