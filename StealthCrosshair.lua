-- 1. SETUP & VARIABLES ----------------------------
local AddonName = "StealthCrosshair"
local frame = CreateFrame("Frame", "StealthCrosshairMain", UIParent)
local unpack = unpack
local tostring = tostring
local tonumber = tonumber

local hBorder = frame:CreateTexture(nil, "BACKGROUND")
local vBorder = frame:CreateTexture(nil, "BACKGROUND")
local hLine = frame:CreateTexture(nil, "ARTWORK")
local vLine = frame:CreateTexture(nil, "ARTWORK")

-- Static anchors (set once at initialization)
hLine:SetPoint("CENTER")
vLine:SetPoint("CENTER")
hBorder:SetPoint("CENTER")
vBorder:SetPoint("CENTER")

local defaults = {
    Color = { 0, 1, 0, 1 },
    Size = 25,
    Thickness = 3,
    OffsetX = 0,
    OffsetY = 0,
    BorderThickness = 0,
    BorderColor = { 0, 0, 0, 1 },
}

-- 2. CORE FUNCTIONS -------------------------------

local function UpdateVisuals()
    if not StealthCrosshairDB then
        return
    end

    local c = StealthCrosshairDB.Color or defaults.Color
    local s = StealthCrosshairDB.Size or defaults.Size
    local t = StealthCrosshairDB.Thickness or defaults.Thickness
    local x = StealthCrosshairDB.OffsetX or 0
    local y = StealthCrosshairDB.OffsetY or 0
    local bt = StealthCrosshairDB.BorderThickness or defaults.BorderThickness
    local bc = StealthCrosshairDB.BorderColor or defaults.BorderColor

    frame:SetSize(s, s)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

    hLine:SetSize(s, t)
    hLine:SetColorTexture(unpack(c))

    vLine:SetSize(t, s)
    vLine:SetColorTexture(unpack(c))

    if bt > 0 then
        hBorder:Show()
        vBorder:Show()
        hBorder:SetSize(s + (bt * 2), t + (bt * 2))
        hBorder:SetColorTexture(unpack(bc))
        vBorder:SetSize(t + (bt * 2), s + (bt * 2))
        vBorder:SetColorTexture(unpack(bc))
    else
        hBorder:Hide()
        vBorder:Hide()
    end
end

RegisterStateDriver(frame, "visibility", "[stealth] show; hide")

-- 3. EVENT HANDLING -------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        if not StealthCrosshairDB then
            StealthCrosshairDB = CopyTable(defaults)
        end
        self:CreateOptionsPanel()
        UpdateVisuals()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- 4. OPTIONS PANEL (SETTINGS) ---------------------
