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
	Comm.Send("PING:" .. ns.VERSION)
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
		if not UnitIsGroupLeader("player") then
			Comm.Send("PONG:" .. ns.VERSION .. ":" .. tostring(Comm.GetMySpecID()))
		end
	elseif msgType == "PONG" then
		local version, specID = rest:match("^(.-):(%d+)$")
		if version and specID then
			UpdateRoster(fullSender, version, tonumber(specID))
		end
	elseif msgType == "KICK" then
		local spellID, timestamp = rest:match("^(%d+):([%d%.]+)$")
		spellID, timestamp = tonumber(spellID), tonumber(timestamp)
		MarkSeen(fullSender)
		if spellID and timestamp and ns.Bars then
			ns.Bars.OnKickReceived(fullSender, spellID, timestamp)
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

	local now = GetTime()
	Comm.Send("KICK:" .. spellID .. ":" .. now)
	if ns.Bars then
		ns.Bars.OnKickReceived(Comm.GetMyFullName(), spellID, now)
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
