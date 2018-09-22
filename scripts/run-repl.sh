#!/bin/bash
bd=".build/release"
swift build -c release -Xswiftc -enable-testing \
    && swift ${inc} -I${bd} -L${bd} -lBigInt -lBigNum
