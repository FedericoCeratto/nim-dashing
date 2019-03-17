## dashing - terminal dashboards for Nim - test stub
##
## This is executed by tests/functional.nim
##
# Copyright 2018 Federico Ceratto <federico.ceratto@gmail.com>
# Released under LGPLv3. See LICENSE file.

import math,
  os,
  strutils,
  terminal

import dashing

const sleeptime = 400

proc basic() =
  var ui = Tile(kind:HSplit, title:"foo", border_color:"00f")
  ui.display()
  sleep sleeptime

proc basic3display() =
  var ui = Tile(kind:HSplit, title:"foo", border_color:"00f")
  ui.display()
  set_cursor_at(0, terminal_height())
  ui.display()
  set_cursor_at(0, terminal_height())
  ui.display()
  set_cursor_at(0, terminal_height())
  sleep sleeptime

proc two_rows() =
  var ui = Tile(kind:VSplit, border_color:"f00", items: @[
    Tile(kind:HChart, border_color:"0f0", low_color:"2d2", high_color:"bfb"),
    Tile(kind:VChart, border_color:"88f", color:""),
  ])
  ui.display()
  sleep sleeptime

proc titles() =
  var ui = Tile(kind:VSplit, items: @[
    Tile(kind:HChart, title: "a-short-title",
      border_color:"0f0"),
    Tile(kind:HChart, title: "quite-long-title",
      border_color:"0f0"),
    Tile(kind:HChart, title: "quite-long-title1",
      border_color:"0f0"),
    Tile(kind:HChart, title: "quite-long-title22",
      border_color:"0f0"),
    Tile(kind:HChart, title: "quite-long-title333",
      border_color:"0f0"),
    Tile(kind:HChart, title: "quite-long-title4444",
      border_color:"0f0"),
  ])
  ui.display()
  sleep sleeptime


proc three_cols() =
  var ui = Tile(kind:HSplit, border_color:"f00", items: @[
    Tile(kind:VSplit, items: @[
      Tile(kind:HGauge, val:50, title:"only title", border_color:"f88"),
      Tile(kind:HGauge, label:"label", val:20, border_color:"f88"),
      Tile(kind:HGauge, label:"label", val:30, border_color:"f88"),
      Tile(kind:HGauge, label:"label", val:80, border_color:"f88"),
      Tile(kind:HGauge, label:"label, no border", val:55),
      Tile(kind:HSplit, items: @[
        Tile(kind:VGauge, val:0),
        Tile(kind:VGauge, val:5),
        Tile(kind:VGauge, val:10),
        Tile(kind:VGauge, val:20),
        Tile(kind:VGauge, val:40),
        Tile(kind:VGauge, val:80),
      ]),
    ]),
    Tile(kind:VSplit, items: @[
      Tile(kind:HSplit, border_color:"0ff"),
      Tile(kind:HChart, border_color:"0f0", low_color:"2d2", high_color:"bfb"),
      Tile(kind:Log, title:"logs", border_color:"000"),
    ]),
    Tile(kind:VSplit, items: @[
      Tile(kind:Text, text:"Hello World,\nthis is dashing.\n012345678901234567890123\n0123456789012345678901234\n01234567890123456789012345\na\nb", border_color:"000"),
      Tile(kind:VChart, border_color:"88f", color:""),
      Tile(kind:HBrailleChart, border_color:"88f", color:""),
      Tile(kind:HBrailleFilledChart, border_color:"88f", color:"")
    ])
  ])

  var cycle = 10.1
  ui.items[0].items[0].val = int(50 + 49.9 * math.sin(cycle / 80.0))
  ui.items[0].items[1].val = int(50 + 45 * math.sin(cycle / 20.0))
  ui.items[0].items[2].val = int(50 + 45 * math.sin(cycle / 30.0 + 3))

  # Center column
  # HChart
  for c in 0..25:
    ui.items[1].items[1].add_dp(50 + 49.9 * sin((c.float) / 16.0))
  ui.items[1].items[2].add_log("log n. $#" % $cycle)

  # Right column
  #for c in 0..25:
  #  ui.items[1].items[2].add_dp(50 + 49.9 * sin((c.float) / 16.0))
  #ui.items[2].items[0].add_log("end")
  for c in 0..55:
    ui.items[2].items[1].add_dp(50 + 49.9 * sin((c.float) / 8.0)) # VChart
    ui.items[2].items[2].add_dp(50 + 49.9 * sin((c.float) / 8.0)) # HBrailleChart
    ui.items[2].items[3].add_dp(50 + 49.9 * sin((c.float) / 8.0)) # HBrailleFilledChart
  ui.display()
  set_cursor_at(0, terminal_height())
  sleep sleeptime

proc braille() =
  var ui = Tile(kind:HBrailleChart, border_color:"88f", color:"")
  for cycle in 0..<150:
    ui.add_dp(50.0 + cycle.float / 8.0 * sin((cycle.float) / 2.0))
    #ui.append(50 + float(cycle)/ 40 * 5 * math.sin(cycle / 2.0)
  ui.display()
  set_cursor_at(0, terminal_height())
  sleep sleeptime


when isMainModule:
  if paramCount() != 1:
    echo "ERROR: use ./stub <testname>"
    quit(1)
  case paramStr(1):
  of "basic": basic()
  of "basic3display": basic3display()
  of "2rows": two_rows()
  of "3cols": three_cols()
  of "titles": titles()
  of "braille": braille()
  else:
    echo "ERROR: unknown test " & paramStr(1)
    quit(1)

