# Package

version       = "0.1.0"
author        = "Federico Ceratto"
description   = "Terminal dashboards for Nim"
license       = "LGPLv3"

# Dependencies

requires "nim >= 0.18.0"

bin       = @["dashing"]

task tests, "Execute tests":
  exec("mkdir -p tests/bin")
  exec("nim c -r --out:tests/bin/dashing_tests tests/dashing_tests.nim")

task httpTest, "Execute http test":
  exec("mkdir -p tests/bin")
  exec("nim c -r tests/dashing_tests dashing::HTTPTextTest")

task development_test, "Build for testing":
  exec("mkdir -p bin")
  exec("nim c -r -d:testing --out:bin/dashing dashing")

task development, "Build tests for dev":
  exec("mkdir -p bin")
  exec("nim c -r --out:bin/dashing dashing")

