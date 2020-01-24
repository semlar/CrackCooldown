local SETTINGS = {
	colors = {
		real = {r=1,g=0,b=0,a=1},
		energy = {r=0,g=1,b=1,a=1},
		aura = {r=0,g=1,b=0,a=1},
		default = {r=1,g=1,b=0,a=1},
	},
	font = STANDARD_TEXT_FONT,
	size = 18,
	glint = true,
}

local GetTime, _ = GetTime

local function fTime(s)
	if s >= 86400 then return '%dd',s/86400 end
	if s >= 3600 then return '%dh',s/3600 end
	if s >= 60 then return '%dm',s/60 end
	if s > 9.95 then return '%d',s end
	return '%.1f',s
end

-- Glint animation handler --
local aniCount = 5
local duration = 0.2
local animations = {}
for i=1, aniCount do
	local frame = CreateFrame('Frame')
	local tex = frame:CreateTexture()
	tex:SetTexture([[Interface\Cooldown\star4]])
	tex:SetAlpha(0)
	tex:SetAllPoints()
	tex:SetBlendMode('ADD')
	local group = tex:CreateAnimationGroup()
	local alpha = group:CreateAnimation('Alpha')
	alpha:SetOrder(1)
	alpha:SetFromAlpha(0)
	alpha:SetToAlpha(1)
	alpha:SetDuration(0)
	local scale = group:CreateAnimation('Scale')
	scale:SetOrder(1)
	scale:SetScale(1.5,1.5)
	scale:SetDuration(0)
	local scale2 = group:CreateAnimation('Scale')
	scale2:SetOrder(2)
	scale2:SetScale(0,0)
	scale2:SetDuration(duration)
	local spin = group:CreateAnimation('Rotation')
	spin:SetOrder(2)
	spin:SetDegrees(90)
	spin:SetDuration(duration)
	animations[i] = {frame = frame, group = group}
end

local aniNum = 1
local function animate(button)
	if not SETTINGS.glint or not button:IsVisible() then return end
	local animation = animations[aniNum]
	local frame,group = animation.frame,animation.group
	group:Stop()
	--frame:SetFrameStrata(button:GetFrameStrata())
	frame:SetFrameStrata('HIGH')
	frame:SetFrameLevel(button:GetFrameLevel() + 10)
	frame:SetAllPoints(button)
	group:Play()
	aniNum = (aniNum % aniCount) + 1
end

-- Cooldown spinner and action timers --
timers,actions = {},{}
local function CooldownTimer(parent)
	if timers[parent] then return timers[parent] end
	local timer = CreateFrame('frame', nil, parent)
	timer:SetAllPoints(parent)
	timer:SetFrameLevel(parent:GetFrameLevel() + 3)
	
	timer.text = timer:CreateFontString(nil, 'OVERLAY')
	--timer.text:SetShadowOffset(1,-1)
	timer.text:SetFont(SETTINGS.font or STANDARD_TEXT_FONT, SETTINGS.size or 18, 'OUTLINE')
	
	timer.start = 0
	timer.duration = 0
	
	timers[parent] = timer
	return timer
end

local function ActionTimer(parent)
	if actions[parent] then return actions[parent] end
	local timer = CreateFrame('frame', nil, parent)
	timer:SetAllPoints(parent)
	timer:SetFrameLevel(parent:GetFrameLevel() + 3)
	
	timer.text = timer:CreateFontString(nil, 'OVERLAY')
	--timer.text:SetShadowOffset(1,-1)
	timer.text:SetFont(SETTINGS.font or STANDARD_TEXT_FONT, SETTINGS.size or 18, 'OUTLINE')
	timer.text:SetPoint('CENTER')
	
	---[=[
	timer.border = timer:CreateTexture(nil, 'BACKGROUND')
	timer.border:SetTexture([[Interface\Buttons\CheckButtonHilight]])
	timer.border:SetAllPoints()
	timer.border:SetBlendMode('add')
	timer.border:SetAlpha(0)
	--]=]
	--[=[
	timer.border = CreateFrame('frame', nil, timer)
	timer.border:SetPoint('TOPLEFT', -1, 1)
	timer.border:SetPoint('BOTTOMRIGHT', 1, -1)
	timer.border:SetBackdrop({edgeFile = 'interface/buttons/white8x8', edgeSize = 1})
	timer.border:SetBackdropBorderColor(0,0,0)
	--]=]
	--t:SetVertexColor(0, 0.25, 1, 1)
	
	--timer.action = parent:GetAttribute('action') or ActionButton_CalculateAction(parent)
	timer.action = parent:GetAttribute('action') or  ActionButton_GetPagedID(parent) or ActionButton_CalculateAction(parent)
	
	actions[parent] = timer
	return timer
