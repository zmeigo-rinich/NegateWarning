--[[
    NegateWarning 1.2
    Persistent warning while a Negate Magic / Suppression Field /
    Absorption Field debuff is active on the player.

    The banner is shown from the moment the effect is gained on the
    player until it fades (with a short delay against flicker).

    Since 1.1 beta: a screaming cat picture is drawn to the left of the text.
    The top-left corner of the text adjoins the top-right corner of the
    picture. The text has no plate/background - it is drawn directly on
    the screen.

    No group broadcast: this addon only warns the local player.

    Slash: /testnegatewarning [show|hide|debug|help]
]]

NegateWarning = {}
NegateWarning.name = "NegateWarning"

local LAM = LibAddonMenu2

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

-- Tracked abilities. Add new entries (NPC variants, morphs, separate
-- applied-effect IDs) as { id = <number>, label = "<name>" }.
-- The label is only used in chat/debug output, never for matching.
local TRACKED_ABILITIES = {
	{ id = 29824, label = "Negate Magic" },
	{ id = 47160, label = "Suppression Field" },
	{ id = 47168, label = "Absorption Field" },
	{ id = 51894, label = "NPC Negate Magic" },
}

-- Fallback: show the banner from a combat event when no effect event is
-- available (some effects are not exposed through EVENT_EFFECT_CHANGED).
-- May cause false positives, keep it off unless the effect tracking does
-- not work for a specific ability.
local USE_COMBAT_EVENT_FALLBACK = false
local FALLBACK_DURATION = 10000   -- ms

local HIDE_DELAY     = 100        -- ms delay before hiding, anti-flicker
local END_TIME_GRACE = 100        -- ms extra after the effect end time

local FALLBACK_SLOT = -1          -- synthetic slot keys for non-effect states
local TEST_SLOT     = -2

-- Numeric fallback in case the constant is missing in a future API.
local EFFECT_FADED = EFFECT_RESULT_FADED or 2

-- Look and feel. Red text on a transparent background, no plate.
local TEXT_WARNING = "Enemy Negate!!!"
local FONT = "$(MEDIUM_FONT)|$(KB_48)|thick-outline"
local TEXT_COLOR = { 1, 0.3, 0.3, 1 }

-- Cat picture. The file lives next to this script inside the addon
-- folder, so the path is relative to the AddOns directory. The folder
-- must stay named "NegateWarning".
local TEXTURE_PATH = "NegateWarning/negatecat.dds"
local ICON_SIZE    = 200          -- displayed size of the picture, px

-- Bar is only a layout container for the picture and the text; it has no
-- background of its own.
local BAR_WIDTH  = 640
local BAR_HEIGHT = 200

-- Offset from the screen center. Different from AgonyWarning (-275) so
-- both banners can be visible at the same time.
local BAR_DEFAULT_X = 0
local BAR_DEFAULT_Y = -420

---------------------------------------------------------------------------
-- State / helpers
---------------------------------------------------------------------------

-- [effectSlot] = { abilityId = <number>, endTime = <ms, 0 = unknown> }
local ActiveEffects = {}

local function GetGameTimeMs()
	return GetGameTimeMilliseconds()
end

local function GetAbilityLabel(abilityId)
	for i = 1, #TRACKED_ABILITIES do
		local entry = TRACKED_ABILITIES[i]
		if entry.id == abilityId then
			return entry.label
		end
	end
	return nil
end

local function IsTrackedAbility(abilityId)
	return GetAbilityLabel(abilityId) ~= nil
end

local function Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

function NegateWarning.LoadSettings()
	local panelName = "NegateWarningPanel"

	local panelData = {
		type = "panel",
		name = "NegateWarning",
		author = "Zmeigo Rinich",
	}
	LAM:RegisterAddonPanel(panelName, panelData)

	local optionsData = {
		[1] = {
			type = "checkbox",
			name = "Lock",
			tooltip = "Toggle off to move the banner on screen. Toggle back on to save the new position.",
			getFunc = function() return NegateWarning.Locked == true end,
			setFunc = function(value)
				if value then
					NegateWarning.Locked = true
					NegateWarning.Bar:SetHidden(true)

					local coordX, coordY = NegateWarning.Bar:GetCenter()
					NegateWarning.SavedVariables.OffsetX = coordX - (GuiRoot:GetWidth() / 2)
					NegateWarning.SavedVariables.OffsetY = coordY - (GuiRoot:GetHeight() / 2)

					NegateWarning.Bar:SetMouseEnabled(false)
					NegateWarning.Bar:SetMovable(false)

					d("NegateWarning position saved.")
				else
					NegateWarning.Locked = false
					NegateWarning.Bar:SetHidden(false)

					NegateWarning.Bar:SetMouseEnabled(true)
					NegateWarning.Bar:SetMovable(true)
				end
			end,
			width = "full",
		},
	}
	LAM:RegisterOptionControls(panelName, optionsData)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function NegateWarning.OnAddOnLoaded(event, addonName)
	if addonName == NegateWarning.name then
		NegateWarning.Locked = true
		NegateWarning.Initialize()
		NegateWarning.LoadSettings()

		EVENT_MANAGER:UnregisterForEvent(NegateWarning.name, EVENT_ADD_ON_LOADED)
	end
