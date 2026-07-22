-- Licensed Young Sheldon cast-photo gallery for the Cooper house.
-- Run in Roblox Studio edit context after the decal assets have been uploaded.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Workspace = game:GetService("Workspace")

local ASSET_IDS = {
	IainArmitage = 0,
	LanceBarber = 0,
	RaeganRevord = 0,
	MontanaJordan = 0,
	ZoePerry = 0,
	AnniePotts = 0,
}

for subject, assetId in pairs(ASSET_IDS) do
	assert(assetId > 0, string.format("Photo asset ID is still pending for %s", subject))
end

local PHOTO_DATA = {
	IainArmitage = {
		assetId = ASSET_IDS.IainArmitage,
		caption = "the eye contact will continue until IQ improves",
		author = "White Pony Express",
		license = "CC BY 3.0",
		source = "https://commons.wikimedia.org/wiki/File:Iain_Armitage_(2019).png",
	},
	LanceBarber = {
		assetId = ASSET_IDS.LanceBarber,
		caption = "he knows you skipped the beer run",
		author = "SpiritedMichelle",
		license = "CC BY-SA 4.0",
		source = "https://commons.wikimedia.org/wiki/File:Lance_Barber_at_Fan_Expo_Denver_2026.jpg",
	},
	RaeganRevord = {
		assetId = ASSET_IDS.RaeganRevord,
		caption = "missy heard that",
		author = "Kevin Paul (PaulLim11)",
		license = "CC BY 4.0",
		source = "https://commons.wikimedia.org/wiki/File:Raegan_Revord_-_LATFOB_2026-01.jpg",
	},
	MontanaJordan = {
		assetId = ASSET_IDS.MontanaJordan,
		caption = "certified tire businessman",
		author = "Kevin Paul (PaulLim11)",
		license = "CC BY 4.0",
		source = "https://commons.wikimedia.org/wiki/File:Montana_Jordan_-_Los_Angeles_Comic_Con_2025.jpg",
	},
	ZoePerry = {
		assetId = ASSET_IDS.ZoePerry,
		caption = "mary can hear this picture frame",
		author = "SpiritedMichelle",
		license = "CC BY-SA 4.0",
		source = "https://commons.wikimedia.org/wiki/File:Zoe_Perry_at_Fan_Expo_Denver_2026.jpg",
	},
	AnniePotts = {
		assetId = ASSET_IDS.AnniePotts,
		caption = "meemaw already knows",
		author = "Louise Palanker",
		license = "CC BY-SA 2.0",
		source = "https://commons.wikimedia.org/wiki/File:Annie_Potts_(53705697262).jpg",
	},
}

local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
assert(environment, "CooperHouseEnvironment was not found")
local house = environment:FindFirstChild("CooperHouse")
assert(house, "CooperHouse was not found")
local props = house:FindFirstChild("FurnitureAndProps")
assert(props, "FurnitureAndProps was not found")
local detail = props:FindFirstChild("YoungSheldonBedroomDetails_V2")
assert(detail, "YoungSheldonBedroomDetails_V2 was not found")

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(
		"LicensedCastPhotoGallery",
		"Replace text signs with licensed cast photos"
	)
end)

local function clearSurfaceGuis(part)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end
end

