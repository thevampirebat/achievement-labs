import AppKit
import Foundation
let root = URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let target = root.appendingPathComponent("mobile/App/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at:target,withIntermediateDirectories:true)
let image = NSImage(contentsOf:root.appendingPathComponent("src/AchievementLabs.App/Assets/achievement-labs-icon.png"))!
let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,bitsPerSample:8,samplesPerPixel:3,hasAlpha:false,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
NSGraphicsContext.current?.imageInterpolation = .high
NSColor.black.setFill(); NSRect(x:0,y:0,width:1024,height:1024).fill()
image.draw(in:NSRect(x:0,y:0,width:1024,height:1024),from:.zero,operation:.sourceOver,fraction:1)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:target.appendingPathComponent("Icon.png"))
let contents = #"{"images":[{"filename":"Icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}"#
try Data(contents.utf8).write(to:target.appendingPathComponent("Contents.json"))
try Data(#"{"info":{"author":"xcode","version":1}}"#.utf8).write(to:target.deletingLastPathComponent().appendingPathComponent("Contents.json"))
print("Prepared the existing app icon for iPhone and iPad.")
