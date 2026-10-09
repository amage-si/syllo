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

# Bit-for-bit equal layouts (exact floats, glyphs, spans and lines).
def exact_placements(a: List<&2, S.Placement>, b: List<&2, S.Placement>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{S.Placement{ag, sa, ea, ax, ay, aa, al}, at} Con{S.Placement{bg, sb, eb, bx, by, ba, bl}, bt}:
      U32.is_eq(ag, bg) && U32.is_eq(sa, sb) && U32.is_eq(ea, eb) && F32.is_eq(ax, bx) && F32.is_eq(ay, by) &&
        F32.is_eq(aa, ba) && U32.is_eq(al, bl) && exact_placements(at, bt)
    case _ _: False{}

def same_exact(a: Result<&2, &2, String, S.Layout>, b: Result<&2, &2, String, S.Layout>) -> Bool:
  match a b:
    case Done{S.Layout{ap, aw, ah, aasc, adesc, alh, alc}} Done{S.Layout{bp, bw, bh, basc, bdesc, blh, blc}}:
      exact_placements(ap, bp) && F32.is_eq(aw, bw) && F32.is_eq(ah, bh) && F32.is_eq(aasc, basc) &&
        F32.is_eq(adesc, bdesc) && F32.is_eq(alh, blh) && U32.is_eq(alc, blc)
    case _ _: False{}

def same_failure(a: Result<&2, &2, String, S.Layout>, b: Result<&2, &2, String, S.Layout>) -> Bool:
  match a b:
    case Fail{x} Fail{y}: String.eq(x, y)
    case _ _: False{}

def glyphs_are(ps: List<&2, S.Placement>, gs: List<&2, U32>) -> Bool:
  match ps gs:
    case Nil{} Nil{}: True{}
    case Con{S.Placement{g, sa, ea, x, y, a, l}, pt} Con{e, et}: U32.is_eq(g, e) && glyphs_are(pt, et)
    case _ _: False{}

def glyphs(r: Result<&2, &2, String, S.Layout>, gs: List<&2, U32>, +w: F32) -> Bool:
  match r:
    case Done{S.Layout{ps, lw, h, asc, desc, lh, lines}}: glyphs_are(ps, gs) && F32.is_eq(lw, w) && U32.is_eq(lines, 1)
    case Fail{e}: False{}

def failed_with(r: Result<&2, &2, String, S.Layout>, message: String) -> Bool:
  match r:
    case Fail{e}: String.eq(e, message)
    case Done{l}: False{}

# The line of the placement whose source starts at i (4096 when none).
def line_at(ps: List<&2, S.Placement>, +i: U32) -> U32:
  match ps:
    case Nil{}: 4096
    case Con{S.Placement{g, sa, ea, x, y, a, l}, rest}: Bool.pick(U32, U32.is_eq(sa, i), l, line_at(rest, i))

def line_of(r: Result<&2, &2, String, S.Layout>, +i: U32) -> U32:
  match r:
    case Done{S.Layout{ps, w, h, asc, desc, lh, lines}}: line_at(ps, i)
    case Fail{e}: 4096

# "a", the scalar c, "b" (for characters that are invisible in source).
def around(+c: U32) -> String:
  SCon{'a', SCon{Chr{c}, SCon{'b', SNil{}}}}

def refused(+c: U32) -> Bool:
  C.is_fail(List<&2, U.Cluster>, U.normalize(around(c)))

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
    C.expect(same_exact(S.layout(font, "Texto real em Bend: ação, coração, café. Ativado 12 vezes.", 16.0, 300.0),
      S.layout(F.latin.set(font, F.Unknown{}), "Texto real em Bend: ação, coração, café. Ativado 12 vezes.", 16.0, 300.0)),
      "the font's Latin-1 table lays out exactly as reading cmap and hmtx")
    C.expect(same_failure(S.layout(font, "Ação ☃", 16.0, 300.0), S.layout(F.latin.set(font, F.Unknown{}), "Ação ☃", 16.0, 300.0)),
      "unsupported text fails the same with and without the table")
    # Liberation Sans 2.1.5 glyph ids and advances (units of 2048) from its
    # cmap and hmtx: € 2088/1139, — 2016/2048, … 2031/2048, “ 2024/682,
    # ” 2025/682, Ł 259/1139, ő 275/1139, Ж 967/1891, Ω 859/1531. At 20 px
    # the nine advances sum to 12299 units = 120.107421875.
    C.expect(glyphs(S.layout(font, "€—…“”ŁőЖΩ", 20.0, 1000.0), [2088, 2016, 2031, 2024, 2025, 259, 275, 967, 859], 120.107421875),
      "€ — … “ ” Ł ő Ж Ω map to their glyphs and advances on one line")
    C.expect(same_exact(S.layout(font, "Preço: 5 € — “Olá”… Łódź, Ωμέγα, Привет!", 16.0, 120.0),
      S.layout(F.latin.set(font, F.Unknown{}), "Preço: 5 € — “Olá”… Łódź, Ωμέγα, Привет!", 16.0, 120.0)),
      "mixed Latin-1 and cmap characters lay out the same with and without the Latin-1 table")
    C.expect(failed_with(S.layout(font, "Preço ₹ 5", 20.0, 1000.0), "font lacks a required Unicode glyph"),
      "₹ (U+20B9, not in Liberation Sans 2.1.5) fails the whole call, never substituted")
    C.expect(C.is_fail(List<&2, U.Cluster>, U.normalize("שלום")) && C.is_fail(S.Layout, S.layout(font, "שלום", 20.0, 1000.0)),
      "Hebrew is refused although the font has its glyphs (right to left)")
    C.expect(refused(9749) && refused(128578) && refused(8205) && refused(8203) && refused(8206) && refused(8232) &&
      refused(8234) && refused(8288) && refused(1155) && refused(8407) && refused(13) && refused(127) && refused(133),
      "☕, emoji, ZWJ, ZWSP, LRM, U+2028, U+202A, word joiner, combining U+0483 and U+20D7, CR, DEL and NEL are refused")
    C.expect(C.is_fail(List<&2, U.Cluster>, U.normalize("Ж́")), "a combining accent on a Cyrillic letter is an unlisted pair")
    C.expect(U32.is_eq(line_of(S.layout(font, "A AA—AA", 20.0, 80.0), 2), 1) && U32.is_eq(line_of(S.layout(font, "A AA—AA", 20.0, 80.0), 6), 1),
      "an em dash is not a break opportunity: AA—AA wraps as one word")
    C.expect(C.is_fail(S.Layout, S.layout(font, "a", 0.0, 100.0)), "zero font size rejected")
    C.expect(C.is_fail(S.Layout, S.layout(font, "a", 20.0, F32.neg(1.0))), "negative width rejected")
    IO.print("Syllo tests complete")
