local Humanoid = game.Players.LocalPlayer.Character:WaitForChild("Humanoid")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local CS = game:GetService("CollectionService")

local CurrentTraverse = 0
local CurrentElevation = 0
local StabilizedTraverse = 0
local StabilizedElevation = 0
local RecoilRotation = 0
local Stabilized = 0
local MG_Sound = 1
local Zoom = 1
local Thermal = 1
local HatchView = false
local Loop = nil
local MGLoop = nil
local MGFiring = false
local TankGui = nil
local GrainEffect = false
local ZoomCooldown = false
local Firing = false
local TurretStop = false
local TurretStart = false
local Reloading = false
local timeAcculumator = 0

local HatchZoom = 70
local DriverCam = 1

local _Stats = nil
local SystemModule = require(game.ReplicatedStorage.TankSystem.Modules.Client.SystemModule)
local GlobalConfig = require(game:WaitForChild("ReplicatedStorage"):WaitForChild("TankSystem"):WaitForChild("Settings"):WaitForChild("GlobalConfig"))
local APS_Module = require(game.ReplicatedStorage:WaitForChild("TankSystem").Modules.Client.APSModule)
local Hitboxes = GlobalConfig.Hitboxes
local Ammos = GlobalConfig.Ammos
local FastCast = require(game.ReplicatedStorage.TankSystem.Modules.Misc.Cast)
local Cast = FastCast.new()

local CameraShaker = require(game.ReplicatedStorage.TankSystem.Modules.Client.CameraShaker)
local CameraShake = nil
local OriginalCFrame = nil
local CameraPart = nil
local SelectedAmmo = nil
local HatchModel = nil

local EngineCooldown = false

local APS_RANGE = 5 -- radius of detection
local APS_COOLDOWN = 0.5
local lastIntercept = {}



-----------------------------
REPLICATION HANDLER 
-----------------------------
game.ReplicatedStorage.TankSystem.Events.Replicate.OnClientEvent:Connect(function(Player, Event, Var1, Var2, Var3, Var4, Var5)
	if Player.Name ~= game.Players.LocalPlayer.Name then
		if Event == "TankReplicate" then
			TS:Create(Var1.Traverse, TweenInfo.new(Var2), {C1 = CFrame.Angles(0, math.rad(Var4),0)}):Play()
			TS:Create(Var1.Elevate, TweenInfo.new(Var3), {C1 = CFrame.Angles(math.rad(Var5), 0,0)}):Play()
		elseif Event == "FireReplicate" then
			SystemModule.Fire(Ammos[Var2], TankGui, Var1.Parent.Parent.Turret.FirePart, Cast, true)
		elseif Event == "MGReplicate" then
			SystemModule.Fire(Ammos[Var1], TankGui, Var4.Parent.Parent.Turret.MGFirePart, Cast, true, Var3, true)
		end
	end

	if Player == "TrackRepair" then
		warn("tracks repaired")
		local TracksFolder = Event

		for _, v in pairs(TracksFolder:GetDescendants()) do
			if v:IsA("BasePart") and v.Parent.Name == "TrackLinks" then
				v.Transparency = 0
			end
		end

	end

	if Player == "TrackDisable" then
		local TracksFolder = Event
		local HitTrack = Var1

		if HitTrack then --------------- Track disable on the tank, handles everything to be replicated
			local hitNumber = tonumber(HitTrack:match("%d+"))
			if hitNumber then
				-- find current destroyed min/max
				local minDestroyed = hitNumber
				local maxDestroyed = hitNumber

				for _, v in pairs(TracksFolder:GetDescendants()) do
					if v:IsA("BasePart") and v.Parent.Name == "TrackLinks" and v.Transparency == 1 then
						local num = tonumber(v.Name:match("%d+"))
						if num then
							if num < minDestroyed then minDestroyed = num end
							if num > maxDestroyed then maxDestroyed = num end
						end
					end
				end

				if hitNumber < minDestroyed then minDestroyed = hitNumber end
				if hitNumber > maxDestroyed then maxDestroyed = hitNumber end

				local MAX_GAP = 20 
				local gap = maxDestroyed - minDestroyed
				if gap > MAX_GAP then
					-- shrink range so it's not absurdly big
					if hitNumber == maxDestroyed then
						-- shooting further (higher number)
						minDestroyed = maxDestroyed - MAX_GAP
					else
						-- shooting lower (smaller number)
						maxDestroyed = minDestroyed + MAX_GAP
					end
				end

				-- hide all tracks between min and max
				for _, v in pairs(TracksFolder:GetDescendants()) do
					if v:IsA("BasePart") and v.Parent.Name == "TrackLinks" then
						local num = tonumber(v.Name:match("%d+"))
						if num and num >= minDestroyed and num <= maxDestroyed then
							v.Transparency = 1
							v.CanCollide = false
						end
					end
				end
			end
		end
	end

end)
-----------------------------
TANK SETUP WHEN SEATED
-----------------------------

Humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
	local SeatPart = Humanoid.SeatPart

	if  SeatPart ~= nil and SeatPart.Name == "DriverSeat" then
		warn("drive")

		CAS:BindAction("Thermal", FunctionsHandler, false, Enum.KeyCode.T)
		CAS:BindAction("Lights", FunctionsHandler, false, Enum.KeyCode.Q)
		CAS:BindAction("EngineTurn", FunctionsHandler, false, Enum.KeyCode.X)
		CAS:BindAction("FoF", FunctionsHandler, false, Enum.KeyCode.F)

		game.Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
		UIS.MouseIconEnabled = false	


		TankGui = game.Players.LocalPlayer.PlayerGui.TankUI.Hatch
		_Stats = require(SeatPart.Parent.TurretSeat.Config)

		HatchView = true
		game.Players.LocalPlayer.PlayerGui.TankUI.Hatch.Visible = true

		CameraPart = SeatPart.Parent.Turret.EWeld.NLEChoppa.NLEChoppa

		Loop = RS.RenderStepped:Connect(function(Delta)
			Looping(SeatPart, Delta)
		end)
	end

	if  SeatPart ~= nil and SeatPart.Name == "TurretSeat" then
		game.Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
		game.Players.LocalPlayer.PlayerGui.TankUI.Merkava.Visible = true
		UIS.MouseIconEnabled = false

		CAS:BindAction("Zoom", FunctionsHandler, false, Enum.KeyCode.C)
		CAS:BindAction("RangeAdjust", FunctionsHandler, false, Enum.KeyCode.Q)
		CAS:BindAction("FoF", FunctionsHandler, false, Enum.KeyCode.F)
		CAS:BindAction("Thermal", FunctionsHandler, false, Enum.KeyCode.T)
		CAS:BindAction("Fire", FunctionsHandler, false, Enum.UserInputType.MouseButton1)
		CAS:BindAction("MGFire", FunctionsHandler, false, Enum.UserInputType.MouseButton2)
		CAS:BindAction("Reload", FunctionsHandler, false, Enum.KeyCode.R)
		CAS:BindAction("Smoke", FunctionsHandler, false, Enum.KeyCode.G)

		game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("Team_Set", Humanoid.SeatPart.Parent)
		game.Workspace.CurrentCamera.CameraType = "Attach"

		CurrentElevation = SeatPart:GetAttribute("Elevation")
		CurrentTraverse = SeatPart:GetAttribute("Traverse")

		StabilizedElevation = SeatPart:GetAttribute("Elevation")
		StabilizedTraverse = SeatPart:GetAttribute("Traverse")

		_Stats = require(SeatPart.Config)

		if _Stats.Shell1 ~= "" then
			CAS:BindAction("WeaponSwitch1", FunctionsHandler, false, Enum.KeyCode.One)
		end
		if _Stats.Shell2 ~= "" then
			CAS:BindAction("WeaponSwitch2", FunctionsHandler, false, Enum.KeyCode.Two)
		end
		if _Stats.Shell3 ~= "" then
			CAS:BindAction("WeaponSwitch3", FunctionsHandler, false, Enum.KeyCode.Three)
		end


		TankGui = game.Players.LocalPlayer.PlayerGui.TankUI[_Stats.TankGui]

		CameraPart = SeatPart.Parent.Turret.EWeld.NLEChoppa.NLEChoppa
		SelectedAmmo = _Stats.Shell1
		Humanoid.SeatPart.Stats.Shell.Value = SelectedAmmo

		spawn(function()
			while task.wait(_Stats.MGFirerate) do	
				if SeatPart == nil then
					break
				elseif MGFiring == true and Humanoid.SeatPart.Stats.MG_Ammo.Value > 0 then

					local SpreadY = math.rad(math.random(-30, 30)*0.1*Ammos[_Stats.MG_Type].SpreadMultiplier)
					local SpreadX = math.rad(math.random(-30, 30)*0.1*Ammos[_Stats.MG_Type].SpreadMultiplier)
					local Spread = CFrame.Angles(SpreadX, SpreadY, 0)	

					game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("MG_Fire", _Stats.MG_Type, _Stats, Spread, Humanoid.SeatPart.Stats)
					SystemModule.Fire(Ammos[_Stats.MG_Type], TankGui, Humanoid.SeatPart.Parent.Turret.MGFirePart, Cast, true, Spread, false)
				end
			end
		end)

		------------------------------------------------
		OriginalCFrame = CameraPart.CFrame
		CameraShake = CameraShaker.new(Enum.RenderPriority.Last.Value, function(shakeCf)
			CameraPart.CFrame = CameraPart.CFrame * shakeCf
			task.wait(0.2)
			CameraPart.CFrame = OriginalCFrame
		end)
		CameraShake:Start()
		------------------------------------------------

		Loop = RS.RenderStepped:Connect(function(Delta)
			Looping(SeatPart, Delta)
		end)
	elseif SeatPart == nil then

		if Loop ~= nil then
			Loop:Disconnect()
			Loop = nil
		end

		CAS:UnbindAction("Fire")
		CAS:UnbindAction("MGFire")
		CAS:UnbindAction("Reload")
		CAS:UnbindAction("Zoom")
		CAS:UnbindAction("Thermal")
		CAS:UnbindAction("WeaponSwitch1")
		CAS:UnbindAction("WeaponSwitch2")
		CAS:UnbindAction("WeaponSwitch3")

		game.Players.LocalPlayer.CameraMode = Enum.CameraMode.Classic
		game.Players.LocalPlayer.PlayerGui.TankUI.Merkava.Visible = false
		game.Workspace.CurrentCamera.FieldOfView = 70
		game.Workspace.CurrentCamera.CameraType = "Custom"
		UIS.MouseDeltaSensitivity = 1
		UIS.MouseIconEnabled = true

		HatchView = false
		game.Players.LocalPlayer.PlayerGui.TankUI.Hatch.Visible = false

		if CameraShake then
			CameraShake:Stop()
		end



	end