end

local function SetTimer(parent, start, duration, action)
	if not parent then return end
	local timer = CooldownTimer(parent)
	timer.start = start or 0
	timer.duration = duration or 0
end

-- Fires normally when a cooldown spinner is set, except on action buttons, which behave spuriously
--ActionButton1.cooldown
hooksecurefunc(getmetatable(CreateFrame('cooldown')).__index, 'SetCooldown', function(cooldown, start, duration, enable)
	if not cooldown:IsForbidden() then
		local parent = cooldown:GetParent()
		if parent and not parent:IsForbidden() then
			if parent and parent.GetAttribute and parent:GetAttribute('type') == 'action' then return end
			--if cooldown:GetReverse() then return end -- breaks weak auras
			local width = cooldown:GetWidth() or 0
			if width and width < 100 then -- hack to pevent numbers from showing up on honor frame
				SetTimer(cooldown, start, duration, 'spinner')
			end
		end
	end
end)

-- Hook for action buttons created by an addon like bartender
hooksecurefunc(getmetatable(CreateFrame('checkbutton', nil, nil, 'SecureActionButtonTemplate')).__index, 'SetAttribute', function(button, attribute, slot)
	--if attribute ~= 'action' or not HasAction(slot) then return end
	if attribute ~= 'action' or not slot or type(slot) ~= 'number' or not HasAction(slot) then return end
	if not actions[button] then
		ActionTimer(button)
	end
	actions[button].action = slot
end)

--SpellFlyoutButtonTemplate, buttons have .spellID attribute


-- Loop through every frame in the interface to register existing action buttons
local function GetActionButtons(...)
	for i = 1, select('#',...) do
		local frame = select(i, ...)
		if not frame:IsForbidden() then
			if frame:GetNumChildren() > 0 then
				GetActionButtons(frame:GetChildren())
			end
			if frame:GetAttribute('type') == 'action' then
				ActionTimer(frame)
			end
		end
	end
end
--GetActionButtons(UIParent:GetChildren())

-- Play Glint animation on any action buttons that match
hooksecurefunc('UseAction', function(slot1, target, mouseButton)
	for button,timer in pairs(actions) do
		--local slot2 = button:GetAttribute('action') or  ActionButton_GetPagedID(button) or ActionButton_CalculateAction(button)
		if slot1 == timer.action and button:IsVisible() then
			animate(button)
		end
	end
end)


local function SetTimerTime(timer,left,color)
	local width = timer:GetWidth() or 0
	if not timer:IsVisible() or width <= 0 or left <= 0 then timer.text:SetText('') return end
	if timer.border and color then
		if IsUsableAction(timer.action) and color == SETTINGS.colors.aura then
			timer.border:SetVertexColor(SETTINGS.colors.aura.r,SETTINGS.colors.aura.g,SETTINGS.colors.aura.b,SETTINGS.colors.aura.a)
		else
			timer.border:SetVertexColor(SETTINGS.colors.real.r,SETTINGS.colors.real.g,SETTINGS.colors.real.b,SETTINGS.colors.real.a)
		end
	end
	if not color then color = SETTINGS.colors.default end
	timer.text:SetTextColor(color.r or 1, color.g or 1, color.b or 0, color.a or 1)
	timer.text:ClearAllPoints()
	-- todo: only resize font strings when the frame resizes instead of setting the font every single update
	-- :HookScript('OnSizeChanged', fixFonts)
	local p = timer:GetParent()
	if p then p = p:GetParent() end
	if p.GetName and p:GetName() and p:GetName():find('^Gwtarget') then
		timer.text:SetText('')
	else
		if width < 27 then
			if left < 60 then
				timer.text:SetPoint("CENTER", timer, "TOPRIGHT")
				timer.text:SetFont(SETTINGS.font or STANDARD_TEXT_FONT, width*(SETTINGS.size/26), "OUTLINE")
				timer.text:SetFormattedText("%d", left)
			else
				timer.text:SetText('')
			end
		else
			timer.text:SetPoint('CENTER')
			if left < 600 then
				timer.text:SetFont(SETTINGS.font or STANDARD_TEXT_FONT, width*(SETTINGS.size/36), "OUTLINE")
			else
				timer.text:SetFont(SETTINGS.font or STANDARD_TEXT_FONT, width*(SETTINGS.size/45), "OUTLINE")
			end
			timer.text:SetFormattedText(fTime(left))
		end
	end
