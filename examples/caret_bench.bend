import Base
import ../../Runika/font.bend as F
import ../../Runika/check.bend as C
import ../main.bend as S
import ../caret.bend as SC

# Times the caret queries on one 256-scalar line of Portuguese at 20 px,
# repeating each query `runs` times (IO.now has millisecond resolution).
# Every loop folds its results into a checksum that is printed before the
# next clock read, so no work is left pending across a measurement.

def text() -> String:
  "Texto real em Bend: ação, coração, café e pão. " ++ "Olá! Edição de um campo só, com acentos: é, ê, ã, õ, ç. " ++
    "Texto real em Bend: ação, coração, café e pão. " ++ "Olá! Edição de um campo só, com acentos: é, ê, ã, õ, ç. " ++
    "Mais dezoito letras de teste, para fechar a linha."

def stops_count(xs: List<&2, SC.Stop>, acc: U32) -> U32:
  match xs:
    case Nil{}: acc
    case Con{SC.Stop{i, x}, rest}: stops_count(rest, (acc + 1 : U32))

def stops_of(r: Result<&2, &2, String, List<&2, SC.Stop>>) -> U32:
  match r:
    case Fail{e}: 0
    case Done{xs}: stops_count(xs, 0)

def layout_ok(r: Result<&2, &2, String, S.Layout>) -> U32:
  match r:
    case Fail{e}: 0
    case Done{l}: 1

def bands(bs: List<&2, SC.Band>) -> U32:
  match bs:
    case Nil{}: 0
    case Con{b, rest}: 1

def found(m: Maybe<&2, SC.Unsupported>) -> U32:
  match m:
    case None{}: 1
    case Some{u}: 0

def run_layout(n: Nat, +font: F.Font, +t: String, acc: U32) -> U32:
  match n:
    case 0n: acc
    case 1n+p: run_layout(p, font, t, (acc + layout_ok(S.layout(font, t, 20.0, 1000000.0)) : U32))

def run_stops(n: Nat, +l: S.Layout, acc: U32) -> U32:
  match n:
    case 0n: acc
    case 1n+p: run_stops(p, l, (acc + stops_of(SC.stops(l)) : U32))

def run_hit(n: Nat, +st: List<&2, SC.Stop>, +i: U32, acc: U32) -> U32:
  match n:
    case 0n: acc
    case 1n+p: run_hit(p, st, (i + 1 : U32), (acc + SC.hit(st, U32.to_f32((i % 3000 : U32))) : U32))

def run_caret(n: Nat, +st: List<&2, SC.Stop>, +i: U32, acc: F32) -> F32:
  match n:
    case 0n: acc
    case 1n+p: run_caret(p, st, (i + 1 : U32), (acc + SC.caret_x(st, (i % 257 : U32)) : F32))

def run_selection(n: Nat, +st: List<&2, SC.Stop>, +lh: F32, +i: U32, acc: U32) -> U32:
  match n:
    case 0n: acc
    case 1n+p: run_selection(p, st, lh, (i + 1 : U32), (acc + bands(SC.selection(st, 3, (i % 257 : U32), lh)) : U32))

def run_unsupported(n: Nat, +font: F.Font, +t: String, acc: U32) -> U32:
  match n:
    case 0n: acc
    case 1n+p: run_unsupported(p, font, t, (acc + found(SC.unsupported(font, t)) : U32))

def line_height(l: S.Layout) -> F32:
  match l:
    case S.Layout{ps, w, h, asc, desc, lh, lines}: lh

def report(+name: String, +runs: U32, +t0: Nat, +t1: Nat, +check: String) -> IO(Unit):
  IO.print(name ++ ": " ++ Nat.show(Nat.sub(t1, t0)) ++ " ms for " ++ U32.show(runs) ++ " runs  (check " ++ check ++ ")")

def main() -> IO(Unit):
  do IO<Unit>:
    fr : Result<&2, &2, String, F.Font> <- F.load("/usr/share/fonts/liberation/LiberationSans-Regular.ttf")
    +font : F.Font <- C.unwrap(F.Font, fr)
    +t : String = text()
    IO.print("scalars " ++ Nat.show(String.length(t)))
    +l : S.Layout <- C.unwrap(S.Layout, S.layout(font, t, 20.0, 1000000.0))
    +st : List<&2, SC.Stop> <- C.unwrap(List<&2, SC.Stop>, SC.stops(l))
    IO.print("stops " ++ U32.show(stops_count(st, 0)))
    +a0 : Nat <- IO.now()
    +a : U32 = run_layout(2000n, font, t, 0)
    IO.print("layout checksum " ++ U32.show(a))
    +a1 : Nat <- IO.now()
    +b : U32 = run_stops(2000n, l, 0)
    IO.print("stops checksum " ++ U32.show(b))
    +b1 : Nat <- IO.now()
    +c : U32 = run_hit(20000n, st, 0, 0)
    IO.print("hit checksum " ++ U32.show(c))
    +c1 : Nat <- IO.now()
    +d : F32 = run_caret(20000n, st, 0, 0.0)
    IO.print("caret_x checksum " ++ F32.show(d))
    +d1 : Nat <- IO.now()
    +e : U32 = run_selection(20000n, st, line_height(l), 0, 0)
    IO.print("selection checksum " ++ U32.show(e))
    +e1 : Nat <- IO.now()
    +f : U32 = run_unsupported(2000n, font, t, 0)
    IO.print("unsupported checksum " ++ U32.show(f))
    +f1 : Nat <- IO.now()
    report("layout (256 scalars)", 2000, a0, a1, U32.show(a))
    report("stops", 2000, a1, b1, U32.show(b))
    report("hit", 20000, b1, c1, U32.show(c))
    report("caret_x", 20000, c1, d1, F32.show(d))
    report("selection", 20000, d1, e1, U32.show(e))
    report("unsupported", 2000, e1, f1, U32.show(f))
