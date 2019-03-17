## dashing - terminal dashboards for Nim - functional tests
##
## Compiles and executes stub.nim wrapped in tmux and captures the output
##
# Copyright 2018 Federico Ceratto <federico.ceratto@gmail.com>
# Released under LGPLv3. See LICENSE file.

import unittest
from osproc import execCmd
import strutils, times
from os import sleep

# the sleeptime here must be lower than in stub.nim to capture the output while stub.nim is "running"
const sleeptime = 200

# tmux attach-session -r -t foo

proc new_session(x, y: int) =
  discard execCmd "tmux new-session -d -x $# -y $# -s foo" % [$x, $y]

proc start_test(testname: string) =
  ## Run tests binary
  assert 0 == execCmd("tmux send -t foo ./tests/stub \\ " & testname & " ENTER")

proc set_size(x, y: int) =
  assert 0 == execCmd("tmux setw -t foo force-width " & $x)
  assert 0 == execCmd("tmux setw -t foo force-height " & $y)
  #assert 0 == execCmd("tmux showenv")
  assert 0 == execCmd("tmux send-keys -t foo C-r")
  #assert 0 == execCmd("tmux attach-session -d -r \\; detach")

proc capture(): seq[string] =
  assert 0 == execCmd("tmux capture-pane -t foo -p > out")
  result = readFile("out").splitLines()
  if result[^1] == "" and result[^2].endsWith("$"):
    result.delete(result.high - 1)  # trim line containing prompt

proc runtest(testname: string, x, y: int): seq[string] =
  ## Run tests binary. Capture output.
  ## Run command in a new, detached tmux session named "foo".
  ## The test command is ran straight away without a shell
  #let cmd = "tmux new-session -d -x $# -y $# -s foo ./tests/stub $#" % [$x, $y, testname]
  #echo "    Running: " & cmd
  #assert 0 == execCmd(cmd)
  new_session(x, y)
  start_test(testname)
  sleep sleeptime  # allow test to start
  #assert 0 == execCmd("tmux send -t foo ENTER")
  #tmux send-keys -t "$pane" C-z 'some -new command' Enter
  #sleep 100
  capture()


proc compare(o: seq[string], expected_s: string): bool =
  ## compare output
  var expected: seq[string] = @[]
  for i in expected_s.splitLines():
    if i.len > 6:
      expected.add i[6..^1]
    elif i == "    " or i == "":
      expected.add ""

  for cnt, oline in o:
    if cnt > expected.high:
      echo "line num: ", $cnt
      echo "unexpected line!"
      echo "output   >" & oline & "<"
      return false
    if expected[cnt] != oline:
      echo "line num: ", $cnt
      echo "expected >" & expected[cnt] & "<"
      echo ""
      for cnt2, oline2 in o:
        if cnt == cnt2:
          echo "output   >" & oline2 & "<"
        else:
          echo "output    " & oline2
      return false

  return o.len == expected.len

proc expect_output(expected_s: string): bool =
  ## Capture and compare output
  let output = capture()
  compare(output, expected_s)

suite "functional":

  assert execCmd("nim c -d:prefill -p:. tests/stub.nim") == 0
  discard execCmd "tmux kill-session -t foo"

  teardown:
    discard execCmd "tmux kill-session -t foo"

  test "basic - tiny 2x3":
    const expected = """
      ┌┐
      ││
      └┘
    """
    let o = runtest("basic", 2, 3)
    check compare(o, expected)

  test "basic3display - tiny":
    const expected = """
      ┌────── foo ───────┐
      │                  │
      │                  │
      │                  │
      └──────────────────┘
    """
    let o = runtest("basic3display", 20, 5)
    check compare(o, expected)

