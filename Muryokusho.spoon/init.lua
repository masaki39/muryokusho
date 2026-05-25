-- Muryokusho.spoon/init.lua
-- Spoon entry point for Muryokusho (無量空処)
-- Captures clipboard or prompts for a word, translates via OpenAI, and adds to Anki.

local _spoonDir = (function()
	local info = debug.getinfo(1, "S")
	local src = info.source:match("^@(.+)$") or info.source
	return src:match("^(.+)/[^/]+$") or "."
end)()

local function _require(name)
	return dofile(_spoonDir .. "/" .. name .. ".lua")
end

local keychain = _require("keychain")
local openai   = _require("openai")
local anki     = _require("anki")
local ui       = _require("ui")

local obj = {}
obj.__index = obj

obj.name    = "Muryokusho"
obj.version = "0.0.3"
obj.author  = "masaki39"
obj.license = "MIT"

-- Settings
obj.ankiDeck          = "Default"      -- Anki deck name
obj.ankiModelName     = "Basic"        -- Anki note type
obj.ankiFrontField    = "Front"        -- front field name
obj.ankiBackField     = "Back"         -- back field name
obj.openaiModel       = "gpt-4.1-nano" -- OpenAI model
obj.targetLanguage    = "Japanese"     -- translation target language
obj.customPrompt      = nil            -- override system prompt (nil = use built-in)
obj.allowDuplicate    = false          -- allow duplicate Anki cards
obj.alertDuration     = 6             -- seconds to show translation alert

local ALERT_STYLE = {
	textSize    = 15,
	radius      = 8,
	strokeWidth = 2,
	strokeColor = { white = 1, alpha = 0.5 },
	fillColor   = { white = 0, alpha = 0.8 },
	textColor   = { white = 1, alpha = 1 },
}

local DISMISS_EVENTS = {
	hs.eventtap.event.types.leftMouseDown,
	hs.eventtap.event.types.rightMouseDown,
	hs.eventtap.event.types.keyDown,
}

-- Internal state
obj._hotkeys  = {}
obj._alertId  = nil
obj._alertTap = nil

-- Dismiss the translation alert and its eventtap
function obj:_dismissAlert()
	if self._alertId  then hs.alert.closeSpecific(self._alertId); self._alertId  = nil end
	if self._alertTap then self._alertTap:stop();                  self._alertTap = nil end
end

-- Show translation alert; dismissed on click, any key, or timeout
function obj:_showAlert(word, result)
	self:_dismissAlert()
	self._alertId = hs.alert.show(
		word .. "\n" .. result, ALERT_STYLE, hs.screen.mainScreen(), self.alertDuration
	)
	self._alertTap = hs.eventtap.new(DISMISS_EVENTS, function()
		self:_dismissAlert()
		return false  -- pass event through
	end)
	self._alertTap:start()
end

-- Retrieve API key from Keychain (call once on start)
function obj:_loadApiKey()
	local key, err = keychain.get("openai-api-key", "muryokusho")
	if not key then
		local msg = "OpenAI API key not found in Keychain: " .. tostring(err)
		print("[Muryokusho] " .. msg)
		hs.notify.show("Muryokusho", "", msg)
	end
	openai.apiKey = key
end

-- Core action: translate word and add to Anki
function obj:addCard(word)
	if not word or word == "" then return end
	self:_dismissAlert()
	self._alertId = hs.alert.show(word .. "\n⏳ Translating…", ALERT_STYLE, hs.screen.mainScreen(), 0)
	openai.translate(word, self.openaiModel, self.targetLanguage, self.customPrompt, function(result, err)
		if err then
			self:_dismissAlert()
			local msg = "OpenAI error: " .. tostring(err)
			print("[Muryokusho] " .. msg)
			hs.notify.show("Muryokusho", "", msg)
			return
		end
		self:_showAlert(word, result)
		local ankiBack = result:gsub("\n", "<br>")
		anki.addNote(self.ankiDeck, self.ankiModelName, self.ankiFrontField, self.ankiBackField, word, ankiBack, self.allowDuplicate, function(noteErr)
			if noteErr then
				local msg = tostring(noteErr):lower():find("duplicate") and "Duplicate: " .. word or "Anki error: " .. tostring(noteErr)
				print("[Muryokusho] " .. msg)
				hs.notify.show("Muryokusho", "", msg)
			else
				hs.notify.show("Muryokusho", "", "Added: " .. word)
			end
		end)
	end)
end

-- Show input dialogs (front → translate → back editable) and add card
function obj:captureAndAdd()
	ui.promptWord("", function(front)
		self:_dismissAlert()
		self._alertId = hs.alert.show(front .. "\n⏳ Translating…", ALERT_STYLE, hs.screen.mainScreen(), 0)
		openai.translate(front, self.openaiModel, self.targetLanguage, self.customPrompt, function(result, err)
			self:_dismissAlert()
			if err then
				local msg = "OpenAI error: " .. tostring(err)
				print("[Muryokusho] " .. msg)
				hs.notify.show("Muryokusho", "", msg)
				return
			end
			ui.promptBack(result, function(back)
				local ankiBack = back:gsub("\n", "<br>")
				anki.addNote(self.ankiDeck, self.ankiModelName, self.ankiFrontField, self.ankiBackField, front, ankiBack, self.allowDuplicate, function(noteErr)
					if noteErr then
						local msg = tostring(noteErr):lower():find("duplicate") and "Duplicate: " .. front or "Anki error: " .. tostring(noteErr)
						print("[Muryokusho] " .. msg)
						hs.notify.show("Muryokusho", "", msg)
					else
						hs.notify.show("Muryokusho", "", "Added: " .. front)
					end
				end)
			end)
		end)
	end)
end

-- Start the spoon
function obj:start()
	self:_loadApiKey()
	return self
end

-- Stop the spoon
function obj:stop()
	for _, hk in ipairs(self._hotkeys) do pcall(function() hk:delete() end) end
	self._hotkeys = {}
	self:_dismissAlert()
	return self
end

-- Bind hotkeys
-- map: { addCard = { mods, key } }
function obj:bindHotkeys(map)
	if map.addCard then
		local mods, key = map.addCard[1], map.addCard[2]
		table.insert(self._hotkeys, hs.hotkey.bind(mods, key, function()
			self:captureAndAdd()
		end))
	end
	return self
end

return obj
