local AddonName, Addon = ...
local Addon = _G[AddonName]
local LSM = LibStub("LibSharedMedia-3.0")

assert(Addon ~= nil, AddonName .. " could not be load")

local assert = assert
local type = type
local unpack = unpack
local getmetatable = getmetatable
local CreateFrame = CreateFrame
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local GetNetStats = GetNetStats
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local IsHarmfulSpell = IsHarmfulSpell
local IsHelpfulSpell = IsHelpfulSpell
local UIParent = UIParent
local INTERRUPTED = INTERRUPTED
local CHANNELING = CHANNELING

function Addon:CreateCastingBar3D(Unit, Parent)
  Parent = Parent or UIParent
  assert(type(Unit) == "string", "Usage : CreateCastingBar3D(Unit[, Parent]) : Wrong argument type for Unit argument")
  local config = assert(self.db.profile[Unit], "Unit has no db")

  local f = self.CreateSparkleStatusBar(AddonName .. Unit, Parent)
  local l = CreateFrame("StatusBar", nil, f)
  local textoverlay = CreateFrame("Frame", nil, f)
  
  local setup = Addon.modelSetups[2]
  local gradient = setup.barGradient
  local modelId = setup.modelId
  local transform = setup.modelTransform
  local sparkColor = setup.sparkColor

  f:ClearAllPoints()
  f:SetPoint("CENTER", Parent, "BOTTOM", config.xoffset, config.yoffset)
  f:Show()

  do 
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(0, 0, 0, 0.4)
    t:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
    t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
  end

  do
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(0, 0, 0)
    t:SetAllPoints(f)
  end

  f:SetWidth(config.width)
  f:SetHeight(config.height)  
  
  do
    local t = f:CreateTexture("StatusBarTexture")
    t:SetTexture(LSM:Fetch("statusbar", "Solid"))
    t:ClearAllPoints()
    f:SetStatusBarTexture(t)
    f:SetSparkleTexture(130877)
    f:SetSparkleColor(unpack(sparkColor))
    f:SetStatusBarColor(1, 1, 1, 1)
    t:SetGradientAlpha("HORIZONTAL", unpack(gradient))
    f:SetFillStyle("STANDARD")
    f:SetMinMaxValues(0.0, 1.0)
  end

  -- Temporary (expectingly) because of a problem affecting attached textures, like sparkle in this case
  f:Hide()
  --

  local m = self:CreateBoundedModel(nil, f)
  m:SetModel(modelId)
  m:SetFrameLevel(2)
  m:SetAllPoints(f:GetStatusBarTexture())
  m:GetBoundedModel():SetAllPoints(f)
  m:GetBoundedModel():SetTransform(unpack(transform))
  m:GetBoundedModel():SetAlpha(setup.modelColor[4])

  textoverlay:SetAllPoints(f)
  textoverlay:SetFrameLevel(3)
  local nametext = textoverlay:CreateFontString()
  nametext:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
  nametext:SetAllPoints(f)
  nametext:SetTextColor(1, 1, 1)

  local timertext = textoverlay:CreateFontString()
  timertext:SetPoint("TOPLEFT", f, "TOPRIGHT", -60, 0)
  timertext:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 0)
  timertext:SetWidth(60)
  timertext:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
  timertext:SetJustifyH("RIGHT")

  l:SetFrameLevel(1)
  l:SetAllPoints(f)
  l:SetHeight(24)

  l:SetStatusBarTexture(LSM:Fetch("statusbar", "Solid"))
  l:GetStatusBarTexture():SetGradientAlpha("HORIZONTAL", 1.0, 0.878, 0.298, 0.0, 1.0, 0.827, 0, 1)
  l:SetAlpha(0.5)
  l:SetFillStyle("REVERSE")
  l:SetMinMaxValues(0.0, 1.0)

  f.fadein = f:CreateAnimationGroup()
  f.fadein:SetLooping("NONE")
  local alpha = f.fadein:CreateAnimation("Alpha")
  alpha:SetDuration(0.2)
  alpha:SetFromAlpha(0.0)
  alpha:SetToAlpha(1.0)
  alpha:SetSmoothing("IN_OUT")

  f.fadeout = f:CreateAnimationGroup()
  f.fadeout:SetLooping("NONE")
  local alpha = f.fadeout:CreateAnimation("Alpha")
  alpha:SetDuration(0.2)
  alpha:SetFromAlpha(1.0)
  alpha:SetToAlpha(0.0)
  alpha:SetStartDelay(0.4)
  alpha:SetSmoothing("IN_OUT")

  local currently_casting = false

  function f:GetCurrentlyCasting()
    return currently_casting
  end

  f.fadein:SetScript(
    "OnPlay",
    function(self, ...)
      currently_casting = true
      f.fadeout:Stop()
      f:Show(true)
    end
  )

  f.fadeout:SetScript(
    "OnPlay",
    function(self, ...)
      currently_casting = false
    end
  )

  f.fadeout:SetScript(
    "OnFinished",
    function(self, ...)
      f:SetShown(false)
    end
  )

  do
    local ccname, cctext, cctexture, ccstime, ccetime, currentTime, cccastID

    f:RegisterEvent(
      "UNIT_SPELLCAST_START",
      function(event, unit, ...)
        if (unit ~= Unit) then
          return
        end
        ccname, cctext, cctexture, ccstime, ccetime, _, cccastID = UnitCastingInfo(unit)
        currentTime = ccstime
        l:SetValue(GetSpellQueueWindow() / (ccetime - ccstime))
        nametext:SetFormattedText("%s", string.sub(cctext, 1, 40))
        f.fadein:Play()
      end
    )

    f:RegisterEvent(
      "UNIT_SPELLCAST_CHANNEL_START",
      function(event, unit, ...)
        if (unit ~= Unit) then
          return
        end
        ccname, cctext, cctexture, ccetime, ccstime, _, cccastID = UnitChannelInfo(unit)
        currentTime = ccetime
        l:SetValue(0)
        nametext:SetFormattedText("%s", string.sub(cctext, 1, 40))
        f.fadein:Play()
      end
    )

    f:RegisterEvent(
      "UNIT_SPELLCAST_STOP",
      function(event, unit, name, rank, castid, spellid)
        if (unit ~= Unit) then
          return
        end
        f.fadeout:Play()
      end
    )

    f:RegisterEvent(
      "UNIT_SPELLCAST_CHANNEL_STOP",
      function(event, unit, name, rank, castid, spellid)
        if (unit ~= Unit) then
          return
        end
        f.fadeout:Play()
      end
    )

    f:RegisterEvent(
      "UNIT_SPELLCAST_INTERRUPTED",
      function(event, unit, name, rank, castid, spellid)
        if (unit ~= Unit) then
          return
        end
        local val = f:GetMinMaxValues()
        nametext:SetText(INTERRUPTED)
        timertext:SetText("")
        f:SetValue(0)
        l:SetValue(0)
        f.fadeout:Play()
      end
    )

    f:RegisterEvent(
      "UNIT_SPELLCAST_SUCCEEDED",
      function(event, unit, name, rank, castid, spellid)
        if (unit ~= Unit) then
          return
        end
        if (castid == cccastID) then
          local _, val = f:GetMinMaxValues()
          currentTime = ccetime
          f:SetValue(val)
        end
      end
    )

    f:SetScript(
      "OnUpdate",
      function(self, rate)
        if (currently_casting) then
          local nmin, nmax = f:GetMinMaxValues()
          currentTime = GetTime() * 1000
          f:SetValue((currentTime - ccstime) / (ccetime - ccstime))
          timertext:SetFormattedText(
            "%.1f",
            math.abs((currentTime - ccstime) / 1000),
            math.abs((ccetime - ccstime) / 1000)
          )
        end
      end
    )
  end

  return f
end
