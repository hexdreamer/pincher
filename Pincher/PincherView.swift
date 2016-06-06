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
            self.backTransform = self.imageTransform!.invert()
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
        self.isMultipleTouchEnabled = true
        self.layer.addSublayer(layer)
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touch1 != nil && touch2 != nil {
            return
        }
        
        for obj in touches {
            let touch :UITouch = obj 
            let touchLoc = touch.location(in: self)
            
            if self.touch1 == nil {
                self.touch1 = touch
                self.p1p = touchLoc.apply(transform: self._backNormalizeTransform())
                self.p1 = self.p1p!.apply(transform: self.backTransform!)
                continue
            }
            if self.touch2 == nil {
                self.touch2 = touch
                self.p2p = touchLoc.apply(transform: self._backNormalizeTransform())
                self.p2 = self.p2p!.apply(transform: self.backTransform!)
                continue
            }
        }
        
        self._computeSolutionMatrix()
        if ( self.touchesUpdated != nil ) {
            self.touchesUpdated(self)
        }
    }
    
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for obj in touches {
            let touch :UITouch = obj 
            
            if self.touch1 == touch {
                p1p = touch.location(in: self).apply(transform: self._backNormalizeTransform())
            }
            if self.touch2 == touch {
                p2p = touch.location(in: self).apply(transform: self._backNormalizeTransform())
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
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
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
        guard
            let imageLayer = self.imageLayer,
            let image = self.image,
            let cgimage = image.cgImage else {
            return
        }

        let r = CGRect(x:0, y:0, width:cgimage.width, height:cgimage.height)
        imageLayer.contents = cgimage;
        imageLayer.bounds = r
        imageLayer.position = self.bounds.center
        self.imageTransform = self._initialTransform()
    }
    
    private func _normalizeTransform() -> CGAffineTransform {
        let center = self.bounds.center
        
        return CGAffineTransform(translationX: center.x, y: center.y)
    }
    
    private func _backNormalizeTransform() -> CGAffineTransform {
        return self._normalizeTransform().invert();
    }
    
    private func _initialTransform() -> CGAffineTransform {
        guard
            let image = self.image,
            let cgimage = image.cgImage else {
                return CGAffineTransform.identity;
        }

        let r = CGRect(x:0, y:0, width:cgimage.width, height:cgimage.height)
        let s = r.scaleIn(rect: self.bounds)
        
        return CGAffineTransform(scaleX: s, y: s)
    }
    
    private func _adjustScaleForBoundsChange() {
        guard
            let image = self.image,
            let cgimage = image.cgImage else {
            return
        }

        let r = CGRect(x:0, y:0, width:cgimage.width, height:cgimage.height)
        let oldIdeal = r.scaleAndCenterIn(rect: self.oldBounds!)
        let newIdeal = r.scaleAndCenterIn(rect: self.bounds)
        let s = newIdeal.height / oldIdeal.height
        
        self.imageTransform = self.imageTransform!.scaleBy(x: s, y: s)
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
            q2 = CGPoint(x: q1p.x + 10, y: q1p.y + 10)
            q2 = q2.apply(transform: self.backTransform!)
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
            return CGAffineTransform.identity
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
        
        var t :CGAffineTransform = CGAffineTransform.identity
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

