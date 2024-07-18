---@meta _

---@class bufferline.DebugOpts
---@field logging boolean

---@class bufferline.GroupOptions
---@field toggle_hidden_on_enter? boolean re-open hidden groups on bufenter

---@class bufferline.GroupOpts
---@field options? bufferline.GroupOptions
---@field items bufferline.Group[]

---@class bufferline.Indicator
---@field style? "underline" | "icon" | "none"
---@field icon? string?

---@alias bufferline.Mode 'tabs' | 'buffers'

---@alias bufferline.DiagnosticIndicator fun(count: number, level: string, errors: table<string, any>, ctx: table<string, any>): string

---@alias bufferline.HoverOptions {reveal: string[], delay: integer, enabled: boolean}
---@alias bufferline.BufFormatterOpts {name: string, path: string, bufnr: number}
---@alias bufferline.TabFormatterOpts {buffers: number[], tabnr: number} | bufferline.BufFormatterOpts
---@alias bufferline.IconFetcherOpts {directory: boolean, path: string, extension: string, filetype: string?}

---@class bufferline.Options
---@field public mode? bufferline.Mode
---@field public style_preset? bufferline.StylePreset | bufferline.StylePreset[]
---@field public view? string
---@field public debug? bufferline.DebugOpts
---@field public numbers? string | fun(ordinal: number, id: number, lower: number_helper, raise: number_helper): string
---@field public buffer_close_icon? string
---@field public modified_icon? string
---@field public close_icon? string
---@field public close_command? string | function
---@field public custom_filter? fun(buf: number, bufnums: number[]): boolean
---@field public left_mouse_command? string | function
---@field public right_mouse_command? string | function
---@field public middle_mouse_command? (string | function)?
---@field public indicator? bufferline.Indicator
---@field public left_trunc_marker? string
---@field public right_trunc_marker? string
---@field public separator_style? string | {[1]: string, [2]: string}
---@field public name_formatter? (fun(path: string):string)?
---@field public tab_size? number
---@field public truncate_names? boolean
---@field public max_name_length? number
---@field public color_icons? boolean
---@field public show_buffer_icons? boolean
---@field public show_buffer_close_icons? boolean
---@field public show_buffer_default_icon? boolean
---@field public get_element_icon? fun(opts: bufferline.IconFetcherOpts): string?, string?
---@field public show_close_icon? boolean
---@field public show_tab_indicators? boolean
---@field public show_duplicate_prefix? boolean
---@field public duplicates_across_groups? boolean
---@field public enforce_regular_tabs? boolean
---@field public always_show_bufferline? boolean
---@field public auto_toggle_bufferline? boolean
---@field public persist_buffer_sort? boolean
---@field public move_wraps_at_ends? boolean
---@field public max_prefix_length? number
---@field public sort_by? string
---@field public diagnostics? boolean | 'nvim_lsp' | 'coc'
---@field public diagnostics_indicator? bufferline.DiagnosticIndicator
---@field public diagnostics_update_in_insert? boolean
---@field public diagnostics_update_on_event? boolean
---@field public offsets? table[]
---@field public groups? bufferline.GroupOpts
---@field public themable? boolean
---@field public hover? bufferline.HoverOptions

---@class bufferline.HLGroup
---@field fg? string
---@field bg? string
---@field sp? string
---@field special? string
---@field bold? boolean
---@field italic? boolean
---@field underline? boolean
---@field undercurl? boolean
---@field hl_group? string
---@field hl_name? string

---@alias bufferline.Highlights table<string, bufferline.HLGroup>

---@class bufferline.UserConfig
---@field public options? bufferline.Options
---@field public highlights? bufferline.Highlights | fun(BufferlineHighlights): bufferline.Highlights

---@class bufferline.Config
---@field public options? bufferline.Options
---@field public highlights? bufferline.Highlights
---@field user bufferline.UserConfig original copy of user preferences
---@field merge fun(self: bufferline.Config, defaults: bufferline.Config): bufferline.Config
---@field validate fun(self: bufferline.Config, defaults: bufferline.Config, resolved: bufferline.Highlights): nil
---@field resolve fun(self: bufferline.Config, defaults: bufferline.Config): bufferline.Config
---@field is_tabline fun(self: bufferline.Config):boolean

--- @alias bufferline.Visibility 1 | 2 | 3
--- @alias bufferline.Duplicate "path" | "element" | nil

---@class bufferline.Component
---@field name? string
---@field id integer
---@field path? string
---@field length integer
---@field component fun(BufferlineState): bufferline.Segment[]
---@field hidden boolean
---@field focusable boolean
---@field type 'group_end' | 'group_start' | 'buffer' | 'tabpage'

