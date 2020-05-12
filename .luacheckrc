-- vim: ft=lua tw=80

-- Rerun tests only if their modification time changed.
cache = true

-- Global objects defined by the C code
globals = {
  "Buffers"
}
read_globals = {
  "vim",
}
