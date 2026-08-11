#!/usr/bin/env python3
#
# Turn the four harnesses' output into the tables in Benchmark.md.
#
#     python3 cross/merge.py .out
#
# Agreement is checked before anything is formatted.  If two implementations
# disagree about an answer, the row is marked and no ratio is printed for it --
# comparing how fast two functions compute different things is not a comparison.
#
import os
import sys

out_dir = sys.argv[1] if len(sys.argv) > 1 else ".out"
LANGS = ["swift", "node", "python", "ruby"]
LABEL = {"swift": "swift-bignum", "node": "node", "python": "python", "ruby": "ruby"}
SIZES = [64, 256, 1024, 4096]
# the order they are reported in, which is the order they are run in
OPS = ["baseline", "+", "-", "*", "/", "%", "<", "<< 61", ">> 61",
       "description", "init(radix: 10)", "init(radix: 16)",
       "squareRoot", "gcd", "power(5)", "power(e, mod:)"]


def read(path):
    if not os.path.exists(path):
        return None
    with open(path) as f:
        rows = [line.rstrip("\n").split("\t") for line in f if line.strip()]
    return rows[1:]


times, values, semantics = {}, {}, {}
for lang in LANGS:
    r = read("%s/results-%s.tsv" % (out_dir, lang))
    if r is None:
        sys.exit("missing results for %s -- did its harness run?" % lang)
    for op, bits, ns in r:
        times[(lang, op, int(bits))] = float(ns)
    for op, bits, value in read("%s/values-%s.tsv" % (out_dir, lang)) or []:
        values[(lang, op, int(bits))] = value
    semantics[lang] = read("%s/semantics-%s.tsv" % (out_dir, lang)) or []
semantics["attaswift"] = read("%s/semantics-attaswift.tsv" % out_dir) or []


# A row whose time is within this factor of its own harness overhead is mostly
# measuring the harness.  Marked, and left out of the summary.
FLOOR_FACTOR = 2.0


def floor_of(lang, bits):
    return times.get((lang, "baseline", bits), 0.0)


def above_floor(lang, op, bits):
    t = times.get((lang, op, bits))
    f = floor_of(lang, bits)
    return t is not None and (f == 0.0 or t >= FLOOR_FACTOR * f)


def fmt(ns):
    if ns < 1000:
        return "%.0f ns" % ns
    if ns < 1_000_000:
        return "%.2f µs" % (ns / 1000)
    return "%.2f ms" % (ns / 1_000_000)


# ---- agreement, first and before any timing is shown
disagreements = []
for op in OPS:
    for bits in SIZES:
        present = {l: values.get((l, op, bits)) for l in LANGS
                   if (l, op, bits) in values}
        if len(present) < 2:
            continue
        distinct = set(present.values())
        if len(distinct) > 1:
            disagreements.append((op, bits, present))

print("## Against JavaScript, Python and Ruby")
print()
checked = sum(1 for op in OPS for bits in SIZES
              if sum(1 for l in LANGS if (l, op, bits) in values) >= 2)
if disagreements:
    print("**%d of %d shared answers disagree.**" % (len(disagreements), checked))
    print()
    for op, bits, present in disagreements:
        print("* `%s` at %d bits: " % (op, bits)
              + ", ".join("%s → `%s`" % (LABEL[l], v[:40]) for l, v in present.items()))
    print()
else:
    print("All four implementations agree on every one of the %d shared answers "
          "they were asked for, at every size." % checked)
    print()

# ---- one table per size
for bits in SIZES:
    print("### %d bits" % bits)
    print()
    print("| operation | swift-bignum | node | python | ruby |")
    print("|---|---:|---:|---:|---:|")
    for op in OPS:
        if ("swift", op, bits) not in times:
            continue
        base = times[("swift", op, bits)]
        cells = [fmt(base)]
        for lang in ["node", "python", "ruby"]:
            t = times.get((lang, op, bits))
            if t is None:
                cells.append("—")
                continue
            ratio = t / base
            bad = any(d[0] == op and d[1] == bits for d in disagreements)
            mark = "" if above_floor(lang, op, bits) or op == "baseline" else " †"
            if bad:
                cells.append("%s (n/c)%s" % (fmt(t), mark))
            elif ratio >= 1:
                cells.append("%s (**%.2f×**)%s" % (fmt(t), ratio, mark))
            else:
                cells.append("%s (%.2f×)%s" % (fmt(t), ratio, mark))
        print("| `%s` | %s |" % (op, " | ".join(cells)))
    print()

# ---- summary: the median ratio per language per size, over the shared ops
print("### Summary")
print()
print("Median of the per-operation ratios, over the operations all four have.")
print("Greater than 1 means swift-bignum was faster.")
print()
shared = [op for op in OPS
          if all((l, op, 64) in times for l in LANGS) and op != "baseline"]
print("| | " + " | ".join("%d bits" % b for b in SIZES) + " |")
print("|---|" + "---:|" * len(SIZES))
for lang in ["node", "python", "ruby"]:
    cells = []
    for bits in SIZES:
        rs = sorted(times[(lang, op, bits)] / times[("swift", op, bits)]
                    for op in shared
                    if (lang, op, bits) in times and ("swift", op, bits) in times
                    and above_floor(lang, op, bits) and above_floor("swift", op, bits))
        if not rs:
            cells.append("—")
        else:
            m = rs[len(rs) // 2]
            cells.append("**%.2f×**" % m if m >= 1 else "%.2f×" % m)
    print("| %s | %s |" % (LABEL[lang], " | ".join(cells)))
print()
print("Operations counted: those that clear %.0f× their own harness's `baseline` on "
      "both sides, out of %s. A † in the tables above marks a cell that does not, "
      "and is therefore mostly measuring the loop rather than the arithmetic."
      % (FLOOR_FACTOR, ", ".join("`%s`" % o for o in shared)))
print()

# ---- the negative-shift table, now with three more implementations in it
print("### `>> 1` on negative values, across five implementations")
print()
have = [l for l in ["swift", "node", "python", "ruby", "attaswift"] if semantics.get(l)]
print("| value | " + " | ".join(LABEL.get(l, l) for l in have) + " |")
print("|---:|" + "---:|" * len(have))
rows = {l: dict(semantics[l]) for l in have}
for v, _ in semantics["swift"]:
    cells = []
    for l in have:
        got = rows[l].get(v, "?")
        cells.append(got if got == rows["python"].get(v) else "**%s**" % got)
    print("| %s | %s |" % (v, " | ".join(cells)))
print()
odd = [l for l in have if rows[l] != rows["python"]]
print("Agreeing: " + ", ".join(LABEL.get(l, l) for l in have if l not in odd)
      + (". Differing: " + ", ".join(LABEL.get(l, l) for l in odd) + "." if odd else "."))
