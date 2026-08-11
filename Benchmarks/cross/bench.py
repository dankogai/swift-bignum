#!/usr/bin/env python3
#
# The same operations, in CPython's int, on the same inputs.
#
#     python3 cross/bench.py .out/inputs.tsv .out
#
# See bench.js for the shared method notes.  Python has all of the operations,
# `math.isqrt` and `math.gcd` and three-argument `pow` included, so nothing here
# is hand-written.
#
# One semantic difference worth knowing, though it does not affect these numbers:
# Python's `//` and `%` floor, where Swift's `/` and `%` truncate toward zero.
# Every operand below is positive, where the two agree.
#
import math
import sys
import time

input_path, out_dir = sys.argv[1], sys.argv[2]

with open(input_path) as f:
    rows = f.read().strip().split("\n")[1:]

inputs = []
for line in rows:
    bits, a, b, wide = line.split("\t")
    inputs.append((int(bits), int(a, 16), int(b, 16), int(wide, 16), a))

checksum = 0


def measure(body):
    global checksum
    n = 1
    while True:
        t0 = time.perf_counter_ns()
        acc = 0
        for _ in range(n):
            acc ^= body()
        elapsed = time.perf_counter_ns() - t0
        checksum ^= acc
        if elapsed >= 50_000_000 or n >= 1 << 28:
            break
        n = n * 16 if elapsed < 1_000_000 else n * 2
    best = elapsed / n
    for _ in range(4):
        t0 = time.perf_counter_ns()
        acc = 0
        for _ in range(n):
            acc ^= body()
        each = (time.perf_counter_ns() - t0) / n
        checksum ^= acc
        best = min(best, each)
    return best


results = []
values = []


def bench(op, bits, body, value):
    ns = measure(body)
    results.append((op, bits, ns))
    values.append((op, bits, str(value)))
    sys.stderr.write("  %-18s %5d bits  %.1f ns\n" % (op, bits, ns))


def fold(r):
    return abs(r) & 0xFFFF


for bits, a, b, wide, a_hex in inputs:
    dec = str(a)
    bench("baseline", bits, lambda: fold(a), a)
    bench("+", bits, lambda: fold(a + b), a + b)
    bench("-", bits, lambda: fold(a - b), a - b)
    bench("*", bits, lambda: fold(a * b), a * b)
    bench("/", bits, lambda: fold(wide // b), wide // b)
    bench("%", bits, lambda: fold(wide % b), wide % b)
    bench("<", bits, lambda: 1 if a < b else 0, 1 if a < b else 0)
    bench("<< 61", bits, lambda: fold(a << 61), a << 61)
    bench(">> 61", bits, lambda: fold(a >> 61), a >> 61)
    bench("description", bits, lambda: len(str(a)), len(dec))
    bench("init(radix: 10)", bits, lambda: fold(int(dec)), int(dec))
    bench("init(radix: 16)", bits, lambda: fold(int(a_hex, 16)), int(a_hex, 16))
    bench("squareRoot", bits, lambda: fold(math.isqrt(a)), math.isqrt(a))
    bench("gcd", bits, lambda: fold(math.gcd(a, b)), math.gcd(a, b))
    bench("power(5)", bits, lambda: fold(a ** 5), a ** 5)
    if bits <= 1024:
        bench("power(e, mod:)", bits, lambda: fold(pow(a, b, wide)), pow(a, b, wide))


def write(name, header, rows_out):
    with open("%s/%s" % (out_dir, name), "w") as f:
        f.write("\t".join(header) + "\n")
        for r in rows_out:
            f.write("\t".join(str(x) for x in r) + "\n")


semantics = [(v, v >> 1) for v in (-1, -2, -3, -5, -7, -8, -1025)]

write("results-python.tsv", ("op", "bits", "ns"), results)
write("values-python.tsv", ("op", "bits", "value"), values)
write("semantics-python.tsv", ("value", "shifted"), semantics)
sys.stderr.write("\n%s. Checksum: %d\n" % (sys.version.split()[0], checksum))
