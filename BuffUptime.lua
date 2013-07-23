local _, ns = ...
-- GLOBALS: _G, DEFAULT_CHAT_FRAME, BINDING_HEADER_BUFFUPTIME, BuffUptime, BuffUptimeDB, SLASH_BuffUptime1, BuffUptimeFrame, BuffUptimeMessageFrame, BuffUptimeMessage, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, FauxScrollFrame, BuffUptimeScrollFrame, GameTooltip, BuffUptimeToggleButton, BuffUptimeTotalAttacks
-- GLOBALS: UnitAura, GetSpellInfo
local print = print
local select = select
local pairs = pairs
local tinsert = table.insert
local tsort = table.sort
local floor = math.floor

BINDING_HEADER_BUFFUPTIME = "BuffUptime"
local playerName = UnitName("player")
local UpdateInterval = 2.0
local TimeSinceLastUpdate = 0


BuffUptime = { List = {} }
-- Saved variables
BuffUptimeDB = {}
BuffUptimeDB.enabled = true
BuffUptimeDB.spellCasts = nil
BuffUptimeDB.selfOnly = true
BuffUptimeDB.resetCombat = true
BuffUptimeDB.history = {}
BuffUptimeDB.attacks = 0


-- OnLoad()
function BuffUptime:OnLoad()
	self:RegisterEvent("PLAYER_LOGIN")
end


-- OnEvent()
function BuffUptime:OnEvent(event, ...)
	local name, texture, caster, spellID

	if event == "PLAYER_LOGIN" then
		if BuffUptimeDB.enabled then
			BuffUptimeFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			BuffUptimeFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
			BuffUptimeFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		else
			BuffUptimeFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			BuffUptimeFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
			BuffUptimeFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		end

		-- Allows the frame to be closed with the escape key
		-- tinsert(UISpecialFrames, "BuffUptimeFrame")

	elseif event == "PLAYER_REGEN_DISABLED" then
		if BuffUptimeDB.resetCombat then
			BuffUptimeDB.history = {}
			BuffUptimeDB.attacks = 0
			BuffUptime:UpdateDisplay()
		end

	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		if select(5, ...) == playerName then
			local eventType = select(2,...)
			if eventType and (eventType == "SWING_DAMAGE" or eventType == "RANGE_DAMAGE" or eventType == "SPELL_DAMAGE") then
				for i=1,40 do
					name, _, texture, _, _, _, _, caster, _, _, spellID = UnitAura("player", i, "HELPFUL")
					if name then
						-- Add the buff to the history table
						if not BuffUptimeDB.history[spellID] then
							BuffUptimeDB.history[spellID] = {}
							BuffUptimeDB.history[spellID].name = name
							BuffUptimeDB.history[spellID].texture = texture
						end

						-- Update the buff history
						BuffUptimeDB.history[spellID].count = (BuffUptimeDB.history[spellID].count or 0) + 1
						BuffUptimeDB.history[spellID].caster = caster
					else
						break
					end
				end
				BuffUptimeDB.attacks = BuffUptimeDB.attacks + 1
			end
		end

	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- procs that don't give buffs
		caster, name, _, _, spellID = ...
		if caster == "player" then
			-- Add the buff to the history table
			if not BuffUptimeDB.history[spellID] then
				BuffUptimeDB.history[spellID] = {}
				BuffUptimeDB.history[spellID].name = "*"..name
				BuffUptimeDB.history[spellID].noDuration = true
				BuffUptimeDB.history[spellID].texture = select(3, GetSpellInfo(spellID))
				BuffUptimeDB.history[spellID].caster = caster
			end

			-- Update the buff history
			BuffUptimeDB.history[spellID].count = (BuffUptimeDB.history[spellID].count or 0) + 1
		end
	end
end


-- OnUpdate()
function BuffUptime:OnUpdate(elapsed)
	TimeSinceLastUpdate = TimeSinceLastUpdate + elapsed
	if TimeSinceLastUpdate > UpdateInterval then

		-- Update the buff history if the frame is visible
		if BuffUptimeFrame:IsVisible() then
			BuffUptime:UpdateDisplay()
		end

		TimeSinceLastUpdate = 0
	end
end


