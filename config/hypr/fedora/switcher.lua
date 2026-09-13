-- Recent-window switching without a daemon/plugin or synthetic key events.
-- Snapshot order while Alt is held so repeated Tab reaches every window.
local M = {}
local order, index = nil, 1

function M.finish()
    order, index = nil, 1
end

function M.cycle(backwards)
    local live, by_address = {}, {}
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and not w.hidden and w.workspace and w.workspace.id > 0 then
            table.insert(live, w)
            by_address[w.address] = w
        end
    end
    if #live == 0 then M.finish(); return end
    if not order then
        table.sort(live, function(a, b)
            local ar = a.focus_history_id >= 0 and a.focus_history_id or math.huge
            local br = b.focus_history_id >= 0 and b.focus_history_id or math.huge
            if ar == br then return a.address < b.address end
            return ar < br
        end)
        order = {}
        local active = hl.get_active_window()
        for i, w in ipairs(live) do
            order[i] = w.address
            if active and active.address == w.address then index = i end
        end
    end
    for _ = 1, #order do
        index = ((index - 1 + (backwards and -1 or 1)) % #order) + 1
        local target = by_address[order[index]]
        if target then
            hl.dispatch(hl.dsp.focus({ window = target }))
            hl.dispatch(hl.dsp.window.alter_zorder({ window = target, mode = "top" }))
            return
        end
    end
    M.finish()
end

-- Release binds avoid reading key state before Hyprland updates it.
-- Let the normal Alt release reach applications as well.
hl.bind("Alt_L", M.finish, { release = true, ignore_mods = true, non_consuming = true, description = "Finish window switch" })
hl.bind("Alt_R", M.finish, { release = true, ignore_mods = true, non_consuming = true, description = "Finish window switch" })
return M
