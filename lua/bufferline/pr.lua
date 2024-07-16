local fmt = string.format


-------------
--- @Utils

--- @class PR
local P = {}

--- @Group PR
-- 1. Made type on_close optional in bufferline.Group type [types.lua:193]
-- 2. in Group Setup - added group specific separator options - such as placing the sep at start/end [config.lua:678]
-- 3. Added functionality to Add/Remove groups on their own, for flexibility [groups:286]
-- 4. Fixed the render() function and kept the old one for reference [groups:913]
-- 5. Added a BufferLineDebug user command to print the rendered tabline with HL's and Text + Padding [bufferline:207]
-- 6. Updated doc to provide more info on how to use options [doc/bufferline.txt]
-- 7. Added a  set_bufferline_hls function for the user to directly specify all the styles required for Group Labels and Buffers in one go [pr:38]
-- 8. Fixed the error of BufferLineCyclePrev/Next not working when current buffer is toggled and in a group [commands.lua:204 and groups:67]



-- The functions used from this file are -
-- 1. set_group_hls -> Not sure if this should go in config or groups
-- 2. get_tabline_text_and_highlights -> fn that prints the rendered data with applied hl's
----------------------------------------------------------------------------------------------
--- Function to set all group related highlights - for the Group Label, and the Group Buffers
--- @class HighlightOpts
--- @field active_fg string?
--- @field active_bg string?
--- @field inactive_fg string?
--- @field inactive_bg string?
--- @field bold boolean?
--- @field italic boolean?
--- @field label_fg string?
--- @field label_bg string?

--- @alias BufferLineHighlights HighlightOpts


--- @param group string
--- @param highlight vim.api.keyset.highlight
local function set_hl(group, highlight)
    vim.api.nvim_set_hl(0, group, highlight)
end

local inactive = "#7a8aaa"

--- Set required highlight groups for Group Buffers and Group Label
--- @Usage set_group_hls("A",{active_fg=C.blue,label_fg=C.teal,inactive_fg=C.comment...})
--- @param group_name string
--- @param opts BufferLineHighlights
local function set_group_hls(group_name, opts)
    if not opts or (not opts.active_bg and not opts.active_fg) then return end

    local function set_style(style, fg, bg, bold, italic)
        if fg then style.fg = fg end
        if bg then style.bg = bg end
        if bold then style.bold = true end
        if italic then style.italic = true end
    end

    local active_style = {}
    local inactive_style = {}

    set_style(active_style, opts.active_fg, opts.active_bg, opts.bold, opts.italic)
    set_style(inactive_style, opts.inactive_fg, opts.inactive_bg)
    set_hl(fmt("BufferLine%sSelected", group_name), active_style)

    if opts.inactive_bg or opts.inactive_fg then
        set_hl(fmt("BufferLine%s", group_name), inactive_style)
        set_hl(fmt("BufferLine%sVisible", group_name), inactive_style)
    else
        set_hl(fmt("BufferLine%s", group_name), active_style)
        set_hl(fmt("BufferLine%sVisible", group_name), { fg = inactive })
    end

    if opts.label_bg or opts.label_fg then
        local label_style = {}
        set_style(label_style, opts.label_fg, opts.label_bg)
        set_hl(fmt("BufferLine%sLabel", group_name), label_style)
    end
end

----------------------------------------------------------------------------------------------
---@Group Functionality

-- Maintain count of toggled groups - to fix cycling not working if the user toggles an active tab
P.toggled_groups = 0

--- This solves the issue of cycling when the user is on a toggled group
--- We keep a count of how many groups are currently toggled off (minimized)
--- thus we can get the next index by passing the count of toggled groups as the index (1 for example)
function P:toggled_index()
    if self.toggled_groups >= 1 then return self.toggled_groups end
end

--- @Group PR

--[[ old
local C = lazy.require("bufferline.constants") ---@module "bufferline.constants"
local function space_end(hl_groups) return { { highlight = hl_groups.fill.hl_group, text = C.padding } } end
local function tab_old(group, hls, count)
    -- On Toggle - the tab_sep is not hiding
    -- '▎' "▏"
    local hl = hls.fill.hl_group
    local indicator_hl = hls.buffer.hl_group
    local indicator = {
        { highlight = hl,           text = C.padding },
        { highlight = indicator_hl, text = C.padding .. group.name .. count .. C.padding },
        { highlight = hl,           text = C.padding },
    }
    return { sep_start = indicator, sep_end = space_end(hls) }
end
--]]

-- these are defined in groups.lua
--- @param count 1 | -1
local function update_toggled(count)
    P.toggled_groups = P.toggled_groups + count
end

--- just updated toggle function to increment/decrement the toggled counter at [groups:463]
--- @param group_by_callback function
local function toggle_hidden(group_by_callback)
    local group = group_by_callback()
    if group then
        if not group.hidden then update_toggled(1) else update_toggled(-1) end
        group.hidden = not group.hidden
    end
end

---@class ActiveBuffers
---@field length     integer
---@field id         integer
---@field filename   string
---@field name       string
---@field highlights ActiveHighlights
---@field modified   boolean


---@class ActiveHighlights
---@field text string
---@field highlight string
---@field config_hl string
---@field id integer

--- Convert highlight name to readable form
--- @param highlight string
--- @return string
local function convert_highlight_name(highlight)
    local name = highlight:gsub("^BufferLine", "")
    name = name:gsub("(%u)", function(c)
        return "_" .. c:lower()
    end)
    name = name:gsub("^_", "")
    return name
end