-- ToggleAddon() - Enable or disable the addon
function BuffUptime:ToggleAddon()
	BuffUptimeDB.enabled = not BuffUptimeDB.enabled
	if BuffUptimeDB.enabled then
		BuffUptime:DisplayMessage("BuffUptime: Enabled", 0, 1, 0)
		BuffUptimeFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		BuffUptimeFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		BuffUptimeFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	else
		BuffUptime:DisplayMessage("BuffUptime: Disabled", 1, 0, 0)
		BuffUptimeFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		BuffUptimeFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
		BuffUptimeFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	end

	BuffUptime:UpdateDisplay()
end

-- toggle tracking of how often which spell was cast
function BuffUptime:ToggleSpellCasts()
	BuffUptimeDB.spellCasts = not BuffUptimeDB.spellCasts
	if BuffUptimeDB.spellCasts then
		BuffUptime:DisplayMessage("BuffUptime: Tracking cast spells", 0, 1, 0)
	else
		BuffUptime:DisplayMessage("BuffUptime: Not tracking cast spells", 0, 1, 0)
	end

	BuffUptime:UpdateDisplay()
end

-- ToggleSelfOnly() - Only show self buffs or show all buffs
function BuffUptime:ToggleSelfOnly()
	BuffUptimeDB.selfOnly = not BuffUptimeDB.selfOnly
	if BuffUptimeDB.selfOnly then
		BuffUptime:DisplayMessage("BuffUptime: Only showing self buffs", 0, 1, 0)
	else
		BuffUptime:DisplayMessage("BuffUptime: Showing all buffs", 0, 1, 0)
	end

	BuffUptime:UpdateDisplay()
end


-- ToggleResetCombat() - Enable or disable resetting the history between fights
function BuffUptime:ToggleResetCombat()
	BuffUptimeDB.resetCombat = not BuffUptimeDB.resetCombat
	if BuffUptimeDB.resetCombat then
		BuffUptime:DisplayMessage("BuffUptime: Resetting history between fights", 0, 1, 0)
	else
		BuffUptime:DisplayMessage("BuffUptime: Preserving history between fights", 0, 1, 0)
	end
end


-- ToggleDisplay() - Show or hide the frame
function BuffUptime:ToggleDisplay()
	if BuffUptimeFrame:IsVisible() then
		BuffUptimeFrame:Hide()
	else
		BuffUptime:UpdateDisplay()
		BuffUptime:UpdateList()
		BuffUptimeFrame:Show()
	end
end


