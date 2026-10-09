import Base
import ../Runika/font.bend as F
import ./main.bend as S
import ./unicode.bend as U

# Caret queries over a single-line layout: where the caret may stand, where
# it is drawn, which stop a pointer x lands on, and the selection band.
# Indices count Unicode scalars, as Placement.source_start does. Positions
# are logical units relative to the layout's origin (top left, y down).

# A caret position: a scalar index the caret may stand at and its pen x.
type Stop is Data:
  Stop{index: U32, x: F32}

# A selection rectangle in layout coordinates.
type Band is Data:
  Band{x: F32, top: F32, width: F32, height: F32}

# One stop per placement at (source_start, x), then an end stop at the last
# placement's (source_end, x + advance). A combining cluster spans two
# scalars, so the scalar between base and mark is never a stop.
def stops.go(ps: List<&2, S.Placement>, acc: List<&2, Stop>, end: U32, end_x: F32) -> List<&2, Stop>:
  match ps:
    case Nil{}:
      List.reverse(&2, Stop, Con{Stop{end, end_x}, acc})
    case Con{S.Placement{g, start, next, +x, b, advance, l}, rest}:
      stops.go(rest, Con{Stop{start, x}, acc}, next, (x + advance : F32))

def stops.single(one: Bool, ps: List<&2, S.Placement>) -> Result<&2, &2, String, List<&2, Stop>>:
  match one:
    case True{}:
      Done{stops.go(ps, Nil{}, 0, 0.0)}
    case False{}:
      Fail{"caret stops need a single-line layout"}

# The caret stops of a single-line layout, in index (and x) order. Empty text
# gives the one stop (0, 0). A layout with more than one line (a line feed
# or a wrap) fails.
def stops(l: S.Layout) -> Result<&2, &2, String, List<&2, Stop>>:
  match l:
    case S.Layout{ps, w, h, asc, desc, lh, lines}:
      stops.single(U32.is_le(lines, 1), ps)

# The last stop whose index is at most i (the list is in index order).
def snap.go(stops: List<&2, Stop>, +i: U32, best: Stop) -> Stop:
  match stops:
    case Nil{}:
      best
    case Con{Stop{+index, +x}, rest}:
      snap.go(rest, i, Bool.pick(Stop, U32.is_le(index, i), Stop{index, x}, best))

def stop_index(s: Stop) -> U32:
  match s:
    case Stop{index, x}:
      index

def stop_x(s: Stop) -> F32:
  match s:
    case Stop{index, x}:
      x

# The caret index for scalar index i: i itself when it is a stop, else the
# stop before it (inside a combining cluster); past the end, the end stop.
def snap(stops: List<&2, Stop>, +i: U32) -> U32:
  stop_index(snap.go(stops, i, Stop{0, 0.0}))

# The pen x of the caret at index i, after snapping.
def caret_x(stops: List<&2, Stop>, +i: U32) -> F32:
  stop_x(snap.go(stops, i, Stop{0, 0.0}))

def hit.go(stops: List<&2, Stop>, +x: F32, +best: U32, +best_d: F32) -> U32:
  match stops:
    case Nil{}:
      best
    case Con{Stop{index, sx}, rest}:
      +d = F32.abs((x - sx : F32))
      +closer = F32.is_lt(d, best_d)
      hit.go(rest, x, Bool.pick(U32, closer, index, best), Bool.pick(F32, closer, d, best_d))

# The stop nearest to x; at an exact tie the left stop wins. Negative x
# gives the first stop and x past the end gives the end stop.
def hit(stops: List<&2, Stop>, +x: F32) -> U32:
  match stops:
    case Nil{}:
      0
    case Con{Stop{index, sx}, rest}:
      hit.go(rest, x, index, F32.abs((x - sx : F32)))

type Ends is Data:
  Ends{low: Stop, high: Stop}

def ends.go(stops: List<&2, Stop>, +lo: U32, +hi: U32, a: Stop, b: Stop) -> Ends:
  match stops:
    case Nil{}:
      Ends{a, b}
    case Con{Stop{+index, +x}, rest}:
      ends.go(rest, lo, hi, Bool.pick(Stop, U32.is_le(index, lo), Stop{index, x}, a),
        Bool.pick(Stop, U32.is_le(index, hi), Stop{index, x}, b))

def band.of(empty: Bool, +ax: F32, bx: F32, height: F32) -> List<&2, Band>:
  match empty:
    case True{}:
      Nil{}
    case False{}:
      [Band{ax, 0.0, (bx - ax : F32), height}]

