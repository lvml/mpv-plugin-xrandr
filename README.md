mpv-plugin-xrandr
======================

mpv plugin for setting display output parameters, e.g. the refresh rate,
automatically to the best suitable value for playing the current file.

(This is currently implemented only for Unix systems which provide the
"xrandr" command to control the X server. No Windows/Mac support yet.)

(written by Lutz Vieweg)

Rationale / Use Case:
=====================

Video replay looks choppy if the display refresh rate is not an even
multiple of the frame rate the video is encoded at.

Many displays support different refresh rates, and for some of them,
namely TVs, choosing the correct refresh rate is also important for the
quality of computing interpolated frames for "smoother motion".

Setting the display to the best suitable refresh rate manually
for each video you play is annoying, so this plugin aims at
automatizing this task.

Prerequisites / Installation
============================

In order to use xrand.lua, you only need to have mpv installed.

Usage:
======

mpv --script /path/to/xrandr.lua ...

(Or copy xrandr.lua to ~/.config/mpv/scripts/ for permanent default usage.)

Options:
========

Normally, you won't need to specify any options.

But you can set the script option "xrandr-blacklist" to a certain refresh rate
or to a comma separated list of refresh rates that you don't want to be used at all.
This can be done to address compatibility issues - e.g., when you know that your
display can use 25 Hz, but if your computer tries to use that rate, your TV stays black,
you can use

 mpv --script-opts=xrandr-blacklist=25 ...

or if both 25 and 24 Hz are unusable, you could specify:

 mpv --script-opts=xrandr-blacklist=[24,25]

DISCLAIMER
==========

This software is provided as-is, without any warranties.