end)

function Looping(SeatPart, Delta)
	if HatchView then

		if Humanoid.SeatPart.Parent.Engine.Status.Value == true then
			game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("TankEngine", true, SeatPart)
		else
			game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("TankEngine", false, SeatPart)
		end

		game.Workspace.CurrentCamera.CFrame = SeatPart.Parent["Hatch"..DriverCam].EWeld.NLEChoppa.WorldCFrame
	else
		game.Workspace.CurrentCamera.CFrame = SeatPart.Parent.Turret.EWeld.NLEChoppa.NLEChoppa.WorldCFrame
	end


	APS_Module.APS(SeatPart, 40, 2, 0.005, Delta)


	if not HatchView then
		CurrentTraverse,TurretStart,TurretStop = SystemModule.GetDelta(3, Delta, "X", CurrentTraverse, UIS, _Stats, "Traverse", Humanoid.SeatPart.Parent.Turret.EWeld, TurretStart, TurretStop)
		CurrentElevation = SystemModule.GetDelta(3, Delta, "Y", CurrentElevation, UIS, _Stats, "Elevation")
	else
		CurrentTraverse,TurretStart,TurretStop = SystemModule.GetDelta(13, Delta, "X", CurrentTraverse, UIS, _Stats, "Traverse", Humanoid.SeatPart.Parent.Turret.EWeld, TurretStart, TurretStop)
		CurrentElevation = SystemModule.GetDelta(13, Delta, "Y", CurrentElevation, UIS, _Stats, "Elevation")
	end

	local RX, RY, RZ =  SeatPart.Parent.Turret.EBase.CFrame:ToOrientation()
	local TRX, TRY, TRZ =  SeatPart.Parent.Turret.TBase.CFrame:ToOrientation()


	StabilizedElevation = CurrentElevation
	StabilizedElevation = math.clamp(StabilizedElevation, _Stats.MaxElevation[1], _Stats.MaxElevation[2])

	StabilizedTraverse = CurrentTraverse

	if _Stats.MaxTraverse[1] ~= 0 and _Stats.MaxTraverse[2] ~= 0 then
		StabilizedTraverse = math.clamp(StabilizedTraverse, _Stats.MaxTraverse[1], _Stats.MaxTraverse[2])
	end

	SeatPart:SetAttribute("Elevation", StabilizedElevation)
	SeatPart:SetAttribute("Traverse", StabilizedTraverse)

	SystemModule.RangeFind(SeatPart.Parent.Turret.EWeld.NLEChoppa.WorldCFrame, SeatPart.Parent.Parent, _Stats)


	if not HatchView then
		TankGui.Ammo.Text = Humanoid.SeatPart.Stats.Shell.Value.." "..Humanoid.SeatPart.Parent.Ammos[SelectedAmmo].Value
		TankGui.AmmoMG.Text = "M240 COAX "..Humanoid.SeatPart.Stats.MG_Ammo.Value

		TankGui.GrainLine.TileSize = UDim2.new(math.random(1500, 2500) / 1000, 0, math.random(1500, 2500) / 1000, 0)
		TankGui.Grain2.TileSize = UDim2.new(math.random(1500, 2500) / 1000, 0, math.random(1500, 2500) / 1000, 0)
	end

	if GrainEffect == false and not HatchView then
		local Modifier = (math.random(400, 600))/1000

		if Firing == true then
			Modifier = (math.random(4500, 8000))/1000
		end

		TankGui.Grain.TileSize = UDim2.new(Modifier, 0, Modifier, 0)
	end


	if HatchView then

		game.Workspace.CurrentCamera.FieldOfView = HatchZoom

		TankGui.Speed.Text = tostring(math.floor(game.Players.LocalPlayer.Character.Humanoid.SeatPart.Velocity.Magnitude))


		TankGui.GrainLine.TileSize = UDim2.new(math.random(1500, 2500) / 1000, 0, math.random(1500, 2500) / 1000, 0)
		TankGui.Grain.TileSize = UDim2.new(math.random(1500, 2500) / 1000, 0, math.random(1500, 2500) / 1000, 0)

		CurrentTraverse = math.clamp(CurrentTraverse, -45, 45)
		CurrentElevation = math.clamp(CurrentElevation, -15, 75)

		SeatPart.Parent["Hatch"..DriverCam].Traverse.C1 = SeatPart.Parent["Hatch"..DriverCam].Traverse.C1:Lerp(CFrame.Angles(0, math.rad(CurrentTraverse), 0), Delta*10)
		SeatPart.Parent["Hatch"..DriverCam].Elevate.C1 = SeatPart.Parent["Hatch"..DriverCam].Elevate.C1:Lerp(CFrame.Angles(math.rad(CurrentElevation), 0, 0), Delta*10)
	else
		SeatPart.Parent.Turret.Elevate.C1 = SeatPart.Parent.Turret.Elevate.C1:Lerp(CFrame.Angles(math.rad(StabilizedElevation), 0, 0), Delta*10)
		SeatPart.Parent.Turret.Traverse.C1 = SeatPart.Parent.Turret.Traverse.C1:Lerp(CFrame.Angles(0, math.rad(StabilizedTraverse),0), Delta*10)
		game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("TurretReplicate", SeatPart.Parent.Turret,_Stats.TLTime[1], _Stats.TLTime[2], CurrentTraverse, CurrentElevation)
	end
