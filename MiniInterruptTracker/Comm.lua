local ADDON_NAME, ns = ...

local PREFIX = "MIT1"
local PROBE_INTERVAL = 5
local STALE_TIMEOUT = 12

ns.Comm = {}
local Comm = ns.Comm

ns.roster = {} -- [fullName] = { version, specID, lastSeen }
ns.firstProbeAt = nil

local function GetNormalizedRealm()
	return (GetNormalizedRealmName())
end

local function NormalizeSenderName(name)
	if not name then return nil end
	if not name:find("%-") then
		name = name .. "-" .. GetNormalizedRealm()
	end
	return name
end

local function GetUnitFullName(unit)
	local name, realm = UnitName(unit)
	if not name then return nil end
	if not realm or realm == "" then
		realm = GetNormalizedRealm()
	end
	return name .. "-" .. realm
end
Comm.GetUnitFullName = GetUnitFullName

function Comm.GetMyFullName()
	return GetUnitFullName("player")
end

function Comm.GetMySpecID()
	local specIndex = GetSpecialization()
	if not specIndex then return nil end
	return (GetSpecializationInfo(specIndex))
end

local function GetChannel()
	if IsInGroup() and not IsInRaid() then
		return "PARTY"
	end
	return nil
end

function Comm.Send(message)
	local channel = GetChannel()
	if not channel then return end
	C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
end

function Comm.SendPing()
	Comm.Send("PING:" .. ns.VERSION .. ":" .. tostring(Comm.GetMySpecID()))
	ns.firstProbeAt = ns.firstProbeAt or GetTime()
end

-- Seed/refresh our own roster entry locally -- we never receive our own
-- addon messages, so this is set directly instead of via PONG.
function Comm.RefreshSelf()
	local fullName = Comm.GetMyFullName()
	local specID = Comm.GetMySpecID()
	ns.roster[fullName] = {
		version = ns.VERSION,
		specID = specID,
		lastSeen = math.huge,
	}
	if ns.Bars then
		ns.Bars.RefreshRoster()
	end
end

local function UpdateRoster(fullName, version, specID)
	ns.roster[fullName] = {
		version = version,
		specID = specID,
		lastSeen = GetTime(),
	}
	if ns.Bars then
		ns.Bars.RefreshRoster()
	end
end

local function MarkSeen(fullName)
	local entry = ns.roster[fullName]
	if entry then
		entry.lastSeen = GetTime()
	end
end

function Comm.IsStale(fullName)
	local entry = ns.roster[fullName]
	if not entry then
		return (ns.firstProbeAt and (GetTime() - ns.firstProbeAt) > STALE_TIMEOUT) or false
	end
	return (GetTime() - entry.lastSeen) > STALE_TIMEOUT
end

-- Probe ticker: only the party leader pings, and only outside an active key.
local pingTicker

local function ShouldPing()
	return IsInGroup() and not IsInRaid() and UnitIsGroupLeader("player")
		and not C_ChallengeMode.IsChallengeModeActive()
end

local function StartPingTicker()
	if pingTicker then return end
	Comm.SendPing()
	pingTicker = C_Timer.NewTicker(PROBE_INTERVAL, Comm.SendPing)
end

local function StopPingTicker()
	if pingTicker then
		pingTicker:Cancel()
		pingTicker = nil
	end
end

function Comm.EvaluatePingState()
	-- Only the leader actually sends pings, but every member needs its own
	-- "checking..." grace period to start as soon as we're in a party --
	-- otherwise non-leader clients never mark an absent member stale.
	if IsInGroup() and not IsInRaid() then
		ns.firstProbeAt = ns.firstProbeAt or GetTime()
	else
		ns.firstProbeAt = nil
	end

	if ShouldPing() then
		StartPingTicker()
	else
		StopPingTicker()
	end
end

local function OnAddonMessage(prefix, message, _channel, sender)
	if prefix ~= PREFIX then return end
	local fullSender = NormalizeSenderName(sender)
	if not fullSender or fullSender == Comm.GetMyFullName() then return end

	local msgType, rest = message:match("^(%u+):(.*)$")
	if msgType == "PING" then
		-- Only the leader pings, so this is also the only way other members
		-- ever learn the leader's own specID -- register the sender here,
		-- not just on PONG replies.
		local version, specID = rest:match("^(.-):(%d+)$")
		if version and specID then
			UpdateRoster(fullSender, version, tonumber(specID))
		end
		if not UnitIsGroupLeader("player") then
			Comm.Send("PONG:" .. ns.VERSION .. ":" .. tostring(Comm.GetMySpecID()))
		end
	elseif msgType == "PONG" then
		local version, specID = rest:match("^(.-):(%d+)$")
		if version and specID then
			UpdateRoster(fullSender, version, tonumber(specID))
		end
	elseif msgType == "KICK" then
		local spellID, timestamp, duration = rest:match("^(%d+):([%d%.]+):([%d%.]+)$")
		if not spellID then
			-- Legacy (pre-measured-duration) senders only send spellID:timestamp.
			spellID, timestamp = rest:match("^(%d+):([%d%.]+)$")
		end
		spellID, timestamp, duration = tonumber(spellID), tonumber(timestamp), tonumber(duration)
		MarkSeen(fullSender)
		if spellID and timestamp and ns.Bars then
			ns.Bars.OnKickReceived(fullSender, spellID, timestamp, duration)
		end
	end
end

local function OnSpellCastSucceeded(unit, _castGUID, spellID)
	if unit ~= "player" and unit ~= "pet" then return end

	if ns.db and ns.db.debug then
		local name = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
		print(("|cff40ff40[MIT debug]|r %s cast spellID %d (%s) -- known interrupt: %s"):format(
			unit, spellID, (name and name.name) or "?", tostring(ns.spellIDToCooldown[spellID] ~= nil)))
	end

	if not ns.spellIDToCooldown[spellID] then return end

	-- Note: C_Spell.GetSpellCooldown()'s numeric fields are wrapped as
	-- "secret" values by the client and can't be compared/used in arithmetic
	-- by addon code (throws a taint error), so live per-character cooldown
	-- measurement isn't possible here -- fall back to the static table.
	local duration = ns.spellIDToCooldown[spellID]

	local now = GetTime()
	Comm.Send("KICK:" .. spellID .. ":" .. now .. ":" .. duration)
	if ns.Bars then
		ns.Bars.OnKickReceived(Comm.GetMyFullName(), spellID, now, duration)
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "CHAT_MSG_ADDON" then
		OnAddonMessage(...)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		OnSpellCastSucceeded(...)
	end
end)

function Comm.Init()
	C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	Comm.RefreshSelf()
	Comm.EvaluatePingState()
end
