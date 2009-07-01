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
	ShadowUF.defaults.profile.units.arena.xOffset = 0
	ShadowUF.defaults.profile.units.arena.yOffset = 0
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
	ShadowUF.modules.movers.headers.arena = true
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
	frame:SetAttribute("point", config.attribPoint)
	frame:SetAttribute("xOffset", config.xOffset)
	frame:SetAttribute("yOffset", config.yOffset)
	
	if( #(frame.children) == 0 ) then return end
	
    local point = frame:GetAttribute("point") or "TOP"
    local relativePoint, xOffsetMulti, yOffsetMulti = getRelativeAnchor(point)
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

local instanceType
local function OnEvent(self, event)
	local type = select(2, IsInInstance())
	-- Entered an arena, weren't in one before
	if( type == "arena" and instanceType ~= type ) then
		for i=1, 5 do
			if( not self.children[i] ) then
				local frame = CreateFrame("Button", self:GetName() .. "UnitButton" .. i, self, "SecureUnitButtonTemplate")
				ShadowUF.Units:CreateUnit(frame)
				
				frame.ignoreAnchor = true
				frame:SetAttribute("unit", "arena" .. i)
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
				
				self.children[i] = frame
				RegisterUnitWatch(frame, true)

				self:SetAttribute("lockedVisible", false)

				-- Create the child units
				if( ShadowUF.Units.loadedUnits.arenapet ) then
					ShadowUF.Units:LoadChildUnit(self.children[i], "arenapet", "arenapet" .. i)
				end

				if( ShadowUF.db.profile.units.arenatarget.enabled ) then
					ShadowUF.Units:LoadChildUnit(self.children[i], "arenatarget", "arena" .. i .. "target")
				end
			end
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

	-- Hooking my own code, how fun!
	local CreateHeader = ShadowUF.modules.movers.CreateHeader
	ShadowUF.modules.movers.CreateHeader = function(self, type, ...)
		CreateHeader(self, type, ...)
		if( type ~= "arena" or not SUFMoverarena ) then return end
		SUFMoverarena:SetHeight(0.1)
		SUFMoverarena:SetWidth(0.1)
	end
	
	-- Realllllllllllly I shouldn't do this, but it's such a corner case because the only unit that truly needs this is the arena units, not really
	-- worth it for me to add plugins for something a single module uses when I can just hook it.
	local OnInitialize = ShadowUF.OnInitialize
	ShadowUF.OnInitialize = function(...)
		OnInitialize(...)
		
		-- Basically, the first time we load this we need to set the layout data, because we do not re-import the layout
		-- so pretty much, we're hacking in another units configuration (In this case, arenas)
		if( not ShadowUF.db.profile.units.arena.healthBar.height ) then
			ShadowUF.db.profile.units.arena = CopyTable(ShadowUF.db.profile.units.party)
			-- Except, arena frames do not have indicators attached to them so will just kill those off
			ShadowUF.db.profile.units.arena.indicators = {}
		end
		
		if( not ShadowUF.db.profile.units.arenapet.healthBar.height ) then
			ShadowUF.db.profile.units.arenapet = CopyTable(ShadowUF.db.profile.units.partypet)
			ShadowUF.db.profile.units.arenapet.enabled = false
			ShadowUF.db.profile.units.arenapet.indicators = {}
		end

		if( not ShadowUF.db.profile.units.arenatarget.healthBar.height ) then
			ShadowUF.db.profile.units.arenatarget = CopyTable(ShadowUF.db.profile.units.partytarget)
			ShadowUF.db.profile.units.arenatarget.enabled = false
			ShadowUF.db.profile.units.arenatarget.indicators = {}
		end
	end
	
	-- See if we need to add postioning data for the frames
	local ReloadHeader = ShadowUF.Units.ReloadHeader
	ShadowUF.Units.ReloadHeader = function(self, type, ...)
		if( type == "arenatarget" or type == "arenapet" ) then
			for _, frame in pairs(self.unitFrames) do
				if( frame.unitType == type ) then
					ShadowUF.Layout:AnchorFrame(self.unitFrames[ShadowUF.arenaUnits[frame.unitID]], frame, ShadowUF.db.profile.positions[type])
				end
			end
			return
		end
		
		return ReloadHeader(self, type, ...)
	end
	
	-- Check if our unit was initialized
	local InitializeFrame = ShadowUF.Units.InitializeFrame
	ShadowUF.Units.InitializeFrame = function(self, config, type, ...)
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
				
				self.unitFrames[type] = header
				
				-- Do a quick check to make sure we aren't in an arena already
				OnEvent(header)
			end
			
			self.unitFrames[type]:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			ShadowUF.Layout:AnchorFrame(UIParent, self.unitFrames[type], ShadowUF.db.profile.positions[type])
			return
		elseif( type == "arenapet" or type == "arenatarget" ) then
			for id=1, 5 do
				if( self.loadedUnits[ShadowUF.arenaUnits[i]] ) then
					self:LoadChildUnit(self.loadedUnits[ShadowUF.arenaUnits[i]], type, type .. id)
				end
			end
		end
		
		return InitializeFrame(self, config, type, ...)
	end

	-- Check if the frame was uninitialized
	local UninitializeFrame = ShadowUF.Units.UninitializeFrame
	ShadowUF.Units.UninitializeFrame = function(self, config, type, ...)
		if( type == "arena" ) then
			if( self.unitFrames[type] ) then
				self.unitFrames[type]:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
			end
			return
		end
		
		return UninitializeFrame(self, config, type, ...)
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
				args = {
					xOffset = {
						order = 1,
						type = "range",
						name = ShadowUFLocals["X Offset"],
						min = -50, max = 50, step = 1,
						hidden = function(info)
							local point = ShadowUF.Config.getVariable(info[2], nil, nil, "attribPoint")
							return point ~= "LEFT" and point ~= "RIGHT"
						end,
						arg = "xOffset",
					},
					yOffset = {
						order = 2,
						type = "range",
						name = ShadowUFLocals["Y Offset"],
						min = -50, max = 50, step = 1,
						hidden = function(info)
							local point = ShadowUF.Config.getVariable(info[2], nil, nil, "attribPoint")
							return point ~= "TOP" and point ~= "BOTTOM"
						end,
						arg = "yOffset",
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
