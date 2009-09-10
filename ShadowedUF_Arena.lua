--[[ 
	Shadow Unit Frames (Arena), Mayen of US-Mal'Ganis PvP
]]

local L = {
	["Arena"] = "Arena",
	["Arena pet"] = "Arena pet",
	["Arena target"] = "Arena target",
	["Arena frames"] = "Arena frames",
	["Arena #%d"] = "Arena #%d",
}

local Arena = {}
ShadowUF:RegisterModule(Arena, "arena")

function Arena:OnDefaultsSet()
	ShadowUF.defaults.profile.units.arena.height = 55
	ShadowUF.defaults.profile.units.arena.width = 190
	ShadowUF.defaults.profile.units.arena.offset = 0
	ShadowUF.defaults.profile.units.arena.attribPoint = "TOP"
	ShadowUF.defaults.profile.units.arena.indicators.raidTarget = nil
	
	ShadowUF.defaults.profile.positions.arena = {anchorPoint = "C", anchorTo = "UIParent", point = "", relativePoint = "", x = 0, y = 0}
	ShadowUF.defaults.profile.positions.arenapet = {anchorPoint = "RB", anchorTo = "$parent", x = 0, y = 0}
	ShadowUF.defaults.profile.positions.arenatarget = {anchorPoint = "RT", anchorTo = "$parent", x = 0, y = 0}
	
	-- Make the new mover function support the arena units as well.
	ShadowUF.arenaUnits = {}
	for i=1, 5 do
		table.insert(ShadowUF.arenaUnits, "arena" .. i)
	end
	
	-- Make the mover work with this
	ShadowUF.modules.movers.headers.arena = "arenaUnits"
	ShadowUF.modules.movers.headerDesc.arena = L["Arena frames"]
	ShadowUF.modules.movers.childHeaders.arenapet = "arena"
	ShadowUF.modules.movers.childHeaders.arenatarget = "arena"
	ShadowUFLocals.headers["arena"] = L["Arena #%d"]
end

-- Ripped a lot of this out of SecureTemplates.lua, shame it's not global
local function getRelativeAnchor(point)
    point = string.upper(point)
    if( point == "TOP") then
        return "BOTTOM", 0, -1
    elseif( point == "BOTTOM") then
        return "TOP", 0, 1
    elseif( point == "LEFT") then
        return "RIGHT", 1, 0
    elseif( point == "RIGHT") then
        return "LEFT", -1, 0
    elseif( point == "TOPLEFT") then
        return "BOTTOMRIGHT", 1, -1
    elseif( point == "TOPRIGHT") then
        return "BOTTOMLEFT", -1, -1
    elseif( point == "BOTTOMLEFT") then
        return "TOPRIGHT", 1, 1
    elseif( point == "BOTTOMRIGHT") then
        return "TOPLEFT", -1, 1
    else
        return "CENTER", 0, 0
    end
end

