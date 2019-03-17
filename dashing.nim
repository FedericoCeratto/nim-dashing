## dashing - terminal dashboards for Nim
# Copyright 2018 Federico Ceratto <federico.ceratto@gmail.com>
# Released under LGPLv3. See LICENSE file.

import os,
  strutils,
  terminal,
  unicode

from math import floor

# "graphic" elements

const
  border_bl = "└"
  border_br = "┘"
  border_tl = "┌"
  border_tr = "┐"
  border_h = "─"
  border_v = "│"
  hbar_elements = ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
  vbar_elements = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
  braille_h_symbols = [
    "⠀", "⢀", "⠠", "⠐", "⠈",
    "⡀", "⣀", "⡠", "⡐", "⡈",
    "⠄", "⢄", "⠤", "⠔", "⠌",
    "⠂", "⢂", "⠢", "⠒", "⠊",
    "⠁", "⢁", "⠡", "⠑", "⠉",
  ]
  braille_h_symbols_filled = [
    "⠀", "⢀", "⢠", "⢰", "⢸",
    "⡀", "⣀", "⣠", "⣰", "⣸",
    "⡄", "⣄", "⣤", "⣴", "⣼",
    "⡆", "⣆", "⣦", "⣶", "⣾",
    "⡇", "⣇", "⣧", "⣷", "⣿",
  ]
  max_chart_datapoints = 256
  max_logs = 128

type
  TBox = object
    t: string
    x, y, w, h: int

  TileKind* = enum
    HSplit, VSplit, VChart, HChart, HGauge, VGauge, Log, Text, HBrailleChart, HBrailleFilledChart

  Tile* = ref object of RootObj
    title*: string
    border_color*: string
    color*: string
    low_color*, mid_color*, high_color*: string
    case kind*: TileKind
    of HSplit, VSplit:
      items*: seq[Tile]
    of HBrailleChart, HBrailleFilledChart, VChart, HChart:
      datapoints*: array[max_chart_datapoints, float]
      datapoints_cnt, last_dp_pos: int
    of HGauge, VGauge:
      val*: int
      label*: string
    of Log:
      logs*: array[max_logs, string]
      logs_cnt, last_log_pos: int
    of Text:
      text*: string


  RGBColor = tuple
    r, g, b: int


proc print(s: string) =
  stdout.write s

proc flush() =
  stdout.flushFile

proc set_cursor_at*(x, y: int) =
  when not defined(testing):
    set_cursor_pos(x, y)


proc is_empty(s: string): bool =
  return s == ""


proc newTBox(t: string, x, y, w, h: int): TBox =
  TBox(t:t, x:x, y:y, w:w, h:h)


proc unpack_color(c: string): RGBColor =
  case c.len
  of 3:
    return (
      parseHexInt($c[0]) * 16,
      parseHexInt($c[1]) * 16,
      parseHexInt($c[2]) * 16
    )
  of 6:
    return (
      parseHexInt(c[0..1]),
      parseHexInt(c[2..3]),
      parseHexInt(c[3..4])
    )
  else:
    raise newException(Exception, "unsupported color $#" % c)

proc set_color(c: RGBColor) =
  print "\x1b[38;2;$#;$#;$#m" % [$c.r, $c.g, $c.b]

proc set_color(c: string) =
  ## Set foreground color
  if c == "":
    return
  set_color(unpack_color(c))

proc set_merged_color(lo, mid, hi: string, ratio: float) =
  ## Set merged foreground color
  var lo_c, hi_c: RGBColor
  var ratio = ratio
  if mid == "":
    lo_c = unpack_color(lo)
    hi_c = unpack_color(hi)
  elif ratio < 0.5:
    lo_c = unpack_color(mid)
    hi_c = unpack_color(hi)
    ratio *= 2
  else:
    lo_c = unpack_color(lo)
    hi_c = unpack_color(mid)
    ratio -= 0.5
    ratio *= 2

  let c:RGBColor = (
    int(lo_c.r.float * ratio + hi_c.r.float * (1.0 - ratio)),
    int(lo_c.g.float * ratio + hi_c.g.float * (1.0 - ratio)),
    int(lo_c.b.float * ratio + hi_c.b.float * (1.0 - ratio)),
  )
  set_color c



