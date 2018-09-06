## dashing - terminal dashboards for Nim
# Copyright 2018 Federico Ceratto <federico.ceratto@gmail.com>
# Released under LGPLv3. See LICENSE file.

import os, terminal, strutils

# "graphic" elements

let log = open("dashing.log", fmAppend)

const
  border_bl = "└"
  border_br = "┘"
  border_tl = "┌"
  border_tr = "┐"
  border_h = "─"
  border_v = "│"
  hbar_elements = ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
  vbar_elements = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
  braille_left = (0x01, 0x02, 0x04, 0x40, 0)
  braille_right = (0x08, 0x10, 0x20, 0x80, 0)
  braille_r_left = (0x04, 0x02, 0x01)
  braille_r_right = (0x20, 0x10, 0x08)

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
    of HSplit, VSplit, HBrailleChart, HBrailleFilledChart:
      items*: seq[Tile]
    of VChart, HChart:
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


# #

proc print(s: string) =
  when defined(testing):
    #echo s.len
    discard
  else:
    stdout.write s

proc set_cursor_at*(x, y: int) =
  when not defined(testing):
    set_cursor_pos(x, y)


proc is_empty(s: string): bool =
  return s.isNil or s == ""


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
  if c.isNil or c == "":
    return
  set_color(unpack_color(c))

proc set_merged_color(lo, mid, hi: string, ratio: float) =
  ## Set merged foreground color
  var lo_c, hi_c: RGBColor
  var ratio = ratio
  if mid == nil or mid == "":
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
  if self.title.len != 0:
    #Skip the title area
    print(border_tl)
    set_cursor_at(tbox.x + (3 + self.title.len), tbox.y)
    print(border_h.repeat(tbox.w - (4 + self.title.len)) & border_tr)
  else:
    #log.write("$# $# $# $# $#\n" % [$self.kind, $tbox.x, $tbox.y, $tbox.w, $tbox.h])
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


proc draw_title(self: Tile, tbox: TBox, fill_all_width: bool) =
  ##
  set_cursor_at(tbox.x + 2, tbox.y)
  print self.title

proc draw_borders_and_title(self: Tile, tbox: TBox): TBox =
  ## Draw borders and title as needed and returns inset (x, y, width, height)
  if self.border_color != "":
    self.draw_borders(tbox)

  if self.title.len != 0:
    let fill_all_width = (self.border_color == "")
    self.draw_title(tbox, fill_all_width)

  if self.border_color != "":
    return newTBox(tbox.t, tbox.x + 1, tbox.y + 1, tbox.w - 2, tbox.h - 2)

  elif self.title != "":
    return newTBox(tbox.t, tbox.x + 1, tbox.y, tbox.w - 1, tbox.h - 1)

  return newTBox(tbox.t, tbox.x, tbox.y, tbox.w, tbox.h)

proc fill_area(self: Tile, tbox: TBox, c: char) =
  # FIXME
  discard

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
  let leftover_y = tbox.h - y + 1
  if leftover_y > 0:
    self.fill_area(newTBox(tbox.t, tbox.x, y, tbox.w, leftover_y), ' ')

proc display_hsplit(self: Tile, tbox: TBox, parent: Tile) =
  ## Render current tile and its items. Recurse into nested splits
  let tbox = self.draw_borders_and_title(tbox)

  if self.items.len == 0:
      # empty split
      self.fill_area(tbox, ' ')
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
  set_cursor_at(tbox.x, tbox.y)
  let textLines = self.text.splitLines()
  for i in 0..<textLines.len:
    set_cursor_at(tbox.x, tbox.y + i)
    print textLines[i]

proc display_braillechart(self: Tile, tbox: TBox, parent: Tile, filled: bool) =
  discard

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
  # park cursor in a safe place and reset color
  #FIXME print(t.move(terminal_height() - 3, 0) + t.color(0))
  set_cursor_at(terminal_width() - 3, 0)

  #log.write("I> $# $# $# $#\n" % [$tbox.x, $tbox.y, $tbox.w, $tbox.h])
  #set_cursor_at(0, terminal_height())
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
    self.display_braillechart(tbox, parent, false)
  of HBrailleFilledChart:
    self.display_braillechart(tbox, parent, true)


proc display*(self: Tile) =
  ## Render current tile and its items. Recurse into nested splits if any.
  let tbox = newTBox("", 1, 1, terminalWidth(), terminalHeight() - 1)
  self.idisplay(tbox, Tile())
  # park cursor in a safe place and reset color
  #FIXME print(t.move(terminal_height() - 3, 0) + t.color(0))
  set_cursor_at(terminal_width() - 3, 0)

  #set_cursor_at(0, terminal_height())
  self.idisplay(tbox, Tile())
  when not defined(testing):
    hideCursor()

proc add_dp*(chart: var Tile, val: float) =
  ## Add datapoint
  chart.last_dp_pos.inc
  if chart.last_dp_pos == max_chart_datapoints:
    chart.last_dp_pos = 0
  if chart.datapoints_cnt != max_chart_datapoints:
    chart.datapoints_cnt.inc
  chart.datapoints[chart.last_dp_pos] = val

when isMainModule:
  var ui = Tile(kind:Hsplit, title:"Test", border_color:"f00", items: @[
    Tile(kind:Text, text:"Test\cText"),
    Tile(kind:Log, title:"Test Title")
  ])

  ui.items[1].add_log("Test String")
  ui.items[1].add_log("Test2 String")

  erase_screen()
  while true:
    display(ui)