function Arena:UpdateHeader()
	if( not ShadowUF.Units.unitFrames.arena ) then return end

	local frame = ShadowUF.Units.unitFrames.arena
	local config = ShadowUF.db.profile.units.arena

    local point = frame:GetAttribute("point") or "TOP"
    local relativePoint, xOffsetMulti, yOffsetMulti = getRelativeAnchor(point)
	frame:SetAttribute("point", config.attribPoint)
	frame:SetAttribute("xOffset", config.offset * xOffsetMulti)
	frame:SetAttribute("yOffset", config.offset * yOffsetMulti)
	
	if( #(frame.children) == 0 ) then return end

    local xMultiplier, yMultiplier = math.abs(xOffsetMulti), math.abs(yOffsetMulti)
    local x = frame:GetAttribute("xOffset") or 0
    local y = frame:GetAttribute("yOffset") or 0
	
	for id, child in pairs(frame.children) do
		if( id > 1 ) then
			frame.children[id]:ClearAllPoints()
			frame.children[id]:SetPoint(point, frame.children[id - 1], relativePoint, xMultiplier * x, yMultiplier * y)
		else
			frame.children[id]:ClearAllPoints()
			frame.children[id]:SetPoint(point, frame, point, 0, 0)
		end
	end

	ShadowUF.Layout:AnchorFrame(UIParent, ShadowUF.Units.unitFrames.arena, ShadowUF.db.profile.positions.arena)
end

-- OnUpdate for the arena children
local function OnUpdate(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	if( self.timeElapsed >= self.pollInterval ) then
		self.timeElapsed = 0
		
		if( self.exists and not UnitExists(self.unit) ) then
			self.exists = nil
			self.pollInterval = 0.5
		elseif( not self.exists and UnitExists(self.unit) ) then
			self.exists = true
			self.pollInterval = 1
			self.parent:FullUpdate()
		end
	end
end

-- OnEvent for the arena header
local instanceType
local function OnEvent(self, event)
	local type = select(2, IsInInstance())
	-- Entered an arena, weren't in one before
	if( type == "arena" and instanceType ~= type ) then
		for id, unit in pairs(ShadowUF.arenaUnits) do
			-- Frame doesn't exist yet, create it
			if( not self.children[id] ) then
				local frame = CreateFrame("Button", self:GetName() .. "UnitButton" .. id, self, "SecureUnitButtonTemplate")
				ShadowUF.Units:CreateUnit(frame)
				frame.ignoreAnchor = true
				frame:SetAttribute("unit", unit)
				
				-- We don't want frames to hide after they've been shown, so will lock them in place
				-- this prevents them from hiding if a Rogue vanishes and such
				self:WrapScript(frame, "OnAttributeChanged", [[
					if( name == "state-unitexists" ) then
						if( value ) then
							self:SetAttribute("lockedVisible", true)
							self:Show()
						elseif( not value and not self:GetAttribute("lockedVisible") ) then
							self:Hide()
						end
					end
				]])
				
				RegisterUnitWatch(frame, true)
				self.children[id] = frame
				
				-- When a unit becomes invalid due to them stealthing after seeing them they are considered offline
				-- normally this wouldn't be an issue since unit watch handles it, but since I override it, also need
				-- to do a poll and check if we have to update the frames when they are back
				frame.existFrame = CreateFrame("Frame", nil, frame)
				frame.existFrame.pollInterval = 1
				frame.existFrame.timeElapsed = 0
				frame.existFrame.parent = frame
				frame.existFrame:SetScript("OnUpdate", OnUpdate)
			end

			-- Create the child units
			if( ShadowUF.Units.loadedUnits.arenapet ) then
				ShadowUF.Units:LoadChildUnit(self, unit, "arenapet", "arenapet" .. id)
			end

			if( ShadowUF.Units.loadedUnits.arenatarget ) then
				ShadowUF.Units:LoadChildUnit(self, unit, "arenatarget", unit .. "target")
			end

			-- Unlock them of course too
			self.children[id]:SetAttribute("lockedVisible", false)
			self.children[id].existFrame.exists = true
			self.children[id].existFrame.unit = unit
		end

		Arena:UpdateHeader()
	-- We were in an arena
	elseif( type ~= "arena" and instanceType == "arena" ) then
		for _, child in pairs(self.children) do
			child:SetAttribute("lockedVisible", false)
			child:Hide()
		end
	end
	
	instanceType = type
end

-- Hook in the arena unitid and handle creation and stuff
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event)
	if( not IsAddOnLoaded("ShadowedUnitFrames") ) then return end
	self:UnregisterAllEvents()
	
	-- For me mostly, so if I break something in SUF this doens't error.
	if( not ShadowUF or not ShadowUF.Units or not ShadowUF.modules.movers ) then return end
	
	table.insert(ShadowUF.units, "arena")
	table.insert(ShadowUF.units, "arenatarget")
	table.insert(ShadowUF.units, "arenapet")
	ShadowUFLocals.units.arena = L["Arena"]
	ShadowUFLocals.units.arenapet = L["Arena pet"]
	ShadowUFLocals.units.arenatarget = L["Arena target"]
	
	-- Realllllllllllly I shouldn't do this, but it's such a corner case because the only unit that truly needs this is the arena units, not really
	-- worth it for me to add plugins for something a single module uses when I can just hook it.
	local OnInitialize = ShadowUF.OnInitialize
	ShadowUF.OnInitialize = function(self)
		OnInitialize(self)
		
		-- Basically, the first time we load this we need to set the layout data, because we do not re-import the layout
		-- so pretty much, we're hacking in another units configuration (In this case, arenas)
		if( not ShadowUF.db.profile.units.arena.healthBar.height ) then
			ShadowUF.db.profile.units.arena = CopyTable(ShadowUF.db.profile.units.party)
			-- Except, arena frames do not have indicators attached to them so will just kill those off
			ShadowUF.db.profile.units.arena.indicators = nil
			ShadowUF.defaults.profile.units.arena.indicators = nil
		end
		
		if( not ShadowUF.db.profile.units.arenapet.healthBar.height ) then
			ShadowUF.db.profile.units.arenapet = CopyTable(ShadowUF.db.profile.units.partypet)
			ShadowUF.db.profile.units.arenapet.enabled = false
			ShadowUF.db.profile.units.arenapet.indicators = nil
			ShadowUF.defaults.profile.units.arenapet.indicators = nil
		end

		if( not ShadowUF.db.profile.units.arenatarget.healthBar.height ) then
			ShadowUF.db.profile.units.arenatarget = CopyTable(ShadowUF.db.profile.units.partytarget)
			ShadowUF.db.profile.units.arenatarget.enabled = false
			ShadowUF.db.profile.units.arenatarget.indicators = nil
			ShadowUF.defaults.profile.units.arenatarget.indicators = nil
		end
	end
		
	-- Check if our unit was initialized
	local InitializeFrame = ShadowUF.Units.InitializeFrame
	ShadowUF.Units.InitializeFrame = function(self, config, type)
		if( type == "arena" ) then
			-- While arena# do not actually provide a header, we do a fake one to make faking it easier
			if( not self.unitFrames[type] ) then
				local header = CreateFrame("Frame", "SUFHeaderarena", UIParent, "SecureHandlerBaseTemplate")
				header:SetScript("OnEvent", OnEvent)
				header:SetClampedToScreen(true)
				header:SetMovable(true)
				header:SetHeight(0.1)
				header:SetWidth(0.1)
				header.unitType = "arena"
				header.children = {}
				header.isHeaderFrame = true
				
				self.unitFrames[type] = header
				
				-- Do a quick check to make sure we aren't in an arena already
				OnEvent(header)
			end
			
			self.unitFrames[type]:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			self.unitFrames[type]:RegisterEvent("PLAYER_ENTERING_WORLD")
			ShadowUF.Layout:AnchorFrame(UIParent, self.unitFrames[type], ShadowUF.db.profile.positions[type])

			self.loadedUnits[type] = true
			return
		elseif( type == "arenapet" ) then
			self.loadedUnits[type] = true

			for id, unit in pairs(ShadowUF.arenaUnits) do
				if( self.loadedUnits.arena and self.unitFrames[unit] ) then
					self:LoadChildUnit(self.unitFrames.arena, unit, type, type .. id)
				end
			end
		elseif( type == "arenatarget" ) then
			self.loadedUnits[type] = true

			for id, unit in pairs(ShadowUF.arenaUnits) do
				if( self.loadedUnits.arena and self.unitFrames[unit] ) then
					self:LoadChildUnit(self.unitFrames.arena, unit, type, "arena" .. id .. "target")
				end
			end
		end
		
		return InitializeFrame(self, config, type)
	end

	-- Check if the frame was uninitialized
	local UninitializeFrame = ShadowUF.Units.UninitializeFrame
	ShadowUF.Units.UninitializeFrame = function(self, config, type)
		if( type == "arena" ) then
			self.loadedUnits[type] = nil
			
			if( self.unitFrames[type] ) then
				self.unitFrames[type]:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
				self.unitFrames[type]:UnregisterEvent("PLAYER_ENTERING_WORLD")
			end
			return
		end
		
		return UninitializeFrame(self, config, type)
	end
end)

