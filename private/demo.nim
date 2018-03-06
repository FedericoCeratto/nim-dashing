## dashing - terminal dashboards for Nim - demo
# Copyright 2018 Federico Ceratto <federico.ceratto@gmail.com>
# Released under LGPLv3. See LICENSE file.

import math,
  strutils,
  terminal

from os import sleep

import dashing

proc demo() =
  ## Demo
  #var d = QuickDash()
  #d.status = "Running..."
  #d.logs.append("Started")
  #for progress in 0..100:
  #  d.gauges["progess"] = progress
  #  if progress == 0:
  #    d.logs.append("Started")
  #  sleep 50

  #d.status = "Done!"
  #sleep 500

  when not defined(testing):
    erase_screen()

  var ui = Tile(kind:HSplit, title:"foo", border_color:"f00", items: @[
    Tile(kind:VSplit, items: @[
      Tile(kind:HGauge, val:50, title:"only title", border_color:"f88"),
      Tile(kind:HGauge, label:"only label", val:20, border_color:"f88"),
      Tile(kind:HGauge, label:"only label", val:30, border_color:"f88"),
      Tile(kind:HGauge, label:"only label", val:50, border_color:"f88"),
      Tile(kind:HGauge, label:"only label", val:80, border_color:"f88"),
      Tile(kind:HGauge, val:20),
      Tile(kind:HGauge, label:"label, no border", val:55),
      Tile(kind:HSplit, items: @[
        Tile(kind:VGauge, val:0),
        Tile(kind:VGauge, val:5),
        Tile(kind:VGauge, val:30),
        Tile(kind:VGauge, val:50),
        Tile(kind:VGauge, val:80),
        Tile(kind:VGauge, val:95),
      ]),
    ]),
    Tile(kind:VSplit, items: @[
      Tile(kind:HSplit, border_color:"0ff"),
      Tile(kind:HChart, border_color:"0f0", low_color:"2d2", high_color:"bfb"),
      Tile(kind:Log, title:"logs", border_color:"000"),
    ]),
    Tile(kind:HSplit, items: @[
      # Tile(kind:VGauge, val:95, low_color:"2d2", high_color:"22d"),
      # Tile(kind:VGauge, val:95, low_color:"2d2", high_color:"22d"),
      # Tile(kind:VGauge, val:95, low_color:"2d2", high_color:"22d"),
      # Tile(kind:VGauge, val:95, low_color:"0c0", high_color:"c00"),
      Tile(kind:Text, text:"Hello World,\nthis is dashing.", border_color:"000"),
      Tile(kind:Log, title:"logs", border_color:"000"),
      Tile(kind:VChart, border_color:"", color:""),
      Tile(kind:HChart, border_color:"0f0", low_color:"2d2", high_color:"bfb"),
      Tile(kind:HBrailleChart, border_color:"", color:""),
      Tile(kind:HBrailleFilledChart, border_color:"", color:"")
    ])
  ])

  const demo_count = 130
  for cycle_i in 0..demo_count:
    var cycle = float cycle_i
    ui.items[0].items[0].val = int(50 + 49.9 * math.sin(cycle / 80.0))
    ui.items[0].items[1].val = int(50 + 45 * math.sin(cycle / 20.0))
    ui.items[0].items[2].val = int(50 + 45 * math.sin(cycle / 30.0 + 3))

    # vgauges
    #for n in 0..5:
    #  ui.items[0].items[7].items[n].val =
    #    int(50 + 49.9 * math.sin(cycle / 12.0 + n.float))
    #for n in 0..3:
    #  ui.items[2].items[n].val = int(50 + 49.9 * math.sin(cycle / 52.0 + n.float))

    # HChart
    ui.items[1].items[1].add_dp(50 + 49.9 * sin(cycle / 16.0))

    ui.items[1].items[2].add_log("log n. $#" % $cycle_i)

    ui.display()
    sleep 1000 div 30

  set_cursor_at(0, terminal_height() - 1)


when isMainModule:
  demo()