---@generic T
---@alias bufferline.AncestorSearch fun(self: T, depth: integer, formatter: (fun(string, integer): string)?): string

---@alias bufferline.TabElement bufferline.Tab|bufferline.Buffer

---@class bufferline.Tab
---@field public id integer
---@field public buf integer
---@field public icon string
---@field public name string
---@field public group string
---@field public letter string
---@field public modified boolean
---@field public modifiable boolean
---@field public duplicated bufferline.Duplicate
---@field public extension string the file extension
---@field public path string the full path to the file
---@field public visibility fun(self: bufferline.Tab): integer
---@field public current fun(self: bufferline.Tab): boolean
---@field public visible fun(self: bufferline.Tab): boolean
---@field public ancestor bufferline.AncestorSearch
---@field public __ancestor bufferline.AncestorSearch

-- A single buffer class
-- this extends the [Component] class
---@class bufferline.Buffer
---@field public extension string the file extension
---@field public path string the full path to the file
---@field public name_formatter fun(opts: bufferline.BufFormatterOpts): string?
---@field public id integer the buffer number
---@field public name string the visible name for the file
---@field public filename string
---@field public icon string the icon
---@field public icon_highlight string?
---@field public diagnostics table
---@field public modified boolean
---@field public modifiable boolean
---@field public buftype string
---@field public letter string?
---@field public ordinal integer
---@field public duplicated bufferline.Duplicate
---@field public prefix_count integer
---@field public component BufferComponent
---@field public group string?
---@field public group_fn string
---@field public length integer the length of the buffer component
---@field public visibility fun(self: bufferline.Buffer): integer
---@field public current fun(self: bufferline.Buffer): boolean
---@field public visible fun(self: bufferline.Buffer): boolean
---@field public ancestor bufferline.AncestorSearch
---@field public __ancestor bufferline.AncestorSearch
---@field public find_index fun(Buffer, BufferlineState): integer?
---@field public newly_opened fun(Buffer, BufferlineState): boolean
---@field public previously_opened fun(Buffer, BufferlineState): boolean

---@alias bufferline.ComponentsByGroup (bufferline.Group | bufferline.Component[])[]

--- @class bufferline.GroupState
--- @field manual_groupings table<number, string>
--- @field user_groups table<string, bufferline.Group>
--- @field components_by_group bufferline.ComponentsByGroup

--- @class bufferline.Separators
--- @field sep_start bufferline.Segment[]
--- @field sep_end bufferline.Segment[]

---@alias GroupSeparator fun(group:bufferline.Group, hls: bufferline.HLGroup, count_item: string?): bufferline.Separators
---@alias GroupSeparators table<string, GroupSeparator>

---@class bufferline.Group
---@field public id? string used for identifying the group in the tabline
---@field public name? string 'formatted name of the group'
---@field public display_name? string original name including special characters
---@field public matcher? fun(b: bufferline.Buffer): boolean?
---@field public separator? GroupSeparators
---@field public priority? number
---@field public highlight? table<string, string>
---@field public icon? string
---@field public hidden? boolean
---@field public with? fun(Group, Group): bufferline.Group
---@field auto_close boolean when leaving the group automatically close it

---@class bufferline.RenderContext
---@field preferences bufferline.Config
---@field current_highlights {[string]: string}
---@field tab bufferline.TabElement
---@field is_picking boolean

---@class bufferline.SegmentAttribute
---@field global boolean whether or not the attribute applies to other elements apart from the current one
---@field prefix string
---@field suffix string
---@field extends number how many positions the attribute extends for

---@class bufferline.Segment
---@field text string
---@field highlight string
---@field attr bufferline.SegmentAttribute

---@class bufferline.Section
---@field items bufferline.Component[]
---@field length integer
---@field drop fun(self: bufferline.Section, count: integer): bufferline.Section?
---@field add fun(self: bufferline.Section, item: bufferline.Component)

---@class bufferline.State
---@field components bufferline.Component[]
---@field current_element_index number?
---@field is_picking boolean
---@field visible_components bufferline.Component[]
---@field __components bufferline.Component[]
---@field custom_sort number[]?
---@field left_offset_size number
---@field right_offset_size number

---@alias bufferline.Sorter fun(buf_a: bufferline.Buffer, buf_b: bufferline.Buffer): boolean

---@class bufferline.SorterOptions
---@field sort_by (string|function)?
---@field current_index integer?
---@field custom_sort boolean?
---@field prev_components bufferline.TabElement[]
