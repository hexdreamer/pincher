# pincher
This is a sample program illustrating the pinch gesture for simultaneously rotating and resizing an image on iOS.

There are various hand-wavy solutions for doing the pinch to resize-rotate gesture that get the job done, but they typically have a disconnected feel between your finger motion and the image underneath. That is, the image will get translated and rotated, but may slide around under your fingers in an unrealistic manner.

This example directly computes the transformation matrix to match your finger motions rather than doing sequential translate-then-rotate transforms.

You can find a richer explanation at http://www.algorhythmicpoet.com/articles/pincher