end


--\\---------------------------\\--
--//   MANY AURAS, HANDLE IT   //--
--\\---------------------------\\--
local GetSpellInfo = GetSpellInfo
local auras = {} -- [aura name] = expiration time
local SharedAurasList = { -- [aura name] = psuedo group
	-- "Temporarily" removed for 6.0
}
local SharedAuras = {}
for spellID, aura in pairs(SharedAurasList) do -- Fill up table with spell names instead of IDs so I don't have to track down every last ID for the same spell
	local spellName = GetSpellInfo(spellID)
	if spellName then
		SharedAuras[spellName] = aura
	end
end

local MisnamedAuraList, MisnamedAuras = {
    [125359] = 100787, -- Tiger Power = Tiger Palm
    [115307] = 100784, -- Shuffle = Blackout Kick
	
	[199603] = 193316, -- Skull and Crossbones = Roll the Bones
	[193358] = 193316, -- Grand Melee
	[193357] = 193316, -- Ruthless Precision
	[193359] = 193316, -- True Bearing
	[199600] = 193316, -- Burried Treasure
	[193356] = 193316, -- Broadside
}, {}

for auraID, spellID in pairs(MisnamedAuraList) do
    local auraName = GetSpellInfo(auraID)
    local spellName = GetSpellInfo(spellID)
    if auraName and spellName then
        MisnamedAuras[auraName] = spellName
    end
end

-- keep track of auras on you, your target, and your pet
--[[
local MisnamedAuras = {
	['Tiger Power'] = 'Tiger Palm',
	['Shuffle'] = 'Blackout Kick',
}
--]]



local StickyAuras = {} -- things to keep track of regardless of target, like my crowd controls, single-target abilities
local function updateAuras()
	wipe(auras) -- lazy
	
	
	if UnitExists('pet') then -- Regardless of whether the player has a target, if we have a pet then add the pet's auras to the list
		for i = 1,40 do
			local name, _, _, _, _, expires, caster, _, _, spellID = UnitBuff('pet', i)
			if not name then break end
			if caster == "player" and expires > 0 then -- not sure if this needs any more logic here
				auras[name] = expires
			end
		end
	end
	
	local unit = (UnitExists("target") and (UnitIsPlayer("target") or UnitCanAttack("player", "target"))) and "target" or "player"
	if UnitIsFriend("player", unit) then
		for i = 1,40 do
			local name, _, _, _, _, expires, caster = UnitBuff(unit, i)
			--local name, rank, icon, count, dispelType, duration, expires, caster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, value1, value2, value3 = UnitBuff(unit, i)
			if not name then break end
			if caster == "player" and expires > 0 then
				if (auras[name] and expires > auras[name]) or not auras[name] then
					auras[name] = expires
				end
			elseif SharedAuras[name] and expires > 0 then
				auras[SharedAuras[name]] = expires
			end
		end
		for i = 1,40 do
			local name, _, _, _, _, expires, caster, _, _, spellID = UnitBuff("player", i)
			if not name then break end
			if caster == "player" and expires > 0 and SpellIsSelfBuff(spellID) then
				--if name == 'Tiger Power' then name = 'Tiger Palm' end
				if MisnamedAuras[name] then name = MisnamedAuras[name] end
				if (auras[name] and expires > auras[name]) or not auras[name] then
					auras[name] = expires
				end
			end
		end
	else
		for i = 1,40 do
			local name, _, _, _, _, expires, caster = UnitDebuff(unit, i)
			if not name then break end
			if caster == "player" and expires > 0 then
				if (auras[name] and expires > auras[name]) or not auras[name] then
					auras[name] = expires
				end
			elseif SharedAuras[name] and expires > 0 then
				auras[SharedAuras[name]] = expires
			end
		end
		for i = 1,40 do
			local name, _, _, _, _, expires, caster = UnitBuff("player", i)
			if not name then break end
			if caster == "player" and expires > 0 then
				--if name == 'Tiger Power' then name = 'Tiger Palm' end
				if MisnamedAuras[name] then name = MisnamedAuras[name] end
				if (auras[name] and expires > auras[name]) or not auras[name] then
					auras[name] = expires
				end
			elseif SharedAuras[name] and expires > 0 then
				auras[SharedAuras[name]] = expires
			end
		end
	end
