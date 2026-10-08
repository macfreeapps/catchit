import SwiftUI

struct CatchItMenuBarMark: View {
    var body: some View {
        Canvas { context, size in
            let page = Path(roundedRect: CGRect(x: 2.5, y: 3, width: 9, height: 12), cornerRadius: 1.5)
            context.stroke(page, with: .foreground, style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))

            var textLines = Path()
            textLines.move(to: CGPoint(x: 4.5, y: 11.5))
            textLines.addLine(to: CGPoint(x: 9.1, y: 11.5))
            textLines.move(to: CGPoint(x: 4.5, y: 9))
            textLines.addLine(to: CGPoint(x: 8.2, y: 9))
            textLines.move(to: CGPoint(x: 4.5, y: 6.5))
            textLines.addLine(to: CGPoint(x: 7.2, y: 6.5))
            context.stroke(textLines, with: .foreground, style: StrokeStyle(lineWidth: 1.15, lineCap: .round))

            let lens = CGRect(x: 8.3, y: 6.2, width: 6.4, height: 6.4)
            context.stroke(Path(ellipseIn: lens), with: .foreground, style: StrokeStyle(lineWidth: 1.45))
            var handle = Path()
            handle.move(to: CGPoint(x: 13.1, y: 7.5))
            handle.addLine(to: CGPoint(x: 16, y: 4.6))
            context.stroke(handle, with: .foreground, style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
        }
        .frame(width: 18, height: 18)
        .accessibilityLabel("Catch It")
    }
}