function Arena:OnConfigurationLoad()
	local getAnchorParents = ShadowUF.Config.getAnchorParents
	local childAnchor = {["$parent"] = L["Arena frames"]}
	ShadowUF.Config.getAnchorParents = function(info)
		if( info[2] == "arenapet" or info[2] == "arenatarget" ) then
			return childAnchor
		end
		
		return getAnchorParents(info)
	end
	
	ShadowUF.Config.unitTable.args.frame.args.anchor.args.anchorTo.values = ShadowUF.Config.getAnchorParents
	ShadowUF.Config.unitTable.args.frame.args.position.args.anchorTo.values = ShadowUF.Config.getAnchorParents
	ShadowUF.Config.unitTable.args.arena = {
		order = 1.5,
		type = "group",
		name = L["Arena"],
		hidden = function(info) return info[2] ~= "arena" end,
		set = function(info, value)
			ShadowUF.Config.setUnit(info, value)
			ShadowUF.modules.movers:Update()
			Arena:UpdateHeader()
		end,
		get = ShadowUF.Config.getUnit,
		args = {
			general = {
				type = "group",
				inline = true,
				name = ShadowUFLocals["General"],
				hidden = false,
				args = {
					offset = {
						order = 2,
						type = "range",
						name = ShadowUFLocals["Row offset"],
						min = 0, max = 100, step = 1,
						arg = "offset",
					},
					attribPoint = {
						order = 3,
						type = "select",
						name = ShadowUFLocals["Frame growth"],
						desc = ShadowUFLocals["How the frame should grow when new group members are added."],
						values = {["TOP"] = ShadowUFLocals["Down"], ["LEFT"] = ShadowUFLocals["Right"], ["BOTTOM"] = ShadowUFLocals["Up"], ["RIGHT"] = ShadowUFLocals["Left"]},
						arg = "attribPoint",
					},
				},
			},
		},
	}
end
