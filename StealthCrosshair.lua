-- 1. SETUP & VARIABLES ----------------------------
local AddonName = "StealthCrosshair"
local frame = CreateFrame("Frame", "StealthCrosshairMain", UIParent)

-- Create textures: Borders on BACKGROUND, Main lines on ARTWORK (so they sit on top)
local hBorder = frame:CreateTexture(nil, "BACKGROUND")
local vBorder = frame:CreateTexture(nil, "BACKGROUND")
local hLine = frame:CreateTexture(nil, "ARTWORK")
local vLine = frame:CreateTexture(nil, "ARTWORK")

-- Default Settings
local defaults = {
    Color = {0, 1, 0, 1}, -- Green
    Size = 25,
    Thickness = 3,
    OffsetX = 0,
    OffsetY = 0,
    BorderThickness = 0,
    BorderColor = {0, 0, 0, 1} -- Black
}

-- 2. CORE FUNCTIONS -------------------------------

-- Updates the look (Color/Size/Position/Border) based on current DB settings
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

    -- Clear previous points to prevent stacking anchors when moving
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

    -- Main Lines
    hLine:SetHeight(t)
    hLine:SetWidth(s)
    hLine:SetPoint("CENTER")
    hLine:SetColorTexture(unpack(c))

    vLine:SetWidth(t)
    vLine:SetHeight(s)
    vLine:SetPoint("CENTER")
    vLine:SetColorTexture(unpack(c))

    -- Borders (Outline)
    -- If BorderThickness is 0, hide them effectively by setting size to 0 or hiding
    if bt > 0 then
        hBorder:Show()
        vBorder:Show()

        -- Border is the size of the line + 2x thickness (for top/bottom and left/right outline)
        hBorder:SetHeight(t + (bt * 2))
        hBorder:SetWidth(s + (bt * 2))
        hBorder:SetPoint("CENTER")
        hBorder:SetColorTexture(unpack(bc))

        vBorder:SetWidth(t + (bt * 2))
        vBorder:SetHeight(s + (bt * 2))
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
        -- Initialize Database
        if not StealthCrosshairDB then
            StealthCrosshairDB = CopyTable(defaults)
        else
            -- Fix Saving: Backfill missing keys (e.g., if user has old DB without Border settings)
            for k, v in pairs(defaults) do
                if StealthCrosshairDB[k] == nil then
                    StealthCrosshairDB[k] = v
                end
            end
        end

        -- Initialize Options Panel (Function defined below)
        self:CreateOptionsPanel()
        -- Apply initial look
        UpdateVisuals()
    end
end)

