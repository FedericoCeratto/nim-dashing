# Package

version       = "0.1.1"
author        = "Federico Ceratto"
description   = "Terminal dashboards for Nim"
license       = "LGPLv3"

# Dependencies

requires "nim >= 0.17.2"

bin       = @["dashing"]

task functests, "functional tests":
  exec "nim c tests/functional.nim"
  exec "./tests/functional"
