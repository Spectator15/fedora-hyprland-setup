-- Behavioral tests for callbacks that the native parse-only check cannot run.
package.path = "config/hypr/?.lua;" .. package.path
local binds, events, focused, raised = {}, {}, nil, nil
local windows = {
    { address = "a", mapped = true, hidden = false, workspace = { id = 1 }, focus_history_id = 0 },
    { address = "b", mapped = true, hidden = false, workspace = { id = 2 }, focus_history_id = 1 },
    { address = "c", mapped = true, hidden = false, workspace = { id = 3 }, focus_history_id = 2 },
}
local active = windows[1]
local function action(kind)
    return function(value) return { kind = kind, value = value } end
end
hl = {
    bind = function(key, fn, options)
        local identity = key:lower() .. tostring(options.release == true)
        assert(not binds[identity], "Duplicate binding: " .. key)
        binds[identity] = { fn = fn, options = options }
    end,
    on = function(event, fn)
        assert(event ~= "config.unload", "config.unload is unavailable in 0.56")
        events[event] = fn
    end,
    get_windows = function() return windows end,
    get_active_window = function() return active end,
    dispatch = function(a)
        if a.kind == "focus" then focused = a.value.window.address; active = a.value.window end
        if a.kind == "raise" then raised = a.value.window.address end
    end,
    dsp = { focus = action("focus"), exec_cmd = action("exec"), window = {
        alter_zorder = action("raise"), close = action("close"), fullscreen = action("fullscreen"),
        float = action("float"), drag = action("drag"), resize = action("resize"), move = action("move"),
    } },
}
local switcher = require("fedora.switcher")
switcher.cycle(false); assert(focused == "b" and raised == "b")
-- MRU order must remain frozen even as the active window changes.
windows[2].focus_history_id = 0; windows[1].focus_history_id = 1
switcher.cycle(false); assert(focused == "c")
switcher.cycle(true); assert(focused == "b")
binds["alt_ltrue"].fn()
switcher.cycle(false); assert(focused == "a", "Quick Alt+Tab should return to previous window")
switcher.finish(); active = windows[1]
windows[1].focus_history_id = 0; windows[2].focus_history_id = 1
switcher.cycle(true); assert(focused == "c", "Reverse switching")
windows[2].mapped = false
switcher.cycle(true); assert(focused == "a", "Skip closed windows")
windows = {}; switcher.cycle(false)
require("fedora.keybinds")
for i = 1, 9 do
    assert(binds["super + " .. i .. "false"])
    assert(binds["super + shift + " .. i .. "false"])
end
for _, key in ipairs({ "alt + tab", "alt + shift + tab", "alt + f4", "super + e", "super + l",
    "super + shift + s", "super + space", "super + return", "super + tab", "super + v",
    "super + shift + slash", "super + mouse:272", "super + mouse:273", "xf86audiomicmute" }) do
    assert(binds[key .. "false"], "Missing familiar shortcut: " .. key)
end
local count = 0
for _ in pairs(binds) do count = count + 1 end
print("PASS: " .. count .. " unique bindings; MRU forward/reverse/release/closed-window behavior")

-- Emulate the released 0.56 monitor API, without newer `enabled`/`all` fields.
local lid = "closed"
local internal = { name = "eDP-9", x = 0, y = 0, scale = 1 }
local external = { name = "DP-8", x = 1920, y = 0, scale = 1 }
local monitors, rules, timer = { internal, external }, {}, nil
hl.get_monitors = function(...) assert(select("#", ...) == 0); return monitors end
hl.monitor = function(rule) rules[#rules + 1] = rule end
hl.timer = function(fn) timer = fn end
local open, popen = io.open, io.popen
io.open = function() return { read = function() return lid end, close = function() end } end
io.popen = function() return { lines = function() local done = false; return function() if not done then done = true; return "/mock/lid/state" end end end, close = function() end } end
require("fedora.clamshell")
events["hyprland.start"]()
assert(rules[1].output == "eDP-9" and rules[1].disabled)
monitors = { external }; timer(); assert(#rules == 1, "Don't repeatedly disable")
monitors = {}; timer(); assert(#rules == 2 and not rules[2].disabled, "Restore panel when external is unplugged")
monitors = { internal, external }; timer(); assert(rules[3].disabled)
lid = "open"; timer(); assert(not rules[4].disabled)
-- Reload starts a new Lua context after on-disk output rules are applied.
package.loaded["fedora.clamshell"] = nil
require("fedora.clamshell")
events["config.reloaded"]()
assert(#rules == 4)
lid = "closed"; timer(); assert(rules[5].disabled)
lid = "open"; timer(); assert(not rules[6].disabled)
io.open, io.popen = open, popen
print("PASS: clamshell uses detected outputs and restores internal panel on unplug/open")
