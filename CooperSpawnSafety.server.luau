--!strict
-- Deterministic startup guard for the movable Cooper house environment.
--
-- The authored SpawnLocation is parented under SiteAndStreet so moving the
-- complete environment also moves the spawn. This short-lived guard covers the
-- remaining engine/startup race: if a fresh character appears on the baseplate
-- far below the elevated home, return it to the real spawn. Legitimate physical
-- access to the backyard bunker is explicitly excluded.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local environment = Workspace:WaitForChild("CooperHouseEnvironment")
local site = environment:WaitForChild("SiteAndStreet")
local lot = site:WaitForChild("CooperLot")
local spawnLocation = site:WaitForChild("SpawnLocation")

assert(environment:IsA("Model"), "CooperHouseEnvironment must be a Model")
assert(site:IsA("Model"), "SiteAndStreet must be a Model")
assert(lot:IsA("BasePart"), "CooperLot must be a BasePart")
assert(spawnLocation:IsA("SpawnLocation"), "SiteAndStreet.SpawnLocation must be a SpawnLocation")
assert(spawnLocation.Enabled, "Cooper SpawnLocation must be enabled")

local bunker = environment:FindFirstChild("BackyardBunker")
local underground = bunker and bunker:FindFirstChild("Underground")
local surface = bunker and bunker:FindFirstChild("SurfaceEntrance")
local shaftOpening = surface and surface:FindFirstChild("ShaftOpening")

local function insideBounds(cframe: CFrame, size: Vector3, point: Vector3, margin: number): boolean
	local localPoint = cframe:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= size.X * 0.5 + margin
		and math.abs(localPoint.Y) <= size.Y * 0.5 + margin
		and math.abs(localPoint.Z) <= size.Z * 0.5 + margin
end

local function insideLegitimateBunkerSpace(player: Player, point: Vector3): boolean
	if not bunker
		or bunker:GetAttribute("UnlockState") ~= "Unlocked"
		or player:GetAttribute("CooperSecretBunkerUnlocked") ~= true
	then
		return false
	end
	if underground and underground:IsA("Model") then
		local undergroundCFrame, undergroundSize = underground:GetBoundingBox()
		if insideBounds(undergroundCFrame, undergroundSize, point, 2.5) then
			return true
		end
	end

	if shaftOpening and shaftOpening:IsA("BasePart") then
		local localPoint = shaftOpening.CFrame:PointToObjectSpace(point)
		local lotSurfaceY = lot.CFrame:PointToWorldSpace(
			Vector3.new(0, lot.Size.Y * 0.5, 0)
		).Y
		local minimumShaftY = if underground and underground:IsA("Model")
			then underground:GetBoundingBox().Position.Y - 10
			else lotSurfaceY - 45
		return math.abs(localPoint.X) <= shaftOpening.Size.X * 0.5 + 1.5
			and math.abs(localPoint.Z) <= shaftOpening.Size.Z * 0.5 + 1.5
			and point.Y >= minimumShaftY
			and point.Y <= lotSurfaceY + 7
	end

	return false
end

local function recoverFreshCharacter(character: Model, root: BasePart)
	character:PivotTo(spawnLocation.CFrame * CFrame.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function watchFreshCharacter(player: Player, character: Model)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
			return
		end

		-- Watch only the startup window. Normal gameplay and physical bunker
		-- traversal remain untouched after the character has settled.
		for _ = 1, 20 do
			if character.Parent == nil or humanoid.Health <= 0 then
				return
			end
			local lotSurfaceY = lot.CFrame:PointToWorldSpace(
				Vector3.new(0, lot.Size.Y * 0.5, 0)
			).Y
			if root.Position.Y < lotSurfaceY - 8
				and not insideLegitimateBunkerSpace(player, root.Position)
			then
				recoverFreshCharacter(character, root)
				return
			end
			task.wait(0.25)
		end
	end)
end

local function attachPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchFreshCharacter(player, character)
	end)
	if player.Character then
		watchFreshCharacter(player, player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	attachPlayer(player)
end
Players.PlayerAdded:Connect(attachPlayer)

print("[CooperSpawnSafety] Movable spawn and startup under-map guard ready")
