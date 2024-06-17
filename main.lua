local SCREEN_W = love.graphics.getWidth()
local SCREEN_H = love.graphics.getHeight()

local ARENA_W = SCREEN_W*3
local ARENA_H = SCREEN_H*3

local P1_DMG = 4
local P2_DMG = 10
local P3_DMG = 1
local UNIT_SIZE = 15
local LEAKSPEED = 0.05
local P1_LEAK = 0.1
local P2_LEAK = 0.2
local P3_LEAK = 0.05
local BLEED_DPS = 0.02
local DEATHBLOW_CD = 1.5
local RUSH_DISTANCE = 16


local CLAWMARK_TOP = love.graphics.newImage("clawmarktop.png")
local CLAWMARK_BOT = love.graphics.newImage("clawmarkbot.png")
local CLAW_ANIM_SPEED = 0.05

local MAP_GAP=10
local MAP_LINE_THICC = 10
local MAPSIZE=SCREEN_H/4

local BARBORDER = MAP_GAP-3
local INTERBAR_HEIGHT = 20
local BAR_LENGTH = SCREEN_W/2.5
local BOTTOMBAR_X = SCREEN_W - BARBORDER - BAR_LENGTH
local BAR_LINE_THICC = 3
local BAR_THICC = 8

local function PLAYER1_COLOR() love.graphics.setColor(0.62, 0.16, 0.16) end
local function PLAYER2_COLOR() love.graphics.setColor(0.62, 0.46, 0.16) end
local function PLAYER3_COLOR() love.graphics.setColor(0.62, 0.16, 0.46) end
local function ENEMY_COLOR() love.graphics.setColor(0.97, 0.89, 0.71) end
local ENEMY_COUNT0 = 8

local MAP = love.graphics.newImage("map.png")
local SPAWNRATE = 4
local RNG_BLOW = love.math.random(70)

local DEATH_THRESHOLD = 20
local DEATH_HEAL = 60

local scrolling = 0
local scrolling_y = 0
local scrolling_x = 0

local apm = 0
local input_dates = {}
local clock = 0
local drawbuffer = {}
local leaked = 0

local enemy_focus = nil
local entities = {}
local deathblow_cd = 0
local has_killed = true
local atk_cycles = 2
local spawndate = 0

local player_focus = 1

--fixes weird rng
love.math.random();love.math.random();love.math.random()

local arena_pos = {
    x = 0,
    y = 0
}

local function pos_in_arena(ent, axis)
    return ent[axis] - arena_pos[axis]
end

local function unit_round(x)
    return math.floor(x/UNIT_SIZE) * UNIT_SIZE
end

local function random_arena_pos()
    return (unit_round(love.math.random(UNIT_SIZE, ARENA_W)) + arena_pos.x), (unit_round(love.math.random(UNIT_SIZE, ARENA_H)) + arena_pos.y)
end


local player1 = {
    DMG = P1_DMG;
    foot = 0;
    direction = "right";
    bloodbar = 100;
}
local player2 = {
    DMG = P2_DMG;
    foot = 0;
    direction = "right";
    bloodbar = 100;
}
local player3 = {
    DMG = P3_DMG;
    foot = 0;
    direction = "right";
    bloodbar = 100;
}
player1.x, player1.y = random_arena_pos()
player2.x, player2.y = random_arena_pos()
player3.x, player3.y = random_arena_pos()

--shortens variables names. do not update player data on this one.
-- readability and maintainibility to improve
local player_ = player1

local function collision(x1, y1, x2, y2, direction)
    --detect potential collisions between two entities
    if direction == "up" then
        return math.abs(x1 - x2) <= UNIT_SIZE and y1 - y2 == 2*UNIT_SIZE
    elseif direction == "down" then
        return math.abs(x1 - x2) <= UNIT_SIZE and y2 - y1 == 2*UNIT_SIZE
    elseif direction == "left" then
        return x1 - x2 == 2*UNIT_SIZE and math.abs(y1 - y2) <= UNIT_SIZE
    else
        return x2 - x1 == 2*UNIT_SIZE and math.abs(y1 - y2) <= UNIT_SIZE
    end
end

