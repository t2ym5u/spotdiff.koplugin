local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Blitbuffer     = require("ffi/blitbuffer")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local UIManager      = require("ui/uimanager")

local Board  = lrequire("board")
local Shapes = lrequire("shapes")

local C_BG    = Blitbuffer.COLOR_WHITE
local C_FG    = Blitbuffer.COLOR_BLACK
local C_GRID  = Blitbuffer.COLOR_GRAY_9
local C_TRIED = Blitbuffer.COLOR_GRAY_E
local C_SHOWN = Blitbuffer.COLOR_GRAY_7

local function bsearchFont(lo, hi, max_w, max_h, sample)
    local best = lo
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local m = RenderText:sizeUtf8Text(0, math.huge, Font:getFace("cfont", mid), sample, true, false)
        if m.x <= max_w and (m.y_top + m.y_bottom) <= max_h then
            best, lo = mid, mid + 1
        else
            hi = mid - 1
        end
    end
    return best
end

local function centeredText(bb, text, face, cx, cy)
    local m = RenderText:sizeUtf8Text(0, math.huge, face, text, true, false)
    RenderText:renderUtf8Text(bb, cx - math.floor(m.x / 2), cy + math.floor((m.y_top - m.y_bottom) / 2),
        face, text, true, false, C_FG)
end

-- ---------------------------------------------------------------------------
-- SymbolGrid — the player's grid, with A.. / 1.. labels to read it aloud.
-- ---------------------------------------------------------------------------

local SymbolGrid = InputContainer:extend{
    board      = nil,
    max_width  = 0,
    max_height = 0,
    onCellTapped = nil,   -- function(r, c)
}

function SymbolGrid:init()
    local n = self.board.n
    -- The label band is half a cell: the symbols get the room.
    local cell = math.floor(math.min(self.max_width, self.max_height) / (n + 0.6))
    self.cell = math.max(cell, 16)
    self.band = math.floor(self.cell * 0.6)
    local side = self.band + n * self.cell
    self.dimen = Geom:new{ w = side, h = side }
    local fit = math.floor(self.band * 0.8)
    self.label_face = Font:getFace("cfont", bsearchFont(6, math.max(6, self.band), fit, fit, "8"))
    self.ges_events = {
        TapCell = { GestureRange:new{ ges = "tap", range = function() return self.paint_rect end } },
    }
end

function SymbolGrid:onTapCell(_, ges)
    if not self.paint_rect then return false end
    local c = math.floor((ges.pos.x - self.paint_rect.x - self.band) / self.cell) + 1
    local r = math.floor((ges.pos.y - self.paint_rect.y - self.band) / self.cell) + 1
    local n = self.board.n
    if r >= 1 and r <= n and c >= 1 and c <= n and self.onCellTapped then
        self.onCellTapped(r, c)
    end
    return true
end

function SymbolGrid:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.dimen.w, h = self.dimen.h }
    local b, n, cell, band = self.board, self.board.n, self.cell, self.band
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, C_BG)
    for i = 1, n do
        centeredText(bb, string.char(64 + i), self.label_face,
            x + band + (i - 1) * cell + math.floor(cell / 2), y + math.floor(band / 2))
        centeredText(bb, tostring(i), self.label_face,
            x + math.floor(band / 2), y + band + (i - 1) * cell + math.floor(cell / 2))
    end
    local frame = math.max(3, math.floor(cell / 12))
    for r = 1, n do
        for c = 1, n do
            local cx, cy = x + band + (c - 1) * cell, y + band + (r - 1) * cell
            if b.wrong[r][c] then bb:paintRect(cx, cy, cell, cell, C_TRIED) end
            local sym = b.grid[r][c]
            Shapes.paint(bb, Board.shapeOf(sym), Board.isFilled(sym), cx, cy, cell)
            if b.found[r][c] then
                bb:paintBorder(cx + 2, cy + 2, cell - 4, cell - 4, frame, C_FG)
            elseif b.revealed and b.diff[r][c] then
                bb:paintBorder(cx + 2, cy + 2, cell - 4, cell - 4, frame, C_SHOWN)
            end
        end
    end
    local gx, gy = x + band, y + band
    for i = 0, n do
        local edge = i == 0 or i == n
        local w = edge and 2 or 1
        local off = i == n and w - 1 or 0
        bb:paintRect(gx + i * cell - off, gy, w, n * cell, edge and C_FG or C_GRID)
        bb:paintRect(gx, gy + i * cell - off, n * cell, w, edge and C_FG or C_GRID)
    end
end

function SymbolGrid:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

return SymbolGrid
