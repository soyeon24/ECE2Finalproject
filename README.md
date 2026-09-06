# Multi-Function Digital Clock — Verilog / Vivado

Final project, ECE (2025-2). A single FPGA design that boots into a menu and runs
nine independent timekeeping and game modes on a text LCD and 7-segment display.

## Modes

| Module | What it does |
|---|---|
| `watch.v` | real-time clock |
| `date.v` | calendar date |
| `world_time.v` | clock in a selectable timezone |
| `stopwatch.v` | stopwatch with lap |
| `timer.v` | countdown timer |
| `alarm.v`, `alarmpiezo.v` | alarm with piezo buzzer output |
| `chess_clock.v` | two-player chess clock |
| `metronome.v` | adjustable-tempo metronome |
| `dday.v` | days remaining to a set date |
| `reaction_game.v` | reaction-time game |

## Supporting modules

```
top_system.v    top level, clock/reset, mode routing
menu.v          mode selection state machine
setting.v       per-mode parameter entry
textlcd.v       character LCD driver
seg_decode.v    7-segment decoder
```

## Build

Xilinx Vivado — open `project_1.xpr`. The full write-up is in
`Project_2024440057_박소연.pdf`.
