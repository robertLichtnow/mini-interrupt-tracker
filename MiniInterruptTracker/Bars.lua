local ADDON_NAME, ns = ...

ns.Bars = {}
local Bars = ns.Bars

local container = CreateFrame("Frame", "MiniInterruptTrackerBarsFrame", UIParent)
container:SetMovable(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self)
	if not ns.db.barsLocked then
		self:StartMoving()
	end
end)
container:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	ns.db.barsPoint = { point = point, relPoint = relPoint, x = x, y = y }
end)

Bars.rowPool = {}
Bars.currentList = {}
Bars.memberState = {} -- [fullName] = { spellID, endTime, duration }

local TEST_MEMBERS = {
	{ shortName = "Testwarr", class = "WARRIOR", specName = "Arms", role = "melee", cooldown = 10, baseSpellID = 6552 },
	{ shortName = "Testpal", class = "PALADIN", specName = "Protection", role = "tank", cooldown = 15, baseSpellID = 96231 },
	{ shortName = "Testhunter", class = "HUNTER", specName = "Marksmanship", role = "ranged", cooldown = 24, baseSpellID = 147362 },
	{ shortName = "Testevoker", class = "EVOKER", specName = "Devastation", role = "ranged", cooldown = 20, baseSpellID = 351338 },
}

local function CreateRowFrame(parent)
	local row = CreateFrame("Frame", nil, parent)

	row.icon = row:CreateTexture(nil, "ARTWORK")

	row.bar = CreateFrame("StatusBar", nil, row)
	row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
	row.bar:SetMinMaxValues(0, 1)

	row.bg = row.bar:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints(row.bar)
	row.bg:SetColorTexture(0, 0, 0, 0.5)

	row.nameText = row.bar:CreateFontString(nil, "OVERLAY")
	row.nameText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	row.nameText:SetTextColor(1, 1, 1, 1)
	row.nameText:SetShadowOffset(1, -1)
	row.nameText:SetShadowColor(0, 0, 0, 1)
	row.nameText:SetPoint("LEFT", row.bar, "LEFT", 4, 0)

	row.statusText = row.bar:CreateFontString(nil, "OVERLAY")
	row.statusText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
	row.statusText:SetPoint("RIGHT", row.bar, "RIGHT", -4, 0)

	return row
end

local function AcquireRow(index)
	local row = Bars.rowPool[index]
	if not row then
		row = CreateRowFrame(container)
		Bars.rowPool[index] = row
	end
	return row
end

local function LayoutRow(row, index)
	local db = ns.db
	local h, w, spacing = db.barHeight, db.barWidth, db.barSpacing

	row:ClearAllPoints()
	row:SetSize(w, h)
	row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -((index - 1) * (h + spacing)))

	row.icon:ClearAllPoints()
	row.icon:SetSize(h, h)
	row.bar:ClearAllPoints()

	if db.reverseBarGrowth then
		row.icon:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
		row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.bar:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMLEFT", 0, 0)
	else
		row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.bar:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
		row.bar:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 0, 0)
	end
	row.bar:SetReverseFill(db.reverseBarGrowth)

	local statusFontSize = math.max(10, math.floor(h * 0.7))
	row.statusText:SetFont("Fonts\\FRIZQT__.TTF", statusFontSize, "OUTLINE")
end

