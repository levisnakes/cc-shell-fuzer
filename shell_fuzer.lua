-- Shell Fuzer (mining turtle): takes shells from the INPUT barrel, places one
-- in front, waits for a hopper above that spot to drop a fuze in, breaks it
-- again and sends the fuzed shell to OUTPUT.

INPUT_SIDE = "up"         -- barrel with unfuzed shells: "up" or "down"
OUTPUT_SIDE = "down"      -- where fuzed shells go: "up" or "down"

-- Seconds a placed shell waits for the hopper before being broken again.
-- A shell that comes back without a fuze is simply tried again.
FUZE_WAIT = 0.5

-- Shells to fuze. Anything else from the barrel is passed straight to OUTPUT.
SHELLS = {
  "createbigcannons:he_shell",
  "createbigcannons:ap_shell",
  "createbigcannons:shrapnel_shell",
  "createbigcannons:fluid_shell",
  "createbigcannons:smoke_shell",
  "createbigcannons:drop_mortar_shell",
}

-- Misses in a row before the screen says the hopper is out of fuzes
OUT_OF_FUZES_AFTER = 3
AUTO_UPDATE = true        -- install new versions from GitHub automatically, keeping these settings

-- Settings in /config.lua override the ones above. Use it for anything you
-- don't want to retype: it survives reinstalls and updates, and one file can
-- be shared by every computer (each program ignores settings it doesn't use).
do
  local path = "/config.lua"
  if fs.exists(path) then
    local fn, err = loadfile(path, "t", _ENV)
    if fn then
      local ok, runErr = pcall(fn)
      if not ok then printError("config.lua: " .. tostring(runErr)) sleep(3) end
    else
      printError("config.lua: " .. tostring(err))
      sleep(3)
    end
  end
end

-- ==================================================================== main

if not turtle then error("Shell Fuzer must run on a turtle", 0) end

local SIDE = {
  up = { suck = turtle.suckUp, drop = turtle.dropUp },
  down = { suck = turtle.suckDown, drop = turtle.dropDown },
}
if not SIDE[INPUT_SIDE] then error("INPUT_SIDE must be \"up\" or \"down\"", 0) end
if not SIDE[OUTPUT_SIDE] then error("OUTPUT_SIDE must be \"up\" or \"down\"", 0) end
if INPUT_SIDE == OUTPUT_SIDE then error("INPUT_SIDE and OUTPUT_SIDE can't be the same", 0) end

local isShell = {}
for _, name in ipairs(SHELLS) do isShell[name] = true end

local stats = { fuzed = 0, passed = 0, misses = 0 }
local missStreak = 0
local status = "Starting"
local placed = false      -- a shell of ours is sitting in front

local function setStatus(text)
  if text ~= status then
    status = text
    os.queueEvent("fuzer_redraw")
  end
end

-- A shell's item carries a component hash ("nbt") once a fuze (or tracer) is
-- in it; a fresh shell from the crafter has none.
local function hasFuze(item)
  return item.nbt ~= nil
end

local function countFuzed()
  local n = 0
  for slot = 1, 16 do
    local item = turtle.getItemDetail(slot)
    if item and isShell[item.name] and hasFuze(item) then n = n + item.count end
  end
  return n
end

-- Send fuzed shells and anything that isn't a shell to OUTPUT.
-- Returns false if OUTPUT is full.
local function emptyOutput()
  for slot = 1, 16 do
    local item = turtle.getItemDetail(slot)
    if item and not (isShell[item.name] and not hasFuze(item)) then
      turtle.select(slot)
      if not SIDE[OUTPUT_SIDE].drop() then return false end
      if isShell[item.name] then
        stats.fuzed = stats.fuzed + item.count
      else
        stats.passed = stats.passed + item.count
      end
      os.queueEvent("fuzer_redraw")
    end
  end
  return true
end

local function findUnfuzed()
  for slot = 1, 16 do
    local item = turtle.getItemDetail(slot)
    if item and isShell[item.name] and not hasFuze(item) then return slot end
  end
end

local function hasFreeSlot()
  for slot = 1, 16 do
    if turtle.getItemCount(slot) == 0 then return true end
  end
  return false
end

local function breakFront()
  local before = countFuzed()
  local ok, err = turtle.dig()
  placed = false
  if not ok then return false, err end
  if countFuzed() > before then
    missStreak = 0
  else
    stats.misses = stats.misses + 1
    missStreak = missStreak + 1
  end
  return true
end

local function worker()
  -- a shell left in front from before a restart gets picked back up
  if turtle.detect() then
    local ok, block = turtle.inspect()
    if ok and isShell[block.name] then breakFront() end
  end

  while true do
    if not emptyOutput() then
      setStatus("Output full")
      sleep(2)
    else
      local slot = findUnfuzed()
      if not slot then
        if hasFreeSlot() then turtle.select(1) SIDE[INPUT_SIDE].suck() end
        slot = findUnfuzed()
      end

      if not slot then
        setStatus("Waiting for shells")
        sleep(1)
      elseif turtle.detect() then
        setStatus("Something is in front")
        sleep(2)
      else
        turtle.select(slot)
        local ok, err = turtle.place()
        if not ok then
          setStatus("Can't place: " .. tostring(err))
          sleep(2)
        else
          placed = true
          if missStreak >= OUT_OF_FUZES_AFTER then
            setStatus("No fuzes coming - fill the hopper")
          else
            setStatus("Fuzing")
          end
          -- slow down while the hopper is empty so we're not spamming place/break
          sleep(missStreak >= OUT_OF_FUZES_AFTER and 3 or FUZE_WAIT)
          ok, err = breakFront()
          if not ok then
            setStatus("Can't break: " .. tostring(err))
            sleep(2)
          end
        end
      end
    end
  end
end

local function screen()
  while true do
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.orange)
    print("Shell Fuzer")
    term.setTextColor(colors.white)
    print()
    print("Fuzed:  " .. stats.fuzed)
    print("Misses: " .. stats.misses)
    if stats.passed > 0 then print("Passed through: " .. stats.passed) end
    print()
    if status == "Fuzing" or status == "Waiting for shells" then
      term.setTextColor(colors.lime)
    else
      term.setTextColor(colors.red)
    end
    print(status)
    term.setTextColor(colors.lightGray)
    print()
    print("Input " .. INPUT_SIDE .. ", output " .. OUTPUT_SIDE .. ", shell in front")
    os.pullEvent("fuzer_redraw")
  end