end

--[[
local CostTip = CreateFrame('GameTooltip')
local CostText = CostTip:CreateFontString()
CostTip:AddFontStrings(CostTip:CreateFontString(), CostTip:CreateFontString())
CostTip:AddFontStrings(CostText, CostTip:CreateFontString())
local function GetPowerCost(spellID) -- returns the value of the second line of the tooltip
	if not spellID then return end
	CostTip:SetOwner(WorldFrame, 'ANCHOR_NONE')
	CostTip:SetSpellByID(spellID)
	return CostText:GetText()
end

local PowerPatterns = {
	[0] = '^' .. gsub(MANA_COST, '%%d', '([.,%%d]+)', 1) .. '$',
	[2] = '^' .. gsub(FOCUS_COST, '%%d', '([.,%%d]+)', 1) .. '$',
	[3] = '^' .. gsub(ENERGY_COST, '%%d', '([.,%%d]+)', 1) .. '$',
}
--]]

function GetPowerCost(spellID)
	local powerType = UnitPowerType('player')
	local costTable = GetSpellPowerCost(spellID)
	for _, costInfo in pairs(costTable) do
		if costInfo.type == powerType then
			return costInfo.cost
		end
	end
end


local f,ts = CreateFrame('frame'),0
f:SetScript('OnUpdate', function(self, e)
	ts = ts + e
	if ts >= 0.1 then
		local now,left,parent,timer = GetTime(),0
		for parent,timer in pairs(timers) do
			if timer.duration > 2.2 then
				left = timer.start + timer.duration - now
				SetTimerTime(timer,left)
			end
		end
		
		local PlayerPowerType = UnitPowerType('player')
		--local powerPattern = PowerPatterns[PlayerPowerType]
		local passiveRegen, activeRegen = GetPowerRegen()
		local regenRate = UnitAffectingCombat("player") and activeRegen or passiveRegen
		local currentPower = UnitPower('player', PlayerPowerType)
		for button,timer in pairs(actions) do
			--local slot = timer.action or button:GetAttribute('action') or  ActionButton_GetPagedID(button) or ActionButton_CalculateAction(button)
			local slot = button:GetAttribute('action') or  ActionButton_GetPagedID(button) or ActionButton_CalculateAction(button)
			timer.action = slot
			if HasAction(slot) and button:IsVisible() then
				local start, duration, enabled, currentCharges, totalCharges = GetActionCooldown(slot)
				
				local realCooldown, energyCooldown, auraDuration = 0, 0, 0
				local btype, id = GetActionInfo(slot)
				if btype == 'macro' then _,_,id = GetMacroSpell(id) end -- tainting the global underscore, could use select() here
				if btype == 'item' then
					local name = GetItemInfo(id)
					if name and auras[name] then
						auraDuration = auras[name]-now
					end
				elseif btype == 'spell' or (btype == 'macro' and id) then
					--local name, _, _, cost, _, power = GetSpellInfo(id)
					local name = GetSpellInfo(id)
					if name then
						-- They've removed power type and cost from GetSpellInfo in WoD for some reason
						-- So we're implementing a hack to pull it out of the spell tooltip
						--local costText = GetPowerCost(id)
						--local cost = powerPattern and costText and strmatch(costText, powerPattern)
						local cost = GetPowerCost(id)
						if auras[name] then
							auraDuration = auras[name] - now
							--SpellIsSelfBuff(id)
						elseif SharedAuras[name] and auras[SharedAuras[name]] then
							auraDuration = auras[SharedAuras[name]] - now
						end
						
						--if powerPattern and PlayerPowerType == power and cost > 0 then -- because GetPowerRegen only works for the active energy type
						if cost then
							--cost = gsub(cost, LARGE_NUMBER_SEPERATOR, '') + 0
							cost = gsub(cost, '%D', '') + 0
							--local currentPower = UnitPower("player", power)
							if cost and cost > currentPower then
								--local passiveRegen, activeRegen = GetPowerRegen()
								--local regenRate = UnitAffectingCombat("player") and activeRegen or passiveRegen
								local powerDifference = cost - currentPower
								if regenRate >= 1 then
									energyCooldown = powerDifference/regenRate
								end
							end
						end
					end
				end
				
				left = start + duration - now
				if left > energyCooldown and left > 0 and duration > 2.2 then
					if enabled == 1 then
						SetTimerTime(timer,left,SETTINGS.colors.real)
					else
						SetTimerTime(timer,left,{r=0.6,g=0.6,b=0.6,a=1})
					end
				elseif energyCooldown > 0 then
					SetTimerTime(timer,energyCooldown,SETTINGS.colors.energy)
				elseif auraDuration > 0 then
					SetTimerTime(timer,auraDuration,SETTINGS.colors.aura)
				else
					timer.text:SetText('')
					timer.border:SetVertexColor(1,1,1,0)
				end
			else
				timer.text:SetText('')
				timer.border:SetVertexColor(1,1,1,0)
			end
		end
		ts = 0
	end
end)

