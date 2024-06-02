local love = require("love")

function love.conf(t)
    t.window.width = 800
    t.window.height = 600
    t.window.fullscreen = false
    t.modules.joystick = false
    t.modules.physics = false
    t.window.title = "APMW"
    t.console = false
end