end

function NegateWarning.OnPlayerActivated(eventCode, initial)
	NegateWarning.HideImmediate()
end

function NegateWarning.OnPlayerDead(eventCode, unitTag)
	if unitTag == nil or unitTag == "player" then
		NegateWarning.HideImmediate()
	end
end

function NegateWarning.Initialize()
	EVENT_MANAGER:RegisterForEvent(NegateWarning.name, EVENT_EFFECT_CHANGED, NegateWarning.OnEffectChanged)
	EVENT_MANAGER:RegisterForEvent(NegateWarning.name, EVENT_COMBAT_EVENT, NegateWarning.OnCombatEvent)

	local myDefaults = {}
	myDefaults.OffsetX = BAR_DEFAULT_X
	myDefaults.OffsetY = BAR_DEFAULT_Y
	NegateWarning.SavedVariables = ZO_SavedVars:NewCharacterIdSettings(
		"NegateWarningSavedVariables", 1.0, nil, myDefaults, GetWorldName())

	NegateWarning.WarningVisible = false
	NegateWarning.HideGeneration = 0
	NegateWarning.DebugEnabled = false

	NegateWarning.CreateBar()

	SLASH_COMMANDS["/testnegatewarning"] = NegateWarning.SlashCommand
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

function NegateWarning.CreateBar()
	local wm = WINDOW_MANAGER

	NegateWarning.TLW = wm:CreateTopLevelWindow("NegateWarningTLW")

	NegateWarning.Bar = wm:CreateControl("NegateWarningBar", NegateWarning.TLW, CT_CONTROL)
	NegateWarning.Bar:SetHidden(true)
	NegateWarning.Bar:ClearAnchors()
	NegateWarning.Bar:SetAnchor(CENTER, GuiRoot, CENTER,
		NegateWarning.SavedVariables.OffsetX, NegateWarning.SavedVariables.OffsetY)
	NegateWarning.Bar:SetDimensions(BAR_WIDTH, BAR_HEIGHT)

	-- Cat picture, top-left corner of the bar.
	local icon = wm:CreateControl("NegateWarningBarIcon", NegateWarning.Bar, CT_TEXTURE)
	icon:SetAnchor(TOPLEFT, NegateWarning.Bar, TOPLEFT, 0, 0)
	icon:SetDimensions(ICON_SIZE, ICON_SIZE)
	icon:SetTexture(TEXTURE_PATH)

	-- Text, its top-left corner exactly at the top-right corner of the
	-- picture. No backdrop: the text is drawn on a transparent background.
	local label = wm:CreateControl("NegateWarningBarLabel", NegateWarning.Bar, CT_LABEL)
	label:SetAnchor(TOPLEFT, icon, TOPRIGHT, 0, 0)
	label:SetFont(FONT)
	label:SetColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], TEXT_COLOR[4])
	label:SetVerticalAlignment(TEXT_ALIGN_TOP)
	label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	label:SetText(TEXT_WARNING)

	NegateWarning.Bar.Label = label
	NegateWarning.Bar.Icon = icon
end

function NegateWarning.ShowBanner()
	NegateWarning.WarningVisible = true
	NegateWarning.Bar:SetHidden(false)
end

function NegateWarning.HideBanner()
	NegateWarning.WarningVisible = false
	if NegateWarning.Locked then
		NegateWarning.Bar:SetHidden(true)
	end
end

-- Drops all tracked effects and hides the banner without waiting for the
-- anti-flicker delay (death, reload, zone change).
function NegateWarning.HideImmediate()
	for slot in pairs(ActiveEffects) do
		ActiveEffects[slot] = nil
	end
	NegateWarning.HideGeneration = NegateWarning.HideGeneration + 1
	NegateWarning.HideBanner()
end

