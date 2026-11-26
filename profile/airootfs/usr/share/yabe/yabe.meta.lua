---@meta

--- handle returned by `yabe.dispatchers.*`
---@alias YabeDispatcherID integer

---@class YabeObject
---@field config fun(config: YabeConfig): nil # Set the configuration
---@field dispatchers YabeDispatchersNamespace
---@field dispatch fun(dispatcher: YabeDispatcherID): nil # Execute the dispatcher immediately
---@field on YabeOnNamespace
---@field keybind fun(keys: string[], dispatcher: YabeDispatcherID): nil # Register a keybind

---@class YabeDispatchersNamespace
---@field set_workspace fun(index: integer): YabeDispatcherID # Set the current workspace by absolute index
---@field add_workspace_index fun(delta: integer): YabeDispatcherID # Add to the current workspace index (can be negative)
---@field reset_ray fun(): YabeDispatcherID # Point the ray horizontally in the current head direction
---@field recenter fun(): YabeDispatcherID # Make the current head direction the front
---@field exec fun(command: string): YabeDispatcherID # Execute a shell command via `sh -c`

---@class YabeOnNamespace
---@field startup fun(callback: fun()): nil # Register a callback called every time the compositor starts
---@field config_reloaded fun(callback: fun()): nil # Register a callback called when the config is reloaded while the compositor is running
---@field workspace_changed fun(callback: fun(previous: integer, current: integer)): nil # Register a callback called when the current workspace is changed
---@field recentered fun(callback: fun()): nil # Register a callback called when the front direction is reset

---@class YabeConfig
---@field input? YabeConfigInput
---@field surface_grouping? YabeConfigSurfaceGrouping
---@field window? YabeConfigWindow
---@field decoration? YabeConfigDecoration
---@field fixed_layer? YabeConfigFixedLayer
---@field auto_reload_config? boolean # Automatically reload config file if it is changed
---@field pixels_per_meter? number # Number of pixels per meter in the world

---@class YabeConfigInput
---@field pointer? YabeConfigInputPointer
---@field keyboard? YabeConfigInputKeyboard

---@class YabeConfigInputPointer
---@field movement_multiplier? number # This value will be multiplied to the amount of pointer movement
---@field scroll_multiplier? number # This value will be multiplied to the amount of pointer scroll

---@class YabeConfigInputKeyboard
---@field rules? string # keyboard rules (XKB)
---@field model? string # keyboard model (XKB)
---@field layout? string # keyboard layout (XKB)
---@field variant? string # keyboard variant (XKB)
---@field options? string # keyboard options (XKB)

---@class YabeConfigSurfaceGrouping
---@field enabled? boolean # Enable surface grouping feature
---@field fadeout_duration_ms? integer # Duration in milliseconds for the lasso to fade out after selection
---@field line_width? number # line width of the lasso while selecting
---@field line_distance? number # how far the lasso is from the camera
---@field window_spacing? number # space between windows in a group
---@field padding? number # padding around the group
---@field detach_threshold? number # the amount of triggering children detach

---@class YabeConfigWindow
---@field resize_handle_thickness? integer # line width of the resize handle (px)
---@field resize_handle_threshold? integer # length to activate the resize handle (px). set zero to disable

---@class YabeConfigDecoration
---@field height? integer # height of the decoration bar (px)
---@field offset? integer # space between contents (ex: window) and the decoration (px)

---@class YabeConfigFixedLayer
---@field margin? YabeConfigFixedLayerMargin
---@field follow_speed? number # how fast the head-fixed layer follows the user's head direction

---@class YabeConfigFixedLayerMargin
---@field top? integer # top margin
---@field bottom? integer # bottom margin
---@field left? integer # left margin
---@field right? integer # right margin
---@field x? integer # left and right margin
---@field y? integer # top and bottom margin
---@field rest? integer # margin that is not specified

---@type YabeObject
yabe = {}
