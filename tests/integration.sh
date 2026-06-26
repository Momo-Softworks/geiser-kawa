#!/usr/bin/env bash
# Integration test: pipes exact geiser protocol expressions to Kawa.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/../src" && pwd)"
PASS=0
FAIL=0

check() {
    local label="$1" expr="$2" expected="$3"
    echo -n "  $label ... "
    local out=$(echo "$expr" | timeout 5 kawa -Dkawa.import.path="$SRC" \
                 -e '(import (geiser emacs))' -s 2>/dev/null)
    if echo "$out" | grep -q "$expected"; then
        echo "PASS"
        PASS=$((PASS+1))
    else
        echo "FAIL (expected '$expected')"
        echo "    got: '$out'"
        FAIL=$((FAIL+1))
    fi
}

echo "=== Geiser protocol simulation tests ==="

# These are the EXACT expressions that geiser sends to Kawa.

# Test 1: geiser-eval wraps completions  
# geiser sends: (:eval (:ge completions "String:valu"))
# Our eval case produces: (geiser-eval #f "(geiser-completions \"String:valu\")")
check "eval + completions String:valu" \
      '(geiser-eval #f "(geiser-completions \"String:valu\")")' \
      'valueOf'

# Test 2: geiser-eval with fully qualified
check "eval + completions java.lang.String:valu" \
      '(geiser-eval #f "(geiser-completions \"java.lang.String:valu\")")' \
      'valueOf'

# Test 3: raw completions call (bypassing geiser-eval)
check "raw completions String:valu" \
      '(geiser-completions "String:valu")' \
      'valueOf'

# Test 4: Scheme symbol completion through geiser-eval
check "eval + completions disp" \
      '(geiser-eval #f "(geiser-completions \"disp\")")' \
      'display'

# Test 5: basic eval  
check "basic eval" \
      '(geiser-eval #f "(+ 1 2)")' \
      '"3"'

# Test 6: classpath completions
check "classpath completions" \
      '(begin (import (geiser classpath)) (ensure-class-cache) (> (length *class-cache*) 100))' \
      '#t'

echo "=== $PASS passed, $FAIL failed ==="
exit $FAIL
