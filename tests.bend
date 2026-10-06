import Base
import ./main.bend as S
import ./unicode.bend as U
import ../Runika/font.bend as F
import ../Runika/check.bend as C

def clusters_equal(a: List<&2, U.Cluster>, b: List<&2, U.Cluster>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{U.Cluster{ac, ax, ay}, at} Con{U.Cluster{bc, bx, by}, bt}:
      Bool.and(U32.is_eq(ac, bc), clusters_equal(at, bt))
    case _ _: False{}

def span(cs: List<&2, U.Cluster>) -> Bool:
  match cs:
    case Con{U.Cluster{227, 0, 2}, Nil{}}: True{}
    case _: False{}

def same_placements(a: List<&2, S.Placement>, b: List<&2, S.Placement>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{S.Placement{ag, sa, ea, ax, ay, aa, al}, at} Con{S.Placement{bg, sb, eb, bx, by, ba, bl}, bt}:
      Bool.and(U32.is_eq(ag, bg), Bool.and(C.near(ax, bx), Bool.and(C.near(ay, by), Bool.and(C.near(aa, ba), Bool.and(U32.is_eq(al, bl), same_placements(at, bt))))))
    case _ _: False{}

def same_layout(a: S.Layout, b: S.Layout) -> Bool:
  match a b:
    case S.Layout{ap, aw, ah, aasc, adesc, alh, alc} S.Layout{bp, bw, bh, basc, bdesc, blh, blc}:
      Bool.and(same_placements(ap, bp), Bool.and(C.near(aw, bw), Bool.and(C.near(ah, bh), U32.is_eq(alc, blc))))

def line_count(l: S.Layout) -> U32:
  match l:
    case S.Layout{ps, w, h, asc, desc, lh, lines}: lines

def width(l: S.Layout) -> F32:
  match l:
    case S.Layout{ps, w, h, asc, desc, lh, lines}: w

def empty(l: S.Layout) -> Bool:
  match l:
    case S.Layout{Nil{}, w, h, asc, desc, lh, 1}: C.near(w, 0.0)
    case _: False{}

def same_pairs(text: String, normalized: String) -> IO(Unit):
  do IO<Unit>:
    a : List<&2, U.Cluster> <- C.unwrap(List<&2, U.Cluster>, U.normalize(text))
    b : List<&2, U.Cluster> <- C.unwrap(List<&2, U.Cluster>, U.normalize(normalized))
    C.expect(clusters_equal(a, b), "listed precomposed/combining pairs agree")

def main() -> IO(Unit):
  do IO<Unit>:
    same_pairs("ÀÁÂÃÇÉÊÍÓÔÕÚÜ àáâãçéêíóôõúü", "ÀÁÂÃÇÉÊÍÓÔÕÚÜ àáâãçéêíóôõúü")
    cs : List<&2, U.Cluster> <- C.unwrap(List<&2, U.Cluster>, U.normalize("ã"))
    C.expect(span(cs), "combining cluster retains two scalar source span")
    C.expect(C.is_fail(List<&2, U.Cluster>, U.normalize("́a")), "leading combining mark rejected")
    C.expect(C.is_fail(List<&2, U.Cluster>, U.normalize("x́")), "unsupported base plus mark rejected")
    C.expect(C.is_fail(List<&2, U.Cluster>, U.normalize("ã́")), "multiple combining marks rejected")
    C.expect(C.is_fail(List<&2, U.Cluster>, U.normalize("🙂")), "emoji explicitly unsupported")
    C.expect(C.is_fail(List<&2, U.Cluster>, U.normalize("مرحبا")), "Arabic shaping explicitly unsupported")
    C.expect(C.is_fail(List<&2, U.Cluster>, U.normalize("a\tb")), "tab policy explicit rejection")
    fr : Result<&2, &2, String, F.Font> <- F.load("/usr/share/fonts/liberation/LiberationSans-Regular.ttf")
    +font : F.Font <- C.unwrap(F.Font, fr)
    a : S.Layout <- C.unwrap(S.Layout, S.layout(font, "ação, coração, café", 24.0, 400.0))
    b : S.Layout <- C.unwrap(S.Layout, S.layout(font, "ação, coração, café", 24.0, 400.0))
    C.expect(same_layout(a, b), "precomposed and combining have identical glyph positions/metrics")
    zero : S.Layout <- C.unwrap(S.Layout, S.layout(font, "", 20.0, 100.0))
    C.expect(empty(zero), "empty text has zero width and one line box")
    nl : S.Layout <- C.unwrap(S.Layout, S.layout(font, "A\nA\n", 20.0, 100.0))
    C.expect(U32.is_eq(line_count(nl), 3), "explicit LF and trailing empty line")
    +exact : S.Layout <- C.unwrap(S.Layout, S.layout(font, "AA", 20.0, 26.6796875))
    C.expect(Bool.and(U32.is_eq(line_count(exact), 1), C.near(width(exact), 26.6796875)), "exact advance fits width")
    wrap : S.Layout <- C.unwrap(S.Layout, S.layout(font, "AA", 20.0, 26.0))
    C.expect(U32.is_eq(line_count(wrap), 2), "long word breaks by cluster when necessary")
    words : S.Layout <- C.unwrap(S.Layout, S.layout(font, "AA AA", 20.0, 45.0))
    C.expect(U32.is_eq(line_count(words), 2), "greedy word wrap at space")
    +narrow : S.Layout <- C.unwrap(S.Layout, S.layout(font, "A", 20.0, 1.0))
    C.expect(Bool.and(U32.is_eq(line_count(narrow), 1), F32.is_gt(width(narrow), 1.0)), "oversized single glyph kept intact with measured overflow")
    C.expect(C.is_fail(S.Layout, S.layout(font, "a", 0.0, 100.0)), "zero font size rejected")
    C.expect(C.is_fail(S.Layout, S.layout(font, "a", 20.0, F32.neg(1.0))), "negative width rejected")
    IO.print("Syllo tests complete")
