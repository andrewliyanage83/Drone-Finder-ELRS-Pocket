-- Drone Finder v3.6p (monochrome port) - original by michalek.me
-- Original target: Radiomaster TX15 / color EdgeTX (LVGL UI)
--
-- Modified 2026-06-21 by Andrew Liyanage:
--   Ported to Radiomaster Pocket (128x64 monochrome, classic lcd API).
--   The LVGL circular gauge has been replaced with a horizontal signal
--   bar that fills toward 100% as the signal gets stronger (closer to
--   the drone). Telemetry reading and Geiger-style audio are unchanged.
--
-- License: GPL-3.0 (see LICENSE). This is a modified version of the
-- original work and is distributed under the same license.

local app_ver = "3.6p"

local lastUpdate = 0
local lastBeep   = 0
local lastDetect = 0
local updateEveryTicks = 2
local detectEveryTicks = 100

local beepEnabled = true

local raw, kind = -120, "NA"
local avg = -120
local signalPercent = 0
local battV, battSrc = nil, "NA"

local alphaNormal = 0.40
local alphaDrop   = 0.88

local have = { rssi=false, snr=false, rql=false, vfas=false, rxbt=false, batt=false, a4=false }

local function clamp(x, a, b)
  if x < a then return a elseif x > b then return b else return x end
end

-- ---------- Telemetry (hardware-agnostic, unchanged) ----------
local function detectSensors()
  have.rssi = (getFieldInfo("1RSS") ~= nil)
  have.snr  = (getFieldInfo("RSNR") ~= nil)
  have.rql  = (getFieldInfo("RQly") ~= nil)
  have.vfas = (getFieldInfo("VFAS") ~= nil)
  have.rxbt = (getFieldInfo("RxBt") ~= nil)
  have.batt = (getFieldInfo("Batt") ~= nil)
  have.a4   = (getFieldInfo("A4")   ~= nil)
end

local function readSignal()
  local v
  if have.rssi then
    v = getValue("1RSS")
    if v and v ~= 0 then return v, "1RSS" end
  end
  if have.snr then
    v = getValue("RSNR")
    if v and v ~= 0 then return (v * 2 - 120), "RSNR" end
  end
  if have.rql then
    v = getValue("RQly")
    if v and v ~= 0 then return (v - 120), "RQly" end
  end
  return -120, "NA"
end

local function readBattery()
  local v
  if have.vfas then v = getValue("VFAS"); if v and v ~= 0 then return v, "VFAS" end end
  if have.rxbt then v = getValue("RxBt"); if v and v ~= 0 then return v, "RxBt" end end
  if have.batt then v = getValue("Batt"); if v and v ~= 0 then return v, "Batt" end end
  if have.a4   then v = getValue("A4");   if v and v ~= 0 then return v, "A4"   end end
  return nil, "NA"
end

local function estimateCells(v)
  if not v then return nil end
  if v < 5.0  then return 1 end
  if v < 8.8  then return 2 end
  if v < 13.2 then return 3 end
  if v < 17.6 then return 4 end
  if v < 22.0 then return 5 end
  if v < 26.4 then return 6 end
  return nil
end

-- ---------- Monochrome UI (128x64) ----------
local function drawUI()
  lcd.clear()
  local W = LCD_W   -- 128 on the Pocket
  local H = LCD_H   -- 64  on the Pocket

  -- Header bar (inverted title)
  lcd.drawFilledRectangle(0, 0, W, 11)
  lcd.drawText(2, 1, "DRONE FINDER", SMLSIZE + INVERS)
  lcd.drawText(W - 1, 1, "v" .. app_ver, SMLSIZE + INVERS + RIGHT)

  -- Big signal percentage (left)
  lcd.drawText(3, 13, tostring(signalPercent) .. "%", DBLSIZE)

  -- Signal type + raw value (right)
  lcd.drawText(W - 1, 13, tostring(kind), SMLSIZE + RIGHT)
  lcd.drawText(W - 1, 22, tostring(raw) .. "dBm", SMLSIZE + RIGHT)

  -- Scale ticks at 25 / 50 / 75 %
  local barX, barY = 3, 36
  local barW, barH = W - 6, 15
  local innerW = barW - 4
  for _, p in ipairs({25, 50, 75}) do
    local tx = barX + 2 + math.floor(innerW * p / 100)
    lcd.drawLine(tx, barY - 3, tx, barY - 1, SOLID, FORCE)
  end

  -- Signal bar: fills toward 100% the closer you get
  lcd.drawRectangle(barX, barY, barW, barH)
  local fillW = math.floor(innerW * signalPercent / 100)
  if fillW > 0 then
    lcd.drawFilledRectangle(barX + 2, barY + 2, fillW, barH - 4)
  end

  -- Bottom line: battery (blinks when low) + sound state
  local battStr
  local battLow = false
  if battV then
    local cells = estimateCells(battV)
    if cells then
      battStr = string.format("%.2fV %ds", battV, cells)
      if (battV / cells) < 3.40 then battLow = true end
    else
      battStr = string.format("%.2fV", battV)
    end
  else
    battStr = "Batt NA"
  end
  lcd.drawText(2, 55, battStr, SMLSIZE + (battLow and BLINK or 0))
  lcd.drawText(W - 1, 55, beepEnabled and "SND ON" or "SND OFF", SMLSIZE + RIGHT)
end

-- ---------- Update loop (telemetry + audio, unchanged logic) ----------
local function updateData(now)
  if now - lastDetect >= detectEveryTicks then
    lastDetect = now
    detectSensors()
  end

  if now - lastUpdate >= updateEveryTicks then
    lastUpdate = now
    raw, kind = readSignal()
    battV, battSrc = readBattery()

    if kind == "NA" or raw <= -118 then
      avg = avg * (1 - alphaDrop) + raw * alphaDrop
    else
      avg = avg * (1 - alphaNormal) + raw * alphaNormal
    end

    local s = clamp((avg + 110) * (100 / 70), 0, 100)
    signalPercent = math.floor(s + 0.5)

    if beepEnabled then
      local period = clamp(120 - signalPercent, 10, 120)
      if now - lastBeep >= period then
        playTone(650 + (signalPercent * 6), 35, 0, 0)
        lastBeep = now
      end
    end
  end
end

-- ---------- EdgeTX entry points ----------
local function init()
  detectSensors()
  return 0
end

local function run(event)
  local now = getTime()

  if event == EVT_VIRTUAL_ENTER or event == EVT_ENTER_BREAK then
    beepEnabled = not beepEnabled
  end

  updateData(now)
  drawUI()
  return 0
end

return { init = init, run = run }
