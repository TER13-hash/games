--!strict
-- Enchanted Realm: Inkbound — admin chat commands (testing helpers)
-- Type any of these in chat (server-side, no client install needed):
--   /help                — list commands
--   /heal                — restore full HP
--   /ink                 — refill ink to full
--   /xp <n>              — grant N XP (e.g. /xp 100)
--   /levelup             — grant exactly enough XP for the next level
--   /grant <abilityId>   — unlock an ability (e.g. /grant shockwave)
--   /bossreset           — reset all bosses
--
-- NOTE: these run for ANY player. If you publish the game, gate handle()
-- to your own UserId (Players.GetPlayerByUserId(YOUR_ID) == player).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Session = require(script.Parent:WaitForChild("Session"))
local Bosses = require(script.Parent:WaitForChild("Bosses"))

local AdminCommands = {}

local HELP = "Commands: /heal /ink /xp <n> /levelup /grant <ability> /bossreset /help"

-- TextChatService mode fires MessageReceived; legacy mode fires Chatted.
-- Both are wired below; this dedupes double-fires of the same line.
local lastSeen: { [number]: { text: string, t: number } } = {}

local function handle(RE, player: Player, text: string)
	local now = tick()
	local prev = lastSeen[player.UserId]
	if prev and prev.text == text and now - prev.t < 1 then
		return
	end
	lastSeen[player.UserId] = { text = text, t = now }

	if text:sub(1, 1) ~= "/" then
		return
	end

	local args = {}
	for word in text:gmatch("%S+") do
		table.insert(args, word)
	end
	local cmd = (args[1] or ""):lower()
	local s = Session.get(player)
	if not s then
		return
	end

	local function ack(msg: string)
		RE.narrator:FireClient(player, msg, 3)
		RE.sync:FireClient(player, Session.syncPayload(s))
	end

	if cmd == "/help" then
		ack(HELP)

	elseif cmd == "/heal" then
		s.hp = Session.maxHp(s)
		s.dirty = true
		ack("HP restored.")

	elseif cmd == "/ink" then
		s.ink = Config.INK.max
		s.dirty = true
		ack("Ink refilled.")

	elseif cmd == "/xp" then
		local n = tonumber(args[2])
		if not n then
			ack("Usage: /xp <n>")
			return
		end
		Session.addXp(s, n)
		ack("+" .. n .. " XP.")

	elseif cmd == "/levelup" then
		local level = s.save.level or 1
		Session.addXp(s, Config.xpToNext(level))
		ack("Level up!")

	elseif cmd == "/grant" then
		local id = args[2]
		if not id or not (Config.ABILITIES :: any)[id] then
			local valid = {}
			for key in pairs(Config.ABILITIES) do
				table.insert(valid, key)
			end
			ack("Unknown ability. Valid: " .. table.concat(valid, ", "))
			return
		end
		Session.grantAbility(s, id)
		ack("Ability granted: " .. id)

	elseif cmd == "/bossreset" then
		Bosses.resetAll()
		ack("Bosses reset.")
	end
end

function AdminCommands.init(RE)
	-- TextChatService path (current Roblox default)
	local ok, textChatService = pcall(function()
		return game:GetService("TextChatService")
	end)
	if ok and textChatService then
		textChatService.MessageReceived:Connect(function(msg)
			local src = msg.TextSource
			if not src then
				return
			end
			local player = Players:GetPlayerByUserId(src.UserId)
			if player then
				handle(RE, player, msg.Text)
			end
		end)
	end
	-- Legacy Chatted path (harmless if both fire; handle() dedupes)
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(text)
			handle(RE, player, text)
		end)
	end)
end

return AdminCommands
