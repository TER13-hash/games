--!strict
-- Ink River ferry: shuttles between the two forest docks forever.
-- The water is lethal, so players must sit on a ferry seat to cross.
-- The ferry is anchored and moved with PivotTo; seated characters are
-- welded to the seats and get carried across automatically.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local marker = Workspace:WaitForChild("EnchantedRealm", 30)
local ferry: Model? = nil
if marker then
	local riverFolder = marker:FindFirstChild("River")
	if riverFolder then
		local f = riverFolder:FindFirstChild("RiverFerry")
		if f and f:IsA("Model") then
			ferry = f
		end
	end
end

if not ferry then
	warn("[Inkbound] RiverFerry model not found — ferry crossing disabled")
	return
end

local dockA = (ferry:GetAttribute("DockA") or 211) :: number
local dockB = (ferry:GetAttribute("DockB") or 245) :: number
local speed = (ferry:GetAttribute("Speed") or 11) :: number
local pause = (ferry:GetAttribute("Pause") or 4) :: number

local targetX = dockB
local pausedUntil = 0

local conn = RunService.Heartbeat:Connect(function(dt)
	if not ferry or not ferry.Parent then
		conn:Disconnect()
		return
	end
	if tick() < pausedUntil then
		return
	end
	local pivot = ferry:GetPivot()
	local x = pivot.Position.X
	local remaining = targetX - x
	local step = speed * dt
	if math.abs(remaining) <= step then
		ferry:PivotTo(CFrame.new(targetX, pivot.Position.Y, pivot.Position.Z))
		pausedUntil = tick() + pause
		targetX = if targetX == dockA then dockB else dockA
	else
		ferry:PivotTo(CFrame.new(x + math.sign(remaining) * step, pivot.Position.Y, pivot.Position.Z))
	end
end)

print(("[Inkbound] River ferry running between x=%d and x=%d"):format(dockA, dockB))