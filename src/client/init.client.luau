-- Client bootstrap. Mirrors the server: every module under Controllers/ has
-- optional Init() and Start() methods; all Inits run before any Start.

local ORDER = {
	"DataController",
	"PetController",
	"MiningController",
	"FishingController",
	"UIController",
}

local controllers = {}
for _, name in ORDER do
	controllers[name] = require(script.Controllers[name])
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Init then
		controller.Init()
	end
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Start then
		task.spawn(controller.Start)
	end
end
