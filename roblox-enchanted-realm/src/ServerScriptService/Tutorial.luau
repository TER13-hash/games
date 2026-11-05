--!strict
-- Enchanted Realm: Inkbound — first-time tutorial
-- Fires a short sequence of HUD narration on a player's first ever session.
-- Hooked from Main.server.luau via Tutorial.onPlayer(RE, player).
-- Guarded by s.save.tutorialDone so it runs only once per save.

local Players = game:GetService("Players")
local Session = require(script.Parent:WaitForChild("Session"))

local Tutorial = {}

type Line = { delay: number, text: string, hold: number }

local LINES: { Line } = {
	{ delay = 1.2, text = "Move with A and D — the world is a sketch, walk it.", hold = 4 },
	{ delay = 6,   text = "Press E at lanterns to save your progress.",          hold = 4 },
	{ delay = 11,  text = "Click to swing. Space jumps. Mind the gap.",          hold = 4 },
	{ delay = 16,  text = "Lightning opens the sealed machinery to the east.",   hold = 5 },
}

function Tutorial.onPlayer(RE, player: Player)
	local s = Session.get(player)
	if not s then
		return
	end
	if s.save.tutorialDone then
		return
	end
	s.save.tutorialDone = true
	s.dirty = true

	for _, line in ipairs(LINES) do
		task.delay(line.delay, function()
			-- still in the server?
			if Players:GetPlayerByUserId(player.UserId) then
				RE.narrator:FireClient(player, line.text, line.hold)
			end
		end)
	end
end

return Tutorial
