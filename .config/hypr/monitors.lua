-- Monitor layout: HDMI-A-1 primary (center/right), DVI-D-1 secondary (left).
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "DVI-D-1", mode = "1920x1080@120", position = "-1920x0", scale = 1 })
