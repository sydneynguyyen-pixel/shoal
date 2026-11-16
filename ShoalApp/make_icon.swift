import SwiftUI
import AppKit

func C(_ h: UInt32, _ a: Double = 1) -> Color { Color(.sRGB, red: Double((h>>16)&255)/255, green: Double((h>>8)&255)/255, blue: Double(h&255)/255, opacity: a) }

// Five stones of the Shoal mark, as in start.js: piece, x%, y%, w%, h%, rotation
let MARK: [(String, Double, Double, Double, Double, Double)] = [
  ("top", 50, 18, 29, 18, 0),
  ("right", 79.48, 40.42, 25, 16, 72),
  ("bottom-right", 69.1, 76.3, 30, 19, 144),
  ("bottom-left", 32.07, 74.68, 23, 15, -144),
  ("lit", 20.05, 40.27, 37.53, 27.53, -72),
]

struct Mark: View {
  var s: CGFloat
  var body: some View {
    ZStack(alignment: .topLeading) {
      ForEach(MARK, id: \.0) { m in
        let lit = m.0 == "lit"
        // the lit svg has 5px padding for its glow; the ellipse is 25.65 x 16.15 of 35.65 x 26.15
        let w = s * m.3 / 100 * (lit ? 25.65 / 35.65 : 1), h = s * m.4 / 100 * (lit ? 16.15 / 26.15 : 1)
        Ellipse().fill(lit ? C(0x82DAFF) : C(0x0F4C93))
          .frame(width: w, height: h)
          .shadow(color: lit ? C(0x418EF3, 0.9) : .clear, radius: s * 0.05)
          .shadow(color: lit ? C(0x418EF3, 0.6) : .clear, radius: s * 0.12)
          .rotationEffect(.degrees(m.5))
          .position(x: s * m.1 / 100, y: s * m.2 / 100)
      }
    }
    .frame(width: s, height: s)
  }
}

struct Icon: View {
  var body: some View {
    ZStack {
      LinearGradient(colors: [.white, C(0xeef5ff)], startPoint: .top, endPoint: .bottom)
      Mark(s: 640).shadow(color: C(0x0F4C93, 0.12), radius: 24, y: 12)
    }
    .frame(width: 1024, height: 1024)
    .clipped()
  }
}

@MainActor func render() {
  let r = ImageRenderer(content: Icon())
  r.scale = 1
  guard let cg = r.cgImage else { print("fail"); return }
  let rep = NSBitmapImageRep(cgImage: cg)
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
  print("ok")
}
MainActor.assumeIsolated { render() }
