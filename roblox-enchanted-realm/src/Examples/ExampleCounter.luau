--!strict
-- =====================================================================
-- EXAMPLE: anatomy of an Inkbound server module
-- =====================================================================
-- This file is a *pattern reference*, not a feature. It is mapped into the
-- game (see default.project.json → Modules) so you can open and read it in
-- Studio, but Main never requires it, so none of this code ever runs.
--
-- It mirrors how the real modules (Session, Enemies, Bosses, SaveData,
-- LootChests…) are shaped. Copy it as a starting point for your own.
--
-- THE RULES OF THE ROAD
--   1. Server logic lives here; the client is only HUD + input.
--   2. Shared constants/tables go in ReplicatedStorage/Modules/Config.luau.
--   3. Per-player persistent state goes in Session (HP/ink/XP/save) —
--      never keep it in loose globals you cannot save.
--   4. Communicate server→client with RE (remotes): RE.sync pushes the
--      HUD payload, RE.narrator shows a banner, RE.dialogue shows a toast.
--   5. Scripts must not block forever at require time — define and return,
--      and do the work inside an init() the master script calls.
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config is the shared truth table (icons, costs, regions, objectives).
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

-- Session is the per-player database. It owns HP / ink / XP / save.
local Session = require(script.Parent:WaitForChild("Session"))

-- Your module always returns one table. Other scripts require it and call it.
local ExampleCounter = {}

-- Private state stays upvalue. Never put it on the public table unless a
-- caller truly needs it. (`opened` in LootChests works the same way.)
local counters: { [number]: number } = {}

-- ------------------------------------------------------------------
-- 1) Read the player's session — it may be nil (player left).
-- ------------------------------------------------------------------
function ExampleCounter.increment(player: Player, by: number?): number?
	local s = Session.get(player)
	if not s then
		return nil
	end
	local amount = by or 1
	counters[player.UserId] = (counters[player.UserId] or 0) + amount

	-- Example of spending real currency instead of a made-up counter:
	-- Session.addXp(s, 10) grants XP (and handles leveling), same call the
	-- chests and the boss-kill handler use.
	s.dirty = true -- flag the save for flushing (Session.flushAll/30s loop)
	return counters[player.UserId]
end

function ExampleCounter.get(player: Player): number
	return counters[player.UserId] or 0
end

-- ------------------------------------------------------------------
-- 2) React to players joining — Main does this via Players.PlayerAdded.
--    If you need your own hook, export onPlayer() and Main calls it there.
-- ------------------------------------------------------------------
function ExampleCounter.onPlayer(RE, player: Player)
	do -- example: greet with the narrator banner used across the game
		RE.narrator:FireClient(player, "Welcome to Inkbound, traveler.", 4)
	end
end

-- ------------------------------------------------------------------
-- 3) init() keeps require time cheap and side-effect free.
--    Everything that touches the world happens here — Main calls this once.
-- ------------------------------------------------------------------
function ExampleCounter.init(RE)
	Players.PlayerRemoving:Connect(function(player)
		counters[player.UserId] = nil -- no leaks on leave
	end)
end

-- ------------------------------------------------------------------
-- To ship a new module inside the game:
--   1. Write the file under scripts/... keep it child of the owning service
--   2. Map it in BOTH project files:
--        roblox-enchanted-realm/default.project.json
--        ../default.project.json   (root — rojo build runs from here)
--   3. require it from Main.server.luau and call init(RE) / onPlayer()
--   4. rojo build to parse-check; Play in Studio to run it
--   5. watching the Output window is how you find runtime errors —
--      pcall()+warn() anything you are unsure about, on purpose.
-- ------------------------------------------------------------------

return ExampleCounter