local function rectangle_collide(unit, x0, y0, width, height)
    local x = pos_in_arena(unit, "x")
    local y = pos_in_arena(unit, "y")
    return x == x0 and y >= y0 and y <= y0 + height and unit.direction == "right"
    or x == x0 + UNIT_SIZE and y >= y0 and y <= y0 + height and unit.direction == "left"

    or x == x0 + width - UNIT_SIZE and y >= y0 and y <= y0 + height and unit.direction == "right"
    or x == x0 + width and y >= y0 and y <= y0 + height and unit.direction == "left"

    or y == y0 and x >= x0 and x <= x0 + width and unit.direction == "up"
    or y == y0 - UNIT_SIZE and x >= x0 and x <= x0 + width and unit.direction == "down"

    or y == y0 + height - UNIT_SIZE and x >= x0 and x <= x0 + width and unit.direction == "up"
    or y == y0 + height - 2*UNIT_SIZE and x >= x0 and x <= x0 + width and unit.direction == "down"
end

local cave_x = unit_round(ARENA_W/2)
local cave_y = unit_round(ARENA_H/2)
local cave_side = UNIT_SIZE*5

local function move(unit)
    --increment pos considering the facing direction, if there's no collision
    local collide = false
    local unit_direction = unit.direction
    for i = 1, #entities do
        local ent = entities[i]
        if ent ~= unit and collision(unit.x, unit.y, ent.x, ent.y, unit_direction) then
            collide = true
            break
        end
    end
    if rectangle_collide(player_, cave_x, cave_y, cave_side, cave_side) then
        love.event.quit()
    elseif collide or rectangle_collide(unit, 0, 0, ARENA_W, ARENA_H) then return
    elseif scrolling == 0 or unit[1] == 'foe' then
        if unit_direction == "up" then
            unit.y = unit.y - UNIT_SIZE
        elseif unit_direction == "left" then
            unit.x = unit.x - UNIT_SIZE
        elseif unit_direction == "down" then
            unit.y = unit.y + UNIT_SIZE
        elseif unit_direction == "right" then
            unit.x = unit.x + UNIT_SIZE
        end
        return
    elseif unit.direction == "up" then
        scrolling_y = UNIT_SIZE
    elseif unit.direction == "left" then
        scrolling_x = UNIT_SIZE
    elseif unit.direction == "down" then
        scrolling_y = -UNIT_SIZE
    elseif unit.direction == "right" then
        scrolling_x = -UNIT_SIZE
    end
end

local function insert_drawbuffer(x, y)
    --used to queue attacks to render
    table.insert(drawbuffer,{
        clock = clock,
        x = x,
        y = y,
        anim = CLAWMARK_TOP
    })
    table.insert(drawbuffer,{
        clock = clock + CLAW_ANIM_SPEED,
        x = x,
        y = y,
        anim = CLAWMARK_BOT
    })
end

local function damage_over_time()
    if clock - leaked > LEAKSPEED then
        leaked = clock
        player1.bloodbar = player1.bloodbar - P1_LEAK
        player2.bloodbar = player2.bloodbar - P2_LEAK
        player3.bloodbar = player3.bloodbar - P3_LEAK
    end
    for i = 3, #entities do
        local foe = entities[i]
        if foe[1] == "foe" then
            foe.health = foe.health - foe.bleed * BLEED_DPS
        end
    end
end

local function player_attack(player)
    --visual part
    local claw_x = player.x
    local claw_y = player.y
    local direction = player.direction
    if player.foot == 0 then
        if direction == "up" then
            claw_y = player.y-UNIT_SIZE
        elseif direction == "left" then
            claw_x = player.x-2*UNIT_SIZE
        elseif direction == "down" then
            claw_y = player.y+2*UNIT_SIZE
        elseif direction == "right" then
            claw_x = player.x+UNIT_SIZE
        end
    else
        claw_x = claw_x - UNIT_SIZE
        claw_y = player.y + UNIT_SIZE
        if direction == "up" then
            claw_y = player.y-UNIT_SIZE
        elseif direction == "left" then
            claw_x = player.x-2*UNIT_SIZE
        elseif direction == "down" then
            claw_y = player.y+2*UNIT_SIZE
        elseif direction == "right" then
            claw_x = player.x+UNIT_SIZE
        end
    end
    insert_drawbuffer(claw_x, claw_y)
    --damaging enemy part
    for i = 1, #entities do
        local foe = entities[i]
        if foe[1] == "foe" and collision(player.x, player.y, foe.x, foe.y, direction) then
            foe.health = foe.health - player.DMG
            enemy_focus = i
            if player == player2 and foe.health <= 0 then has_killed = true end
            if foe.health <= 0 then player.bloodbar = player.bloodbar + DEATH_HEAL end
        end
    end
