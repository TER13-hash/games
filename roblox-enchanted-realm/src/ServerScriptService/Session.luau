--!strict
-- Per-player session state: HP / ink / XP / level / abilities / echoes / save sync.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local SaveData = require(script.Parent:WaitForChild("SaveData"))

local Session = {}
Session.__index = Session

export type State = {
	player: Player,
	save: any,
	dirty: boolean,
	hp: number,
	ink: number,
	invulnerableUntil: number,
	hazardCooldowns: { [string]: number },
	barrierPromptCooldown: number,
	barrierHintCooldown: number,
	burnUntil: number,
	burnAccum: number,
	rootUntil: number,
	awakenUntil: number,
	lastCheckpointId: string,
	checkpointPos: Vector3,
	deaths: number,
}

local sessions: { [number]: State } = {}

local function level(s: State): number
	return s.save.level or 1
end

function Session.fresh(player: Player): State
	local save = SaveData.load(player.UserId)
	save.level = save.level or 1 -- safety: never nil
	local s: State = {
		player = player,
		save = save,
		dirty = false,
		hp = 0, -- set below
		ink = Config.INK.startInk,
		invulnerableUntil = 0,
		hazardCooldowns = {},
		barrierPromptCooldown = 0,
		barrierHintCooldown = 0,
		burnUntil = 0,
		burnAccum = 0,
		rootUntil = 0,
		awakenUntil = 0,
		lastCheckpointId = save.checkpointId or "cp_start",
		-- FIX: restore the saved Y too (was always 2, which dropped sky-island
		-- checkpoints into the pit on rejoin)
		checkpointPos = Vector3.new(save.checkpointX or 30, save.checkpointY or 2, 0),
		deaths = save.deaths or 0,
	}
	Session.recalcHp(s, true)
	sessions[player.UserId] = s
	return s
end

function Session.get(player: Player): State?
	return sessions[player.UserId]
end

-- FIX: sessions were never removed, leaking memory and leaving stale entries
function Session.remove(player: Player)
	sessions[player.UserId] = nil
end

function Session.all(): { State }
	local out = {}
	for _, s in pairs(sessions) do
		table.insert(out, s)
	end
	return out
end

function Session.jobRank(s: State, job: string): number
	s.save.jobs = s.save.jobs or {}
	return s.save.jobs[job] or 0
end

function Session.maxHp(s: State): number
	return Config.PLAYER.baseHealth
		+ Config.PLAYER.levelHealthBonus * (level(s) - 1)
		+ (s.save.maxHpBonus or 0)
		+ 15 * Session.jobRank(s, "warrior")
end

function Session.baseDamage(s: State): number
	return Config.PLAYER.baseDamage + Config.PLAYER.levelDamageBonus * (level(s) - 1)
end

function Session.recalcHp(s: State, heal: boolean?)
	local maxHp = Session.maxHp(s)
	if heal then
		s.hp = maxHp
	end
	if s.hp > maxHp then
		s.hp = maxHp
	end
	s.dirty = true
end

function Session.hasAbility(s: State, abilityId: string): boolean
	return (s.save.abilities or {})[abilityId] == true
end

function Session.hasEcho(s: State, echoId: string): boolean
	return (s.save.echoes or {})[echoId] == true
end

function Session.grantAbility(s: State, abilityId: string)
	s.save.abilities = s.save.abilities or {}
	s.save.abilities[abilityId] = true
	s.dirty = true
end

function Session.grantEcho(s: State, echoId: string)
	s.save.echoes = s.save.echoes or {}
	s.save.echoes[echoId] = true
	s.dirty = true
end

function Session.grantHeart(s: State)
	s.save.maxHpBonus = (s.save.maxHpBonus or 0) + Config.PLAYER.heartBonus
	Session.recalcHp(s, true)
	s.dirty = true
end

function Session.grantSatchel(s: State)
	s.save.maxInkBonus = (s.save.maxInkBonus or 0) + 25
	s.dirty = true
end

function Session.maxInk(s: State): number
	return Config.INK.max + (s.save.maxInkBonus or 0) + 20 * Session.jobRank(s, "mage")
end

function Session.addXp(s: State, amount: number): boolean -- returns true if leveled up
	local leveled = false
	local rank = Session.jobRank(s, "healer")
	if rank > 0 then
		amount = math.floor(amount * (1 + 0.1 * rank) + 0.5)
	end
	s.save.xp = (s.save.xp or 0) + amount
	while level(s) < Config.PLAYER.maxLevel and s.save.xp >= Config.xpToNext(level(s)) do
		s.save.xp -= Config.xpToNext(level(s))
		s.save.level = level(s) + 1
		leveled = true
	end
	if leveled then
		Session.recalcHp(s, true)
	end
	s.dirty = true
	return leveled
end

function Session.markBossDefeated(s: State, kind: string)
	s.save.defeatedBosses = s.save.defeatedBosses or {}
	s.save.defeatedBosses[kind] = true
	s.dirty = true
end

function Session.markBarrierBroken(s: State, barrierKey: string)
	s.save.barriersBroken = s.save.barriersBroken or {}
	s.save.barriersBroken[barrierKey] = true
	s.dirty = true
end

function Session.setCheckpoint(s: State, checkpointId: string, pos: Vector3)
	s.save.checkpointId = checkpointId
	s.save.checkpointX = pos.X
	s.save.checkpointY = pos.Y -- FIX: persist Y as well
	s.lastCheckpointId = checkpointId
	s.checkpointPos = pos
	s.dirty = true
end

function Session.flush(s: State)
	if not s.dirty then
		return
	end
	-- FIX: clear the flag BEFORE the (yielding) save so changes made while
	-- saving are not lost; restore it if the save fails.
	s.dirty = false
	s.save.deaths = s.deaths -- FIX: deaths were never written to the save
	local ok, result = pcall(SaveData.save, s.player.UserId, s.save)
	if not ok or result == false then
		warn("[Session] save failed for", s.player.Name, ok and "" or result)
		s.dirty = true
	end
end

function Session.flushAll()
	for _, s in pairs(sessions) do
		Session.flush(s)
	end
end

function Session.wipeAndReset(s: State)
	local player = s.player
	s.save = SaveData.wipe(player.UserId)
	local fresh = Session.fresh(player)
	-- keep same identity, but fresh() overwrote the sessions table entry; copy fields over
	for k, v in pairs(fresh) do
		(s :: any)[k] = v
	end
	sessions[player.UserId] = s
	s.dirty = true
	Session.flush(s)
end

function Session.syncPayload(s: State)
	return {
		hp = math.floor(s.hp),
		maxHp = Session.maxHp(s),
		ink = math.floor(s.ink),
		maxInk = Session.maxInk(s),
		xp = math.floor(s.save.xp or 0),
		xpNext = Config.xpToNext(level(s)),
		level = level(s),
		abilities = s.save.abilities or {},
		echoes = s.save.echoes or {},
		bossesDefeated = s.save.defeatedBosses or {},
		roles = s.save.roles or {},
		jobs = s.save.jobs or {},
		pages = s.save.foundPages or {},
		grandKey = s.save.grandKey or false,
		machineAwake = s.save.machineAwake or false,
		deaths = s.deaths or 0,
		checkpoint = s.lastCheckpointId,
	}
end

-- damage with Piyedro's Stone Skin applied
function Session.applyDamage(s: State, raw: number)
	if Session.hasEcho(s, "piyedroEcho") then
		raw *= 0.8
	end
	s.hp = math.max(0, s.hp - raw)
	s.dirty = true
end

return Session
