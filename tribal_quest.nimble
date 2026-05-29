version     = "0.1.0"
author      = "treeform@softmax.com"
description = "Tribal Quest adventurer Coworld surface for Tribal Fortress."
license     = "MIT"

srcDir = "src"
bin = @["tribal_quest"]

switch("threads", "on")
switch("mm", "orc")
switch("path", "src")

requires "nim >= 2.2.4"
requires "jsony"
requires "mummy >= 0.4.7"
requires "pixie"
requires "supersnappy >= 2.1.3"
requires "ws >= 0.5.0"
