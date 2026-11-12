local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local ButtonDialog    = require("ui/widget/buttondialog")
local ConfirmBox      = require("ui/widget/confirmbox")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local Duo        = require("duo")
local ScreenBase = require("screen_base")

local Board      = lrequire("board")
local SymbolGrid = lrequire("board_widget")

local RULES_EN = [[
Hidden Differences — two readers, two grids

Each player has a reader. Both show a grid of symbols, and the two grids are the same except for a few cells. Find them all together — without looking at the other screen!

Starting
• One player taps New game → Start a game and reads the code aloud. The other taps New game → Join a game and types it. Each one picks a grid: A or B.
• The difficulty is set by the player who starts (menu): Easy 5×5 with 4 differences, Medium 6×6 with 6, Hard 7×7 with 8 that look alike.

Playing
• Describe your grid to each other, cell by cell or line by line: "row 2: black circle, white square, black cross…". The letters and numbers around the grid help.
• When you think a cell differs, tap it on your own reader. A difference gets a thick frame; a wrong cell turns grey and counts as a mistake.
• Each reader checks its own taps, so both players can tap.

The game is won when every difference is found. Show the differences (menu) gives up and shows the rest.
]]

local RULES_FR = [[
Différences cachées — deux liseuses, deux grilles

Chaque joueur a une liseuse. Les deux affichent une grille de symboles, identiques à quelques cases près. Trouvez-les toutes ensemble, sans regarder l'écran de l'autre !

Pour commencer
• Un joueur touche Nouvelle partie → Lancer une partie et lit le code à voix haute. L'autre touche Nouvelle partie → Rejoindre une partie et le saisit. Chacun choisit une grille : A ou B.
• La difficulté est celle du joueur qui lance (menu) : Facile 5×5 avec 4 différences, Moyen 6×6 avec 6, Difficile 7×7 avec 8 qui se ressemblent.

Déroulement
• Décrivez-vous vos grilles, case par case ou ligne par ligne : « ligne 2 : rond noir, carré blanc, croix noire… ». Les lettres et les chiffres autour de la grille aident.
• Quand vous pensez qu'une case diffère, touchez-la sur votre liseuse. Une différence reçoit un cadre épais ; une case fausse devient grise et compte comme une erreur.
• Chaque liseuse vérifie ses propres touches : les deux joueurs peuvent toucher.

La partie est gagnée quand toutes les différences sont trouvées. Montrer les différences (menu) abandonne et montre le reste.
]]

local LEVEL_NAMES = { "Easy", "Medium", "Hard" }

local SpotDiffScreen = ScreenBase:extend{}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function SpotDiffScreen:init()
    self.board = Board.load(self.plugin:loadState())
    ScreenBase.init(self)
end

function SpotDiffScreen:serializeState()
    return self.board and self.board:serialize() or nil
end

function SpotDiffScreen:save()
    self.plugin:saveState(self:serializeState())
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

-- No game yet, or the last one is over: the bar offers a new one.
function SpotDiffScreen:isRoundOver()
    return not self.board or self.board:isOver()
end

