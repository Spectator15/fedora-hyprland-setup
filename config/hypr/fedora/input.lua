hl.config({
    input = {
        kb_layout = "", -- inherit the session/XKB layout, not a forced US mapping
        follow_mouse = 0, -- focus stays where you clicked; important for Alt+Tab
        sensitivity = 0,
        accel_profile = "adaptive",
        touchpad = {
            tap_to_click = true,
            tap_and_drag = true,
            drag_lock = 0,
            natural_scroll = true,
            disable_while_typing = true,
            clickfinger_behavior = true, -- two fingers for right click
            tap_button_map = "lrm",
            scroll_factor = 1.0,
        },
        scroll_method = "2fg",
    },
    gestures = {
        workspace_swipe_distance = 300,
        workspace_swipe_cancel_ratio = 0.5,
        workspace_swipe_forever = false,
    },
})
-- Native compositor gesture, not a script fired after the gesture ends.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
