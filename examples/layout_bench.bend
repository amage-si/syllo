import Base
import ../../Runika/font.bend as F
import ../../Runika/check.bend as C
import ../main.bend as S
import ../caret.bend as SC

# Times `layout` on the integrated demo's seven texts (Chromi's eco demo,
# same sizes, a 420-unit column), on a 256-scalar Latin-1 line, and on a
# line that mixes Latin-1 with characters outside it (€, dashes, quotes,
# Latin Extended, Greek, Cyrillic), plus one `F.info` per scalar for a
# Latin-1 letter, € and a Cyrillic letter. Each loop folds its results into
# a checksum printed before the next clock read (IO.now has millisecond
# resolution).

def latin1() -> String:
  "Texto real em Bend: ação, coração, café e pão. " ++ "Olá! Edição de um campo só, com acentos: é, ê, ã, õ, ç. " ++
    "Texto real em Bend: ação, coração, café e pão. " ++ "Olá! Edição de um campo só, com acentos: é, ê, ã, õ, ç. " ++
    "Mais dezoito letras de teste, para fechar a linha."

# 241 scalars, 57 of them outside Latin-1.
def mixed() -> String:
  "Preço: 5 € — “Olá”… Łódź, Győr; Ωμέγα; Привет, мир! " ++ "Цена: 9 € – ‘тест’ • ½ → ≤ ∞ ™ № ‰ « » ¿ ¡ " ++
    "Texto real em Bend: ação, coração, café e pão. " ++ "Olá! Edição de um campo só, com acentos: é, ê, ã, õ, ç. " ++
    "Žluťoučký kůň úpěl ďábelské ódy — Ελληνικά."

def count_ok(r: Result<&2, &2, String, S.Layout>) -> U32:
  match r:
    case Fail{e}: 0
    case Done{l}: 1

def seven(+font: F.Font) -> U32:
  (count_ok(S.layout(font, "AMAGE Eco", 34.0, 420.0)) +
    count_ok(S.layout(font, "Uma janela, uma GPU, várias bibliotecas.", 19.0, 420.0)) +
    count_ok(S.layout(font, "Texto real em Bend: ação, coração, café. A Ankra cuida da janela e dos eventos, a Voltra da GPU e o Chromi da lista de desenho.", 16.0, 420.0)) +
    count_ok(S.layout(font, "Ativar", 18.0, 1000000.0)) +
    count_ok(S.layout(font, "Clique no botão ou use Tab e Espaço.", 16.0, 420.0)) +
    count_ok(S.layout(font, "PNG decodificado pela Ocula", 13.0, 1000000.0)) +
    count_ok(S.layout(font, "SVG interpretado pela Splina", 13.0, 1000000.0)) : U32)

def run_seven(n: Nat, +font: F.Font, acc: U32) -> U32:
  match n:
    case 0n: acc
    case 1n+p: run_seven(p, font, (acc + seven(font) : U32))

def run_layout(n: Nat, +font: F.Font, +t: String, acc: U32) -> U32:
  match n:
    case 0n: acc
    case 1n+p: run_layout(p, font, t, (acc + count_ok(S.layout(font, t, 20.0, 1000000.0)) : U32))

def found(m: Maybe<&2, SC.Unsupported>) -> U32:
  match m:
    case None{}: 1
    case Some{u}: 0

def run_unsupported(n: Nat, +font: F.Font, +t: String, acc: U32) -> U32:
  match n:
    case 0n: acc
    case 1n+p: run_unsupported(p, font, t, (acc + found(SC.unsupported(font, t)) : U32))

def glyph_of(r: Result<&2, &2, String, F.Info>) -> U32:
  match r:
    case Fail{e}: 0
    case Done{F.Info{g, a}}: g

def run_info(n: Nat, +font: F.Font, +code: U32, acc: U32) -> U32:
  match n:
    case 0n: acc
    case 1n+p: run_info(p, font, code, (acc + glyph_of(F.info(font, code)) : U32))

def report(+name: String, +runs: U32, +t0: Nat, +t1: Nat, +check: U32) -> IO(Unit):
  IO.print(name ++ ": " ++ Nat.show(Nat.sub(t1, t0)) ++ " ms for " ++ U32.show(runs) ++ " runs  (check " ++
    U32.show(check) ++ ")")

def main() -> IO(Unit):
  do IO<Unit>:
    fr : Result<&2, &2, String, F.Font> <- F.load("/usr/share/fonts/liberation/LiberationSans-Regular.ttf")
    +font : F.Font <- C.unwrap(F.Font, fr)
    IO.print("scalars latin1 " ++ Nat.show(String.length(latin1())) ++ ", mixed " ++ Nat.show(String.length(mixed())))
    +t0 : Nat <- IO.now()
    +a : U32 = run_seven(2000n, font, 0)
    IO.print("seven checksum " ++ U32.show(a))
    +t1 : Nat <- IO.now()
    +b : U32 = run_layout(2000n, font, latin1(), 0)
    IO.print("latin1 checksum " ++ U32.show(b))
    +t2 : Nat <- IO.now()
    +c : U32 = run_layout(2000n, font, mixed(), 0)
    IO.print("mixed checksum " ++ U32.show(c))
    +t3 : Nat <- IO.now()
    +d : U32 = run_unsupported(2000n, font, mixed(), 0)
    IO.print("unsupported checksum " ++ U32.show(d))
    +t4 : Nat <- IO.now()
    +e : U32 = run_info(200000n, font, 97, 0)
    IO.print("info a checksum " ++ U32.show(e))
    +t5 : Nat <- IO.now()
    +f : U32 = run_info(200000n, font, 8364, 0)
    IO.print("info euro checksum " ++ U32.show(f))
    +t6 : Nat <- IO.now()
    +g : U32 = run_info(200000n, font, 1046, 0)
    IO.print("info zhe checksum " ++ U32.show(g))
    +t7 : Nat <- IO.now()
    report("seven demo texts", 2000, t0, t1, a)
    report("layout latin1 (256 scalars)", 2000, t1, t2, b)
    report("layout mixed (241 scalars)", 2000, t2, t3, c)
    report("unsupported mixed", 2000, t3, t4, d)
    report("info U+0061", 200000, t4, t5, e)
    report("info U+20AC", 200000, t5, t6, f)
    report("info U+0416", 200000, t6, t7, g)