end

local function special_attack(player, special)
    for i = 1, #entities do
        local foe = entities[i]
        if foe[1] == "foe" and collision(player.x, player.y, foe.x, foe.y, player.direction) then
            special(foe, i)
        end
    end
    --visual part
    local claw_x, claw_y, claw_x2, claw_y2
    if player.direction == "up" then
        claw_y = player.y - UNIT_SIZE
        claw_y2 = claw_y
        claw_x = player.x
        claw_x2 = claw_x - UNIT_SIZE
    elseif player.direction == "left" then
        claw_x = player.x - 2*UNIT_SIZE
        claw_x2 = claw_x
        claw_y = player.y
        claw_y2 = claw_y + UNIT_SIZE
    elseif player.direction == "down" then
        claw_x = player.x
        claw_x2 = claw_x - UNIT_SIZE
        claw_y = player.y + 2*UNIT_SIZE
        claw_y2 = claw_y
    elseif player.direction == "right" then
        claw_x = player.x + UNIT_SIZE
        claw_x2 = claw_x
        claw_y = player.y
        claw_y2 = claw_y + UNIT_SIZE
    end
    insert_drawbuffer(claw_x, claw_y)
    insert_drawbuffer(claw_x2, claw_y2)
end

local function get_feet_position()
    for i = 1, #entities do
        local ent = entities[i]
        if ent ~= arena_pos then
            --P-- Caching of `ent.x` and `ent.y`
            local ent_x = ent.x
            local ent_y = ent.y
            if ent.foot == 1 then
                ent.y0 = ent_y + UNIT_SIZE
                ent.x0 = ent_x
                ent.x1 = ent_x - UNIT_SIZE
                ent.y1 = ent_y
            else
                ent.y0 = ent_y
                ent.x0 = ent_x
                ent.x1 = ent_x - UNIT_SIZE
                ent.y1 = ent_y + UNIT_SIZE
            end
        end
    end
end

local function screen_movement(x, y)
    for i = 1, #entities do
        local entity = entities[i]
        entity.x = entity.x + x
        entity.y = entity.y + y
    end
end

local function do_scrolling(player)
    -- activate scrolling if player is near the border
    -- maybe not necessary to call it each frame
    if (player.y > 400 and player.direction == "down")
    or (player.y < 200 and player.direction == "up")
    or (player.x > 550  and player.direction == "right")
    or (player.x < 250 and player.direction == "left") then
        scrolling = 1
    else
        scrolling = 0
    end
    if scrolling == 1 then
        for i = 1, #entities do
            local entity = entities[i]
            if entity ~= player then
                entity.x = entity.x + scrolling_x
                entity.y = entity.y + scrolling_y
            end
        end
        scrolling_y = 0
        scrolling_x = 0
    end
end