end

-- safe to restart: no shell is sitting in front waiting for a fuze
local function readyToUpdate()
  return not placed
end

-- ============================================================ auto-update

-- Every UPDATE_CHECK_MINUTES this checks GitHub for a newer version. A new
-- version is downloaded, checked that it loads, given your current settings
-- (the UPPERCASE lines at the top of this file), saved, and the computer
-- reboots into it. Set AUTO_UPDATE = false at the top to turn this off.
local UPDATE_REPO = "levisnakes/cc-shell-fuzer"
local UPDATE_FILE = "shell_fuzer.lua"
local UPDATE_CHECK_MINUTES = 15
local PROGRAM_PATH = (shell and shell.getRunningProgram()) or "startup.lua"
local SHA_FILE = "/.version_" .. UPDATE_FILE

-- Settings are the top-of-file assignments to UPPERCASE names, before the
-- first "local" line or "-- ====" section. Tables can span several lines.
local function splitSettings(src)
  local settings, rest = {}, {}
  local inSettings = true
  for line in (src .. "\n"):gmatch("(.-)\n") do
    if inSettings and (line:match("^local ") or line:match("^%-%- ====")) then inSettings = false end
    table.insert(inSettings and settings or rest, line)
  end
  return settings, rest
end

local function braceDelta(line)
  local code = line:gsub('"[^"]*"', ""):gsub("%-%-.*$", "")
  local _, opens = code:gsub("{", "")
  local _, closes = code:gsub("}", "")
  return opens - closes
