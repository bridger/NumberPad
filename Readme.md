Building
---

This project has several targets. The main math app is the NumberPad target. There is also a DigitRecognizer target that is for working on the handwriting recognition alone. The DigitRecognizerSDK is a dependency of both of them, and contains the algorithms for the handwriting recognition. It is in a separate target so that the compiler can optimize it indepdently.

Sometimes, when building NumberPad, Xcode will complain that it can't build DigitRecognizerSDK. Building the DigitRecognizer target and then going back to NumberPad seems to fix this issue. `¯\_(ツ)_/¯`

Using NumberPad
---

Draw a number, or "x", "/", "+", or "-". Unfortunately, these can only be recognized one at a time. The handwriting recognizer kicks in if you wait a bit, or if the next stroke you draw is sufficiently far away.

Drag from a number to a multiplier or adder to connect them. Tap and hold to move objects around. Use two-finger tap to delete something (couldn't get double-tap to work...). Tap a single time on a number to show the slider.
