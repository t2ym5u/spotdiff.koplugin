package.path = "./?.lua;./common/?.lua;" .. package.path
local Board = dofile("board.lua")

describe("grid pairs", function()
    it("differ in exactly the level's number of cells, on both readers alike", function()
        for level, lvl in ipairs(Board.LEVELS) do
            for seed = 0, 30 do
                local a = Board.new{ seed = seed, level = level, role = "a" }
                local b = Board.new{ seed = seed, level = level, role = "b" }
                local differ = 0
                for r = 1, lvl.n do
                    for c = 1, lvl.n do
                        assert.equals(a.grid[r][c], b.other[r][c])
                        assert.equals(a.diff[r][c], b.diff[r][c])
                        if a.grid[r][c] ~= b.grid[r][c] then
                            differ = differ + 1
                            assert.is_true(a.diff[r][c])
                        end
                    end
                end
                assert.equals(lvl.diffs, differ)
            end
        end
    end)

    it("uses filled shapes only on Easy, and look-alikes on Hard", function()
        for seed = 0, 20 do
            local e = Board.new{ seed = seed, level = 1 }
            for r = 1, e.n do
                for c = 1, e.n do
                    assert.is_true(Board.isFilled(e.grid[r][c]))
                    assert.is_true(Board.isFilled(e.other[r][c]))
                end
            end
            local h = Board.new{ seed = seed, level = 3 }
            for r = 1, h.n do
                for c = 1, h.n do
                    if h.diff[r][c] then
                        local x, y = h.grid[r][c], h.other[r][c]
                        local same_shape = Board.shapeOf(x) == Board.shapeOf(y)
                        local twin = Board.NEAR_SHAPE[Board.shapeOf(x)] == Board.shapeOf(y)
                            and Board.isFilled(x) == Board.isFilled(y)
                        assert.is_true(same_shape or twin)
                    end
                end
            end
        end
    end)

    it("never puts two equal symbols side by side in a row", function()
        for level = 1, 3 do
            local g = Board.new{ seed = 99, level = level }
            for r = 1, g.n do
                for c = 2, g.n do
                    -- grid A is drawn that way; B differs only in a few cells
                    if g.role == "a" then assert.are_not.equal(g.grid[r][c - 1], g.grid[r][c]) end
                end
            end
        end
    end)

    it("gives different games for different seeds", function()
        local a, b = Board.new{ seed = 1, level = 2 }, Board.new{ seed = 2, level = 2 }
        local same = 0
        for r = 1, a.n do
            for c = 1, a.n do
                if a.grid[r][c] == b.grid[r][c] then same = same + 1 end
            end
        end
        assert.is_true(same < a.n * a.n)
    end)

    it("levels get harder: more cells, more differences", function()
        for i = 2, #Board.LEVELS do
            assert.is_true(Board.LEVELS[i].n > Board.LEVELS[i - 1].n)
            assert.is_true(Board.LEVELS[i].diffs > Board.LEVELS[i - 1].diffs)
        end
    end)
end)

describe("play", function()
    it("checks taps and ends once all are found", function()
        local g = Board.new{ seed = 5, level = 1 }
        local diffs, same = {}, nil
        for r = 1, g.n do
            for c = 1, g.n do
                if g.diff[r][c] then diffs[#diffs + 1] = { r, c } else same = same or { r, c } end
            end
        end
        assert.equals("wrong", g:tap(same[1], same[2]))
        assert.equals("again", g:tap(same[1], same[2]))
        assert.equals(1, g:mistakes())
        for i, p in ipairs(diffs) do
            assert.equals("found", g:tap(p[1], p[2]))
            assert.equals(i == #diffs, g:isSolved())
        end
        assert.is_nil(g:tap(1, 1))
    end)

    it("saves progress and rebuilds the same grids", function()
        local g = Board.new{ seed = 77, level = 3, role = "b", code = "12345" }
        g:tap(1, 1)
        g:tap(2, 2)
        local g2 = Board.load(g:serialize())
        assert.same(g.grid, g2.grid)
        assert.same(g:serialize(), g2:serialize())
        assert.is_nil(Board.load({ seed = "x" }))
        assert.is_nil(Board.load({ seed = 1, level = 9 }))
    end)
end)