end

-- [NAME] = the full statement text, possibly several lines
local function statements(lines)
  local out = {}
  local i = 1
  while i <= #lines do
    local name = lines[i]:match("^([%u_][%u%d_]*)%s*=")
    if name then
      local block = { lines[i] }
      local depth = braceDelta(lines[i])
      while depth > 0 and i < #lines do
        i = i + 1
        table.insert(block, lines[i])
        depth = depth + braceDelta(lines[i])
      end
      out[name] = table.concat(block, "\n")
    end
    i = i + 1
  end
  return out
end

-- New file, with each setting that already exists replaced by your value.
local function mergeSettings(oldSrc, newSrc)
  local oldSettings = statements((splitSettings(oldSrc)))
  local newSettings, rest = splitSettings(newSrc)
  local out = {}
  local i = 1
  while i <= #newSettings do
    local line = newSettings[i]
    local name = line:match("^([%u_][%u%d_]*)%s*=")
    if name and oldSettings[name] then
      table.insert(out, oldSettings[name])
      local depth = braceDelta(line)
      while depth > 0 and i < #newSettings do
        i = i + 1
        depth = depth + braceDelta(newSettings[i])
      end
    else
      table.insert(out, line)
    end
    i = i + 1
  end
  for _, line in ipairs(rest) do table.insert(out, line) end
  local merged = table.concat(out, "\n")
  -- splitting added one trailing newline's worth of empty line; match the source
  if newSrc:sub(-1) == "\n" and merged:sub(-1) ~= "\n" then merged = merged .. "\n" end
  return (merged:gsub("\n\n$", "\n"))
end

local function fetch(url, headers)
  local ok, h = pcall(http.get, url, headers)
  if not ok or not h then return nil end
  local body = h.readAll()
  h.close()
  return body
end

local function readText(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r")
  local t = f.readAll()
  f.close()
  return t
end

local function writeText(path, text)
  local f = fs.open(path, "w")
  f.write(text)
  f.close()
end

local function checkForUpdate(atBoot)
  if AUTO_UPDATE == false or not http then return end
  local sha = fetch("https://api.github.com/repos/" .. UPDATE_REPO .. "/commits/main",
    { ["Accept"] = "application/vnd.github.sha", ["User-Agent"] = "cc-auto-update" })
  if not sha then return end
  sha = sha:match("^%s*(%x+)%s*$")
  if not sha or #sha < 40 or readText(SHA_FILE) == sha then return end

  local newSrc = fetch("https://raw.githubusercontent.com/" .. UPDATE_REPO .. "/" .. sha .. "/" .. UPDATE_FILE)
  if not newSrc or not load(newSrc, UPDATE_FILE) then return end
  local oldSrc = readText(PROGRAM_PATH)
  if not oldSrc then return end
  local merged = mergeSettings(oldSrc, newSrc)
  if not load(merged, UPDATE_FILE) then return end
  if merged == oldSrc then
    writeText(SHA_FILE, sha)
    return
  end

  -- at boot nothing is running yet, so there is nothing to wait for
  while not atBoot and not readyToUpdate() do sleep(5) end
  writeText(PROGRAM_PATH .. ".old", oldSrc)
  writeText(PROGRAM_PATH, merged)
  writeText(SHA_FILE, sha)
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1, 1)
  print("Updated to " .. sha:sub(1, 7) .. ", restarting...")
  if not atBoot then sleep(1) end
  os.reboot()
end

local function updateLoop()
  while true do
    sleep(UPDATE_CHECK_MINUTES * 60)
    pcall(checkForUpdate)
  end
end

-- Check for a new version as soon as the computer starts, before the
-- program runs, so a restart always picks up the latest version.
local function bootUpdate()
  if AUTO_UPDATE == false or not http then return end
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1, 1)
  print("Checking for updates...")
  pcall(checkForUpdate, true)
end

bootUpdate()
parallel.waitForAny(worker, screen, updateLoop)
