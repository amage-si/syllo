import Base
import ./main.bend as S
import ./caret.bend as SC
import ../Runika/font.bend as F
import ../Runika/check.bend as C

# Caret checks with Liberation Sans 2.1.5. At 20 px (2048 units per em) "A"
# advances 1366 units = 13.33984375, "a" and "ã" 1139 = 11.123046875, and
# the space 569 = 5.556640625; every value below is exact in F32.

def same_stops(a: List<&2, SC.Stop>, b: List<&2, SC.Stop>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{SC.Stop{ai, ax}, at} Con{SC.Stop{bi, bx}, bt}:
      U32.is_eq(ai, bi) && F32.is_eq(ax, bx) && same_stops(at, bt)
    case _ _: False{}

def is_stops(r: Result<&2, &2, String, List<&2, SC.Stop>>, expected: List<&2, SC.Stop>) -> Bool:
  match r:
    case Fail{e}: False{}
    case Done{xs}: same_stops(xs, expected)

def same_bands(a: List<&2, SC.Band>, b: List<&2, SC.Band>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{SC.Band{ax, at, aw, ah}, ar} Con{SC.Band{bx, bt, bw, bh}, br}:
      F32.is_eq(ax, bx) && F32.is_eq(at, bt) && F32.is_eq(aw, bw) && F32.is_eq(ah, bh) && same_bands(ar, br)
    case _ _: False{}

def is_unsupported(m: Maybe<&2, SC.Unsupported>, +index: U32, +scalar: U32) -> Bool:
  match m:
    case None{}: False{}
    case Some{SC.Unsupported{i, s}}: U32.is_eq(i, index) && U32.is_eq(s, scalar)

def is_none(m: Maybe<&2, SC.Unsupported>) -> Bool:
  match m:
    case None{}: True{}
    case Some{u}: False{}

# Whether `unsupported` and S.layout agree on a text: None exactly when the
# layout succeeds.
def agrees(m: Maybe<&2, SC.Unsupported>, r: Result<&2, &2, String, S.Layout>) -> Bool:
  match m r:
    case None{} Done{l}: True{}
    case Some{u} Fail{e}: True{}
    case _ _: False{}

def line_height(l: S.Layout) -> F32:
  match l:
    case S.Layout{ps, w, h, asc, desc, lh, lines}: lh

def width(l: S.Layout) -> F32:
  match l:
    case S.Layout{ps, w, h, asc, desc, lh, lines}: w

def last_x(xs: List<&2, SC.Stop>, acc: F32) -> F32:
  match xs:
    case Nil{}: acc
    case Con{SC.Stop{i, x}, rest}: last_x(rest, x)

def repeat(n: Nat, +c: Char, acc: String) -> String:
  match n:
    case 0n: acc
    case 1n+p: repeat(p, c, SCon{c, acc})

def main() -> IO(Unit):
  do IO<Unit>:
    fr : Result<&2, &2, String, F.Font> <- F.load("/usr/share/fonts/liberation/LiberationSans-Regular.ttf")
    +font : F.Font <- C.unwrap(F.Font, fr)
    +aa : S.Layout <- C.unwrap(S.Layout, S.layout(font, "AA", 20.0, 1000.0))
    +lh : F32 = line_height(aa)
    +st : List<&2, SC.Stop> <- C.unwrap(List<&2, SC.Stop>, SC.stops(aa))
    C.expect(same_stops(st, [SC.Stop{0, 0.0}, SC.Stop{1, 13.33984375}, SC.Stop{2, 26.6796875}]),
      "AA at 20 px: stops (0, 0), (1, 13.33984375), (2, 26.6796875)")
    C.expect(U32.is_eq(SC.hit(st, 6.669921875), 0), "x 6.669921875, the exact midpoint, goes left to 0")
    C.expect(U32.is_eq(SC.hit(st, 6.67), 1), "x 6.67, just right of the midpoint, hits 1")
    C.expect(U32.is_eq(SC.hit(st, 6.66), 0), "x 6.66, just left of the midpoint, hits 0")
    C.expect(U32.is_eq(SC.hit(st, 20.009765625), 1), "the second midpoint 20.009765625 goes left to 1")
    C.expect(U32.is_eq(SC.hit(st, F32.neg(5.0)), 0), "negative x hits the first stop")
    C.expect(U32.is_eq(SC.hit(st, 1000.0), 2), "x past the end hits the end stop")
    C.expect(U32.is_eq(SC.snap(st, 7), 2) && F32.is_eq(SC.caret_x(st, 7), 26.6796875),
      "an index past the end clamps to the end stop and its x")
    C.expect(F32.is_eq(SC.caret_x(st, 1), 13.33984375), "caret_x of index 1 is the second pen x")
    C.expect(same_bands(SC.selection(st, 0, 2, lh), [SC.Band{0.0, 0.0, 26.6796875, lh}]),
      "selecting 0..2 is one band 26.6796875 wide and one line high")
    C.expect(same_bands(SC.selection(st, 2, 1, lh), [SC.Band{13.33984375, 0.0, 13.33984375, lh}]),
      "a backwards selection 2..1 gives the same band as 1..2")
    C.expect(same_bands(SC.selection(st, 1, 1, lh), Nil{}), "an empty selection gives no band")
    C.expect(same_bands(SC.selection(st, 1, 9, lh), [SC.Band{13.33984375, 0.0, 13.33984375, lh}]),
      "a selection end past the text clamps to the end stop")
    +marks : S.Layout <- C.unwrap(S.Layout, S.layout(font, "ãé", 20.0, 1000.0))
    +ms : List<&2, SC.Stop> <- C.unwrap(List<&2, SC.Stop>, SC.stops(marks))
    C.expect(same_stops(ms, [SC.Stop{0, 0.0}, SC.Stop{1, 11.123046875}, SC.Stop{3, 22.24609375}]),
      "ãé (é combining) has stops at indices 0, 1 and 3")
    C.expect(U32.is_eq(SC.snap(ms, 2), 1) && F32.is_eq(SC.caret_x(ms, 2), 11.123046875),
      "index 2, between e and its accent, snaps to 1")
    C.expect(U32.is_eq(SC.snap(ms, 3), 3), "index 3 is the end stop")
    C.expect(same_bands(SC.selection(ms, 0, 2, lh), [SC.Band{0.0, 0.0, 11.123046875, lh}]),
      "a selection ending inside a cluster snaps back to the cluster start")
    C.expect(U32.is_eq(SC.hit(ms, 20.0), 3), "a hit on the composed é lands on a cluster edge (3)")
    +space : S.Layout <- C.unwrap(S.Layout, S.layout(font, "A ", 20.0, 1000.0))
    +ss : List<&2, SC.Stop> <- C.unwrap(List<&2, SC.Stop>, SC.stops(space))
    C.expect(same_stops(ss, [SC.Stop{0, 0.0}, SC.Stop{1, 13.33984375}, SC.Stop{2, 18.896484375}]),
      "a trailing space keeps its stop and advance (end x 18.896484375)")
    C.expect(F32.is_eq(last_x(ss, 0.0), width(space)), "the end stop x equals the layout width")
    zero : S.Layout <- C.unwrap(S.Layout, S.layout(font, "", 20.0, 1000.0))
    +zs : List<&2, SC.Stop> <- C.unwrap(List<&2, SC.Stop>, SC.stops(zero))
    C.expect(same_stops(zs, [SC.Stop{0, 0.0}]), "empty text has the one stop (0, 0)")
    C.expect(U32.is_eq(SC.hit(zs, 50.0), 0) && U32.is_eq(SC.snap(zs, 4), 0), "empty text: hit and snap give 0")
    nl : S.Layout <- C.unwrap(S.Layout, S.layout(font, "A\nA", 20.0, 1000.0))
    C.expect(C.is_fail(List<&2, SC.Stop>, SC.stops(nl)), "a layout with a line feed (two lines) is refused")
    wrapped : S.Layout <- C.unwrap(S.Layout, S.layout(font, "AA", 20.0, 26.0))
    C.expect(C.is_fail(List<&2, SC.Stop>, SC.stops(wrapped)), "a wrapped layout is refused")
    C.expect(is_unsupported(SC.unsupported(font, "café ☕"), 5, 9749), "unsupported(café ☕) is (5, 9749)")
    C.expect(is_none(SC.unsupported(font, "Olá, ação! Coração, café.")), "Portuguese text is supported")
    C.expect(is_none(SC.unsupported(font, "")), "empty text is supported")
    C.expect(is_none(SC.unsupported(font, "A\nA")), "a line feed is supported, as in layout")
    C.expect(is_unsupported(SC.unsupported(font, "R$ 5 €"), 5, 8364), "the euro sign is (5, 8364)")
    C.expect(is_unsupported(SC.unsupported(font, "́a"), 0, 769), "a leading mark is reported at 0")
    C.expect(is_unsupported(SC.unsupported(font, "ax́"), 2, 769), "an unlisted pair reports its mark")
    C.expect(is_unsupported(SC.unsupported(font, "ã́"), 1, 769), "a mark after a precomposed letter is reported")
    C.expect(is_unsupported(SC.unsupported(font, "ã́"), 2, 769), "a second mark in one cluster is reported")
    C.expect(is_unsupported(SC.unsupported(font, "a\tb"), 1, 9), "a tab is (1, 9)")
    C.expect(is_none(SC.unsupported(font, repeat(4096n, 'a', ""))), "4096 scalars are supported")
    C.expect(is_unsupported(SC.unsupported(font, repeat(4097n, 'a', "")), 4096, 97), "the 4097th scalar is (4096, 97)")
    C.expect(agrees(SC.unsupported(font, "café ☕"), S.layout(font, "café ☕", 20.0, 1000.0)) &&
      agrees(SC.unsupported(font, "ax́"), S.layout(font, "ax́", 20.0, 1000.0)) &&
      agrees(SC.unsupported(font, "Olá, ação!"), S.layout(font, "Olá, ação!", 20.0, 1000.0)) &&
      agrees(SC.unsupported(font, "a\tb"), S.layout(font, "a\tb", 20.0, 1000.0)),
      "unsupported is None exactly when layout succeeds")
    IO.print("Syllo caret tests complete")
