#!/bin/sh

sxhkd -c "$HOME/.config/sxhkd/sxhkdrc" &

$HOME/.local/bin/dwmstatus.sh loop &

