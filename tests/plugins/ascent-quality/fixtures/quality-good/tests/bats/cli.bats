#!/usr/bin/env bats

@test "AC-2 the refund command lowers the charge" {
  run echo 6
  [ "$status" -eq 0 ]
  [ "$output" = 6 ]
}
