import AppKit

// One vector mark, drawn at the destination resolution for crisp menu bar and app icons.
enum MicBrand {
    static func menuImage(recording:Bool=false)->NSImage {
        let image=NSImage(size:NSSize(width:19,height:19),flipped:false){rect in
            NSColor.labelColor.setStroke()
            let body=NSBezierPath(roundedRect:NSRect(x:4,y:1,width:11,height:17),xRadius:2.5,yRadius:2.5)
            body.lineWidth=1.4;body.stroke()
            let capsule=NSBezierPath(roundedRect:NSRect(x:8,y:9,width:3,height:6),xRadius:1.5,yRadius:1.5)
            if recording {NSColor.labelColor.setFill();capsule.fill()} else {capsule.lineWidth=1.2;capsule.stroke()}
            let mic=NSBezierPath();mic.move(to:NSPoint(x:6.5,y:11));mic.line(to:NSPoint(x:6.5,y:9.5))
            mic.curve(to:NSPoint(x:12.5,y:9.5),controlPoint1:NSPoint(x:6.5,y:6),controlPoint2:NSPoint(x:12.5,y:6))
            mic.line(to:NSPoint(x:12.5,y:11));mic.lineWidth=1.2;mic.stroke()
            let stem=NSBezierPath();stem.move(to:NSPoint(x:9.5,y:7));stem.line(to:NSPoint(x:9.5,y:5));stem.lineWidth=1.2;stem.stroke()
            NSColor.labelColor.setFill();NSBezierPath(ovalIn:NSRect(x:8.5,y:2.5,width:2,height:1)).fill()
            return true
        }
        image.isTemplate=true;image.accessibilityDescription="Brick Mic";return image
    }
    static func drawIcon(in rect:NSRect) {
        NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
        let transform=NSAffineTransform();transform.translateX(by:rect.minX,yBy:rect.minY)
        transform.scaleX(by:rect.width/1024,yBy:rect.height/1024);transform.concat()
        let ivory=NSColor(srgbRed:0.95,green:0.93,blue:0.87,alpha:1)
        let green=NSColor(srgbRed:0.09,green:0.26,blue:0.22,alpha:1)
        let screen=NSColor(srgbRed:0.17,green:0.36,blue:0.30,alpha:1)
        let shadow=NSShadow();shadow.shadowColor=green.withAlphaComponent(0.16);shadow.shadowBlurRadius=26;shadow.shadowOffset=NSSize(width:0,height:-10);shadow.set()
        ivory.setFill();NSBezierPath(roundedRect:NSRect(x:64,y:64,width:896,height:896),xRadius:204,yRadius:204).fill()
        NSShadow().set()
        green.setFill();NSBezierPath(roundedRect:NSRect(x:290,y:183,width:444,height:658),xRadius:62,yRadius:62).fill()
        screen.setFill();NSBezierPath(roundedRect:NSRect(x:327,y:439,width:370,height:357),xRadius:28,yRadius:28).fill()
        ivory.setFill();NSBezierPath(roundedRect:NSRect(x:463,y:573,width:98,height:154),xRadius:49,yRadius:49).fill()
        ivory.setStroke()
        let mic=NSBezierPath();mic.move(to:NSPoint(x:420,y:630));mic.line(to:NSPoint(x:420,y:590))
        mic.curve(to:NSPoint(x:604,y:590),controlPoint1:NSPoint(x:420,y:464),controlPoint2:NSPoint(x:604,y:464))
        mic.line(to:NSPoint(x:604,y:630));mic.lineWidth=25;mic.lineCapStyle = .round;mic.stroke()
        let stem=NSBezierPath();stem.move(to:NSPoint(x:512,y:503));stem.line(to:NSPoint(x:512,y:476));stem.move(to:NSPoint(x:478,y:471));stem.line(to:NSPoint(x:546,y:471));stem.lineWidth=25;stem.lineCapStyle = .round;stem.stroke()
        ivory.setFill()
        NSBezierPath(roundedRect:NSRect(x:357,y:304,width:112,height:35),xRadius:8,yRadius:8).fill()
        NSBezierPath(roundedRect:NSRect(x:395.5,y:266,width:35,height:112),xRadius:8,yRadius:8).fill()
        NSBezierPath(ovalIn:NSRect(x:571,y:287,width:45,height:45)).fill()
        NSBezierPath(ovalIn:NSRect(x:637,y:333,width:45,height:45)).fill()
        ivory.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect:NSRect(x:484,y:224,width:56,height:8),xRadius:4,yRadius:4).fill()
    }
}
