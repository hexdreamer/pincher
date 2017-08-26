// Pincher
// PincherView.swift
// Copyright(c) 2016 Kenny Leung
// This code is PUBLIC DOMAIN

import UIKit

class PincherView: UIView {
    
    override var bounds :CGRect {
        willSet(newBounds) {
            oldBounds = self.bounds
        } didSet {
            self.imageLayer.position = ┼self.bounds
            self._adjustScaleForBoundsChange()
        }
    }
    var oldBounds :CGRect
    
    var touch₁  :UITouch?
    var touch₂  :UITouch?
    var p₁      :CGPoint?  // point 1 in image coordiate system
    var p₂      :CGPoint?  // point 2 in image coordinate system
    var p₁ʹ     :CGPoint?  // point 1 in view coordinate system
    var p₂ʹ     :CGPoint?  // point 2 in view coordinate system
    var image   :UIImage? {
        didSet {self.reset()}
    }
    var imageLayer :CALayer
    var imageTransform :CGAffineTransform? {
        didSet {
            self.backTransform = self.imageTransform!.inverted()
            self.imageLayer.transform = CATransform3DMakeAffineTransform(self.imageTransform!)
        }
    }
    var backTransform  :CGAffineTransform
    var solutionMatrix :HXMatrix?
    
    required init?(coder aDecoder: NSCoder) {
        self.oldBounds = CGRect.zero
        let layer = CALayer();
        self.imageLayer = layer
        self.backTransform = CGAffineTransform.identity
        
        super.init(coder: aDecoder)
        
        self.oldBounds = self.bounds
        self.isMultipleTouchEnabled = true
        self.layer.addSublayer(layer)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pʹ = touch.location(in: self).applying(self._backNormalizeTransform())
            let p = pʹ.applying(self.backTransform)
            if self.touch₁ == nil {
                self.touch₁ = touch
                self.p₁ʹ = pʹ
                self.p₁ = p
            } else if self.touch₂ == nil {
                self.touch₂ = touch
                self.p₂ʹ = pʹ
                self.p₂ = p
            }
        }
        self._computeSolutionMatrix()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pʹ = touch.location(in: self).applying(self._backNormalizeTransform())
            if self.touch₁ == touch {
                self.p₁ʹ = pʹ
            } else if self.touch₂ == touch {
                self.p₂ʹ = pʹ
            }
        }
        
        CATransaction.begin()
        CATransaction.setValue(true, forKey:kCATransactionDisableActions)
        // Whether you're using 1 finger or 2 fingers
        if let q₁ʹ = self.p₁ʹ, let q₂ʹ = self.p₂ʹ {
            self.imageTransform = self._computeTransform(q₁ʹ, q₂ʹ)
        } else if let q₁ʹ = (self.p₁ʹ != nil ? self.p₁ʹ : self.p₂ʹ) {
            self.imageTransform = self._computeTransform(q₁ʹ, CGPoint(x:q₁ʹ.x + 10, y:q₁ʹ.y + 10))
        }
        CATransaction.commit()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if self.touch₁ == touch {
                self.touch₁ = nil
                self.p₁ = nil
                self.p₁ʹ = nil
            } else if self.touch₂ == touch {
                self.touch₂ = nil
                self.p₂ = nil
                self.p₂ʹ = nil
            }
        }
        self._computeSolutionMatrix()
    }
    
    func reset() {
        guard
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
    
    //MARK: Private Methods
    
    private func _normalizeTransform() -> CGAffineTransform {
        let center = ┼self.bounds
        return CGAffineTransform(translationX: center.x, y: center.y)
    }
    
    private func _backNormalizeTransform() -> CGAffineTransform {
        return self._normalizeTransform().inverted();
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
        let oldIdeal = r.scaleAndCenterIn(rect: self.oldBounds)
        let newIdeal = r.scaleAndCenterIn(rect: self.bounds)
        let s = newIdeal.height / oldIdeal.height
        self.imageTransform = self.imageTransform!.scaledBy(x: s, y: s)
    }
    
    private func _computeSolutionMatrix() {
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
            q₂ = q₂.applying(self.backTransform)
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
    
    private func _computeTransform(_ q₁ʹ:CGPoint, _ q₂ʹ:CGPoint) -> CGAffineTransform {
        let B = HXMatrix(rows: 4, columns: 1, values: [
            Double(q₁ʹ.x),
            Double(q₁ʹ.y),
            Double(q₂ʹ.x),
            Double(q₂ʹ.y)
            ])
        let C = self.solutionMatrix! ⋅ B
        
        let  U = CGFloat(C[0,0])
        let  V = CGFloat(C[1,0])
        let tx = CGFloat(C[2,0])
        let ty = CGFloat(C[3,0])
        
        var  t :CGAffineTransform = CGAffineTransform.identity
        t.a  =  U; t.b  = V
        t.c  = -V; t.d  = U
        t.tx = tx; t.ty = ty
        
        return t
    }
}

