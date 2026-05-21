-- ui.lua
-- Simple input dialog for manual word entry

local M = {}

-- Show a text-input dialog pre-filled with defaultText and call callback(word) on confirm.
function M.promptWord(defaultText, callback)
	local btn, word = hs.dialog.textPrompt(
		"Muryokusho (無量空処)",
		"Enter a word or phrase:",
		tostring(defaultText or ""),
		"Add",
		"Cancel"
	)
	if btn == "Add" and word and word ~= "" then
		if #word > 1000 then
			hs.notify.show("Muryokusho", "", "Input too long (max 1000 characters)")
		else
			callback(word)
		end
	end
end

return M