local function recalculateActions()
	for button,timer in pairs(actions) do
		timer.action = button:GetAttribute('action') or ActionButton_GetPagedID(button) or ActionButton_CalculateAction(button)
	end
end


local addonName = ...
local function CreateInterfacePanel() -- TODO: Clean this up
	--InterfaceOptions_AddCategory
	local frame = CreateFrame('frame')
	frame.name = addonName
	
	local title = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
	title:SetPoint('TOPLEFT', 16, -16)
	title:SetText(addonName .. ' Configuration')
	
	local function CreateTimer(name)
		local timer = CreateFrame('button', nil, frame, 'ActionButtonTemplate')
		timer:SetSize(36,36)
		timer.text = timer:CreateFontString(nil, 'OVERLAY')
		timer.text:SetFont(SETTINGS.font or STANDARD_TEXT_FONT, SETTINGS.size or 18, 'OUTLINE')
		timer.text:SetPoint('CENTER')
		timer.text:SetText('8m')
		
		timer.icon:SetTexture('interface/icons/inv_mushroom_11')
		
		timer.border = timer:CreateTexture(nil, 'OVERLAY')
		timer.border:SetTexture([[Interface\Buttons\CheckButtonHilight]])
		timer.border:SetAllPoints()
		timer.border:SetBlendMode('add')
		
		timer.subtext = timer:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
		timer.subtext:SetPoint('TOP', timer, 'BOTTOM', 0, -2)
		timer.subtext:SetText(name or '')
		return timer
	end
	
	local defaultTimer = CreateTimer('Default')
	defaultTimer:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -10)
	
	local realTimer = CreateTimer('Real')
	realTimer:SetPoint('TOPLEFT', defaultTimer, 'TOPRIGHT', 20, 0)
	
	local energyTimer = CreateTimer('Energy')
	energyTimer:SetPoint('TOPLEFT', realTimer, 'TOPRIGHT', 20, 0)
	
	local auraTimer = CreateTimer('Aura')
	auraTimer:SetPoint('TOPLEFT', energyTimer, 'TOPRIGHT', 20, 0)
	
	local function colorCallback(restore)
		local newR, newG, newB, newA
		if restore then
			newR, newG, newB, newA = unpack(restore)
		else
			newA, newR, newG, newB = OpacitySliderFrame:GetValue(), ColorPickerFrame:GetColorRGB()
		end
		return newR, newG, newB, newA
		--SETTINGS.colors.default.r, SETTINGS.colors.default.g, SETTINGS.colors.default.b, SETTINGS.colors.default.a = newR, newG, newB, newA
	end
	
	local function defaultCallback(restore)
		SETTINGS.colors.default.r, SETTINGS.colors.default.g, SETTINGS.colors.default.b, SETTINGS.colors.default.a = colorCallback(restore)
		defaultTimer.text:SetTextColor(SETTINGS.colors.default.r, SETTINGS.colors.default.g, SETTINGS.colors.default.b, SETTINGS.colors.default.a)
	end
	
	local function realCallback(restore)
		SETTINGS.colors.real.r, SETTINGS.colors.real.g, SETTINGS.colors.real.b, SETTINGS.colors.real.a = colorCallback(restore)
		realTimer.text:SetTextColor(SETTINGS.colors.real.r, SETTINGS.colors.real.g, SETTINGS.colors.real.b, SETTINGS.colors.real.a)
		realTimer.border:SetVertexColor(SETTINGS.colors.real.r, SETTINGS.colors.real.g, SETTINGS.colors.real.b, SETTINGS.colors.real.a)
		energyTimer.border:SetVertexColor(SETTINGS.colors.real.r, SETTINGS.colors.real.g, SETTINGS.colors.real.b, SETTINGS.colors.real.a)
	end
	
	local function energyCallback(restore)
		SETTINGS.colors.energy.r, SETTINGS.colors.energy.g, SETTINGS.colors.energy.b, SETTINGS.colors.energy.a = colorCallback(restore)
		energyTimer.text:SetTextColor(SETTINGS.colors.energy.r, SETTINGS.colors.energy.g, SETTINGS.colors.energy.b, SETTINGS.colors.energy.a)
		energyTimer.border:SetVertexColor(SETTINGS.colors.real.r, SETTINGS.colors.real.g, SETTINGS.colors.real.b, SETTINGS.colors.real.a)
	end
	
	local function auraCallback(restore)
		SETTINGS.colors.aura.r, SETTINGS.colors.aura.g, SETTINGS.colors.aura.b, SETTINGS.colors.aura.a = colorCallback(restore)
		auraTimer.text:SetTextColor(SETTINGS.colors.aura.r, SETTINGS.colors.aura.g, SETTINGS.colors.aura.b, SETTINGS.colors.aura.a)
		auraTimer.border:SetVertexColor(SETTINGS.colors.aura.r, SETTINGS.colors.aura.g, SETTINGS.colors.aura.b, SETTINGS.colors.aura.a)
	end
	
	local function ShowColorPicker(r, g, b, a, changedCallback)
		ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = (a ~= nil), a
		ColorPickerFrame.previousValues = {r,g,b,a}
		ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = changedCallback, changedCallback, changedCallback
		ColorPickerFrame:SetColorRGB(r,g,b)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end
	
	local color = SETTINGS.colors.default
	defaultTimer.text:SetTextColor(color.r, color.g, color.b, color.a)
	defaultTimer.border:Hide()
	defaultTimer:SetScript('OnClick', function()
		ShowColorPicker(color.r, color.g, color.b, color.a, defaultCallback)
	end)
	
	local color = SETTINGS.colors.real
	realTimer.text:SetTextColor(color.r, color.g, color.b, color.a)
	realTimer.border:SetVertexColor(color.r, color.g, color.b, color.a)
	realTimer:SetScript('OnClick', function()
		ShowColorPicker(color.r, color.g, color.b, color.a, realCallback)
	end)
	
	energyTimer.border:SetVertexColor(SETTINGS.colors.energy.r,SETTINGS.colors.energy.g,SETTINGS.colors.energy.b,SETTINGS.colors.energy.a)
	local color = SETTINGS.colors.energy
	energyTimer.text:SetTextColor(color.r, color.g, color.b, color.a)
	energyTimer.border:SetVertexColor(SETTINGS.colors.real.r, SETTINGS.colors.real.g, SETTINGS.colors.real.b, SETTINGS.colors.real.a)
	energyTimer:SetScript('OnClick', function()
		ShowColorPicker(color.r, color.g, color.b, color.a, energyCallback)
	end)
	
	local color = SETTINGS.colors.aura
	auraTimer.text:SetTextColor(color.r, color.g, color.b, color.a)
	auraTimer.border:SetVertexColor(color.r, color.g, color.b, color.a)
	auraTimer:SetScript('OnClick', function()
		ShowColorPicker(color.r, color.g, color.b, color.a, auraCallback)
	end)
	
	local sizeSlider = CreateFrame('slider', 'CrackCooldownConfigSizeSlider', frame, 'OptionsSliderTemplate')
	sizeSlider:SetPoint('TOPLEFT', defaultTimer, 'BOTTOMLEFT', 0, -30)
	--CrackCooldownConfigSizeSliderText:SetText('Font Size')
	CrackCooldownConfigSizeSliderLow:SetText('Font Size')
	sizeSlider:SetScript('OnValueChanged', function(self, value)
		SETTINGS.size = value
		defaultTimer.text:SetFont(SETTINGS.font, SETTINGS.size, "OUTLINE")
		realTimer.text:SetFont(SETTINGS.font, SETTINGS.size, "OUTLINE")
		energyTimer.text:SetFont(SETTINGS.font, SETTINGS.size, "OUTLINE")
		auraTimer.text:SetFont(SETTINGS.font, SETTINGS.size, "OUTLINE")
		CrackCooldownConfigSizeSliderHigh:SetText(value)
	end)
	--sizeSlider:SetSize(100,20)
	sizeSlider:SetPoint('LEFT', sizeText, 'RIGHT', 5, 0)
	sizeSlider:SetMinMaxValues(12, 24)
	sizeSlider:SetValue(SETTINGS.size)
	CrackCooldownConfigSizeSliderHigh:SetText(SETTINGS.size)
	sizeSlider:SetValueStep(2)
	
	local glintCheckBox = CreateFrame('checkbutton', 'CrackCooldownConfigGlintCheckBox', frame, 'ChatConfigCheckButtonTemplate')
	glintCheckBox:SetPoint('LEFT', sizeSlider, 'RIGHT', 10, 0)
	CrackCooldownConfigGlintCheckBoxText:SetPoint('LEFT', CrackCooldownConfigGlintCheckBox, 'RIGHT', 5, 0)
	CrackCooldownConfigGlintCheckBoxText:SetText('Glint')
	glintCheckBox.tooltip = 'Sparkley thing'
	glintCheckBox:SetChecked(SETTINGS.glint)
	glintCheckBox:SetScript('OnClick', function(self) SETTINGS.glint = self:GetChecked() and true or false end)
	
	InterfaceOptions_AddCategory(frame)
	
	SLASH_CRACKCOOLDOWN1 = '/crackcooldown'
	function SlashCmdList.CRACKCOOLDOWN() InterfaceOptionsFrame_OpenToCategory(frame) end
