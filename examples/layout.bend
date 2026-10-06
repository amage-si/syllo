import Base
import ../../Runika/font.bend as F
import ../../Runika/check.bend as C
import ../main.bend as S

# Lays out a Portuguese sentence in a narrow box and prints every placement.
# The second "café" uses a combining acute accent (U+0301): it maps to the
# same glyph as the precomposed form and keeps a two-scalar source span.

def placement(p: S.Placement) -> String:
  match p:
    case S.Placement{glyph, start, end, x, baseline, advance, line}:
      "line " ++ U32.show(line) ++ "  glyph " ++ U32.show(glyph) ++
        "  source [" ++ U32.show(start) ++ "," ++ U32.show(end) ++ ")" ++
        "  x " ++ F32.show(x) ++ "  baseline " ++ F32.show(baseline) ++
        "  advance " ++ F32.show(advance)

def print_all(ps: List<&2, S.Placement>) -> IO(Unit):
  match ps:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{p, rest}:
      do IO<Unit>:
        IO.print(placement(p))
        print_all(rest)

def summary(l: S.Layout) -> IO(Unit):
  match l:
    case S.Layout{ps, width, height, asc, desc, line_height, lines}:
      do IO<Unit>:
        print_all(ps)
        IO.print("lines " ++ U32.show(lines) ++ "  width " ++ F32.show(width) ++
          "  height " ++ F32.show(height) ++ "  line height " ++ F32.show(line_height))

def main() -> IO(Unit):
  do IO<Unit>:
    fr : Result<&2, &2, String, F.Font> <- F.load("/usr/share/fonts/liberation/LiberationSans-Regular.ttf")
    +font : F.Font <- C.unwrap(F.Font, fr)
    l : S.Layout <- C.unwrap(S.Layout, S.layout(font, "Ação e café, café.", 20.0, 120.0))
    summary(l)
