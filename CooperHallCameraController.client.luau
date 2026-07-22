--!strict
-- Camera confinement for the narrow Cooper-house hall. Bounds are derived
-- from the physical house every frame so moving the completed set cannot leave
-- stale world-coordinate attributes behind.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local NORMAL_MIN = 0.5
local NORMAL_MAX = 14
local HALL_MAX = 4.25
local HALL_MIN_ABOVE_FLOOR = 0.5
local HALL_MAX_ABOVE_FLOOR = 9.35
local BIND_NAME = "CooperHallCameraClamp"

local function restoreZoom()
	player.CameraMinZoomDistance = NORMAL_MIN
	player.CameraMaxZoomDistance = NORMAL_MAX
end

RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		restoreZoom()
		return
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local environment = workspace:FindFirstChild("CooperHouseEnvironment")
	local house = environment and environment:FindFirstChild("CooperHouse")
	local hall = house and house:FindFirstChild("CrossHallFloor", true)
	if not rootPart or not rootPart:IsA("BasePart") or not house or not house:IsA("Model")
		or not hall or not hall:IsA("BasePart")
	then
		restoreZoom()
		return
	end

	local hallMinZ = hall.Position.Z - hall.Size.Z * 0.5
	local hallMaxZ = hall.Position.Z + hall.Size.Z * 0.5
	local hallFloorTop = hall.CFrame:PointToWorldSpace(
		Vector3.new(0, hall.Size.Y * 0.5, 0)
	).Y
	local houseCF, houseSize = house:GetBoundingBox()
	local houseMinX = houseCF.Position.X - houseSize.X * 0.5
	local houseMaxX = houseCF.Position.X + houseSize.X * 0.5
	local position = rootPart.Position
	local inHall = position.X > houseMinX and position.X < houseMaxX
		and position.Z > hallMinZ and position.Z < hallMaxZ
	if not inHall then
		restoreZoom()
		return
	end

	player.CameraMinZoomDistance = NORMAL_MIN
	player.CameraMaxZoomDistance = HALL_MAX
	local cameraPosition = camera.CFrame.Position
	local clampedPosition = Vector3.new(
		math.clamp(cameraPosition.X, houseMinX + 0.5, houseMaxX - 0.5),
		math.clamp(
			cameraPosition.Y,
			hallFloorTop + HALL_MIN_ABOVE_FLOOR,
			hallFloorTop + HALL_MAX_ABOVE_FLOOR
		),
		math.clamp(cameraPosition.Z, hallMinZ + 0.35, hallMaxZ - 0.35)
	)
	if (clampedPosition - cameraPosition).Magnitude > 0.01 then
		camera.CFrame = CFrame.new(clampedPosition) * camera.CFrame.Rotation
	end
end)

script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep(BIND_NAME)
	restoreZoom()
end)
