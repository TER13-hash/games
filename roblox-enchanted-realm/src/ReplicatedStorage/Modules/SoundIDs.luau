--!strict
-- Enchanted Realm — Sound & music registry.
--
-- How audio resolves at runtime (see Main.server.luau `Audio.resolve`):
--   1. If you place a Sound object inside ReplicatedStorage > EnchantedRealmAudio
--      whose Name matches the KEY below (e.g. "SwordSlash"), YOUR asset is used.
--   2. Otherwise the built-in rbxassetid below is used (free community audio).
--   3. If neither loads, the key is skipped with a one-time Studio warning —
--      the game is fully playable silently; nothing breaks.
--
-- To swap any sound: upload your own audio to Roblox and either replace the ID
-- here, or drop a Sound named e.g. "SwordSlash" into the EnchantedRealmAudio
-- folder. No code changes required.

local SoundIDs = {}

SoundIDs.sfx = {
	UiClick        = "rbxassetid://9069516330",   -- soft interface click
	UiHover        = "rbxassetid://9069516330",   -- reused, quieter via Volume
	SwordSlash     = "rbxassetid://9067237166",   -- whoosh slash
	SwordHit       = "rbxassetid://140462043853173", -- melee impact
	PlayerHurt     = "rbxassetid://9073360066",
	EnemyDie       = "rbxassetid://5111678752",
	Jump           = "rbxassetid://9073381561",
	DoubleJump     = "rbxassetid://9067237166",
	Land           = "rbxassetid://9073360066",
	Checkpoint     = "rbxassetid://8940802458",   -- chime / activate
	LevelUp        = "rbxassetid://8940802458",
	HeartPickup    = "rbxassetid://8940802458",
	AbilityUnlock  = "rbxassetid://8946799922",   -- fanfare
	BarrierBreak   = "rbxassetid://5111678752",
	RockShatter    = "rbxassetid://5111678752",
	FireCast       = "rbxassetid://5111678752",
	IceCast        = "rbxassetid://9073360066",
	LightningCast  = "rbxassetid://5111678752",
	WindCast       = "rbxassetid://9067237166",
	MachineWake    = "rbxassetid://5111678752",
	BossRoar       = "rbxassetid://5111678752",
	BossHit        = "rbxassetid://140462043853173",
	BossDefeat     = "rbxassetid://8946799922",
	PortalHum      = "rbxassetid://8940802458",
	KeyClaimed     = "rbxassetid://8946799922",
	Victory        = "rbxassetid://8946799922",
	GameOver       = "rbxassetid://9073360066",
	Heal           = "rbxassetid://8940802458",
	PotionBreak    = "rbxassetid://5111678752",
	ThunderStrike  = "rbxassetid://5111678752",
	SquidSlam      = "rbxassetid://5111678752",
	WaterFreeze    = "rbxassetid://9073360066",
	VineBurn       = "rbxassetid://5111678752",
	MachineDenied  = "rbxassetid://9073360066",
}

SoundIDs.music = {
	Explore   = "rbxassetid://84386740040301",  -- calm exploration theme
	Boss      = "rbxassetid://1837324500",       -- tense driving theme
	FinalBoss = "rbxassetid://4556134799",       -- heavy, ominous theme
	Victory   = "rbxassetid://8946799922",       -- bright resolution
	Menu      = "rbxassetid://84386740040301",
}

-- Module will not error on unknown keys
function SoundIDs.find(kind: string, key: string): string?
	local t = (kind == "music" and SoundIDs.music) or SoundIDs.sfx
	local id = t[key]
	return if typeof(id) == "string" then id else nil
end

return SoundIDs
