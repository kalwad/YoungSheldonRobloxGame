local TestHarness = {}
TestHarness.__index = TestHarness

local function render(value, seen)
	local valueType = type(value)
	if valueType == "string" then
		return string.format("%q", value)
	end
	if valueType ~= "table" then
		return tostring(value)
	end

	seen = seen or {}
	if seen[value] then
		return "<cycle>"
	end
	seen[value] = true

	local keys = {}
	for key in pairs(value) do
		table.insert(keys, key)
	end
	table.sort(keys, function(left, right)
		return tostring(left) < tostring(right)
	end)

	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, "[" .. render(key, seen) .. "]=" .. render(value[key], seen))
	end
	seen[value] = nil
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(left, right, visited)
	if left == right then
		return true
	end
	if type(left) ~= type(right) or type(left) ~= "table" then
		return false
	end

	visited = visited or {}
	visited[left] = visited[left] or {}
	if visited[left][right] then
		return true
	end
	visited[left][right] = true

	for key, value in pairs(left) do
		if not deepEqual(value, right[key], visited) then
			return false
		end
	end
	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end
	return true
end

function TestHarness.new()
	return setmetatable({
		total = 0,
		passed = 0,
		failed = 0,
		currentSuite = nil,
		failures = {},
	}, TestHarness)
end

function TestHarness:equal(actual, expected, message)
	if actual ~= expected then
		error((message or "values are not equal")
			.. "\nexpected: " .. render(expected)
			.. "\nactual:   " .. render(actual), 2)
	end
end

function TestHarness:deepEqual(actual, expected, message)
	if not deepEqual(actual, expected) then
		error((message or "tables are not deeply equal")
			.. "\nexpected: " .. render(expected)
			.. "\nactual:   " .. render(actual), 2)
	end
end

function TestHarness:truthy(value, message)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function TestHarness:falsy(value, message)
	if value then
		error(message or "expected a falsy value", 2)
	end
end

function TestHarness:throws(callback, expectedFragment)
	local ok, problem = pcall(callback)
	if ok then
		error("expected callback to throw", 2)
	end
	if expectedFragment then
		local fragment = tostring(expectedFragment)
		if not string.find(tostring(problem), fragment, 1, true) then
			error("error did not include " .. render(expectedFragment) .. ": " .. tostring(problem), 2)
		end
	end
end

function TestHarness:test(name, callback)
	self.total += 1
	local ok, problem = xpcall(callback, function(err)
		return debug.traceback(tostring(err), 2)
	end)
	if ok then
		self.passed += 1
		print("  PASS  " .. name)
	else
		self.failed += 1
		local fullName = (self.currentSuite and self.currentSuite .. " :: " or "") .. name
		table.insert(self.failures, fullName .. "\n" .. tostring(problem))
		print("  FAIL  " .. name)
	end
end

function TestHarness:runSuite(name, register)
	self.currentSuite = name
	print("\n" .. name)
	local ok, problem = xpcall(function()
		register(self)
	end, function(err)
		return debug.traceback(tostring(err), 2)
	end)
	if not ok then
		self.total += 1
		self.failed += 1
		table.insert(self.failures, name .. " :: registration\n" .. tostring(problem))
		print("  FAIL  suite registration")
	end
	self.currentSuite = nil
end

function TestHarness:finish()
	print(string.format("\nRESULT: %d passed, %d failed, %d total", self.passed, self.failed, self.total))
	if self.failed > 0 then
		print("\nFAILURES")
		for index, failure in ipairs(self.failures) do
			print(string.format("\n%d) %s", index, failure))
		end
		error(string.format("deterministic contract suite failed (%d failure(s))", self.failed), 0)
	end
	return true
end

return TestHarness
