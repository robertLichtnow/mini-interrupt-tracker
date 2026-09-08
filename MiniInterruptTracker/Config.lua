local ADDON_NAME, ns = ...

ns.Config = {}

local function CreateCheckbox(parent, label, dbKey, onChange)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check.text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	check.text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	check.text:SetText(label)
	check:SetScript("OnClick", function(self)
		local value = self:GetChecked() and true or false
		ns.db[dbKey] = value
		if onChange then onChange(value) end
	end)
	return check
end

local function CreateSlider(parent, label, dbKey, minVal, maxVal)
	local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	slider:SetWidth(220)
	slider:SetMinMaxValues(minVal, maxVal)
	slider:SetValueStep(1)
	slider:SetObeyStepOnDrag(true)
	slider.Low:SetText(minVal)
	slider.High:SetText(maxVal)
	slider.Text:SetText(label)
	slider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		ns.db[dbKey] = value
		ns.Bars.RelayoutAll()
	end)
	return slider
end

function ns.Config.Build(frame)
	local content = frame.Inset or frame

	local checkOpenWorld = CreateCheckbox(frame, "Show in Open World", "showInOpenWorld", function()
		ns.Core.RecomputeVisibility()
	end)
	checkOpenWorld:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -32)

	local checkMythicPlus = CreateCheckbox(frame, "Show in Mythic Dungeons (incl. Mythic+)", "showInMythicPlus", function()
		ns.Core.RecomputeVisibility()
	end)
	checkMythicPlus:SetPoint("TOPLEFT", checkOpenWorld, "BOTTOMLEFT", 0, -8)

	local checkHideNoAddon = CreateCheckbox(frame, "Hide Members Without The Addon", "hideNoAddon", function()
		ns.Bars.RefreshRoster()
	end)
	checkHideNoAddon:SetPoint("TOPLEFT", checkMythicPlus, "BOTTOMLEFT", 0, -8)

	local checkLocked = CreateCheckbox(frame, "Lock Bars Position", "barsLocked", function(value)
		ns.Bars.SetLocked(value)
	end)
	checkLocked:SetPoint("TOPLEFT", checkHideNoAddon, "BOTTOMLEFT", 0, -8)

	local checkReverse = CreateCheckbox(frame, "Reverse Bar Growth Direction", "reverseBarGrowth", function()
		ns.Bars.RelayoutAll()
	end)
	checkReverse:SetPoint("TOPLEFT", checkLocked, "BOTTOMLEFT", 0, -8)

	local checkTest = CreateCheckbox(frame, "Test Mode (preview with fake data)", "testMode", function()
		ns.Bars.RefreshRoster()
		ns.Core.RecomputeVisibility()
	end)
	checkTest:SetPoint("TOPLEFT", checkReverse, "BOTTOMLEFT", 0, -8)

	local sliderWidth = CreateSlider(frame, "Bar Width", "barWidth", 100, 400)
	sliderWidth:SetPoint("TOPLEFT", checkTest, "BOTTOMLEFT", 10, -28)

	local sliderHeight = CreateSlider(frame, "Bar Height", "barHeight", 14, 40)
	sliderHeight:SetPoint("TOPLEFT", sliderWidth, "BOTTOMLEFT", 0, -32)

	local sliderSpacing = CreateSlider(frame, "Bar Spacing", "barSpacing", 0, 20)
	sliderSpacing:SetPoint("TOPLEFT", sliderHeight, "BOTTOMLEFT", 0, -32)

	frame:HookScript("OnShow", function()
		checkOpenWorld:SetChecked(ns.db.showInOpenWorld)
		checkMythicPlus:SetChecked(ns.db.showInMythicPlus)
		checkHideNoAddon:SetChecked(ns.db.hideNoAddon)
		checkLocked:SetChecked(ns.db.barsLocked)
		checkReverse:SetChecked(ns.db.reverseBarGrowth)
		checkTest:SetChecked(ns.db.testMode)
		sliderWidth:SetValue(ns.db.barWidth)
		sliderHeight:SetValue(ns.db.barHeight)
		sliderSpacing:SetValue(ns.db.barSpacing)
	end)
end