function love.keypressed(key)
    if key == 'z' then
        player_focus = 1
        screen_movement(SCREEN_W/2 - player1.x, SCREEN_H/2 - player1.y)
    elseif key == 'x' then
        player_focus = 2
        screen_movement(SCREEN_W/2 - player2.x, SCREEN_H/2 - player2.y)
    elseif key == 'c' then
        player_focus = 3
        screen_movement(SCREEN_W/2 - player3.x, SCREEN_H/2 - player3.y)
    elseif key == 'q' and player_.foot == 1 then
        move(entities[player_focus])
        entities[player_focus].foot= 0
    elseif key == 'e' and player_.foot == 0 then
        move(entities[player_focus])
        entities[player_focus].foot = 1
    elseif key == 'w' then
        entities[player_focus].direction = "up"
    elseif key == 'a' then
        entities[player_focus].direction = "left"
    elseif key == 's' then
        entities[player_focus].direction = "down"
    elseif key == 'd' then
        entities[player_focus].direction = "right"
    elseif key == "1" and player_.foot == 1 then
        player_attack(player_)
        entities[player_focus].foot = 0
        if player_focus == 3 then atk_cycles = atk_cycles + 0.5 end
    elseif key == "3" and player_.foot == 0 then
        player_attack(player_)
        entities[player_focus].foot = 1
        if player_focus == 3 then atk_cycles = atk_cycles + 0.5 end
    elseif key == "2" and deathblow_cd - clock < 0 and player_focus == 1 then
        special_attack(player1, function (foe)
            if foe.health - RNG_BLOW < DEATH_THRESHOLD then
                foe.health = 0
                player1.bloodbar =  player1.bloodbar + DEATH_HEAL
            end
        end)
        deathblow_cd = clock + DEATHBLOW_CD
    elseif key == "2" and has_killed == true and player_focus == 2 then
        for _ = 1, RUSH_DISTANCE do
            move(player2)
            do_scrolling(player2)
        end
        has_killed = false
    elseif key == "2" and atk_cycles >= 2 and player_focus == 3 then
        special_attack(player3, function (foe, i)
            foe.bleed = foe.bleed + 1
            enemy_focus = i
        end)
        atk_cycles = 0
    elseif key == "escape" then
        love.event.quit()
    end
    --increment APM score
    table.insert(input_dates, clock)
    apm = apm + 1
end

local enemy = {}

function enemy.spawn()
    -- make enemies appear at a certain frequence
    if spawndate - clock < 0 then
        table.insert(entities, {
            "foe",
            feared = false,
            x = unit_round(math.random(0, ARENA_W))  + arena_pos.x,
            y = unit_round(math.random(0, ARENA_H))  + arena_pos.y,
            direction = nil,
            has_moved = 0,
            foot = 1,
            health = 100,
            bleed = 0
        })
        spawndate = clock + SPAWNRATE
        --prevents drawing nil feet exception
        get_feet_position()
    end
end


function enemy.runaway_dir()
    -- set enemies to run on the opposite direction of the player1 (to improve)
    for i = 1, #entities do
        local ent = entities[i]
        if ent[1] == "foe"
        and ent.feared == false
        and math.abs(ent.x - player1.x) < SCREEN_W
        and math.abs(ent.y - player1.y) < SCREEN_H then
            ent.feared = true
            ent.direction = player1.direction
        end
    end
end

function enemy.runaway()
    for i = 1, #entities do
        local ent = entities[i]
        if ent.direction ~= nil and ent[1] == "foe" and clock - ent.has_moved > 1 then
            move(ent)
            ent.has_moved = clock
            ent.foot = (ent.foot + 1) % 2
        end
    end
end

function enemy.death()
    --kill 0 hp enemies
    for i = #entities, 1, -1 do
        local ent = entities[i]
        if ent[1] == "foe" and ent.health <= 0 then
            table.remove(entities, i)
            enemy_focus = nil
        end
    end
end

entities = {
    player1,
    player2,
    player3,
    arena_pos
}

--initial enemy spawn
for _ = 1, ENEMY_COUNT0 do
    spawndate = -1
    enemy.spawn()
end

local function garbage_collector()
    --clean apm and attack rendering related tables when elements expire
    for i = #input_dates, 1, -1 do
        local v = input_dates[i]
        if clock - v > 60 then
            table.remove(input_dates, i)
            apm = apm - 1
        end
    end
    for i = 1, #drawbuffer do
        local claw = drawbuffer[i]
        if clock - claw.clock > CLAW_ANIM_SPEED then
            claw.x = nil
        end
    end
end

function love.update(dt)
    player_ = entities[player_focus]
    clock = clock + dt
    get_feet_position(entities)
    damage_over_time()
    do_scrolling(entities[player_focus])
    garbage_collector()
    enemy.spawn()
    enemy.runaway_dir()
    enemy.runaway()
    enemy.death()
end

local function draw_map()
    love.graphics.setColor(1,1,1)
    love.graphics.draw(MAP, arena_pos.x, arena_pos.y)
end

local function get_color(ent)
    if ent == player1 then PLAYER1_COLOR()
    elseif ent == player2 then PLAYER2_COLOR()
    elseif ent == player3 then PLAYER3_COLOR()
    else ENEMY_COLOR() end
