import Base
import ../Runika/bytes.bend as B
import ../Runika/font.bend as F
import ./unicode.bend as U

type Shaped is Data:
  Shaped{code: U32, glyph: U32, start: U32, end: U32, advance: F32}

type Placement is Data:
  Placement{glyph: U32, source_start: U32, source_end: U32,
    x: F32, baseline: F32, advance: F32, line: U32}

type Layout is Data:
  Layout{placements: List<&2, Placement>, width: F32, height: F32,
    ascender: F32, descender: F32, line_height: F32, line_count: U32}

def units(font: F.Font) -> F32:
  match font:
    case F.Font{upem, asc, desc, gap, count, metrics, long, cmap, hmtx, loca, glyf}:
      U32.to_f32(upem)

def advance(m: F.Metric) -> F32:
  match m:
    case F.Metric{a, bearing}:
      a

def valid_font(font: F.Font) -> Bool:
  match font:
    case F.Font{upem,asc,desc,gap,count,metrics,long,cmap,hmtx,loca,glyf}:
      Bool.and(U32.is_gt(upem,0), F32.is_gt((asc - desc + gap : F32),0.0))

def map_cluster(newline: Bool, +font: F.Font, c: U.Cluster, scale: F32) -> Result<&2, &2, String, Shaped>:
  match newline c:
    case True{} U.Cluster{code, start, end}:
      Done{Shaped{code, 0, start, end, 0.0}}
    case False{} U.Cluster{+code, start, end}:
      do Result<&2, &2, String, Shaped>:
        +gid : U32 <- F.glyph_id(font, code)
        ok : Unit <- B.require(U32.is_ne(gid, 0), "font lacks a required Unicode glyph")
        metric : F.Metric <- F.metric(font, gid)
        return Shaped{code, gid, start, end, (advance(metric) * scale : F32)}

def cluster_code(c: U.Cluster) -> U32:
  match c:
    case U.Cluster{code, start, end}:
      code

def shape(cs: List<&2, U.Cluster>, +font: F.Font, +scale: F32) -> Result<&2, &2, String, List<&2, Shaped>>:
  match cs:
    case Nil{}:
      Done{Nil{}}
    case Con{+c, rest}:
      do Result<&2, &2, String, List<&2, Shaped>>:
        h : Shaped <- map_cluster(U32.is_eq(cluster_code(c), 10), font, c, scale)
        t : List<&2, Shaped> <- shape(rest, font, scale)
        return Con{h, t}

def word_width(xs: List<&2, Shaped>, acc: F32) -> F32:
  match xs:
    case Nil{}:
      acc
    case Con{Shaped{32, gid, start, end, advance}, rest}:
      acc
    case Con{Shaped{10, gid, start, end, advance}, rest}:
      acc
    case Con{Shaped{code, gid, start, end, advance}, rest}:
      word_width(rest, (acc + advance : F32))

type Cursor is Data:
  Cursor{x: F32, baseline: F32, max_width: F32, line: U32,
    word_start: Bool, placements: List<&2, Placement>}

def newline(cursor: Cursor, line_height: F32) -> Cursor:
  match cursor:
    case Cursor{x, baseline, width, line, word_start, placements}:
      Cursor{0.0, (baseline + line_height : F32), F32.max(width, x), (line + 1 : U32), True{}, placements}

def place(at_break: Bool, cursor: Cursor, g: Shaped, +line_height: F32) -> Cursor:
  match at_break cursor g:
    case True{} Cursor{old_x, +baseline, +width, +line, ws, placements} Shaped{+code, gid, start, end, +adv}:
      Cursor{adv, (baseline + line_height : F32), F32.max(width, old_x), (line + 1 : U32), U32.is_eq(code, 32),
        Con{Placement{gid, start, end, 0.0, (baseline + line_height : F32), adv, (line + 1 : U32)}, placements}}
    case False{} Cursor{+x, +baseline, width, +line, ws, placements} Shaped{code, gid, start, end, +adv}:
      Cursor{(x + adv : F32), baseline, width, line, U32.is_eq(code, 32),
        Con{Placement{gid, start, end, x, baseline, adv, line}, placements}}

def layout_step(cursor: Cursor, +g: Shaped, +word: F32, +max_width: F32, line_height: F32) -> Cursor:
  match cursor g:
    case _ Shaped{10, gid, start, end, adv}:
      newline(cursor, line_height)
    case Cursor{+x, baseline, width, line, +ws, placements} Shaped{+code, gid, start, end, +adv}:
      +wrap = Bool.and(F32.is_gt(x, 0.0), Bool.or(F32.is_gt((x + adv : F32), max_width),
        Bool.and(ws, Bool.and(F32.is_le(word, max_width), F32.is_gt((x + word : F32), max_width)))))
      place(wrap, Cursor{x, baseline, width, line, ws, placements}, Shaped{code, gid, start, end, adv}, line_height)

def position_all(xs: List<&2, Shaped>, +max_width: F32, +line_height: F32, cursor: Cursor) -> Cursor:
  match xs:
    case Nil{}:
      cursor
    case Con{+h, +t}:
      position_all(t, max_width, line_height, layout_step(cursor, h, word_width(Con{h, t}, 0.0), max_width, line_height))

def finish(cursor: Cursor, asc: F32, desc: F32, +line_height: F32) -> Layout:
  match cursor:
    case Cursor{x, baseline, width, +line, ws, placements}:
      Layout{List.reverse(&2, Placement, placements), F32.max(width, x),
        (U32.to_f32((line + 1 : U32)) * line_height : F32), asc, desc, line_height, (line + 1 : U32)}

def lay(font: F.Font, shaped: List<&2, Shaped>, +scale: F32, width: F32) -> Layout:
  match font:
    case F.Font{upem, +asc, +desc, gap, count, metrics, long, cmap, hmtx, loca, glyf}:
      +ascent = (asc * scale : F32)
      +descent = (desc * scale : F32)
      +lh = ((asc - desc + gap) * scale : F32)
      finish(position_all(shaped, width, lh, Cursor{0.0, ascent, 0.0, 0, True{}, Nil{}}), ascent, descent, lh)

def layout(+font: F.Font, text: String, +size: F32, +max_width: F32) -> Result<&2, &2, String, Layout>:
  do Result<&2, &2, String, Layout>:
    font_ok : Unit <- B.require(valid_font(font), "font has invalid units or line metrics")
    ok : Unit <- B.require(Bool.and(F32.is_gt(size, 0.0), F32.is_le(size, 256.0)), "font size must be finite and in (0,256]")
    ok2 : Unit <- B.require(Bool.and(F32.is_gt(max_width, 0.0), F32.is_le(max_width, 1000000.0)), "layout width must be finite and in (0,1000000]")
    cs : List<&2, U.Cluster> <- U.normalize(text)
    +scale : F32 = (size / units(font) : F32)
    gs : List<&2, Shaped> <- shape(cs, font, scale)
    return lay(font, gs, scale, max_width)
