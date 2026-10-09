import Base

type Cluster is Data:
  Cluster{code: U32, start: U32, end: U32}

# Explicit Latin-1 composition, not Unicode NFC. A second combining mark or
# unsupported pair is rejected instead of positioned incorrectly.
def compose(mark: U32, base: U32) -> U32:
  match mark base:
    case 768 65: 192
    case 768 69: 200
    case 768 73: 204
    case 768 79: 210
    case 768 85: 217
    case 768 97: 224
    case 768 101: 232
    case 768 105: 236
    case 768 111: 242
    case 768 117: 249
    case 769 65: 193
    case 769 69: 201
    case 769 73: 205
    case 769 79: 211
    case 769 85: 218
    case 769 89: 221
    case 769 97: 225
    case 769 101: 233
    case 769 105: 237
    case 769 111: 243
    case 769 117: 250
    case 769 121: 253
    case 770 65: 194
    case 770 69: 202
    case 770 73: 206
    case 770 79: 212
    case 770 85: 219
    case 770 97: 226
    case 770 101: 234
    case 770 105: 238
    case 770 111: 244
    case 770 117: 251
    case 771 65: 195
    case 771 78: 209
    case 771 79: 213
    case 771 97: 227
    case 771 110: 241
    case 771 111: 245
    case 776 65: 196
    case 776 69: 203
    case 776 73: 207
    case 776 79: 214
    case 776 85: 220
    case 776 97: 228
    case 776 101: 235
    case 776 105: 239
    case 776 111: 246
    case 776 117: 252
    case 776 121: 255
    case 807 67: 199
    case 807 99: 231
    case _ _: 0

# Whether c lies in [lo, hi] (one unsigned comparison).
def between(+c: U32, +lo: U32, +hi: U32) -> Bool:
  U32.is_le((c - lo : U32), (hi - lo : U32))

# A combining diacritical mark (U+0300..U+036F), composed with its base by
# `compose`. Other combining blocks are outside the accepted ranges.
def is_mark(+c: U32) -> Bool:
  between(c, 768, 879)

# Scalars above U+00FF that lay out left to right one glyph per scalar,
# with no shaping, when the font has the glyph:
#   U+0100..02FF  Latin Extended-A and -B, IPA, spacing modifier letters
#   U+0370..0482  Greek and Coptic, Cyrillic up to U+0482
#   U+048A..052F  the rest of Cyrillic and Cyrillic Supplement (the
#                 combining U+0483..0489 are excluded)
#   U+1E00..1FFF  Latin Extended Additional, Greek Extended
#   U+2000..200A  spaces (laid out as glyphs; not break opportunities)
#   U+2010..2027  dashes, quotes, daggers, bullet, leaders, ellipsis
#   U+202F..205F  narrow no-break space, per mille, primes, guillemets...
#   U+2070..20CF  superscripts and subscripts, currency symbols
#   U+2100..22FF  letterlike, number forms, arrows, mathematical operators
# Left out on purpose: zero-width and bidirectional controls (U+200B..200F,
# U+202A..202E, U+2060..206F), the line and paragraph separators
# (U+2028, 2029), and combining marks for symbols (U+20D0..20FF).
def accepted.wide(+c: U32) -> Bool:
  between(c, 256, 767) || between(c, 880, 1154) || between(c, 1162, 1327) || between(c, 7680, 8191) ||
    between(c, 8192, 8202) || between(c, 8208, 8231) || between(c, 8239, 8287) || between(c, 8304, 8399) ||
    between(c, 8448, 8959)

def accepted.pick(latin1: Bool, +c: U32) -> Bool:
  match latin1:
    case True{}:
      U32.is_eq(c, 10) || between(c, 32, 126) || U32.is_ge(c, 160)
    case False{}:
      accepted.wide(c)

# Whether `layout` accepts c as the base of a cluster: line feed, printable
# ASCII, Latin-1 (U+00A0..00FF), or a scalar of `accepted.wide`. Everything
# else is refused: other controls, tab, CR, combining marks without a base,
# Hebrew, Arabic and other scripts that need bidi or shaping, emoji, and
# scalars above U+FFFF. Latin-1 is decided first, in three comparisons.
def accepted(+c: U32) -> Bool:
  accepted.pick(U32.is_lt(c, 256), c)

def flush(pending: Maybe<&2, Cluster>, acc: List<&2, Cluster>) -> List<&2, Cluster>:
  match pending:
    case None{}:
      acc
    case Some{c}:
      Con{c, acc}

type Step is Data:
  Step{pending: Maybe<&2, Cluster>, acc: List<&2, Cluster>}

def combine.listed(listed: Bool, +cp: U32, +start: U32, +end: U32, acc: List<&2, Cluster>) -> Result<&2, &2, String, Step>:
  match listed:
    case True{}:
      Done{Step{Some{Cluster{cp, start, end}}, acc}}
    case False{}:
      Fail{"unsupported combining sequence; only listed Latin pairs are composed"}

def combine(pending: Maybe<&2, Cluster>, mark: U32, end: U32, acc: List<&2, Cluster>) -> Result<&2, &2, String, Step>:
  match pending:
    case None{}:
      Fail{"combining mark without base"}
    case Some{Cluster{base, start, prev_end}}:
      +cp = compose(mark, base)
      combine.listed(U32.is_ne(cp, 0), cp, start, end, acc)

def accept.base(ok: Bool, +code: U32, +index: U32, pending: Maybe<&2, Cluster>, acc: List<&2, Cluster>) -> Result<&2, &2, String, Step>:
  match ok:
    case True{}:
      Done{Step{Some{Cluster{code, index, (index + 1 : U32)}}, flush(pending, acc)}}
    case False{}:
      Fail{"unsupported text scalar: outside Syllo's Latin, Greek, Cyrillic, punctuation and symbol ranges"}

def accept(is_mark: Bool, +code: U32, +index: U32, pending: Maybe<&2, Cluster>, acc: List<&2, Cluster>) -> Result<&2, &2, String, Step>:
  match is_mark:
    case True{}:
      combine(pending, code, (index + 1 : U32), acc)
    case False{}:
      accept.base(accepted(code), code, index, pending, acc)

def step_pending(s: Step) -> Maybe<&2, Cluster>:
  match s:
    case Step{p, a}:
      p

def step_acc(s: Step) -> List<&2, Cluster>:
  match s:
    case Step{p, a}:
      a

def accept.within(ok: Bool, +code: U32, +index: U32, pending: Maybe<&2, Cluster>, acc: List<&2, Cluster>) -> Result<&2, &2, String, Step>:
  match ok:
    case False{}:
      Fail{"text exceeds 4096 scalar limit"}
    case True{}:
      accept(is_mark(code), code, index, pending, acc)

# Folds the scalars into clusters; `step` is the state after the previous
# scalar (a failure ends the fold with it).
def normalize_go(text: String, +index: U32, step: Result<&2, &2, String, Step>) -> Result<&2, &2, String, List<&2, Cluster>>:
  match text step:
    case _ Fail{e}:
      Fail{e}
    case SNil{} Done{Step{pending, acc}}:
      Done{List.reverse(&2, Cluster, flush(pending, acc))}
    case SCon{Chr{+code}, rest} Done{Step{pending, acc}}:
      normalize_go(rest, (index + 1 : U32), accept.within(U32.is_lt(index, 4096), code, index, pending, acc))

def normalize(text: String) -> Result<&2, &2, String, List<&2, Cluster>>:
  normalize_go(text, 0, Done{Step{None{}, Nil{}}})