local function ApplyMemberData(row, member)
	row.testCooldown = member.testCooldown

	row.duration, row.endTime = nil, nil

	if not member.tracked then
		row.icon:SetTexture(134400) -- INV_Misc_QuestionMark
		row.bar:SetStatusBarColor(0.5, 0.5, 0.5)
		row.bar:SetValue(1)
		row.statusText:SetText("")
		row.nameText:SetText((member.shortName or "?") .. (member.stale and " |cffff4040(No Addon)|r" or " |cffffff40(Checking...)|r"))
		return
	end

	local color = RAID_CLASS_COLORS[member.class]
	if color then
		row.bar:SetStatusBarColor(color.r, color.g, color.b)
	else
		row.bar:SetStatusBarColor(0.8, 0.8, 0.8)
	end

	local state = not member.testCooldown and Bars.memberState[member.fullName] or nil
	if state and state.endTime <= GetTime() then
		-- Cooldown already elapsed since this state was recorded -- stale, drop it.
		Bars.memberState[member.fullName] = nil
		state = nil
	end
	if state then
		row.icon:SetTexture(C_Spell.GetSpellTexture(state.spellID))
		row.duration, row.endTime = state.duration, state.endTime
	else
		row.icon:SetTexture(C_Spell.GetSpellTexture(member.baseSpellID))
		row.duration, row.endTime = nil, nil
		row.bar:SetValue(1)
		row.statusText:SetText("READY")
		row.statusText:SetTextColor(0.1, 1, 0.1, 1)
	end

	local label = member.shortName or "?"
	if member.versionMismatch then
		label = label .. " |cffff4040(Version!)|r"
	end
	row.nameText:SetText(label)
end

local function RowComparator(a, b)
	if a.tracked ~= b.tracked then return a.tracked end
	if not a.tracked then
		return (a.shortName or "") < (b.shortName or "")
	end
	if a.cooldown ~= b.cooldown then return a.cooldown < b.cooldown end
	local pa, pb = ns.ROLE_PRIORITY[a.role], ns.ROLE_PRIORITY[b.role]
	if pa ~= pb then return pa < pb end
	if a.specName ~= b.specName then return a.specName < b.specName end
	return (a.shortName or "") < (b.shortName or "")
end

local function GetPartyUnits()
	local units = { "player" }
	if IsInGroup() and not IsInRaid() then
		for i = 1, 4 do
			local unit = "party" .. i
			if UnitExists(unit) then
				table.insert(units, unit)
			end
		end
	end
	return units
end

local function BuildMemberList()
	if IsInRaid() then return {} end

	local list = {}
	for _, unit in ipairs(GetPartyUnits()) do
		local fullName = ns.Comm.GetUnitFullName(unit)
		if fullName then
			local entry = ns.roster[fullName]
			if entry and entry.specID and ns.specData[entry.specID] then
				local spec = ns.specData[entry.specID]
				table.insert(list, {
					fullName = fullName,
					shortName = (UnitName(unit)),
					tracked = true,
					class = spec.class,
					specName = spec.spec,
					role = spec.role,
					cooldown = spec.cooldown,
					baseSpellID = spec.spellID,
					versionMismatch = entry.version ~= ns.VERSION,
				})
			elseif entry and entry.specID then
				-- Known addon user, but their spec has no trackable interrupt -- drop the row.
			else
				table.insert(list, {
					fullName = fullName,
					shortName = (UnitName(unit)),
					tracked = false,
					stale = ns.Comm.IsStale(fullName),
				})
			end
		end
	end

	table.sort(list, RowComparator)
	return list
end

local function BuildTestList()
	local now = GetTime()
	local list = {}
	for _, m in ipairs(TEST_MEMBERS) do
		table.insert(list, {
			fullName = "Test-" .. m.shortName,
			shortName = m.shortName,
			tracked = true,
			class = m.class,
			specName = m.specName,
			role = m.role,
			cooldown = m.cooldown,
			baseSpellID = m.baseSpellID,
			testCooldown = m.cooldown,
		})
	end
	return list
end