end

local function draw_ent(self)
    --draw both feet
    get_color(self)
    love.graphics.rectangle('fill', self.x0, self.y0, UNIT_SIZE, UNIT_SIZE)
    love.graphics.rectangle('fill', self.x1, self.y1, UNIT_SIZE, UNIT_SIZE)
end

local function draw_mini_ent(self)
    get_color(self)
    love.graphics.rectangle('fill',
        (pos_in_arena(self, "x") / ARENA_W * MAPSIZE) + MAP_GAP,
        (pos_in_arena(self, "y") / ARENA_H * MAPSIZE) + SCREEN_H-(MAPSIZE+MAP_GAP),
        UNIT_SIZE/3, UNIT_SIZE/3
    )
end

local function draw_clawmarks()
    love.graphics.setColor(0.23, 0.66, 0.33)
    for i = 1, #drawbuffer do
        local claw = drawbuffer[i]
        if claw.x ~= nil then
            love.graphics.draw(claw.anim, claw.x, claw.y)
        end
    end
end

local function draw_bloodbars()
    love.graphics.setColor(1, 0, 0)
    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(BAR_LINE_THICC)
    love.graphics.rectangle("line", BARBORDER, BARBORDER, BAR_LENGTH, BAR_THICC)
    love.graphics.rectangle(
        "fill", BARBORDER, BARBORDER,
        player1.bloodbar*BAR_LENGTH/100, BAR_THICC
    )
    love.graphics.rectangle("line", BARBORDER, BARBORDER + INTERBAR_HEIGHT, BAR_LENGTH, BAR_THICC)
    love.graphics.rectangle(
        "fill", BARBORDER, BARBORDER + INTERBAR_HEIGHT,
        player2.bloodbar*BAR_LENGTH/100, BAR_THICC
    )
    love.graphics.rectangle("line", BARBORDER, BARBORDER + 2*INTERBAR_HEIGHT, BAR_LENGTH, BAR_THICC)
    love.graphics.rectangle(
        "fill", BARBORDER, BARBORDER + 2*INTERBAR_HEIGHT,
        player3.bloodbar*BAR_LENGTH/100, BAR_THICC
    )
    if enemy_focus ~= nil then
        love.graphics.rectangle(
            "line", BOTTOMBAR_X,
            SCREEN_H - BARBORDER,
            BAR_LENGTH, BAR_THICC
        )
        love.graphics.rectangle(
            "fill", BOTTOMBAR_X,
            SCREEN_H - BARBORDER,
            BAR_LENGTH * entities[enemy_focus].health/100,
            BAR_THICC
        )
    end
end

local function draw_minimap()
    love.graphics.setColor(1, 0, 0)
    love.graphics.setLineWidth(MAP_LINE_THICC)
    love.graphics.rectangle('line', MAP_GAP, SCREEN_H-(MAPSIZE+MAP_GAP), MAPSIZE, MAPSIZE)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', MAP_GAP, SCREEN_H-(MAPSIZE+MAP_GAP), MAPSIZE, MAPSIZE)
end

local function draw_apm()
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("APM: "..apm, math.floor(6*SCREEN_W/7 - 15), math.floor(SCREEN_H/15),0, 2)
end

local function draw_cave()
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle("fill", cave_x + arena_pos.x, cave_y + arena_pos.y , cave_side, cave_side)
end

function love.load()
    player_focus = 1
    screen_movement(SCREEN_W/2 - player1.x, SCREEN_H/2 - player1.y)
end

function love.draw()
    draw_map()
    draw_cave()
    for i = 1, #entities do
        local entity = entities[i]
        if entity ~= arena_pos then
            draw_ent(entity)
        end
    end

    draw_clawmarks()
    draw_bloodbars()
    draw_minimap()
    draw_apm()
    for i = 1, #entities do
        local ent = entities[i]
        if ent ~= arena_pos then
            draw_mini_ent(ent)
        end
    end
    love.graphics.setColor(0, 1, 0)
--    love.graphics.print(pos_in_arena(player_, "x"), 20, 90)
--    love.graphics.print(pos_in_arena(player_, "y"), 20, 110)
end