--- Get the current segments with their text and HL groups
--- @return ActiveBuffers[], string
--- @param tabline_data BufferlineTablineData
function P:get_highlight_groups(tabline_data)
    local active_bufs = {}
    local buf_str = ""

    for i, component in ipairs(tabline_data.visible_components) do
        if component.component then
            local name = component.name
            local segments = tabline_data.segments[i] -- Directly use segments
            local component_segments = {}
            for _, seg in ipairs(segments) do
                local visible_component        = {}
                local visible_text, visible_hl = seg.text, seg.highlight
                if visible_text then visible_component.text = visible_text end

                if visible_hl then
                    visible_component.highlight = visible_hl
                    visible_component.config_hl = convert_highlight_name(visible_hl)
                    if visible_text and visible_text == name then
                        buf_str = buf_str .. '\n' .. name .. " : " .. visible_component.config_hl
                    end
                end
                table.insert(component_segments, visible_component)
            end
            local active_component = {
                length = component.length,
                id = component.id,
                name = component.name,
                filename = component.filename,
                highlights = component_segments,
                modified = component.modified,
            }


            table.insert(active_bufs, active_component)
        end
    end


    return active_bufs, self:compact(active_bufs)
end

-- Returns a compact table with no spacing
local function compact_print(t, indent, printed)
    indent = indent or ""
    printed = printed or {}
    if printed[t] then return "..." end
    printed[t] = true
    local result = "{"
    local first = true
    for k, v in pairs(t) do
        if not first then result = result .. "," else first = false end
        result = result .. k .. "="
        if type(v) == "table" then
            if next(v) == nil then
                result = result .. "{}"
            else
                result = result .. compact_print(v, indent .. "  ", printed)
            end
        elseif type(v) == "string" then
            result = result .. '"' .. v .. '"'
        elseif type(v) == "function" then
            result = result .. "<function>"
        else
            result = result .. tostring(v)
        end
    end
    return result .. "}"
end


function P:compact(data)
    return compact_print(data)
end

local function rgb_to_hex(rgb)
    local hex = string.format("#%06x", rgb)
    return hex
end


local function parse_to_objects(parsed_tabline)
    local objects = {}
    for _, line in ipairs(parsed_tabline) do
        local highlight, text = line:match("^#(.-)#(.*)$")
        if highlight and text then
            table.insert(objects, { highlight = { hl = highlight }, text = text })
        else
            table.insert(objects, { text = line })
        end
    end

    return objects
end

local function get_highlight_attributes(group)
    local hl = vim.api.nvim_get_hl(0, { name = group })
    if hl then
        if hl.fg then
            hl.fg = rgb_to_hex(hl.fg)
        end
        if hl.bg then
            hl.bg = rgb_to_hex(hl.bg)
        end
        return hl
    else
        return nil
    end
end

local function enhance_with_highlight(objects)
    for _, obj in ipairs(objects) do
        if obj.highlight and obj.highlight.hl then
            local hl = get_highlight_attributes(obj.highlight.hl)
            if hl then
                for k, v in pairs(hl) do
                    obj.highlight[k] = v
                end
            else
                obj.highlight.hl_attributes = "Highlight group not found"
            end
        end
    end
    return objects
end


--- Get all of the Highlight groups and Text (including spaces) to get a complete picture of how the tabline is rendered
--- @param tabline string
function P:get_tabline_text_and_highlights(tabline)
    local result = {}
    for part in tabline:gmatch("([^%%]*)") do
        if part ~= "" then
            table.insert(result, part)
        end
    end
    local split = parse_to_objects(result)
    local whl = enhance_with_highlight(split)

    return whl
end

-------------------------------------------------------------------------------------
--- private utils for debugging, not relevant
-------------------------------------------------------------------------------------
local delim = "-------------------"
P.delimn = '\n' .. delim .. '\n'
P.nl = "\n\n"
P.override = false

local instance -- Singleton

function P.new()
    local self = setmetatable({}, { __index = P })
    self.i = 0
    self.debug = false
    return self
end

P.files = {}

--- @param msg string
--- @param data any
--- @param override boolean?
function P:log(msg, data, override)
    if self.debug == true or override then self:write(msg, data) end
end

--- @param msg string
--- @param data any
function P:write(msg, data)
    if self.file then
        self.file:write('\n' .. msg .. self.delimn)
        if data then self.file:write(vim.inspect(data) .. self.delimn) end
    else
        if type(data) == "string" then
            print(data)
        else
            print(vim.inspect(data) .. self.delimn)
        end
    end
end

--- @param data string
function P:writestr(data)
    if self.debug == true and data then self.file:write('\n' .. data .. self.delimn) end
end

function P:set_logfile(path)
    if path then self.logfile = path end
    local file = io.open(self.logfile, "a") -- Open the file in append mode
    if file then
        self.file = file
        self:log("Logger Initialization")
    else
        print("Error: Could not open file for writing")
    end
end

--- @class InitOptions
--- @field debug boolean
--- @field logfile string?

--- @param opts InitOptions
function P:init(opts)
    self.i = 0
    if opts.debug == false then
        self.debug = false
        return
    end
    self.debug = true
    if opts.logfile then self:set_logfile(opts.logfile) end
end

--- @param msg string
--- @param data any
function P:logf(key, msg, data)
    if self.debug == true and self.files[key] then self:writef(key, msg, data) end
end

function P:writef(key, msg, data)
    if self.files[key] then
        self.files[key]:write('\n' .. msg .. '\n')
        if data then
            local compact_data = self:compact(data)
            self.files[key]:write(compact_data .. self.delimn)
        end
    end
end

function P:add_logfile(path, key)
    local file = io.open(path, "a") -- Open the file in append mode
    if file then
        self.files[key] = file
        self:logf(key, "Logger Initialization")
    else
        print("Error: Could not open file for writing")
    end
end

--- @return PR
local function get_instance()
    if not instance then
        instance = P.new()
    end
    return instance
end

return { get_instance = get_instance, set_group_hls = set_group_hls }
