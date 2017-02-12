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
            self.imageLayer!.position = ┼self.bounds
            self._adjustScaleForBoundsChange()
        }
    }
    var oldBounds :CGRect?
    
    var touch₁  :UITouch?
    var touch₂  :UITouch?
    var p₁      :CGPoint?  // point 1 in image coordiate system
    var p₂      :CGPoint?  // point 2 in image coordinate system
    var p₁ʹ     :CGPoint?  // point 1 in view coordinate system
    var p₂ʹ     :CGPoint?  // point 2 in view coordinate system
    var image   :UIImage? {
        didSet {self.reset()}
    }
    var imageLayer :CALayer? {
        didSet {self.reset()}
    }
    var imageTransform :CGAffineTransform? {
        didSet {
            self.backTransform = self.imageTransform!.inverted()
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
        if touch₁ != nil && touch₂ != nil {
            return
        }
        
        for obj in touches {
            let touch :UITouch = obj 
            let touchLoc = touch.location(in: self)
            
            if self.touch₁ == nil {
                self.touch₁ = touch
                self.p₁ʹ = touchLoc.applying(self._backNormalizeTransform())
                self.p₁ = self.p₁ʹ!.applying(self.backTransform!)
                continue
            }
            if self.touch₂ == nil {
                self.touch₂ = touch
                self.p₂ʹ = touchLoc.applying(self._backNormalizeTransform())
                self.p₂ = self.p₂ʹ!.applying(self.backTransform!)
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
            
            if self.touch₁ == touch {
                p₁ʹ = touch.location(in: self).applying(self._backNormalizeTransform())
            }
            if self.touch₂ == touch {
                p₂ʹ = touch.location(in: self).applying(self._backNormalizeTransform())
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
        if self.touch₁ != nil && touches.contains(self.touch₁!) {
            self.touch₁ = nil
            self.p₁ = nil
            self.p₁ʹ = nil
        }
        if self.touch₂ != nil && touches.contains(self.touch₂!) {
            self.touch₂ = nil
            self.p₂ = nil
            self.p₂ʹ = nil
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
        imageLayer.position = ┼self.bounds
        self.imageTransform = self._initialTransform()
    }
    
    fileprivate func _normalizeTransform() -> CGAffineTransform {
        let center = ┼self.bounds
        
        return CGAffineTransform(translationX: center.x, y: center.y)
    }
    
    fileprivate func _backNormalizeTransform() -> CGAffineTransform {
        return self._normalizeTransform().inverted();
    }
    
    fileprivate func _initialTransform() -> CGAffineTransform {
        guard
            let image = self.image,
            let cgimage = image.cgImage else {
                return CGAffineTransform.identity;
        }

        let r = CGRect(x:0, y:0, width:cgimage.width, height:cgimage.height)
        let s = r.scaleIn(rect: self.bounds)
        
        return CGAffineTransform(scaleX: s, y: s)
    }
    
    fileprivate func _adjustScaleForBoundsChange() {
        guard
            let image = self.image,
            let cgimage = image.cgImage else {
            return
        }

        let r = CGRect(x:0, y:0, width:cgimage.width, height:cgimage.height)
        let oldIdeal = r.scaleAndCenterIn(rect: self.oldBounds!)
        let newIdeal = r.scaleAndCenterIn(rect: self.bounds)
        let s = newIdeal.height / oldIdeal.height
        
        self.imageTransform = self.imageTransform!.scaledBy(x: s, y: s)
    }
    
    fileprivate func _computeSolutionMatrix() {
        var q₁  :CGPoint!
        var q₁ʹ :CGPoint!
        var q₂  :CGPoint!
        
        if self.touch₁ != nil && self.touch₂ != nil {
            q₁ = self.p₁
            q₂ = self.p₂
        } else if self.touch₁ != nil {
            q₁ = self.p₁
            q₁ʹ = self.p₁ʹ
        } else if self.touch₂ != nil {
            q₁ = self.p₂
            q₁ʹ = self.p₂ʹ
        } else {
            return
        }
        
        if q₂ == nil {
            q₂ = CGPoint(x: q₁ʹ.x + 10, y: q₁ʹ.y + 10)
            q₂ = q₂.applying(self.backTransform!)
        }
        
        let x₁ = Double(q₁.x)
        let y₁ = Double(q₁.y)
        let x₂ = Double(q₂.x)
        let y₂ = Double(q₂.y)
        let A = HXMatrix(rows: 4, columns: 4, values:[
            x₁, -y₁, 1, 0,
            y₁,  x₁, 0, 1,
            x₂, -y₂, 1, 0,
            y₂,  x₂, 0, 1
            ])
        let B = A.inverse()
        self.solutionMatrix = B
    }
    
    fileprivate func _computeCurrentTransform() -> CGAffineTransform {
        var q₁ʹ :CGPoint!
        var q₂ʹ :CGPoint!
        
        if ( self.p₁ʹ != nil && self.p₂ʹ != nil ) {
            q₁ʹ = self.p₁ʹ
            q₂ʹ = self.p₂ʹ
        } else if self.p₁ʹ != nil {
            q₁ʹ = self.p₁ʹ
        } else if self.p₂ʹ != nil {
            q₁ʹ = self.p₂ʹ
        } else {
            return CGAffineTransform.identity
        }
        
        if ( q₂ʹ == nil ) {
            q₂ʹ = CGPoint(x:q₁ʹ.x + 10, y:q₁ʹ.y + 10)
        }
        
        let x₁ʹ = Double(q₁ʹ.x)
        let y₁ʹ = Double(q₁ʹ.y)
        let x₂ʹ = Double(q₂ʹ.x)
        let y₂ʹ = Double(q₂ʹ.y)
        let B = HXMatrix(rows: 4, columns: 1, values: [
            x₁ʹ,
            y₁ʹ,
            x₂ʹ,
            y₂ʹ
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

