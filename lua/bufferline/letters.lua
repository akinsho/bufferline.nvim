local M = {}

M.current = {}

M.valid = "abcdefghijklmopqrstuvwxyzABCDEFGHIJKLMOPQRSTUVWXYZ"

function M.reset()
  M.current = {}
end

function M.get(buf)
  local first_letter = buf.filename:sub(1, 1)
  -- should only match alphanumeric characters
  local invalid_char = first_letter:match("[^%w]")

  if not M.current[first_letter] and not invalid_char then
    M.current[first_letter] = buf.id
    return first_letter
  end
  for letter in M.valid:gmatch(".") do
    if not M.current[letter] then
      M.current[letter] = buf.id
      return letter
    end
  end
end

return M