function frame:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "StealthCrosshairOptions", UIParent)
    panel.name = "StealthCrosshair"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Stealth Crosshair Settings")

    -- Layout cursor: chains each row below the previous
    local lastAnchor = title
    local function AddRow(label)
        label:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, lastAnchor == title and -25 or -20)
        lastAnchor = label
    end

    -- COLOR PICKER HELPER
    local function CreateColorPicker(labelText, getVal, setVal)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetSize(120, 20)
        label:SetJustifyH("LEFT")
        label:SetText(labelText)

        local swatch = CreateFrame("Button", nil, panel, "ColorSwatchTemplate")
        swatch:SetSize(28, 28)
        swatch:SetPoint("LEFT", label, "RIGHT", 10, 0)

        local bg = swatch:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("CENTER")
        bg:SetSize(22, 22)
        bg:SetColorTexture(unpack(getVal()))

        local colorScratch = {}
        local function onColorChanged()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = ColorPickerFrame:GetColorAlpha()
            colorScratch[1], colorScratch[2], colorScratch[3], colorScratch[4] = nr, ng, nb, na
            setVal(colorScratch)
            bg:SetColorTexture(nr, ng, nb, na)
            UpdateVisuals()
        end

        swatch:SetScript("OnClick", function()
            local color = getVal()
            ColorPickerFrame:SetupColorPickerAndShow({
                r = color[1], g = color[2], b = color[3],
                opacity = color[4] or 1,
                hasOpacity = true,
                swatchFunc = onColorChanged,
                opacityFunc = onColorChanged,
                cancelFunc = function(prev)
                    colorScratch[1], colorScratch[2], colorScratch[3], colorScratch[4] = prev.r, prev.g, prev.b,
                        prev.opacity
                    setVal(colorScratch)
                    bg:SetColorTexture(prev.r, prev.g, prev.b, prev.opacity)
                    UpdateVisuals()
                end,
            })
        end)
        swatch.bg = bg
        return label, swatch
    end

    -- INPUT HELPER
    local function CreateInput(name, labelText, getVal, setVal)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetSize(120, 20)
        label:SetJustifyH("LEFT")
        label:SetText(labelText)

        local eb = CreateFrame("EditBox", name, panel, "InputBoxTemplate")
        eb:SetSize(80, 24)
        eb:SetAutoFocus(false)
        eb:SetTextInsets(5, 5, 0, 0)
        eb:SetPoint("LEFT", label, "RIGHT", 10, 0)

        local function Refresh()
            eb:SetText(tostring(getVal() or ""))
            eb:SetCursorPosition(0)
        end

        eb:SetScript("OnEnterPressed", function(self)
            local val = tonumber(self:GetText())
            if val then setVal(val); UpdateVisuals() end
            self:ClearFocus()
        end)
        eb:SetScript("OnEditFocusLost", Refresh)
        panel:HookScript("OnShow", Refresh)
        Refresh()
        return label, eb
    end

    -- COLOR ROWS
    local mainLabel, mainSwatch = CreateColorPicker("Crosshair Color",
        function() return StealthCrosshairDB.Color end,
        function(v) StealthCrosshairDB.Color = v end)
    AddRow(mainLabel)

    local borderLabel, borderSwatch = CreateColorPicker("Border Color",
        function() return StealthCrosshairDB.BorderColor end,
        function(v) StealthCrosshairDB.BorderColor = v end)
    AddRow(borderLabel)

    -- NUMERIC INPUT ROWS (data-driven)
    local inputDefs = {
        { "SCSizeEB", "Crosshair Size:", "Size" },
        { "SCThickEB", "Line Thickness:", "Thickness" },
        { "SCBThickEB", "Border Width:", "BorderThickness" },
        { "SCXEB", "Horizontal (X):", "OffsetX" },
        { "SCYEB", "Vertical (Y):", "OffsetY" },
    }
    local editBoxes = {}
    for _, def in ipairs(inputDefs) do
        local id, text, key = def[1], def[2], def[3]
        local label, eb = CreateInput(id, text,
            function() return StealthCrosshairDB[key] end,
            function(v) StealthCrosshairDB[key] = v end)
        AddRow(label)
        editBoxes[key] = eb
    end

    local inputTip = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    inputTip:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -10)
    inputTip:SetText("Press Enter in any box to save the new value.")

    -- RESET BUTTON
    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(160, 30)
    resetButton:SetText("Restore defaults")
    resetButton:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -40)
    resetButton:SetScript("OnClick", function()
        _G["StealthCrosshairDB"] = nil
        StealthCrosshairDB = CopyTable(defaults)
        for key, eb in pairs(editBoxes) do
            eb:SetText(tostring(defaults[key]))
        end
        mainSwatch.bg:SetColorTexture(unpack(defaults.Color))
        borderSwatch.bg:SetColorTexture(unpack(defaults.BorderColor))
        UpdateVisuals()
        print("|cFF00FF00StealthCrosshair|r: Restored default settings.")
    end)

    local resetHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    resetHint:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -8)
    resetHint:SetText("Use this if encountering any issues or LUA errors.")
    resetHint:SetTextColor(0.8, 0.4, 0.4)

    -- Register panel
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "StealthCrosshair")
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(panel)
    end
end