end

f:SetScript('OnEvent', function(self, event, ...)
	if event == 'UNIT_AURA' or event == 'PLAYER_TARGET_CHANGED' then
		updateAuras()
	--elseif event == 'ACTIONBAR_SLOT_CHANGED' or event == 'ACTIONBAR_PAGE_CHANGED' then
		--recalculateActions()
	elseif event == 'PLAYER_LOGIN' then
		GetActionButtons(UIParent:GetChildren())
	elseif event == 'ADDON_LOADED' and ... == addonName then
		SETTINGS = CrackCooldownSettings or SETTINGS
		CrackCooldownSettings = SETTINGS
		CreateInterfacePanel()
		updateAuras()
		f:RegisterEvent('UNIT_AURA')
		f:RegisterEvent('PLAYER_TARGET_CHANGED')
		--f:RegisterEvent('ACTIONBAR_SLOT_CHANGED') -- looping through every action button on this event is overkill
		--f:RegisterEvent('ACTIONBAR_PAGE_CHANGED')
	elseif event == 'VARIABLES_LOADED' then
		SetCVar('countdownForCooldowns', 0) -- Disable blizzard cooldown text
	--elseif event == 'UNIT_SPELLCAST_SUCCEEDED' or event == 'UNIT_SPELLCAST_START' then
		--local unitID = ...
		--if unitID == 'pet' then
			--print(IsSpellInRange("Growl", "pet-target"), event, ...)
			-- returns in range after UNIT_SPELLCAST_SUCCEEDED for bite
		--end
	end
end)

f:RegisterEvent('ADDON_LOADED')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('VARIABLES_LOADED')