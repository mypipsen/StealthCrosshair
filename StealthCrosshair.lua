-- 1. SETUP & VARIABLES ----------------------------
local AddonName = "StealthCrosshair"
local frame = CreateFrame("Frame", "StealthCrosshairMain", UIParent)

local hBorder = frame:CreateTexture(nil, "BACKGROUND")
local vBorder = frame:CreateTexture(nil, "BACKGROUND")
local hLine = frame:CreateTexture(nil, "ARTWORK")
local vLine = frame:CreateTexture(nil, "ARTWORK")

local defaults = {
    Color = {0, 1, 0, 1},
    Size = 25,
    Thickness = 3,
    OffsetX = 0,
    OffsetY = 0,
    BorderThickness = 0,
    BorderColor = {0, 0, 0, 1}
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
    hLine:SetPoint("CENTER")
    hLine:SetColorTexture(unpack(c))

    vLine:SetSize(t, s)
    vLine:SetPoint("CENTER")
    vLine:SetColorTexture(unpack(c))

    if bt > 0 then
        hBorder:Show()
        vBorder:Show()
        hBorder:SetSize(s + (bt * 2), t + (bt * 2))
        hBorder:SetPoint("CENTER")
        hBorder:SetColorTexture(unpack(bc))
        vBorder:SetSize(t + (bt * 2), s + (bt * 2))
        vBorder:SetPoint("CENTER")
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
    end
end)

-- 4. OPTIONS PANEL (SETTINGS) ---------------------
function frame:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "StealthCrosshairOptions", UIParent)
    panel.name = "StealthCrosshair"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Stealth Crosshair Settings")

    -- ALIGNED COLOR PICKER HELPER
    local function CreateColorPicker(name, labelText, parent, anchorTo, getVal, setVal)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetSize(120, 20) -- Matched to Input width for alignment
        label:SetJustifyH("LEFT")
        label:SetText(labelText)

        local swatch = CreateFrame("Button", nil, parent, "ColorSwatchTemplate")
        swatch:SetSize(28, 28)
        -- Standardized offset (10px gap from the 120px label)
        swatch:SetPoint("LEFT", label, "RIGHT", 10, 0)

        local bg = swatch:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("CENTER")
        bg:SetSize(22, 22)
        bg:SetColorTexture(unpack(getVal()))

        swatch:SetScript("OnClick", function()
            local color = getVal()
            ColorPickerFrame:SetupColorPickerAndShow({
                r = color[1],
                g = color[2],
                b = color[3],
                opacity = color[4] or 1,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    setVal({nr, ng, nb, na})
                    bg:SetColorTexture(nr, ng, nb, na)
                    UpdateVisuals()
                end,
                opacityFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    setVal({nr, ng, nb, na})
                    bg:SetColorTexture(nr, ng, nb, na)
                    UpdateVisuals()
                end,
                cancelFunc = function(prev)
                    setVal({prev.r, prev.g, prev.b, prev.opacity})
                    bg:SetColorTexture(prev.r, prev.g, prev.b, prev.opacity)
                    UpdateVisuals()
                end
            })
        end)
        swatch.bg = bg
        return label, swatch
    end

    -- ALIGNED EDITBOX HELPER
    local function CreateInput(name, parent, labelText, getVal, setVal)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetSize(120, 20)
        label:SetJustifyH("LEFT")
        label:SetText(labelText)

        local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
        eb:SetSize(80, 24)
        eb:SetAutoFocus(false)
        eb:SetTextInsets(5, 5, 0, 0)
        eb:SetPoint("LEFT", label, "RIGHT", 10, 0)

        local function Refresh()
            local val = getVal()
            eb:SetText(tostring(val or ""))
            eb:SetCursorPosition(0)
        end

        eb:SetScript("OnEnterPressed", function(self)
            local val = tonumber(self:GetText())
            if val then
                setVal(val)
                UpdateVisuals()
            end
            self:ClearFocus()
        end)

        eb:SetScript("OnEditFocusLost", Refresh)
        panel:HookScript("OnShow", Refresh)

        Refresh()
        return label, eb
    end

    -- Setup Layout
    local mainColorLabel, mainSwatch = CreateColorPicker("MainColor", "Crosshair Color", panel, title, function()
        return StealthCrosshairDB.Color
    end, function(val)
        StealthCrosshairDB.Color = val
    end)
    mainColorLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -25)

    local borderColorLabel, borderSwatch = CreateColorPicker("BorderColor", "Border Color", panel, mainColorLabel,
        function()
            return StealthCrosshairDB.BorderColor
        end, function(val)
            StealthCrosshairDB.BorderColor = val
        end)
    borderColorLabel:SetPoint("TOPLEFT", mainColorLabel, "BOTTOMLEFT", 0, -20)

    local sizeLabel, sizeEB = CreateInput("SCSizeEB", panel, "Crosshair Size:", function()
        return StealthCrosshairDB.Size
    end, function(val)
        StealthCrosshairDB.Size = val
    end)
    sizeLabel:SetPoint("TOPLEFT", borderColorLabel, "BOTTOMLEFT", 0, -20)

    local thickLabel, thickEB = CreateInput("SCThickEB", panel, "Line Thickness:", function()
        return StealthCrosshairDB.Thickness
    end, function(val)
        StealthCrosshairDB.Thickness = val
    end)
    thickLabel:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -20)

    local bThickLabel, bThickEB = CreateInput("SCBThickEB", panel, "Border Width:", function()
        return StealthCrosshairDB.BorderThickness
    end, function(val)
        StealthCrosshairDB.BorderThickness = val
    end)
    bThickLabel:SetPoint("TOPLEFT", thickLabel, "BOTTOMLEFT", 0, -20)

    local xLabel, xEB = CreateInput("SCXEB", panel, "Horizontal (X):", function()
        return StealthCrosshairDB.OffsetX
    end, function(val)
        StealthCrosshairDB.OffsetX = val
    end)
    xLabel:SetPoint("TOPLEFT", bThickLabel, "BOTTOMLEFT", 0, -20)

    local yLabel, yEB = CreateInput("SCYEB", panel, "Vertical (Y):", function()
        return StealthCrosshairDB.OffsetY
    end, function(val)
        StealthCrosshairDB.OffsetY = val
    end)
    yLabel:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 0, -20)

    local inputTip = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    inputTip:SetPoint("TOPLEFT", yLabel, "BOTTOMLEFT", 0, -10)
    inputTip:SetText("Press Enter in any box to save the new value.")

    -- RESET BUTTON
    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(160, 30)
    resetButton:SetText("Restore defaults")
    resetButton:SetPoint("TOPLEFT", yLabel, "BOTTOMLEFT", 0, -40)
    resetButton:SetScript("OnClick", function()
        _G["StealthCrosshairDB"] = nil
        StealthCrosshairDB = CopyTable(defaults)

        -- Refresh UI
        sizeEB:SetText(tostring(defaults.Size))
        thickEB:SetText(tostring(defaults.Thickness))
        bThickEB:SetText(tostring(defaults.BorderThickness))
        xEB:SetText(tostring(defaults.OffsetX))
        yEB:SetText(tostring(defaults.OffsetY))
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
