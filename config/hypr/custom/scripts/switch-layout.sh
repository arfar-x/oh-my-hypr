#!/usr/bin/env bash
# Cycle the keyboard layout and show the new one in the on-screen display.
hyprctl switchxkblayout all next >/dev/null
name=$(hyprctl devices -j | jq -r '[.keyboards[] | select(.main==true)][0].active_keymap // .keyboards[0].active_keymap')
qs -c ii ipc call osdVolume layout "$name"