end

function FunctionsHandler(Name, Input, Object)

	if Name == "EngineTurn" and Input == Enum.UserInputState.End and EngineCooldown == false then
		EngineCooldown = true
		game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("EngineTurn", Humanoid.SeatPart.Parent.Engine)
		task.wait(5)
		EngineCooldown = false
	end

	if Name == "Lights" and Input == Enum.UserInputState.End then
		game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("Lights", Humanoid.SeatPart.Parent.Lights)
		Humanoid.SeatPart.LightSwitch:Play()
	end

	if Name == "Smoke" and Input == Enum.UserInputState.End then
		warn("smoke")
		game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("SmokeFire", Humanoid.SeatPart.Parent.Turret.TWeld.SmokeFire.WorldCFrame)
	end

	if Name == "RangeAdjust" and Input == Enum.UserInputState.End then
		local Range = SystemModule.RangeFind(Humanoid.SeatPart.Parent.Turret.EWeld.NLEChoppa.WorldCFrame, Humanoid.SeatPart.Parent.Parent, _Stats)
		CurrentElevation = math.rad(-(Range/886))
	end

	if Name == "FoF" and Input == Enum.UserInputState.End then
		SystemModule.FoF(Humanoid.SeatPart.Parent, game.Players.LocalPlayer)
	end	

	if Name == "Zoom" and ZoomCooldown == false and Input == Enum.UserInputState.Begin then
		ZoomCooldown = true
		GrainEffect = true
		Zoom = SystemModule.Zoom(Zoom, _Stats, TankGui, UIS)
		GrainEffect = SystemModule.GrainEffect(GrainEffect, TankGui)
		ZoomCooldown = false
	end

	if Name == "DriverCamera" and Input == Enum.UserInputState.End then
		if DriverCam == 1 then
			DriverCam = 2
		else
			DriverCam = 1
		end

		TankGui.CameraClick:Play()

		GrainEffect = true
		GrainEffect = SystemModule.GrainEffect(GrainEffect, TankGui)
	end 

	if Name == "Thermal" and Input == Enum.UserInputState.End then
		Thermal = SystemModule.Thermal(Thermal, _Stats, TankGui)

		if Humanoid.SeatPart.Name == "DriverSeat" then
			GrainEffect = true
			GrainEffect = SystemModule.GrainEffect(GrainEffect, TankGui)

		end
	end

	if Name == "Reload" and Input == Enum.UserInputState.End then
		if Humanoid.SeatPart.Parent.Ammos[SelectedAmmo].Value >= 1 and Humanoid.SeatPart.Stats.Loaded.Value == false and Reloading == false then
			local LoadingAmmo = SelectedAmmo
			Reloading = true
			Humanoid.SeatPart.Parent.Turret.FirePart.Reload:Play()
			task.wait(Ammos[SelectedAmmo].ReloadTime)
			Reloading = false
			game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("Reload", Humanoid.SeatPart.Parent.Ammos[SelectedAmmo], LoadingAmmo)
		end
	end

	if string.find(tostring(Name), "WeaponSwitch") and Input == Enum.UserInputState.End then
		if Object.KeyCode == Enum.KeyCode.One then
			SelectedAmmo = _Stats.Shell1
		elseif Object.KeyCode == Enum.KeyCode.Two then
			SelectedAmmo = _Stats.Shell2
		elseif  Object.KeyCode == Enum.KeyCode.Three then
			SelectedAmmo = _Stats.Shell3	
		end
	end

	if Name == "Fire" and Input == Enum.UserInputState.Begin and Humanoid.SeatPart.Stats.Loaded.Value == true then
		game:GetService("TweenService"):Create(TankGui.GrainLine, TweenInfo.new(0.2), {Position = UDim2.new(0.508, 0, 1.4, 0)}):Play()
		CameraShake:Shake(CameraShake.Presets.MediumRecoil)
		game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("Fire", Humanoid.SeatPart.Stats, SelectedAmmo, -Humanoid.SeatPart.Parent.Turret.FirePart.CFrame.LookVector)
		Firing = true

		SystemModule.Fire(Ammos[SelectedAmmo], TankGui, Humanoid.SeatPart.Parent.Turret.FirePart, Cast, false)

		task.wait(0.15)
		Firing = false
	end

	if Name == "MGFire" then
		if Input == Enum.UserInputState.Begin then
			MGFiring = true

		elseif Input == Enum.UserInputState.End then

			MGFiring = false
		end
	end

