#!/usr/bin/env ruby
#
# The same operations, in Ruby's Integer, on the same inputs.
#
#     ruby cross/bench.rb .out/inputs.tsv .out
#
# See bench.js for the shared method notes.  Ruby has all of the operations
# natively: Integer.sqrt, Integer#gcd, and Integer#pow with a modulus.
#
# Whether Ruby's big integers are its own code or GMP's depends on how the
# interpreter was built, and it changes the large-size numbers completely.  This
# prints which one it got.
#
input_path, out_dir = ARGV[0], ARGV[1]

inputs = File.read(input_path).strip.split("\n")[1..].map do |line|
  bits, a, b, wide = line.split("\t")
  [bits.to_i, a.to_i(16), b.to_i(16), wide.to_i(16), a]
end

$checksum = 0

def measure
  n = 1
  elapsed = 0
  loop do
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
    acc = 0
    n.times { acc ^= yield }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t0
    $checksum ^= acc
    break if elapsed >= 50_000_000 || n >= (1 << 28)
    n = elapsed < 1_000_000 ? n * 16 : n * 2
  end
  best = elapsed.to_f / n
  4.times do
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
    acc = 0
    n.times { acc ^= yield }
    each = (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t0).to_f / n
    $checksum ^= acc
    best = [best, each].min
  end
  best
end

results = []
values = []

def fold(r)
  r.abs & 0xffff
end

def bench(results, values, op, bits, value)
  ns = measure { yield }
  results << [op, bits, ns]
  values << [op, bits, value.to_s]
  $stderr.printf("  %-18s %5d bits  %.1f ns\n", op, bits, ns)
end

inputs.each do |bits, a, b, wide, a_hex|
  dec = a.to_s
  bench(results, values, 'baseline', bits, a) { fold(a) }
  bench(results, values, '+', bits, a + b) { fold(a + b) }
  bench(results, values, '-', bits, a - b) { fold(a - b) }
  bench(results, values, '*', bits, a * b) { fold(a * b) }
  bench(results, values, '/', bits, wide / b) { fold(wide / b) }
  bench(results, values, '%', bits, wide % b) { fold(wide % b) }
  bench(results, values, '<', bits, a < b ? 1 : 0) { a < b ? 1 : 0 }
  bench(results, values, '<< 61', bits, a << 61) { fold(a << 61) }
  bench(results, values, '>> 61', bits, a >> 61) { fold(a >> 61) }
  bench(results, values, 'description', bits, dec.length) { a.to_s.length }
  bench(results, values, 'init(radix: 10)', bits, dec.to_i) { fold(dec.to_i) }
  bench(results, values, 'init(radix: 16)', bits, a_hex.to_i(16)) { fold(a_hex.to_i(16)) }
  bench(results, values, 'squareRoot', bits, Integer.sqrt(a)) { fold(Integer.sqrt(a)) }
  bench(results, values, 'gcd', bits, a.gcd(b)) { fold(a.gcd(b)) }
  bench(results, values, 'power(5)', bits, a**5) { fold(a**5) }
  if bits <= 1024
    bench(results, values, 'power(e, mod:)', bits, a.pow(b, wide)) { fold(a.pow(b, wide)) }
  end
end

def write(out_dir, name, header, rows)
  File.open("#{out_dir}/#{name}", 'w') do |f|
    f.puts header.join("\t")
    rows.each { |r| f.puts r.join("\t") }
  end
end

semantics = [-1, -2, -3, -5, -7, -8, -1025].map { |v| [v, v >> 1] }

write(out_dir, 'results-ruby.tsv', %w[op bits ns], results)
write(out_dir, 'values-ruby.tsv', %w[op bits value], values)
write(out_dir, 'semantics-ruby.tsv', %w[value shifted], semantics)
args = RbConfig::CONFIG['configure_args'].to_s
gmp = if args.include?('without-gmp') then 'built without GMP'
      elsif args.include?('with-gmp') then 'built with GMP'
      else 'GMP not mentioned either way in configure_args'
      end
File.write("#{out_dir}/version-ruby.txt", "ruby #{RUBY_VERSION} (#{RbConfig.ruby}, #{gmp})\n")
$stderr.puts "\nruby #{RUBY_VERSION} at #{RbConfig.ruby} (#{gmp}). Checksum: #{$checksum}"
