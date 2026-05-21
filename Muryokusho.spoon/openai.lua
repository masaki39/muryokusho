-- openai.lua
-- OpenAI Chat Completions wrapper

local M = {}

M.apiKey  = nil
M.baseUrl = "https://api.openai.com/v1/chat/completions"

local function buildPrompt(targetLanguage)
	return string.format([[
You are a concise vocabulary assistant.
Given a word or phrase, output exactly two lines:
Line 1: the %s translation (with reading if applicable)
Line 2: a short example sentence using the word (in English)
No extra commentary.
]], targetLanguage)
end

-- Translate a word asynchronously.
-- customPrompt overrides the built-in prompt when provided.
-- callback(result: string|nil, err: string|nil)
function M.translate(word, model, targetLanguage, customPrompt, callback)
	if not M.apiKey or M.apiKey == "" then
		callback(nil, "API key not set")
		return
	end

	local prompt = customPrompt or buildPrompt(targetLanguage)

	local body = hs.json.encode({
		model = model,
		messages = {
			{ role = "system", content = prompt },
			{ role = "user",   content = word },
		},
		max_tokens = 150,
	})

	local headers = {
		["Content-Type"]  = "application/json",
		["Authorization"] = "Bearer " .. M.apiKey,
	}

	local done = false
	local timer = hs.timer.doAfter(30, function()
		if not done then
			done = true
			callback(nil, "request timeout")
		end
	end)

	hs.http.asyncPost(M.baseUrl, body, headers, function(status, responseBody, _)
		if done then return end
		done = true
		timer:stop()
		if status ~= 200 then
			callback(nil, "HTTP " .. tostring(status) .. ": " .. tostring(responseBody or ""):sub(1, 80))
			return
		end
		local ok, data = pcall(hs.json.decode, responseBody)
		if not ok or not data then
			callback(nil, "JSON parse error: " .. tostring(responseBody or ""):sub(1, 80))
			return
		end
		local text = data.choices
			and data.choices[1]
			and data.choices[1].message
			and data.choices[1].message.content
		if not text then
			callback(nil, "unexpected response shape")
			return
		end
		callback(text:gsub("^%s+", ""):gsub("%s+$", ""), nil)
	end)
end

return M
