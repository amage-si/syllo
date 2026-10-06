import Base
import ../Runika/bytes.bend as B

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

def flush(pending: Maybe<&2, Cluster>, acc: List<&2, Cluster>) -> List<&2, Cluster>:
  match pending:
    case None{}:
      acc
    case Some{c}:
      Con{c, acc}

type Step is Data:
  Step{pending: Maybe<&2, Cluster>, acc: List<&2, Cluster>}

def combine(pending: Maybe<&2, Cluster>, mark: U32, end: U32, acc: List<&2, Cluster>) -> Result<&2, &2, String, Step>:
  match pending:
    case None{}:
      Fail{"combining mark without base"}
    case Some{Cluster{base, start, prev_end}}:
      do Result<&2, &2, String, Step>:
        +cp : U32 = compose(mark, base)
        ok : Unit <- B.require(U32.is_ne(cp, 0), "unsupported combining sequence; only listed Latin pairs are composed")
        return Step{Some{Cluster{cp, start, end}}, acc}

def accept(is_mark: Bool, +code: U32, +index: U32, pending: Maybe<&2, Cluster>, acc: List<&2, Cluster>) -> Result<&2, &2, String, Step>:
  match is_mark:
    case True{}:
      combine(pending, code, (index + 1 : U32), acc)
    case False{}:
      do Result<&2, &2, String, Step>:
        ok : Unit <- B.require(Bool.or(U32.is_eq(code, 10), Bool.or(Bool.and(U32.is_ge(code, 32), U32.is_le(code, 126)), Bool.and(U32.is_ge(code, 160), U32.is_le(code, 255)))), "unsupported text scalar: printable ASCII/Latin-1 and LF only")
        return Step{Some{Cluster{code, index, (index + 1 : U32)}}, flush(pending, acc)}

def step_pending(s: Step) -> Maybe<&2, Cluster>:
  match s:
    case Step{p, a}:
      p

def step_acc(s: Step) -> List<&2, Cluster>:
  match s:
    case Step{p, a}:
      a

def normalize_go(text: String, +index: U32, pending: Maybe<&2, Cluster>, acc: List<&2, Cluster>) -> Result<&2, &2, String, List<&2, Cluster>>:
  match text:
    case SNil{}:
      Done{List.reverse(&2, Cluster, flush(pending, acc))}
    case SCon{Chr{+code}, rest}:
      do Result<&2, &2, String, List<&2, Cluster>>:
        ok : Unit <- B.require(U32.is_lt(index, 4096), "text exceeds 4096 scalar limit")
        +s : Step <- accept(Bool.and(U32.is_ge(code, 768), U32.is_le(code, 879)), code, index, pending, acc)
        normalize_go(rest, (index + 1 : U32), step_pending(s), step_acc(s))

def normalize(text: String) -> Result<&2, &2, String, List<&2, Cluster>>:
  normalize_go(text, 0, None{}, Nil{})