-- 4. OPTIONS PANEL (SETTINGS) ---------------------
function frame:CreateOptionsPanel()
    -- Create the panel frame
    local panel = CreateFrame("Frame", "StealthCrosshairOptions", UIParent)
    panel.name = "StealthCrosshair"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("StealthCrosshair Settings")

    -- === COLOR PICKER HELPER ===
    local function CreateColorPicker(name, labelText, parent, anchorTo, getVal, setVal)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -30)
        label:SetText(labelText)

        local swatch = CreateFrame("Button", nil, parent, "ColorSwatchTemplate")
        swatch:SetSize(25, 25)
        swatch:SetPoint("LEFT", label, "RIGHT", 10, 0)

        local bg = swatch:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("CENTER")
        bg:SetSize(20, 20)
        local initialColor = getVal()
        bg:SetColorTexture(unpack(initialColor))

        swatch:SetScript("OnClick", function()
            local color = getVal()
            local r, g, b, a = color[1], color[2], color[3], color[4]

            ColorPickerFrame:SetupColorPickerAndShow({
                r = r,
                g = g,
                b = b,
                opacity = a or 1, -- Ensure this is a NUMBER, not a table
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
                    -- Prev is passed as a table by Blizzard: {r, g, b, opacity}
                    setVal({prev.r, prev.g, prev.b, prev.opacity})
                    bg:SetColorTexture(prev.r, prev.g, prev.b, prev.opacity)
                    UpdateVisuals()
                end
            })
        end)
        return label
    end

    -- Main Color Picker
    local colorLabel = CreateColorPicker("MainColor", "Crosshair color", panel, title, function()
        return StealthCrosshairDB.Color
    end, function(val)
        StealthCrosshairDB.Color = val
    end)

    -- Border Color Picker
    local borderColorLabel = CreateColorPicker("BorderColor", "Border color", panel, colorLabel, function()
        return StealthCrosshairDB.BorderColor or defaults.BorderColor
    end, function(val)
        StealthCrosshairDB.BorderColor = val
    end)

    -- === SLIDER HELPER ===
    local function CreateSlider(name, parent, label, minVal, maxVal, getVal, setVal)
        local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        slider:SetWidth(200)
        slider:SetHeight(20)
        slider:SetOrientation('HORIZONTAL')
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)

        -- Set Labels
        _G[name .. "Low"]:SetText(minVal)
        _G[name .. "High"]:SetText(maxVal)
        _G[name .. "Text"]:SetText(label .. ": " .. math.floor(getVal()))

        slider:SetValue(getVal())

        slider:SetScript("OnValueChanged", function(self, value)
            setVal(value)
            _G[name .. "Text"]:SetText(label .. ": " .. math.floor(value))
        end)

        return slider
    end

    -- Size Slider
    local sizeSlider = CreateSlider("StealthCrosshairSizeSlider", panel, "Size", 5, 100, function()
        return StealthCrosshairDB.Size
    end, function(val)
        StealthCrosshairDB.Size = val
        UpdateVisuals()
    end)
    sizeSlider:SetPoint("TOPLEFT", borderColorLabel, "BOTTOMLEFT", 0, -40)

    -- Thickness Slider
    local thicknessSlider = CreateSlider("StealthCrosshairThicknessSlider", panel, "Thickness", 1, 20, function()
        return StealthCrosshairDB.Thickness or defaults.Thickness
    end, function(val)
        StealthCrosshairDB.Thickness = val
        UpdateVisuals()
    end)
    thicknessSlider:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -40)

    -- Border Thickness Slider (New)
    local borderThicknessSlider = CreateSlider("StealthCrosshairBorderThicknessSlider", panel, "Border thickness", 0,
        10, function()
            return StealthCrosshairDB.BorderThickness or defaults.BorderThickness
        end, function(val)
            StealthCrosshairDB.BorderThickness = val
            UpdateVisuals()
        end)
    borderThicknessSlider:SetPoint("TOPLEFT", thicknessSlider, "BOTTOMLEFT", 0, -40)

    -- X Offset Slider
    local xSlider = CreateSlider("StealthCrosshairXSlider", panel, "X offset", -500, 500, function()
        return StealthCrosshairDB.OffsetX or 0
    end, function(val)
        StealthCrosshairDB.OffsetX = val
        UpdateVisuals()
    end)
    xSlider:SetPoint("TOPLEFT", borderThicknessSlider, "BOTTOMLEFT", 0, -40)

    -- Reset X Button
    local resetX = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetX:SetSize(60, 20)
    resetX:SetText("Reset")
    resetX:SetPoint("LEFT", xSlider, "RIGHT", 15, 0)
    resetX:SetScript("OnClick", function()
        StealthCrosshairDB.OffsetX = 0
        xSlider:SetValue(0)
        UpdateVisuals()
    end)

    -- Y Offset Slider
    local ySlider = CreateSlider("StealthCrosshairYSlider", panel, "Y offset", -400, 400, function()
        return StealthCrosshairDB.OffsetY or 0
    end, function(val)
        StealthCrosshairDB.OffsetY = val
        UpdateVisuals()
    end)
    ySlider:SetPoint("TOPLEFT", xSlider, "BOTTOMLEFT", 0, -40)

    -- Reset Y Button
    local resetY = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetY:SetSize(60, 20)
    resetY:SetText("Reset")
    resetY:SetPoint("LEFT", ySlider, "RIGHT", 15, 0)
    resetY:SetScript("OnClick", function()
        StealthCrosshairDB.OffsetY = 0
        ySlider:SetValue(0)
        UpdateVisuals()
    end)

    -- Register the panel
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "StealthCrosshair")
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(panel)
    end
end
