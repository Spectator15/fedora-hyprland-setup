-- OPTIONAL. Keep logind's normal suspend policy. Never inhibit the lid globally.
-- Uses detected connector names and restores only panels this module disabled.
local held, lid_files = {}, {}
local function is_internal(name) return name:match("^eDP") or name:match("^LVDS") or name:match("^DSI") end
local function sync()
    local closed = false
    for _, path in ipairs(lid_files) do
        local file = io.open(path)
        if file then closed = closed or file:read("*a"):match("closed") ~= nil; file:close() end
    end
    -- 0.56 exposes active monitors only (no `all` argument or enabled field).
    local monitors, external = hl.get_monitors(), false
    for _, mon in ipairs(monitors) do
        if not is_internal(mon.name) then external = true end
    end
    if not closed or not external then
        for name, rule in pairs(held) do hl.monitor(rule); held[name] = nil end
        return
    end
    for _, mon in ipairs(monitors) do
        if is_internal(mon.name) then
            if not held[mon.name] then
                held[mon.name] = { output = mon.name, mode = "preferred", position = mon.x .. "x" .. mon.y, scale = mon.scale, cm = "srgb", bitdepth = 8 }
                hl.monitor({ output = mon.name, disabled = true })
            end
        end
    end
end
local started = false
local function start()
    if started then return end
    started = true
    local pipe = io.popen("find /proc/acpi/button/lid -name state 2>/dev/null")
    if pipe then for path in pipe:lines() do table.insert(lid_files, path) end; pipe:close() end
    if #lid_files > 0 then
        -- Tiny optional state check; does not redraw the desktop or spawn per tick.
        hl.timer(sync, { timeout = 2000, type = "repeat" })
        sync()
    end
end
hl.on("hyprland.start", start)
hl.on("config.reloaded", start)
hl.on("monitor.added", function() hl.timer(sync, { timeout = 300, type = "oneshot" }) end)
hl.on("monitor.removed", function() hl.timer(sync, { timeout = 300, type = "oneshot" }) end)
-- A full config reload replaces these temporary monitor rules with the on-disk
-- output rules. config.reloaded then reapplies the current lid state. The 0.56
-- release has no config.unload event; don't use the development-only callback.