-- UpdateDisplay() - Update the frame
function BuffUptime:UpdateDisplay()
	BuffUptimeToggleButton:SetNormalTexture(BuffUptimeDB.enabled and "Interface\\TimeManager\\PauseButton" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
	BuffUptimeTotalAttacks:SetText(BuffUptimeDB.attacks)
	if BuffUptimeFrame:IsVisible() then
		BuffUptime:UpdateList()
	end
end


-- Reset() - Reset the history
function BuffUptime:Reset()
	BuffUptimeDB.history = {}
	BuffUptimeDB.attacks = 0
	BuffUptime:DisplayMessage("BuffUptime: Resetting history", 1, 1, 0)
	BuffUptime:UpdateDisplay()
end


-- Slash command
SLASH_BuffUptime1 = "/but"
SlashCmdList["BuffUptime"] = function(msg)
	if msg == "reset" then
		BuffUptime:Reset()
	elseif msg == "enable" then
		BuffUptime:ToggleAddon()
	elseif msg == "show" then
		BuffUptime:ToggleDisplay()
	elseif msg == "selfonly" then
		BuffUptime:ToggleSelfOnly()
	elseif msg == "spellcasts" then
		BuffUptime:ToggleSpellCasts()
	elseif msg == "resetcombat" then
		BuffUptime:ToggleResetCombat()
	else
		print("BuffUptime - list of commands:")
		print("/but enable - Enable or disable the addon")
		print("/but show - Show or hide the buff window")
		print("/but reset - Reset the buff history")
		print("/but selfonly - Show only self buffs or show all buffs")
		print("/but spellcasts - Also track how often you cast spells")
		print("/but resetcombat - Reset or preserve history between fights")
	end
end


-- ShowTooltip() - Display a tooltip when the player hovers over a buff
function BuffUptime.ShowTooltip(self)
	local spellID = self.spellID
	if spellID and BuffUptimeDB.history[spellID] then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
		GameTooltip:SetSpellByID(spellID)
		GameTooltip:Show()
	end
end

-- OnClick()
function BuffUptime.OnClick(self)
	local spellID = self.spellID
	if spellID and BuffUptimeDB.history[spellID] then
		if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
			ChatEdit_InsertLink( GetSpellLink(spellID) )
		end
	end
end


-- ScrollFrameUpdate()
function BuffUptime:ScrollFrameUpdate()
	local offset = FauxScrollFrame_GetOffset(BuffUptimeScrollFrame)	-- Get the scrollbar position
	local list = BuffUptime.List
	local index

	-- Update the scroll frame (arg2 = total number of lines, arg3 = number of lines to show, arg4 = pixel height of each line)
	FauxScrollFrame_Update(BuffUptimeScrollFrame, #(list), 10, 18)

	_G["BuffUptimeList1Name"]:SetText("Buffs")
	_G["BuffUptimeList1Icon"]:SetTexture(nil)
	_G["BuffUptimeList1Hits"]:SetText("Hits")
	_G["BuffUptimeList1Percent"]:SetText("%")

	_G["BuffUptimeList1"]:SetAlpha(.75)
	_G["BuffUptimeList1Icon"]:SetDesaturated(1)

	-- Update the pseudo buttons with the buff details
	for i=2,10 do
		index = offset + i
		if index <= #(list) then
			local history = BuffUptimeDB.history[ list[index] ]
			_G["BuffUptimeList"..i].spellID = list[index]

			_G["BuffUptimeList"..i.."Name"]:SetText(history.name)
			_G["BuffUptimeList"..i.."Icon"]:SetTexture(history.texture)
			_G["BuffUptimeList"..i.."Hits"]:SetText(history.count)
			if history.noDuration then
				_G["BuffUptimeList"..i.."Percent"]:SetText("-")
			else
				_G["BuffUptimeList"..i.."Percent"]:SetText((floor((history.count*100/BuffUptimeDB.attacks)+.5)).."%")
			end

			-- Set the alpha levels
			if BuffUptimeDB.enabled then
				_G["BuffUptimeList"..i]:SetAlpha(1)
				_G["BuffUptimeList"..i.."Icon"]:SetDesaturated(0)
			end
			_G["BuffUptimeList"..i]:Show()
		else
			_G["BuffUptimeList"..i]:Hide()
		end
	end
end


-- UpdateList()
function BuffUptime:UpdateList()
	local list = BuffUptime.List
	for i=1,#(list) do
		list[i] = nil
	end

	for k,v in pairs(BuffUptimeDB.history) do
		if (not BuffUptimeDB.selfOnly or v.caster == "player") and (not BuffUptimeDB.spellCasts or not v.noDuration) then
			tinsert(list, k)
		end
	end

	tsort(list, function(e1, e2)
		local a = BuffUptimeDB.history[e1]
		local b = BuffUptimeDB.history[e2]

		if a.noDuration ~= b.noDuration then
			return not a.noDuration
		elseif a.count ~= b.count then
			return a.count > b.count
		else
			return a.name > b.name
		end
	end)
	BuffUptime:ScrollFrameUpdate()
end


-- DisplayMessage()
function BuffUptime:DisplayMessage(msg, r, g, b)
	if BuffUptimeFrame:IsVisible() then
		BuffUptimeMessage:SetText(msg)
		BuffUptimeMessage:SetTextColor(r, g, b, 1)
		BuffUptimeMessage:SetAlpha(1)
		BuffUptimeMessageFrame.elapsed = 2.0
		BuffUptimeMessageFrame:Show()
	else
		BuffUptimeMessage:SetText("")
		DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)
	end
end


-- MessageOnUpdate() - Used to slowly fade the message
function BuffUptime:MessageOnUpdate(elapsed)
	self.elapsed = self.elapsed - elapsed
	if self.elapsed < 0 then
		BuffUptimeMessageFrame:Hide()
	elseif self.elapsed >= 1 then
		BuffUptimeMessageFrame:SetAlpha(1)
	else
		BuffUptimeMessage:SetAlpha(self.elapsed)
	end
end
