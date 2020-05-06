local api = vim.api
local bufs = {}

local function add_buffer(line, path)
  if path == "" then
    return line
  end
  local file_name = api.nvim_call_function('fnamemodify', {path, ":p:t"})
  line = line..'%#TabLine#'..file_name
  return line
end

local function bufferline()
  local buf_nums = api.nvim_list_bufs()
  local line = ""
  for _,v in pairs(buf_nums) do
    if api.nvim_buf_is_loaded(v) then
      local name =  api.nvim_buf_get_name(v)
      bufs[v] = name
      line = add_buffer(line, name)
    end
  end
  print(vim.inspect(bufs))
  line = line..'%#TabLineFill#%T'
  line = line..'%=%#TabLine#%999Xclose'
  print("Bufferline is: "..line)
  return line
end

bufferline()

return {
  bufferline = bufferline
}