def band(e: Ends, height: F32) -> List<&2, Band>:
  match e:
    case Ends{Stop{ai, ax}, Stop{bi, bx}}:
      band.of(U32.is_eq(ai, bi), ax, bx, height)

# The bands covering the text between from and to (either order, snapped).
# One band per line: on a single line, at most one band, from the top of the
# line box (y 0) down line_height. An empty selection gives no band.
def selection(stops: List<&2, Stop>, +from: U32, +to: U32, line_height: F32) -> List<&2, Band>:
  band(ends.go(stops, U32.min(from, to), U32.max(from, to), Stop{0, 0.0}, Stop{0, 0.0}), line_height)

# A scalar S.layout rejects: its index in the text and its value.
type Unsupported is Data:
  Unsupported{index: U32, scalar: U32}

# Scanning `unsupported`: the open cluster (code 0 when there is none) or the
# first rejected scalar.
type Scan is Data:
  Scanning{code: U32, start: U32}
  Rejected{index: U32, code: U32}

def absent(r: Result<&2, &2, String, F.Info>) -> Bool:
  match r:
    case Fail{e}:
      True{}
    case Done{F.Info{glyph, advance}}:
      U32.is_eq(glyph, 0)

# Whether the open cluster `code` has no glyph. No cluster (0) and a line
# feed (10, laid out without a glyph) never miss.
def missing(skip: Bool, +font: F.Font, +code: U32) -> Bool:
  match skip:
    case True{}:
      False{}
    case False{}:
      absent(F.info(font, code))

def accepted(+c: U32) -> Bool:
  U32.is_eq(c, 10) || (U32.is_ge(c, 32) && U32.is_le(c, 126)) || (U32.is_ge(c, 160) && U32.is_le(c, 255))

def scan.composed(unlisted: Bool, +cp: U32, +index: U32, +mark: U32, +start: U32) -> Scan:
  match unlisted:
    case True{}:
      Rejected{index, mark}
    case False{}:
      Scanning{cp, start}

def scan.mark(+cp: U32, +index: U32, +mark: U32, +start: U32) -> Scan:
  scan.composed(U32.is_eq(cp, 0), cp, index, mark, start)

def scan.base(lacks: Bool, +c: U32, +index: U32, +code: U32, +start: U32) -> Scan:
  match lacks:
    case True{}:
      Rejected{start, code}
    case False{}:
      Bool.pick(Scan, accepted(c), Scanning{c, index}, Rejected{index, c})

def scan.kind(mark: Bool, +font: F.Font, +c: U32, +index: U32, +code: U32, +start: U32) -> Scan:
  match mark:
    case True{}:
      scan.mark(U.compose(c, code), index, c, start)
    case False{}:
      scan.base(missing(U32.is_eq(code, 0) || U32.is_eq(code, 10), font, code), c, index, code, start)

def scan.step(within: Bool, +font: F.Font, +c: U32, +index: U32, +code: U32, +start: U32) -> Scan:
  match within:
    case False{}:
      Rejected{index, c}
    case True{}:
      scan.kind(U32.is_ge(c, 768) && U32.is_le(c, 879), font, c, index, code, start)

def scan.close(lacks: Bool, +start: U32, +code: U32) -> Maybe<&2, Unsupported>:
  match lacks:
    case True{}:
      Some{Unsupported{start, code}}
    case False{}:
      None{}

def scan(text: String, +font: F.Font, +index: U32, state: Scan) -> Maybe<&2, Unsupported>:
  match text state:
    case _ Rejected{i, c}:
      Some{Unsupported{i, c}}
    case SNil{} Scanning{+code, +start}:
      scan.close(missing(U32.is_eq(code, 0) || U32.is_eq(code, 10), font, code), start, code)
    case SCon{Chr{+c}, rest} Scanning{+code, +start}:
      scan(rest, font, (index + 1 : U32), scan.step(U32.is_lt(index, 4096), font, c, index, code, start))

# The first scalar that makes S.layout reject `text` with this font, as
# Unsupported{index, scalar}, or None when the text is supported. It applies
# layout's rules: accepted scalars, listed combining pairs, the font's
# glyphs, and the 4096-scalar limit. For a mark the pair is missing, the
# mark is reported; for a cluster the font has no glyph for, its start and
# its (composed) scalar. Problems are found in text order. Size and width
# are not checked.
def unsupported(+font: F.Font, text: String) -> Maybe<&2, Unsupported>:
  scan(text, font, 0, Scanning{0, 0})
