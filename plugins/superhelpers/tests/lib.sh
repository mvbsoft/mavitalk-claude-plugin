#!/usr/bin/env sh
# Minimal, dependency-free test helpers. Each test file sources this.
TESTS_RUN=0
TESTS_FAILED=0

assert_eq() { # desc, expected, actual
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$2" = "$3" ]; then
    printf '  ok   - %s\n' "$1"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  FAIL - %s\n      expected: [%s]\n      actual:   [%s]\n' "$1" "$2" "$3"
  fi
}

assert_empty() { # desc, actual
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -z "$2" ]; then
    printf '  ok   - %s\n' "$1"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  FAIL - %s\n      expected empty, got: [%s]\n' "$1" "$2"
  fi
}

finish_tests() {
  printf '%s run, %s failed\n' "$TESTS_RUN" "$TESTS_FAILED"
  [ "$TESTS_FAILED" -eq 0 ]
}
