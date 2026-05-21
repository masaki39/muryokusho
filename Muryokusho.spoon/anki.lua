-- anki.lua
-- AnkiConnect HTTP API wrapper (default port 8765)

local M = {}

M.endpoint = "http://localhost:8765"

local function request(action, params, callback)
	local body = hs.json.encode({
		action  = action,
		version = 6,
		params  = params,
	})
	local done = false
	local timer = hs.timer.doAfter(10, function()
		if not done then
			done = true
			callback("AnkiConnect timeout")
		end
	end)
	hs.http.asyncPost(M.endpoint, body, { ["Content-Type"] = "application/json" },
		function(status, responseBody, _)
			if done then return end
			done = true
			timer:stop()
			if status ~= 200 then
				callback("HTTP " .. tostring(status))
				return
			end
			local ok, data = pcall(hs.json.decode, responseBody)
			if not ok then
				callback("JSON parse error: " .. tostring(responseBody or ""):sub(1, 80))
				return
			end
			if data.error then
				callback(data.error)
				return
			end
			callback(nil, data.result)
		end
	)
end

-- Add a Basic note to Anki.
-- front: word, back: translation/definition
-- callback(err: string|nil)
function M.addNote(deck, modelName, frontField, backField, front, back, allowDuplicate, callback)
	request("addNote", {
		note = {
			deckName  = deck,
			modelName = modelName,
			fields    = { [frontField] = front, [backField] = back },
			options   = { allowDuplicate = allowDuplicate },
			tags      = { "muryokusho" },
		},
	}, function(err, _)
		callback(err)
	end)
end

return M