#  test "height of 15":
#    const expected = """
#    """
#    new_session(100, 15)
#    let o = runtest("3cols")
#    check compare(o, expected)
#
#  test "width of 15":
#    const expected = """
#    """
#    new_session(15, 30)
#    let o = runtest("3cols")
#    check compare(o, expected)
#
#  test "small":
#    const expected = """
#    """
#    new_session(15, 10)
#    let o = runtest("3cols")
#    check compare(o, expected)

  test "braille":
    const expected = """
      ┌──────────────────────────────────────┐
      │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
      │⠀⠀⡠⢄⠀⠀⠀⠀⡠⠤⡀⠀⠀⠀⢀⠤⢄⠀⠀⠀⢀⠔⠤⠀⠀⠀⠀⠔⠢⡀⠀⠀⠀⡠⠒⢄⠀⠀│
      │⠊⠁⠀⠀⠈⠒⠒⠁⠀⠀⠀⠑⠤⠊⠀⠀⠀⠑⠤⠔⠀⠀⠀⠈⠢⠤⠁⠀⠀⠀⠢⡠⠊⠀⠀⠀⠡⣀│
      │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
      └──────────────────────────────────────┘
    """
    let o = runtest("braille", 40, 6)
    check compare(o, expected)

  test "2rows":
    const expected = """
      ┌──────────────────┐
      │┌────────────────┐│
      ││                ││
      ││                ││
      │└────────────────┘│
      │┌────────────────┐│
      ││▉▉▉▏            ││
      ││                ││
      │└────────────────┘│
      └──────────────────┘
    """
    let o = runtest("2rows", 20, 10)
    check compare(o, expected)

  test "titles":
    const expected = """
      ┌─ a-short-title ──┐
      └──────────────────┘
      ┌ quite-long-title ┐
      └──────────────────┘
      ┌quite-long-title1─┐
      └──────────────────┘
      ┌quite-long-title22┐
      └──────────────────┘
      ┌quite-long-title33┐
      └──────────────────┘
      ┌quite-long-title44┐
      └──────────────────┘
    """
    let o = runtest("titles", 20, 12)
    check compare(o, expected)

  test "3cols":
    const expected = """
      ┌────────────────────────────────────────────────────────────────────────────────────────┐
      │┌─────── only title ────────┐┌───────────────────────────┐┌───────────────────────────┐ │
      ││▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▏▎▎▎▎▎▎▎▎▎▎▎││                           ││Hello World,               │ │
      ││▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▏▎▎▎▎▎▎▎▎▎▎▎││                           ││this is dashing.           │ │
      │└───────────────────────────┘│                           ││012345678901234567890123   │ │
      │┌───────────────────────────┐│                           ││                           │ │
      ││      ▉▉▉▉▉▉▉▉▉▉▉▉▉▌▎▎▎▎▎▎▎││                           │└───────────────────────────┘ │
      ││label ▉▉▉▉▉▉▉▉▉▉▉▉▉▌▎▎▎▎▎▎▎││                           │┌───────────────────────────┐ │
      │└───────────────────────────┘└───────────────────────────┘│▉▉▉▉▉▏                     │ │
      │┌───────────────────────────┐┌───────────────────────────┐│                           │ │
      ││      ▉▉▉▉▉▉▉▊▎▎▎▎▎▎▎▎▎▎▎▎▎││              ▁▁▂▃▄▄▅▆▆▇▇▇▇││                           │ │
      ││label ▉▉▉▉▉▉▉▊▎▎▎▎▎▎▎▎▎▎▎▎▎││        ▁▂▃▄▆▇█████████████││                           │ │
      │└───────────────────────────┘│   ▁▂▄▅▇███████████████████│└───────────────────────────┘ │
      │┌───────────────────────────┐│  █████████████████████████│┌───────────────────────────┐ │
      ││      ▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▎▎▎▎▎▎││  █████████████████████████││⠀⠀⢀⠔⠉⠉⠉⠉⠢⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ │
      ││label ▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▎▎▎▎▎▎││  █████████████████████████││⡠⠊⠀⠀⠀⠀⠀⠀⠀⠀⠐⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⠊│ │
      │└───────────────────────────┘└───────────────────────────┘│⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⠊⠀⠀│ │
      │                 ▉▉▉▉▉▌▎▎▎▎▎▎┌────────── logs ───────────┐│⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠢⢄⠀⠀⠀⣀⠔⠁⠀⠀⠀⠀│ │
      │                 ▉▉▉▉▉▌▎▎▎▎▎▎│log n. 10.1                │└───────────────────────────┘ │
      │label, no border ▉▉▉▉▉▌▎▎▎▎▎▎│                           │┌───────────────────────────┐ │
      │                 ▉▉▉▉▉▌▎▎▎▎▎▎│                           ││⠀⠀⢀⣴⣿⣿⣿⣿⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ │
      │                    ▂▂▂▂     │                           ││⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣾│ │
      │                    ████     │                           ││⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣾⣿⣿│ │
      │                ▅▅▅▅████     │                           ││⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣄⠀⠀⠀⣀⣴⣿⣿⣿⣿⣿│ │
      │▁▁▁▁▂▂▂▂▄▄▄▄▇▇▇▇████████     └───────────────────────────┘└───────────────────────────┘ │
      └────────────────────────────────────────────────────────────────────────────────────────┘
    """
    let o = runtest("3cols", 90, 26)
    check compare(o, expected)
