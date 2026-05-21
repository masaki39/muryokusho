-- keychain.lua
-- macOS Keychain read/write helpers

local M = {}

-- Store a password in Keychain
-- security add-generic-password -a <account> -s <service> -w <password>
function M.set(service, account, password)
	-- Delete existing entry first (ignore error if not found)
	hs.execute(string.format(
		'security delete-generic-password -a %q -s %q 2>/dev/null',
		account, service
	))
	local _, ok = hs.execute(string.format(
		'security add-generic-password -a %q -s %q -w %q',
		account, service, password
	))
	return ok
end

-- Retrieve a password from Keychain
-- Returns: password (string) or nil, error (string)
function M.get(service, account)
	local out, ok = hs.execute(string.format(
		'security find-generic-password -a %q -s %q -w 2>&1',
		account, service
	))
	if not ok or out == "" then
		return nil, "key not found"
	end
	return out:gsub("%s+$", ""), nil
end

return M