proc draw_borders(self: Tile, tbox: TBox) =
  set_color(self.border_color)

  # top border
  set_cursor_at(tbox.x, tbox.y)
  print(border_tl & border_h.repeat(tbox.w - 2) & border_tr)

  # left and right
  for dy in 1..tbox.h-2:
    set_cursor_at(tbox.x , tbox.y + dy)
    print border_v
    set_cursor_at(tbox.x + tbox.w - 1, tbox.y + dy)
    print border_v

  # bottom
  set_cursor_at(tbox.x, tbox.h - 1 + tbox.y)
  print border_bl & border_h.repeat(tbox.w - 2) & border_br


proc draw_title(self: Tile, tbox: TBox) =
  ## Draw title
  if self.border_color == "":
    # no borders
    return

  let free_space = (tbox.w - self.title.len)
  if free_space >= 4:
    # enough space to have white margins
    set_cursor_at(tbox.x + free_space div 2 - 1, tbox.y)
    print " " & self.title & " "
  elif free_space >= 2:
    # in contact with corners
    set_cursor_at(tbox.x + 1, tbox.y)
    print self.title
  elif free_space >= 0:
    # truncated
    set_cursor_at(tbox.x + 1, tbox.y)
    print self.title[0..(tbox.w - 3)]


proc draw_borders_and_title(self: Tile, tbox: TBox): TBox =
  ## Draw borders and title as needed and returns inset (x, y, width, height)
  if self.border_color != "":
    self.draw_borders(tbox)

  if self.title.len != 0:
    self.draw_title(tbox)

  if self.border_color != "":
    return newTBox(tbox.t, tbox.x + 1, tbox.y + 1, tbox.w - 2, tbox.h - 2)

  elif self.title != "":
    return newTBox(tbox.t, tbox.x + 1, tbox.y, tbox.w - 1, tbox.h - 1)

  return newTBox(tbox.t, tbox.x, tbox.y, tbox.w, tbox.h)

proc fill_area(self: Tile, tbox: TBox, c: char) =
  for dy in 0..<tbox.h:
    set_cursor_at(tbox.x, tbox.y + dy)
    print repeat(c, tbox.w - 1)

proc idisplay(self: Tile, tbox: TBox, parent: Tile)


proc display_vsplit(self: Tile, tbox: TBox, parent: Tile) =
  ## Render current tile and its items. Recurse into nested splits
  let tbox = self.draw_borders_and_title(tbox)

  if self.items.len == 0:
      # empty split
      self.fill_area(tbox, ' ')
      return

  let item_height = tbox.h div len(self.items)  # FIXME floor division

  var y = tbox.y

  for i in self.items:
      i.idisplay(newTBox(tbox.t, tbox.x, y, tbox.w, item_height), self)
      y += item_height

  # Fill leftover area
  let leftover_y = tbox.h - y
  if leftover_y > 0:
    self.fill_area(newTBox(tbox.t, tbox.x, y, tbox.w, leftover_y), ' ')

proc display_hsplit(self: Tile, tbox: TBox, parent: Tile) =
  ## Render current tile and its items. Recurse into nested splits
  let tbox = self.draw_borders_and_title(tbox)

  if self.items.len == 0:
      # empty split
      #self.fill_area(tbox, ' ')
      return

  let item_width = tbox.w div len(self.items)

  var x = tbox.x

  for i in self.items:
      i.idisplay(newTBox(tbox.t, x, tbox.y, item_width, tbox.h), self)
      x += item_width

  # Fill leftover area
  let leftover_x = tbox.w - x + 1
  #if leftover_x > 0:
  #  self.fill_area(newTBox(tbox.t, x, tbox.y, leftover_x, tbox.h), ' ')

proc display_hchart(self: Tile, tbox: TBox, parent: Tile) =
  let tbox = self.draw_borders_and_title(tbox)
  set_color self.color

  for dy in 0..<tbox.h:
    if self.low_color != "":
      # generate gradient
      set_merged_color(self.low_color, self.mid_color, self.high_color,
        dy.float / tbox.h.float)

    var bar = ""
    for dx in 0..<tbox.w:
      let delta = tbox.w - dx
      var dp = 0.0
      if delta <= self.datapoints_cnt:
        var dp_index = self.last_dp_pos - delta
        if dp_index < 0:
          dp_index += max_chart_datapoints
        dp = self.datapoints[dp_index]

      let q = (1 - dp / 100) * tbox.h.float
      if dy == int(q):
        let index = int((q.int.float - q) * 8 + 7)
        bar.add vbar_elements[index]
      elif dy < int(q):
        bar.add " "
      else:
        bar.add $vbar_elements[^1]


    # assert len(bar) == tbox.w
    set_cursor_at(tbox.x, tbox.y + dy)
    print bar

