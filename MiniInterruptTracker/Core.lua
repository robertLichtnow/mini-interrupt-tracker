local ADDON_NAME, ns = ...

ns.Core = {}
ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0"

local DEFAULTS = {
	showInOpenWorld = true,
	showInMythicPlus = true,
	barsLocked = false,
	reverseBarGrowth = false,
	testMode = false,
	barWidth = 200,
	barHeight = 20,
	barSpacing = 4,
	barsPoint = nil,
	debug = false,
}

local configFrame = CreateFrame("Frame", "MiniInterruptTrackerConfigFrame", UIParent, "BasicFrameTemplateWithInset")
configFrame:SetSize(340, 450)
configFrame:SetPoint("CENTER")
configFrame:SetMovable(true)
configFrame:EnableMouse(true)
configFrame:RegisterForDrag("LeftButton")
configFrame:SetScript("OnDragStart", configFrame.StartMoving)
configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
configFrame:Hide()

configFrame.title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
configFrame.title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 5, 0)
configFrame.title:SetText("Mini Interrupt Tracker")

tinsert(UISpecialFrames, "MiniInterruptTrackerConfigFrame")

SLASH_MINIINTERRUPTTRACKER1 = "/mit"
SlashCmdList["MINIINTERRUPTTRACKER"] = function()
	if configFrame:IsShown() then
		configFrame:Hide()
	else
		configFrame:Show()
	end
end

SLASH_MINIINTERRUPTTRACKERDEBUG1 = "/mitdebug"
SlashCmdList["MINIINTERRUPTTRACKERDEBUG"] = function()
	if not ns.db then return end
	ns.db.debug = not ns.db.debug
	print("|cff40ff40[MIT]|r debug mode " .. (ns.db.debug and "ON" or "OFF"))
	if ns.db.debug then
		local fullName = ns.Comm.GetMyFullName()
		local entry = ns.roster[fullName]
		print(("|cff40ff40[MIT]|r self=%s specID=%s knownInterrupt=%s"):format(
			tostring(fullName), tostring(entry and entry.specID), tostring(entry and entry.specID and ns.specData[entry.specID] ~= nil)))
	end
end

function ns.Core.RecomputeVisibility()
	if not ns.db then return end

	if ns.db.testMode then
		ns.Bars.SetShown(true)
		return
	end

	if IsInRaid() then
		ns.Bars.SetShown(false)
		return
	end

	local inOpenWorld = select(2, IsInInstance()) == "none"
	local inMythicPlus = C_ChallengeMode.IsChallengeModeActive()

	local shouldShow = (ns.db.showInOpenWorld and inOpenWorld) or (ns.db.showInMythicPlus and inMythicPlus)
	ns.Bars.SetShown(shouldShow)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")

eventFrame:SetScript("OnEvent", function(_, event, addonName, ...)
	if event == "ADDON_LOADED" then
		if addonName ~= ADDON_NAME then return end
		MiniInterruptTrackerDB = MiniInterruptTrackerDB or {}
		for key, value in pairs(DEFAULTS) do
			if MiniInterruptTrackerDB[key] == nil then
				MiniInterruptTrackerDB[key] = value
			end
		end
		ns.db = MiniInterruptTrackerDB
		ns.Config.Build(configFrame)
	elseif event == "PLAYER_LOGIN" then
		ns.Comm.Init()
		ns.Bars.Init()
		ns.Core.RecomputeVisibility()
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		ns.Comm.RefreshSelf()
		ns.Core.RecomputeVisibility()
		ns.Comm.EvaluatePingState()
	elseif event == "GROUP_ROSTER_UPDATE" then
		ns.Comm.RefreshSelf()
		ns.Comm.EvaluatePingState()
		ns.Bars.RefreshRoster()
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		ns.Comm.RefreshSelf()
	elseif event == "CHALLENGE_MODE_START" then
		ns.Comm.EvaluatePingState()
		ns.Core.RecomputeVisibility()
	elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
		ns.Comm.EvaluatePingState()
		ns.Core.RecomputeVisibility()
	end
end)
