version     = "0.1.0"
author      = "treeform@softmax.com"
description = "Party Progressor Coworld game."
license     = "MIT"

srcDir = "src"
bin = @["party_progressor"]

switch("threads", "on")
switch("mm", "orc")
switch("path", "src")

requires "nim >= 2.2.4"
requires "bitworld >= 0.1.0"
requires "jsony"
requires "mummy >= 0.4.7"
requires "pixie"
requires "supersnappy >= 2.1.3"
requires "whisky >= 0.1.3"