proc display_vchart(self: Tile, tbox: TBox, parent: Tile) =
  let
    tbox = self.draw_borders_and_title(tbox)
    filled_element = hbar_elements[^1]
    scale = tbox.w.float / 100.0
  set_color self.color
  for dx in 0..<tbox.h:
    var bar = ""
    let index1 = 50 - (tbox.h) + dx
    try:
      let
        #dp = self.datapoints[index1] * scale
        dp = 2.0
        index = int((dp - dp.int.float) * 8)
      bar = filled_element.repeat(int(dp)) & hbar_elements[index]
      #assert tbox.w >= bar.len
      bar = bar & ' '.repeat(tbox.w - len(bar))
    except IndexError:
      bar = ' '.repeat(tbox.w)
    except RangeError:
      bar = ' '.repeat(tbox.w)
    set_cursor_at(tbox.x + dx, tbox.y)
    print bar

#import unicode

proc display_hgauge(self: Tile, tbox: TBox, parent: Tile) =
  let tbox = self.draw_borders_and_title(tbox)
  var wi: float
  var v_center: int
  if self.label.is_empty:
    wi = tbox.w.float * self.val.float / 100.0
  else:
    wi = (tbox.w.float - len(self.label).float - 3) * self.val.float / 100.0
    v_center = int(tbox.h.float * 0.5) # vertical center; used to show label

  let index = int((wi - wi.int.float) * 7)
  var bar = hbar_elements[^1].repeat(int(wi)) & hbar_elements[index]
  set_color self.color
  set_cursor_at(tbox.x, tbox.y + 1)

  var pad: int
  if self.label.is_empty:
    pad = tbox.w - wi.int - 1
  else:
    pad = tbox.w - 1 - len(self.label) - wi.int - 1
  bar = bar & hbar_elements[1].repeat(pad)

  # draw bar
  for dy in 0..<tbox.h:
    set_cursor_at(tbox.x, tbox.y + dy)
    if self.label.is_empty:
      print bar
    else:
      if dy == v_center:
        # draw label
        print(self.label & ' ' & bar)
      else:
        print(' '.repeat(len(self.label)) & " " & bar)

proc display_vgauge(self: Tile, tbox: TBox, parent: Tile) =
  let tbox = self.draw_borders_and_title(tbox)
  let nh = tbox.h.float * (self.val.float / 100.5)
  set_color self.color
  for dy in 0..<tbox.h:
    set_cursor_at(tbox.x, tbox.y + tbox.h - dy - 1)
    if not self.low_color.is_empty:
      # generate gradient
      set_merged_color(self.low_color, self.mid_color, self.high_color,
        dy.float / tbox.h.float)

    var bar: string
    if dy < int(nh):
      bar = vbar_elements[^1].repeat tbox.w
    elif dy == int(nh):
      let index = int((nh - nh.int.float) * 8)
      bar = vbar_elements[index].repeat tbox.w
    else:
      bar = ' '.repeat tbox.w

    print(bar)

proc display_log(self: Tile, tbox: TBox, parent: Tile) =
  let tbox = self.draw_borders_and_title(tbox)
  let log_range = min(self.logs_cnt, tbox.h)
  let start = self.logs_cnt - log_range
  set_color self.color
  for i in 0..<log_range:
    assert log_range > 0
    let selector = (self.last_log_pos - log_range + i + 1 + max_logs) mod max_logs
    assert selector < max_logs
    assert selector >= 0
    let line = self.logs[selector]
    set_cursor_at(tbox.x, tbox.y + i)
    print(line & ' '.repeat(tbox.w - len(line)))

  if log_range < tbox.h:
    for i in log_range+1..<tbox.h:
      set_cursor_at(tbox.x, tbox.y + i)
      print(' '.repeat tbox.w)

proc display_text(self: Tile, tbox: TBox, parent: Tile) =
  let tbox = self.draw_borders_and_title(tbox)
  set_color self.color
  var cnt = 0
  for line in self.text.splitLines():
    set_cursor_at(tbox.x, tbox.y + cnt)
    let space = tbox.w - line.len
    if space >= 0:
      print(line & ' '.repeat(space))
    else:
      print(line[0..tbox.w-1])
    cnt.inc
    if cnt > tbox.y:
      return

