local tabPages = require('bufferline.tabpages')
local util = require('bufferline.utils')

local M = {}

function M.on_save()
  local tabFilter = require('bufferline').tab_filter
  local tabs = tabPages.get()
  local tabNames = {}
  for tabIndex, componentData in ipairs(tabs) do
    local isFiltered = tabFilter(tabIndex)
    local components = componentData.component
    -- a little gross, but this will work - see tabPages.lua:render()
    local titleComponent = vim.tbl_filter(
        function(comp) return comp.attr ~= nil end,
        components
      )[1]
    local tabName 
    if isFiltered then tabName = titleComponent.text else tabName = "DELETE" end
    tabNames[#tabNames+1] = tabName
  end
  return tabNames
end


function M.on_post_load(tabNames)

  -- Start from the *current* tab index, and wraparound
  local tabId = vim.api.nvim_win_get_tabpage(0)
  local tabIndex = vim.api.nvim_tabpage_get_number(tabId)
  for _, _ in ipairs(tabNames) do
    local tabName = tabNames[tabIndex]
    if tabName == 'DELETE' then
      tabIndex = tabIndex+1
      vim.cmd('tabclose')
    else 
      tabPages.rename_tab(tabIndex, util.stripString(tabName))
      tabIndex = tabIndex+1
      if tabIndex > #tabNames then tabIndex = 1 end
      vim.cmd('tabnext')
    end
  end
end

return M