end

UIS.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		HatchZoom -= input.Position.Z * 2
		HatchZoom = math.clamp(HatchZoom, 30, 80)
	end
end)

Cast.RayHit:Connect(function(Cast2, Result, Velocity, FBullet)


	if FBullet.Name == "MGBullet" then
		SystemModule.Penetrate(Cast2.StateInfo.DistanceCovered, FBullet.ShellType.Value, Cast, Result, Velocity, FBullet, Hitboxes)
	else
		SystemModule.Penetrate(Cast2.StateInfo.DistanceCovered, FBullet.Name, Cast, Result, Velocity, FBullet, Hitboxes)
	end

	FBullet:Destroy()
end)


Cast.LengthChanged:Connect(function(CastInfo, lastpoint, dir,  Lenght, Velocity, Bullet)

	local APS_RANGE = 15

	local nextPoint = lastpoint + dir * Lenght

	for _, detector in ipairs(CS:GetTagged("APS_Hitbox")) do
		local tankPos = detector.Position

		-- Vector from bullet segment start to detector
		local toTank = tankPos - lastpoint
		local proj = toTank:Dot(dir)

		-- Clamp projection to the ray segment (0 ? Lenght)
		proj = math.clamp(proj, 0, Lenght)

		-- Closest point on bullet path to tank
		local closestPoint = lastpoint + dir * proj
		local dist = (tankPos - closestPoint).Magnitude

		if dist <= APS_RANGE and CastInfo.StateInfo.DistanceCovered > 100 and CastInfo.RayInfo.CosmeticBulletObject.Name ~= "7.62mm" and detector.Count.Value > 0 and not detector:FindFirstChild("CooldownValue")  then
			print(string.format("APS blew up bullet for %s at distance %.1f",
				detector.Parent.Name, dist))

			-- Kill bullet
			CastInfo:Terminate()
			Bullet:Destroy()

			-- FX right on intercept point
			local explosion = game.ReplicatedStorage.APS_Effect:Clone()
			explosion.Parent = workspace
			explosion.CFrame = CFrame.lookAt(closestPoint, closestPoint + dir)

			game.ReplicatedStorage.TankSystem.Events.Replicate:FireServer("APS", detector, lastpoint)

			for _, v in ipairs(explosion:GetDescendants()) do
				if v:IsA("ParticleEmitter") then
					v:Emit(v.Rate)
				end
			end
		end
	end




	if CastInfo.RayInfo.CosmeticBulletObject then
		local Bullet = CastInfo.RayInfo.CosmeticBulletObject
		local Center = Bullet.Size.Z/2
		local Offset = CFrame.new(0,0,-(Lenght-Center))	
		Bullet.CFrame = CFrame.lookAt(lastpoint, lastpoint+dir):ToWorldSpace(Offset)
	end



end)