-- Recomputes the banner state from ActiveEffects and schedules the next
-- check at the latest known end time.
function NegateWarning.RefreshDisplay()
	local now = GetGameTimeMs()

	for slot, info in pairs(ActiveEffects) do
		if info.endTime > 0 and info.endTime <= now then
			ActiveEffects[slot] = nil
		end
	end

	NegateWarning.HideGeneration = NegateWarning.HideGeneration + 1
	local generation = NegateWarning.HideGeneration

	if next(ActiveEffects) == nil then
		-- Small delay so a re-applied effect does not make the banner
		-- flicker off and on again.
		zo_callLater(function()
			if generation ~= NegateWarning.HideGeneration then
				return
			end
			if next(ActiveEffects) ~= nil then
				return
			end
			NegateWarning.HideBanner()
		end, HIDE_DELAY)
		return
	end

	NegateWarning.ShowBanner()

	local maxEnd = 0
	for _, info in pairs(ActiveEffects) do
		if info.endTime > maxEnd then
			maxEnd = info.endTime
		end
	end

	if maxEnd > 0 then
		local delay = (maxEnd - now) + END_TIME_GRACE
		if delay < 0 then
			delay = 0
		end
		zo_callLater(function()
			if generation ~= NegateWarning.HideGeneration then
				return
			end
			NegateWarning.RefreshDisplay()
		end, delay)
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function NegateWarning.OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag,
	beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType,
	statusEffectType, unitName, unitId, abilityId)

	if unitTag ~= "player" then
		return
	end

	local tracked = IsTrackedAbility(abilityId)

	if NegateWarning.DebugEnabled and (tracked or changeType ~= EFFECT_FADED) then
		d(string.format(
			"NW| change=%s slot=%s id=%s name='%s' buffType=%s end=%s tracked=%s",
			tostring(changeType), tostring(effectSlot), tostring(abilityId),
			tostring(effectName), tostring(buffType), tostring(endTime),
			tracked and "yes" or "no"))
	end

	if changeType == EFFECT_FADED then
		-- Slot is the primary identity of an effect; remove it even if
		-- the fade event reports a different/zero ability ID.
		if ActiveEffects[effectSlot] ~= nil then
			ActiveEffects[effectSlot] = nil
			NegateWarning.RefreshDisplay()
			return
		end

		if tracked then
			-- Slot mismatch (rare): remove by ability ID, ignore the
			-- synthetic slots used for testing and fallback.
			for slot, info in pairs(ActiveEffects) do
				if slot >= 0 and info.abilityId == abilityId then
					ActiveEffects[slot] = nil
				end
			end
			NegateWarning.RefreshDisplay()
		end
		return
	end

	if not tracked then
		return
	end

	ActiveEffects[effectSlot] = {
		abilityId = abilityId,
		-- ИСПРАВЛЕНИЕ: Переводим секунды в миллисекунды для точного сравнения
		endTime = (endTime and endTime > 0) and (endTime * 1000) or 0,
	}

	NegateWarning.RefreshDisplay()
end

function NegateWarning.OnCombatEvent(eventCode, result, isError, abilityName, abilityGraphic,
	abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue,
	powerType, damageType, combatEventLog, sourceUnitId, targetUnitId, abilityId)

	local tracked = IsTrackedAbility(abilityId)

	if NegateWarning.DebugEnabled and tracked then
		d(string.format(
			"NW| combat id=%s name='%s' src=%s/'%s' tgt=%s/'%s' result=%s",
			tostring(abilityId), tostring(abilityName),
			tostring(sourceType), tostring(sourceName),
			tostring(targetType), tostring(targetName),
			tostring(result)))
	end

	if not tracked or not USE_COMBAT_EVENT_FALLBACK then
		return
	end

	-- Real effect tracking already knows about this ability; do not
	-- override its duration with a guess.
	if next(ActiveEffects) ~= nil then
		return
	end

	ActiveEffects[FALLBACK_SLOT] = {
		abilityId = abilityId,
		endTime = GetGameTimeMs() + FALLBACK_DURATION,
	}
	NegateWarning.RefreshDisplay()
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

local function PrintTrackedList()
	d("NegateWarning: tracked abilities:")
	for i = 1, #TRACKED_ABILITIES do
		local entry = TRACKED_ABILITIES[i]
		d(string.format("  %d - %s", entry.id, entry.label))
	end
end

local function PrintHelp()
	d("NegateWarning 1.2:")
	d("/testnegatewarning show  - show the banner until 'hide'")
	d("/testnegatewarning hide  - hide the banner and clear the state")
	d("/testnegatewarning debug - toggle effect/combat logging")
end

function NegateWarning.SlashCommand(args)
	local command = string.lower(Trim(args))

	if command == "show" then
		ActiveEffects[TEST_SLOT] = { abilityId = 0, endTime = 0 }
		NegateWarning.RefreshDisplay()
		d("NegateWarning: test banner shown.")
	elseif command == "hide" then
		NegateWarning.HideImmediate()
		d("NegateWarning: banner hidden.")
	elseif command == "debug" then
		NegateWarning.DebugEnabled = not NegateWarning.DebugEnabled
		d(string.format("NegateWarning: debug %s.",
			NegateWarning.DebugEnabled and "ON" or "OFF"))
		if NegateWarning.DebugEnabled then
			PrintTrackedList()
		end
	else
		PrintHelp()
	end
end

---------------------------------------------------------------------------
-- Entry points
---------------------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(NegateWarning.name, EVENT_ADD_ON_LOADED, NegateWarning.OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(NegateWarning.name, EVENT_PLAYER_ACTIVATED, NegateWarning.OnPlayerActivated)
EVENT_MANAGER:RegisterForEvent(NegateWarning.name, EVENT_PLAYER_DEAD, NegateWarning.OnPlayerDead)