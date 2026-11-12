-- shapes.lua — paints the seven symbol shapes, filled or outlined, inside a
-- square box. Plain rectangles only (Blitbuffer:paintRect / paintCircle), so
-- it renders the same on every reader and needs no font.

local Blitbuffer = require("ffi/blitbuffer")

local BLACK = Blitbuffer.COLOR_BLACK
local WHITE = Blitbuffer.COLOR_WHITE

local Shapes = {}

-- Row-by-row fill of a shape given as half-width(t) for t in [0, 1] from top
-- to bottom.
local function fillRows(bb, cx, top, h, halfw, color)
    for i = 0, h - 1 do
        local hw = math.floor(halfw((i + 0.5) / h) + 0.5)
        if hw > 0 then bb:paintRect(cx - hw, top + i, 2 * hw, 1, color) end
    end
end

local function solid(bb, shape, cx, cy, r, color)
    if shape == "circle" then
        bb:paintCircle(cx, cy, r, color)
    elseif shape == "square" then
        local s = math.floor(r * 0.85)
        bb:paintRect(cx - s, cy - s, 2 * s, 2 * s, color)
    elseif shape == "triangle_up" then
        fillRows(bb, cx, cy - r, 2 * r, function(t) return r * t end, color)
    elseif shape == "triangle_down" then
        fillRows(bb, cx, cy - r, 2 * r, function(t) return r * (1 - t) end, color)
    elseif shape == "diamond" then
        fillRows(bb, cx, cy - r, 2 * r, function(t) return r * (1 - math.abs(2 * t - 1)) end, color)
    elseif shape == "plus" then
        local w = math.max(2, math.floor(r * 0.45))
        bb:paintRect(cx - r, cy - w, 2 * r, 2 * w, color)
        bb:paintRect(cx - w, cy - r, 2 * w, 2 * r, color)
    elseif shape == "cross" then
        local w = math.max(2, math.floor(r * 0.32))
        local d = math.floor(r * 0.8)
        for i = -d, d do
            bb:paintRect(cx + i - w, cy + i - w, 2 * w, 2 * w, color)
            bb:paintRect(cx + i - w, cy - i - w, 2 * w, 2 * w, color)
        end
    end
end

-- Paints `shape` centred in the box (x, y, size); outlined shapes are a
-- black shape with a smaller white one inside.
function Shapes.paint(bb, shape, filled, x, y, size)
    local cx, cy = x + math.floor(size / 2), y + math.floor(size / 2)
    local r = math.floor(size * 0.36)
    solid(bb, shape, cx, cy, r, BLACK)
    if not filled then
        local t = math.max(2, math.floor(size / 14))
        local inner = r - t
        if shape == "triangle_up" or shape == "triangle_down" or shape == "diamond" then
            -- Sloped sides look thinner than straight ones at the same inset.
            inner = r - math.floor(t * 1.9)
            local shift = shape == "triangle_up" and math.floor(t * 0.6)
                or shape == "triangle_down" and -math.floor(t * 0.6) or 0
            solid(bb, shape, cx, cy + shift, inner, WHITE)
        elseif shape == "plus" then
            local w = math.max(1, math.floor(r * 0.45) - t)
            local arm = r - t
            bb:paintRect(cx - arm, cy - w, 2 * arm, 2 * w, WHITE)
            bb:paintRect(cx - w, cy - arm, 2 * w, 2 * arm, WHITE)
        elseif shape == "cross" then
            local w = math.max(1, math.floor(r * 0.32) - math.ceil(t * 0.7))
            local d = math.floor(r * 0.8) - math.floor(t * 0.5)
            for i = -d, d do
                bb:paintRect(cx + i - w, cy + i - w, 2 * w, 2 * w, WHITE)
                bb:paintRect(cx + i - w, cy - i - w, 2 * w, 2 * w, WHITE)
            end
        else
            solid(bb, shape, cx, cy, inner, WHITE)
        end
    end
end

return Shapes
