import Base
import ../../Runika/font.bend as F
import ../../Runika/check.bend as C
import ../main.bend as S
import ../caret.bend as SC

# Caret queries on one line of Portuguese. The final "é" is written with a
# combining acute accent (U+0301): it is one cluster spanning two scalars,
# so the index between "e" and its accent is not a stop.

def stop(s: SC.Stop) -> String:
  match s:
    case SC.Stop{index, x}:
      "stop " ++ U32.show(index) ++ "  x " ++ F32.show(x)

def print_stops(xs: List<&2, SC.Stop>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{s, rest}:
      do IO<Unit>:
        IO.print(stop(s))
        print_stops(rest)

def band(bs: List<&2, SC.Band>) -> String:
  match bs:
    case Nil{}:
      "no band"
    case Con{SC.Band{x, top, width, height}, rest}:
      "band x " ++ F32.show(x) ++ "  top " ++ F32.show(top) ++ "  width " ++ F32.show(width) ++
        "  height " ++ F32.show(height)

def unsupported(m: Maybe<&2, SC.Unsupported>) -> String:
  match m:
    case None{}:
      "supported"
    case Some{SC.Unsupported{index, scalar}}:
      "unsupported scalar " ++ U32.show(scalar) ++ " at index " ++ U32.show(index)

def line_height(l: S.Layout) -> F32:
  match l:
    case S.Layout{ps, w, h, asc, desc, lh, lines}: lh

def main() -> IO(Unit):
  do IO<Unit>:
    fr : Result<&2, &2, String, F.Font> <- F.load("/usr/share/fonts/liberation/LiberationSans-Regular.ttf")
    +font : F.Font <- C.unwrap(F.Font, fr)
    +l : S.Layout <- C.unwrap(S.Layout, S.layout(font, "Olá, ação! café", 20.0, 1000.0))
    +st : List<&2, SC.Stop> <- C.unwrap(List<&2, SC.Stop>, SC.stops(l))
    print_stops(st)
    IO.print("snap 15 -> " ++ U32.show(SC.snap(st, 15)) ++ "  caret_x " ++ F32.show(SC.caret_x(st, 15)))
    IO.print("hit 40 -> " ++ U32.show(SC.hit(st, 40.0)) ++ "  hit -3 -> " ++ U32.show(SC.hit(st, F32.neg(3.0))) ++
      "  hit 500 -> " ++ U32.show(SC.hit(st, 500.0)))
    IO.print("select 5..9: " ++ band(SC.selection(st, 9, 5, line_height(l))))
    IO.print("café ☕: " ++ unsupported(SC.unsupported(font, "café ☕")))
    IO.print("Olá, ação!: " ++ unsupported(SC.unsupported(font, "Olá, ação!")))
