-- google_translate.lua
-- Google Translate (unofficial endpoint) wrapper

local M = {}

-- Translate a word asynchronously using the unofficial Google Translate endpoint.
-- language: locale code (e.g. "ja", "zh-CN")
-- callback(result: string|nil, err: string|nil)
function M.translate(word, language, callback)
	local url = "https://translate.googleapis.com/translate_a/single"
		.. "?client=gtx&sl=auto&tl=" .. language
		.. "&dt=t&q=" .. hs.http.encodeForQuery(word)

	local done = false
	local timer = hs.timer.doAfter(10, function()
		if not done then
			done = true
			callback(nil, "request timeout")
		end
	end)

	hs.http.asyncGet(url, nil, function(status, body, _)
		if done then return end
		done = true
		timer:stop()
		if status ~= 200 then
			callback(nil, "HTTP " .. tostring(status) .. ": " .. tostring(body or ""):sub(1, 80))
			return
		end
		local ok, data = pcall(hs.json.decode, body)
		if not ok or not data or not data[1] or not data[1][1] then
			callback(nil, "JSON parse error: " .. tostring(body or ""):sub(1, 80))
			return
		end
		-- Response structure: [ [ ["translated","original",...], ... ], ... ]
		local text = data[1][1][1]
		if not text then
			callback(nil, "unexpected response shape")
			return
		end
		callback(text, nil)
	end)
end

return M
