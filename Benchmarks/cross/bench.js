//
// The same operations, in JavaScript's BigInt, on the same inputs.
//
//     node cross/bench.js .out/inputs.tsv .out
//
// Method notes that matter for reading the numbers:
//
//  *  The loop body is timed as a whole, so per-op figures include one iteration
//     of the interpreter's own loop.  The `baseline` row measures exactly that
//     loop with no arithmetic in it, which is the floor everything else sits on.
//  *  Each result is folded into an accumulator that gets printed, so V8 cannot
//     drop the computation.  The operands are loop-invariant, which a JIT is in
//     principle free to hoist; the `baseline` row is what would expose it, since
//     a hoisted operation would come out at roughly that floor.
//  *  V8 has no BigInt square root, gcd or modular exponentiation.  Those rows
//     are absent rather than hand-written: timing a loop I wrote in JavaScript
//     would measure my loop, not the runtime.
//
const fs = require('fs')

const [inputPath, outDir] = [process.argv[2], process.argv[3]]
const rows = fs.readFileSync(inputPath, 'utf8').trim().split('\n').slice(1)
const inputs = rows.map(line => {
  const [bits, a, b, wide] = line.split('\t')
  return { bits: Number(bits), a: BigInt('0x' + a), b: BigInt('0x' + b),
           wide: BigInt('0x' + wide), aHex: a }
})

let checksum = 0n

function measure(body) {
  let n = 1, elapsed = 0n
  for (;;) {
    const t0 = process.hrtime.bigint()
    let acc = 0n
    for (let i = 0; i < n; i++) acc ^= body()
    elapsed = process.hrtime.bigint() - t0
    checksum ^= acc
    if (elapsed >= 50_000_000n || n >= (1 << 28)) break
    n = elapsed < 1_000_000n ? n * 16 : n * 2
  }
  let best = Number(elapsed) / n
  for (let round = 0; round < 4; round++) {
    const t0 = process.hrtime.bigint()
    let acc = 0n
    for (let i = 0; i < n; i++) acc ^= body()
    const each = Number(process.hrtime.bigint() - t0) / n
    checksum ^= acc
    best = Math.min(best, each)
  }
  return best
}

const results = []   // [op, bits, ns]
const values = []    // [op, bits, decimal] -- for the cross-language agreement check

function bench(op, bits, body, value) {
  const ns = measure(body)
  results.push([op, bits, ns])
  values.push([op, bits, String(value)])
  process.stderr.write(`  ${op.padEnd(18)} ${String(bits).padStart(5)} bits  ${ns.toFixed(1)} ns\n`)
}

// fold a BigInt result down to something cheap that still depends on all of it
const fold = r => (r < 0n ? -r : r) & 0xffffn

for (const { bits, a, b, wide, aHex } of inputs) {
  const dec = a.toString()
  bench('baseline', bits, () => fold(a), a)
  bench('+', bits, () => fold(a + b), a + b)
  bench('-', bits, () => fold(a - b), a - b)
  bench('*', bits, () => fold(a * b), a * b)
  bench('/', bits, () => fold(wide / b), wide / b)
  bench('%', bits, () => fold(wide % b), wide % b)
  bench('<', bits, () => (a < b ? 1n : 0n), a < b ? 1 : 0)
  bench('<< 61', bits, () => fold(a << 61n), a << 61n)
  bench('>> 61', bits, () => fold(a >> 61n), a >> 61n)
  bench('description', bits, () => BigInt(a.toString().length), dec.length)
  bench('init(radix: 10)', bits, () => fold(BigInt(dec)), BigInt(dec))
  bench('init(radix: 16)', bits, () => fold(BigInt('0x' + aHex)), BigInt('0x' + aHex))
  bench('power(5)', bits, () => fold(a ** 5n), a ** 5n)
  // no squareRoot, gcd or power(e, mod:) in the language
}

// `>> 1` on negatives, the same table every harness emits
const semantics = [-1, -2, -3, -5, -7, -8, -1025]
      .map(v => [v, (BigInt(v) >> 1n).toString()])

function write(name, rowsOut) {
  fs.writeFileSync(`${outDir}/${name}`, rowsOut.map(r => r.join('\t')).join('\n') + '\n')
}
write('results-node.tsv', [['op', 'bits', 'ns'], ...results])
write('values-node.tsv', [['op', 'bits', 'value'], ...values])
write('semantics-node.tsv', [['value', 'shifted'], ...semantics])
process.stderr.write(`\nnode ${process.version} (V8 ${process.versions.v8}). Checksum: ${checksum}\n`)
