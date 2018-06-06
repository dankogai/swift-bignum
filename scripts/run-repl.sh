#!/bin/bash
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    inc=-I/usr/lib/swift/clang/include
else
    inc=""
fi
swift build && swift ${inc} -I.build/debug -L.build/debug -lBigInt -lBigNum