proc generate_hbraille(l, r: int): string =
  ## Generate one braille symbol. Time goes left to right.
  braille_h_symbols[l * 5 + r]

proc generate_filled_hbraille(l, r: int): string =
  ## Generate one braille symbol. Time goes left to right.
  ## The area below the symbol is filled.
  braille_h_symbols_filled[l * 5 + r]

proc hbraille_index(dp: float, dx, height: int): int =
  let q = (0.98 - dp / 102.0) * height.float
  if dx == int(q):
    int((q.floor - q + 1) * 5)
  else:
    0  # blank cell

proc hbraille_filled_index(dp: float, dx, height: int): int =
  let q = (0.98 - dp / 102.0) * height.float
  if dx == int(q):
    int((q.floor - q + 1) * 5)
  elif dx > q.int:
    4  # filled cell
  else:
    0  # blank cell


proc display_hbraillechart(self: Tile, tbox: TBox, parent: Tile, filled: bool) =
  ## Display braille chart. Time goes left to right.
  let
    tbox = self.draw_borders_and_title(tbox)
    filled_element = hbar_elements[^1]
    scale = tbox.w.float / 100.0
  set_color self.color
  for dy in 0..<tbox.h:
    var bar = ""
    for dx in 0..<tbox.w:
      let dp_index =  self.datapoints_cnt + (dx - tbox.w) * 2
      assert dp_index <= self.datapoints_cnt
      var dp_l, dp_r: float
      if dp_index >= 0 and dp_index + 1 <= self.datapoints_cnt:
        dp_l = self.datapoints[dp_index]
        dp_r = self.datapoints[dp_index + 1]
        if filled:
          let index_l = hbraille_filled_index(dp_l, dy, tbox.h)
          let index_r = hbraille_filled_index(dp_r, dy, tbox.h)
          bar.add generate_filled_hbraille(index_l, index_r)
        else:
          let index_l = hbraille_index(dp_l, dy, tbox.h)
          let index_r = hbraille_index(dp_r, dy, tbox.h)
          bar.add generate_hbraille(index_l, index_r)
      else:
        # no data available yet or the tile is wider than max_chart_datapoints
        bar.add " "
        continue

    assert bar.runeLen == tbox.w
    set_cursor_at(tbox.x, tbox.y + dy)
    print bar

proc add_log*(self: var Tile, entry: string) =
  ## Add log
  self.last_log_pos.inc
  if self.last_log_pos == max_logs:
    self.last_log_pos = 0
  if self.logs_cnt != max_logs:
    self.logs_cnt.inc
  self.logs[self.last_log_pos] = entry


proc idisplay(self: Tile, tbox: TBox, parent: Tile) =
  ## Render current tile and its items. Recurse into nested splits if any.

  #error("I> $# $# $# $#\n" % [$tbox.x, $tbox.y, $tbox.w, $tbox.h])

  case self.kind
  of HSplit:
    self.display_hsplit(tbox, parent)
  of VSplit:
    self.display_vsplit(tbox, parent)
  of VChart:
    self.display_vchart(tbox, parent)
  of HChart:
    self.display_hchart(tbox, parent)
  of HGauge:
    self.display_hgauge(tbox, parent)
  of VGauge:
    self.display_vgauge(tbox, parent)
  of Log:
    self.display_log(tbox, parent)
  of Text:
    self.display_text(tbox, parent)
  of HBrailleChart:
    self.display_hbraillechart(tbox, parent, false)
  of HBrailleFilledChart:
    self.display_hbraillechart(tbox, parent, true)


proc display*(self: Tile) =
  ## Render main tile and its items. Recurse into nested splits if any.
  let tbox = newTBox("", 0, 0, terminalWidth(), terminalHeight())
  erase_screen()
  self.idisplay(tbox, Tile())

  # park cursor in a safe place and reset color
  set_cursor_at(0, terminal_height())

  # flush once at the end
  flush()

proc add_dp*(chart: var Tile, val: float) =
  ## Add datapoint
  chart.last_dp_pos.inc
  if chart.last_dp_pos == max_chart_datapoints:
    chart.last_dp_pos = 0
  if chart.datapoints_cnt != max_chart_datapoints:
    chart.datapoints_cnt.inc
  chart.datapoints[chart.last_dp_pos] = val