function SpotDiffScreen:buildLayout()
    local title_bar = self:buildTitleBar(_("Hidden Differences"), function()
        local items = {
            { text = _("New game"), callback = function() self:onNewGame() end },
            { text = T(_("Difficulty: %1"), _(LEVEL_NAMES[self.plugin:getSetting("level", 1)])),
              callback = function() self:openLevelMenu() end },
        }
        if self.board then
            items[#items + 1] = { text = _("Show the game code"), callback = function() self:showCode() end }
            if not self.board:isOver() then
                items[#items + 1] = { text = _("Show the differences"), callback = function() self:onReveal() end }
            end
        end
        items[#items + 1] = self:makeRulesButtonConfig(RULES_EN, RULES_FR)
        return items
    end)

    self.status_text:setMaxWidth(self:getControlsWidth())
    local controls = VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self:buildActionBar({}),
    }

    local budget_w, budget_h = self:getBoardBudget(title_bar, controls)
    local content
    if self.board then
        self.grid = SymbolGrid:new{
            board = self.board, max_width = budget_w, max_height = budget_h,
            onCellTapped = function(r, c) self:onCellTapped(r, c) end,
        }
        self.board_widget = self.grid
        content = self.grid
    else
        self.grid, self.board_widget = nil, nil
        content = TextBoxWidget:new{
            text = _("Each player needs a reader with this game. One starts a game and reads the code aloud; the other joins with that code."),
            face = Font:getFace("infofont"),
            width = math.min(budget_w, Device.screen:scaleBySize(500)),
            alignment = "center",
        }
    end
    local frame = FrameContainer:new{ padding = 0, margin = 0, bordersize = 0, content }

    if self:isLandscape() then
        self:buildLandscapeLayout(title_bar, HorizontalGroup:new{
            align = "center", frame, HorizontalSpan:new{ width = self:getGutter() }, controls,
        })
    else
        self:buildPortraitLayout(title_bar, frame,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end
    self:updateStatus()
end

function SpotDiffScreen:rebuild()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function SpotDiffScreen:updateStatus(message)
    local b = self.board
    local status = message
    if not status then
        if not b then
            status = _("Start or join a game.")
        elseif b:isSolved() then
            status = T(_("All %1 differences found, with %2 mistake(s)!"), b.count, b:mistakes())
        elseif b.revealed then
            status = T(_("Found %1 of %2 differences."), b:foundCount(), b.count)
        else
            status = self:joinStatus(
                T(_("Grid %1"), b.role:upper()),
                T(_("Differences found: %1/%2"), b:foundCount(), b.count),
                T(_("Mistakes: %1"), b:mistakes()))
        end
    end
    ScreenBase.updateStatus(self, status)
end

-- ---------------------------------------------------------------------------
-- Play
-- ---------------------------------------------------------------------------

function SpotDiffScreen:onCellTapped(r, c)
    local b = self.board
    local res = b:tap(r, c)
    if not res then return end
    local name = string.char(64 + c) .. r
    self:save()
    self.grid:refresh()
    if res == "again" then
        self:updateStatus(T(_("%1 was already tried."), name))
        return
    end
    if res == "wrong" then
        self:updateStatus(T(_("%1 is the same on both grids."), name))
        return
    end
    self:updateStatus()
    self:refreshActionBar()
    if b:isSolved() then
        self:showMessage(T(_("All %1 differences found, with %2 mistake(s)!"), b.count, b:mistakes()), 4)
    end
end

function SpotDiffScreen:onReveal()
    UIManager:show(ConfirmBox:new{
        text = _("Give up and show the differences left?"),
        ok_text = _("Show"),
        ok_callback = function()
            self.board:reveal()
            self:save()
            self.grid:refresh()
            self:updateStatus()
            self:refreshActionBar()
        end,
    })
end

-- ---------------------------------------------------------------------------
-- New game
-- ---------------------------------------------------------------------------

function SpotDiffScreen:onNewGame()
    Duo.newGameDialog{
        title     = _("Hidden Differences"),
        nvariants = #Board.LEVELS,
        variant   = self.plugin:getSetting("level", 1),
        variant_text = function(v) return T(_("Difficulty: %1"), _(LEVEL_NAMES[v])) end,
        roles = {
            { id = "a", text = _("Grid A") },
            { id = "b", text = _("Grid B") },
        },
        on_start = function(game)
            self.board = Board.new{ seed = game.seed, level = game.variant, role = game.role, code = game.code }
            self:save()
            self:rebuild()
        end,
    }
end

function SpotDiffScreen:showCode()
    local b = self.board
    self:showMessage(T(_("Game code: %1"), Duo.format(b.code)) .. "\n"
        .. T(_("Difficulty: %1"), _(LEVEL_NAMES[b.level])), 6)
end

function SpotDiffScreen:openLevelMenu()
    local dlg
    local buttons = {}
    for i, name in ipairs(LEVEL_NAMES) do
        buttons[#buttons + 1] = { {
            text = _(name),
            callback = function()
                UIManager:close(dlg)
                self.plugin:saveSetting("level", i)
            end,
        } }
    end
    dlg = ButtonDialog:new{
        title = _("Difficulty of the games you start"),
        buttons = buttons,
    }
    UIManager:show(dlg)
end

return SpotDiffScreen
