#!/bin/sh
#
# swift-bignum's BigInt against JavaScript, Python and Ruby.
#
#     cd Benchmarks && sh cross/run.sh
#
# The Swift harness runs first because it is the one that generates the inputs:
# it writes .out/inputs.tsv, and the other three read it, so all four are handed
# identical numbers to work on rather than each making up its own.
#
# Everything lands in .out/ (gitignored).  The tables for Benchmark.md go to
# stdout; progress goes to stderr, so `sh cross/run.sh > tables.md` gives you
# just the tables.
#
# Takes a few minutes.  Most of it is the modular exponentiation at 1024 bits,
# where one call is tens of milliseconds in every language.
#
set -e
cd "$(dirname "$0")/.."
mkdir -p .out

# macOS ships /usr/bin/ruby, and a Mac with Homebrew or MacPorts on PATH has a
# much newer one that measures very differently.  Default to the system copy and
# say which was used; override with RUBY=/path/to/ruby.
RUBY="${RUBY:-/usr/bin/ruby}"
command -v "$RUBY" > /dev/null 2>&1 || RUBY=ruby

missing=""
for tool in node python3 "$RUBY"; do
    command -v "$tool" > /dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
    echo "not found:$missing -- install them, or run the harnesses you have by hand" >&2
    exit 1
fi

echo "=== swift-bignum (release), which also writes the shared inputs" >&2
swift run -c release > .out/swift-vs-attaswift.md

echo "=== node" >&2
node    cross/bench.js .out/inputs.tsv .out
echo "=== python" >&2
python3 cross/bench.py .out/inputs.tsv .out
echo "=== ruby ($RUBY, $("$RUBY" -e 'print RUBY_VERSION'))" >&2
"$RUBY" cross/bench.rb .out/inputs.tsv .out

echo "=== merging" >&2
python3 cross/merge.py .out
