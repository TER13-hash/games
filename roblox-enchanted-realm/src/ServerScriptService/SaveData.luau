--!strict
-- Save/load via DataStore with a graceful in-memory fallback (offline / Studio without API access).
local DataStoreService = game:GetService("DataStoreService")

local SaveData = {}
SaveData.__index = SaveData

local STORE_NAME = "EnchantedRealm_Inkbound_v1"
local store: DataStore? = nil
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

local memoryFallback: { [number]: any } = {}

function SaveData.defaultSave()
	return {
		v = 1,
		checkpointId = "cp_start",
		checkpointX = 30,
		xp = 0,
		level = 1,
		maxHpBonus = 0, -- hearts
		defeatedBosses = {}, -- [bossKind] = true
		abilities = {}, -- [abilityId] = true
		echoes = {}, -- [echoId] = true
		barriersBroken = {}, -- [barrierKey] = true
		grandKey = false,
		portalUnlocked = false,
		machineAwake = false,
		playtimeSeconds = 0,
	}
end

function SaveData.load(userId: number)
	local data: any = nil
	if storeOk and store then
		local ok, result = pcall(store.GetAsync, store, tostring(userId))
		if ok then
			data = result
		else
			warn("[Inkbound] DataStore read failed (using session copy):", result)
		end
	else
		data = memoryFallback[userId]
	end
	if type(data) ~= "table" then
		data = SaveData.defaultSave()
	end
	-- normalize missing keys
	local def = SaveData.defaultSave()
	for k, v in pairs(def) do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data
end

function SaveData.save(userId: number, data: any)
	if storeOk and store then
		local ok, err = pcall(store.SetAsync, store, tostring(userId), data)
		if not ok then
			warn("[Inkbound] DataStore write failed (progress kept in memory):", err)
			memoryFallback[userId] = data
		end
	else
		memoryFallback[userId] = data
	end
end

function SaveData.wipe(userId: number)
	memoryFallback[userId] = nil
	if storeOk and store then
		local ok, err = pcall(store.RemoveAsync, store, tostring(userId))
		if not ok then
			warn("[Inkbound] DataStore wipe failed:", err)
		end
	end
	return SaveData.defaultSave()
end

return SaveData
