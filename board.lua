-- ---------------------------------------------------------------------------
-- board.lua — Hidden Differences: two grids of symbols, one per reader.
-- Pure Lua, no UI.
--
-- Both readers build the same pair of grids from the game code (common/
-- duo.lua): grid A on one reader, grid B on the other. They are identical
-- except for a few cells. The players describe their grids to each other
-- ("row 2: black circle, white square...") without looking at the other
-- screen, and tap the cells they think differ. Each reader knows where the
-- differences are, so it checks every tap.
--
-- A symbol is a shape (1..7) drawn filled or outlined:
--   sym = (shape - 1) * 2 + (filled and 1 or 2), so 1..14, odd = filled.
-- ---------------------------------------------------------------------------

local Duo = require("duo")

local Board = {}
Board.__index = Board

Board.SHAPES = { "circle", "square", "triangle_up", "triangle_down", "diamond", "plus", "cross" }

-- The shape that looks most like each one, for Hard's near-misses.
Board.NEAR_SHAPE = {
    circle = "square", square = "diamond", diamond = "square",
    triangle_up = "triangle_down", triangle_down = "triangle_up",
    plus = "cross", cross = "plus",
}

--   n       grid side
--   diffs   cells that differ
--   filled_only  Easy uses filled shapes only (7 symbols, easy to name)
--   near    a changed cell keeps a look-alike symbol: same shape with the
--           other fill, or its twin shape with the same fill
Board.LEVELS = {
    { id = "easy",   n = 5, diffs = 4, filled_only = true,  near = false },
    { id = "medium", n = 6, diffs = 6, filled_only = false, near = false },
    { id = "hard",   n = 7, diffs = 8, filled_only = false, near = true  },
}

function Board.symbol(shape_index, filled)
    return (shape_index - 1) * 2 + (filled and 1 or 2)
end

function Board.shapeOf(sym)
    return Board.SHAPES[math.floor((sym - 1) / 2) + 1]
end

function Board.isFilled(sym)
    return sym % 2 == 1
end

local SHAPE_INDEX = {}
for i, s in ipairs(Board.SHAPES) do SHAPE_INDEX[s] = i end

-- Symbols that could replace `sym` at the given level.
local function replacements(sym, lvl)
    local out = {}
    if lvl.near then
        local shape, filled = Board.shapeOf(sym), Board.isFilled(sym)
        out[#out + 1] = Board.symbol(SHAPE_INDEX[shape], not filled)
        out[#out + 1] = Board.symbol(SHAPE_INDEX[Board.NEAR_SHAPE[shape]], filled)
        return out
    end
    for s = 1, 14 do
        if s ~= sym and (not lvl.filled_only or Board.isFilled(s)) then out[#out + 1] = s end
    end
    return out
end

-- Builds the pair of grids for (seed, level): { n, a, b, diff[r][c] = true,
-- count }. rng: a Duo rng (common/duo.lua).
function Board.generate(rng, level)
    local lvl = Board.LEVELS[level] or Board.LEVELS[1]
    local n = lvl.n
    local pool = {}
    for s = 1, 14 do
        if not lvl.filled_only or Board.isFilled(s) then pool[#pool + 1] = s end
    end
    local a, b, diff = {}, {}, {}
    for r = 1, n do
        a[r], b[r], diff[r] = {}, {}, {}
        for c = 1, n do
            -- No two equal neighbours in a row: "three black circles" would
            -- make a line hard to tell apart when read aloud.
            local s
            repeat s = rng:pick(pool) until c == 1 or s ~= a[r][c - 1]
            a[r][c] = s
            b[r][c] = s
        end
    end
    local cells = {}
    for r = 1, n do
        for c = 1, n do cells[#cells + 1] = { r, c } end
    end
    rng:shuffle(cells)
    for i = 1, lvl.diffs do
        local r, c = cells[i][1], cells[i][2]
        b[r][c] = rng:pick(replacements(a[r][c], lvl))
        diff[r][c] = true
    end
    return { n = n, a = a, b = b, diff = diff, count = lvl.diffs }
end

-- o: seed, level (1..3), role ("a" | "b"), and the saved progress (found,
-- wrong, revealed).
function Board.new(o)
    local self = setmetatable({}, Board)
    self.seed  = o.seed or 0
    self.level = Board.LEVELS[o.level] and o.level or 1
    self.role  = o.role == "b" and "b" or "a"
    self.code  = o.code
    local g = Board.generate(Duo.rng(self.seed, "spotdiff"), self.level)
    self.n, self.diff, self.count = g.n, g.diff, g.count
    self.grid = self.role == "a" and g.a or g.b
    self.other = self.role == "a" and g.b or g.a
    self.found = o.found or {}
    self.wrong = o.wrong or {}
    self.revealed = o.revealed == true
    for r = 1, self.n do
        self.found[r] = self.found[r] or {}
        self.wrong[r] = self.wrong[r] or {}
    end
    return self
end

function Board:serialize()
    return {
        seed = self.seed, level = self.level, role = self.role, code = self.code,
        found = self.found, wrong = self.wrong, revealed = self.revealed,
    }
end

function Board.load(t)
    if type(t) ~= "table" or type(t.seed) ~= "number" or not Board.LEVELS[t.level] then return nil end
    return Board.new(t)
end

function Board:foundCount()
    local k = 0
    for r = 1, self.n do
        for c = 1, self.n do
            if self.found[r][c] then k = k + 1 end
        end
    end
    return k
end

function Board:mistakes()
    local k = 0
    for r = 1, self.n do
        for c = 1, self.n do
            if self.wrong[r][c] then k = k + 1 end
        end
    end
    return k
end

function Board:isSolved()
    return self:foundCount() >= self.count
end

function Board:isOver()
    return self.revealed or self:isSolved()
end

-- The player taps (r, c): "found", "wrong", "again" (already found or
-- already tried) or nil once the game is over.
function Board:tap(r, c)
    if self:isOver() then return nil end
    if self.found[r][c] or self.wrong[r][c] then return "again" end
    if self.diff[r][c] then
        self.found[r][c] = true
        return "found"
    end
    self.wrong[r][c] = true
    return "wrong"
end

-- Gives up: every difference is shown.
function Board:reveal()
    self.revealed = true
end

return Board
