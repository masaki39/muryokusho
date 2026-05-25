-- ui.lua
-- Input dialogs for Muryokusho

local M = {}

-- Single-line dialog for the front field
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

-- Multiline webview dialog for the back field, pre-filled with defaultText
function M.promptBack(defaultText, callback)
	local screen = hs.screen.mainScreen()
	local sf = screen:frame()
	local W, H = 520, 380
	local wvFrame = {
		x = sf.x + (sf.w - W) / 2,
		y = sf.y + (sf.h - H) / 2,
		w = W, h = H
	}

	local uc = hs.webview.usercontent.new("muryokusho_back")
	local wv

	uc:setCallback(function(msg)
		if wv then wv:delete(); wv = nil end
		if msg.body.action == "add" and msg.body.text ~= "" then
			callback(msg.body.text)
		end
	end)

	wv = hs.webview.new(wvFrame, uc)
	wv:windowStyle({"titled", "closable"})
	wv:windowTitle("Muryokusho — Back")
	wv:allowTextEntry(true)
	wv:bringToFront(true)

	local escaped = (defaultText or "")
		:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")

	local html = string.format([[<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body{font-family:-apple-system,sans-serif;margin:16px;background:#1e1e1e;color:#eee}
  label{display:block;margin-bottom:6px;font-size:13px}
  textarea{width:100%%;height:260px;box-sizing:border-box;background:#2d2d2d;color:#eee;
           border:1px solid #555;border-radius:4px;padding:8px;font-size:13px;resize:vertical}
  .btns{margin-top:10px;text-align:right}
  button{padding:5px 16px;margin-left:8px;border-radius:4px;border:none;cursor:pointer;font-size:13px}
  #add{background:#0a7aff;color:#fff}
  #cancel{background:#555;color:#fff}
</style>
</head>
<body>
<label>Back (editable):</label>
<textarea id="t">%s</textarea>
<div class="btns">
  <button id="cancel" onclick="post('cancel','')">Cancel</button>
  <button id="add" onclick="post('add',document.getElementById('t').value)">Add ⌘↵</button>
</div>
<script>
function post(a,t){window.webkit.messageHandlers.muryokusho_back.postMessage({action:a,text:t})}
var t=document.getElementById('t');t.focus();t.setSelectionRange(t.value.length,t.value.length)
document.addEventListener('keydown',function(e){
  if(e.metaKey&&e.key==='Enter'){e.preventDefault();post('add',t.value)}
  if(e.key==='Escape'){post('cancel','')}
})
</script>
</body>
</html>]], escaped)

	wv:html(html)
	wv:show()
end

return M