function Bars.RefreshRoster()
	if not ns.db then return end
	local list = ns.db.testMode and BuildTestList() or BuildMemberList()
	Bars.currentList = list

	for i, member in ipairs(list) do
		local row = AcquireRow(i)
		ApplyMemberData(row, member)
		LayoutRow(row, i)
		row:Show()
	end
	for i = #list + 1, #Bars.rowPool do
		Bars.rowPool[i]:Hide()
	end

	local db = ns.db
	local count = math.max(1, #list)
	container:SetSize(db.barWidth, count * db.barHeight + (count - 1) * db.barSpacing)
end

function Bars.RelayoutAll()
	if not ns.db then return end
	for i = 1, #Bars.currentList do
		if Bars.rowPool[i] then
			LayoutRow(Bars.rowPool[i], i)
		end
	end
	local db = ns.db
	local count = math.max(1, #Bars.currentList)
	container:SetSize(db.barWidth, count * db.barHeight + (count - 1) * db.barSpacing)
end

function Bars.OnKickReceived(fullName, spellID, timestamp, duration)
	duration = duration or ns.spellIDToCooldown[spellID]
	if not duration then return end
	Bars.memberState[fullName] = {
		spellID = spellID,
		endTime = timestamp + duration,
		duration = duration,
	}
	if ns.db and ns.db.debug then
		print(("|cff40ff40[MIT debug]|r OnKickReceived stored state for %s: spellID=%d duration=%.2f"):format(
			fullName, spellID, duration))
	end
	Bars.RefreshRoster()
end

function Bars.SetShown(shown)
	if shown then
		container:Show()
	else
		container:Hide()
	end
end

function Bars.SetLocked(locked)
	container:EnableMouse(not locked)
end

function Bars.ApplyPosition()
	container:ClearAllPoints()
	local p = ns.db.barsPoint
	if p then
		container:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
	else
		container:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
	end
end

function Bars.Init()
	Bars.ApplyPosition()
	Bars.SetLocked(ns.db.barsLocked)
	Bars.RefreshRoster()

	-- "Checking..." members become stale purely by elapsed time (no event
	-- fires when the timeout passes), so poll for that transition.
	C_Timer.NewTicker(1, function()
		if not ns.db or ns.db.testMode then return end
		for _, member in ipairs(Bars.currentList) do
			if not member.tracked and not member.stale and ns.Comm.IsStale(member.fullName) then
				Bars.RefreshRoster()
				return
			end
		end
	end)

	local debugTick = 0
	C_Timer.NewTicker(0.05, function()
		local now = GetTime()
		debugTick = debugTick + 1
		local shouldPrint = ns.db and ns.db.debug and (debugTick % 20 == 0)
		if shouldPrint then
			print(("|cff40ff40[MIT debug]|r tick: containerShown=%s barsInPool=%d"):format(
				tostring(container:IsShown()), #Bars.rowPool))
		end
		for i, row in ipairs(Bars.rowPool) do
			if row:IsShown() then
				if row.testCooldown then
					local elapsed = math.fmod(now, row.testCooldown)
					local remaining = row.testCooldown - elapsed
					row.bar:SetValue(1 - (elapsed / row.testCooldown))
					row.statusText:SetText(("%.1fs"):format(remaining))
					row.statusText:SetTextColor(1, 1, 1, 1)
				elseif row.duration then
					local remaining = row.endTime - now
					if remaining <= 0 then
						row.bar:SetValue(1)
						row.statusText:SetText("READY")
						row.statusText:SetTextColor(0.1, 1, 0.1, 1)
						row.duration, row.endTime = nil, nil
					else
						local value = remaining / row.duration
						row.bar:SetValue(value)
						row.statusText:SetText(("%.1fs"):format(remaining))
						row.statusText:SetTextColor(1, 1, 1, 1)
						if shouldPrint then
							print(("|cff40ff40[MIT debug]|r row %d: rowShown=%s value=%.2f remaining=%.1f minmax=%.0f-%.0f"):format(
								i, tostring(row:IsShown()), value, remaining, row.bar:GetMinMaxValues()))
						end
					end
				elseif shouldPrint then
					print(("|cff40ff40[MIT debug]|r row %d: no duration set (idle/ready)"):format(i))
				end
			end
		end
	end)
end