local function applyPhoto(part, face, data)
	clearSurfaceGuis(part)
	part:SetAttribute("PhotoAssetId", data.assetId)
	part:SetAttribute("PhotoAuthor", data.author)
	part:SetAttribute("PhotoLicense", data.license)
	part:SetAttribute("PhotoSourceURL", data.source)
	part:SetAttribute("PhotoChanges", "Cropped by Roblox UI; parody caption added separately")

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LicensedCastPhoto"
	surface.Face = face
	surface.CanvasSize = Vector2.new(700, 520)
	surface.LightInfluence = 0.18
	surface.Brightness = 1.1
	surface.Parent = part

	local matte = Instance.new("Frame")
	matte.Name = "WarmPhotoMatte"
	matte.Size = UDim2.fromScale(1, 1)
	matte.BackgroundColor3 = Color3.fromRGB(224, 207, 170)
	matte.BorderSizePixel = 0
	matte.Parent = surface

	local photo = Instance.new("ImageLabel")
	photo.Name = "CastPhoto"
	photo.Position = UDim2.fromScale(0.035, 0.035)
	photo.Size = UDim2.fromScale(0.93, 0.74)
	photo.BackgroundColor3 = Color3.fromRGB(47, 39, 31)
	photo.BorderSizePixel = 0
	photo.Image = "rbxassetid://" .. tostring(data.assetId)
	photo.ImageColor3 = Color3.fromRGB(255, 244, 222)
	photo.ScaleType = Enum.ScaleType.Crop
	photo.Parent = matte

	local caption = Instance.new("TextLabel")
	caption.Name = "PolaroidCaption"
	caption.Position = UDim2.fromScale(0.055, 0.79)
	caption.Size = UDim2.fromScale(0.89, 0.15)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.SpecialElite
	caption.Text = data.caption
	caption.TextColor3 = Color3.fromRGB(66, 48, 36)
	caption.TextScaled = true
	caption.TextWrapped = true
	caption.Parent = matte

	local scanlines = Instance.new("Frame")
	scanlines.Name = "FaintVintageScanlines"
	scanlines.Position = photo.Position
	scanlines.Size = photo.Size
	scanlines.BackgroundTransparency = 1
	scanlines.ZIndex = 3
	scanlines.Parent = matte
	for index = 0, 13 do
		local line = Instance.new("Frame")
		line.Name = "Scanline"
		line.Position = UDim2.fromScale(0, index / 14)
		line.Size = UDim2.fromScale(1, 0.006)
		line.BackgroundColor3 = Color3.fromRGB(63, 45, 32)
		line.BackgroundTransparency = 0.86
		line.BorderSizePixel = 0
		line.ZIndex = 3
		line.Parent = scanlines
	end
end

local hallGallery = detail:FindFirstChild("CooperHallGallery")
assert(hallGallery, "CooperHallGallery was not found")
local hallAssignments = {
	HallFrame1 = PHOTO_DATA.LanceBarber,
	HallFrame2 = PHOTO_DATA.AnniePotts,
	HallFrame3 = PHOTO_DATA.IainArmitage,
	HallFrame4 = PHOTO_DATA.RaeganRevord,
	HallFrame5 = PHOTO_DATA.MontanaJordan,
}
for frameName, data in pairs(hallAssignments) do
	local frame = hallGallery:FindFirstChild(frameName)
	assert(frame and frame:IsA("BasePart"), frameName .. " was not found")
	applyPhoto(frame, Enum.NormalId.Front, data)
end

local parents = detail:FindFirstChild("ParentsRoomStoryProps")
local weddingFrame = parents and parents:FindFirstChild("CooperWeddingPhoto")
assert(weddingFrame and weddingFrame:IsA("BasePart"), "CooperWeddingPhoto was not found")
applyPhoto(weddingFrame, Enum.NormalId.Right, PHOTO_DATA.ZoePerry)

local credits = detail:FindFirstChild("LicensedPhotoCredits")
if credits then
	credits:Destroy()
end
credits = Instance.new("Folder")
credits.Name = "LicensedPhotoCredits"
credits:SetAttribute("Disclaimer", "Unofficial parody; not endorsed by the actors, CBS, or other rights holders")
credits:SetAttribute("Changes", "Roblox UI crops the originals and adds separate parody captions")
credits.Parent = detail
for subject, data in pairs(PHOTO_DATA) do
	local credit = Instance.new("StringValue")
	credit.Name = subject
	credit.Value = string.format("%s | %s | %s", data.author, data.license, data.source)
	credit:SetAttribute("AssetId", data.assetId)
	credit.Parent = credits
end

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
else
	pcall(function()
		ChangeHistoryService:SetWaypoint("Licensed cast-photo gallery")
	end)
end

print("Licensed cast-photo gallery installed", #credits:GetChildren())
return #credits:GetChildren()
