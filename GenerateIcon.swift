import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.88, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let green = NSColor(calibratedRed: 0.18, green: 0.35, blue: 0.29, alpha: 1)
let paper = NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.95, alpha: 1)

let sheet = NSBezierPath(roundedRect: NSRect(x: 205, y: 210, width: 614, height: 620), xRadius: 74, yRadius: 74)
paper.setFill()
sheet.fill()
green.setStroke()
sheet.lineWidth = 21
sheet.stroke()

let cat = NSBezierPath()
cat.move(to: NSPoint(x: 317, y: 436))
cat.line(to: NSPoint(x: 317, y: 678))
cat.line(to: NSPoint(x: 421, y: 603))
cat.curve(to: NSPoint(x: 603, y: 603), controlPoint1: NSPoint(x: 477, y: 629), controlPoint2: NSPoint(x: 547, y: 629))
cat.line(to: NSPoint(x: 707, y: 678))
cat.line(to: NSPoint(x: 707, y: 436))
cat.curve(to: NSPoint(x: 512, y: 316), controlPoint1: NSPoint(x: 704, y: 344), controlPoint2: NSPoint(x: 621, y: 316))
cat.curve(to: NSPoint(x: 317, y: 436), controlPoint1: NSPoint(x: 403, y: 316), controlPoint2: NSPoint(x: 320, y: 344))
cat.close()
green.setFill()
cat.fill()

paper.setFill()
NSBezierPath(ovalIn: NSRect(x: 416, y: 487, width: 36, height: 48)).fill()
NSBezierPath(ovalIn: NSRect(x: 572, y: 487, width: 36, height: 48)).fill()

let nose = NSBezierPath()
nose.move(to: NSPoint(x: 491, y: 444))
nose.line(to: NSPoint(x: 533, y: 444))
nose.line(to: NSPoint(x: 512, y: 421))
nose.close()
paper.setFill()
nose.fill()

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: "TranslateCat/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
