-- Persisted settings.
--
-- One file, one shape, defaults merged under whatever was saved -- so adding a
-- setting in a later version does not invalidate an existing install, and a
-- half-written file falls back to defaults rather than bricking the client.
-- Writes are debounced because the interface calls set() from slider drags.
return function(env)
	local util = env.require("runtime/util")
	local fsx = env.require("runtime/fsx")
	local clock = env.require("runtime/clock")
	local signal = env.require("runtime/signal")
	local log = env.require("runtime/log")

	local FILE = "config.json"

	local DEFAULTS = {
		version = 2,
		ui = {
			density = "comfortable",
			accent = "claude",
			reduceMotion = "auto",
			layout = "auto",
			panel = "chat",
			fontScale = 1,
			showReasoning = true,
			showToolDetail = false,
			-- Whether the code a tool was handed is drawn under its row, outside the
			-- fold. On by default: the listing is the single most useful thing in a
			-- transcript of an agent that writes and executes code, and it used to be
			-- reachable only by opening a pane that defaulted shut.
			showToolCode = true,
			-- The key that opens quick chat, stored as an Enum.KeyCode name because
			-- that is what the capture in Settings produces and what survives a
			-- keyboard layout the character would not.
			quickKey = "Semicolon",
			showUsage = true,
			-- Appearance choices that name a family or a palette rather than a number.
			-- All four are read by ui/theme, so each one changes what is on screen.
			interfaceFont = "builder",
			codeFont = "code",
			codeTheme = "dark",
			transcriptWidth = "wide",
			-- The sidebar, the home card and the range the card opens on. Remembered
			-- because each is a place the user put something.
			sidebarCollapsed = false,
			sidebarExpanded = false,
			showActivity = true,
			activityRange = "all",
			-- Whether a minimized client still gets toasts when a turn finishes, fails
			-- or is stopped. The launcher badge happens either way; this is only the
			-- floating text.
			notifications = true,
			window = { width = 0, height = 0, x = 0, y = 0, maximised = false, placed = false },
			mobilePanel = { width = 0, height = 0, x = 0, y = 0, maximised = false, placed = false },
			mobileSheet = { width = 0, height = 0, x = 0, y = 0, maximised = false, placed = false },
			launcher = { x = 0, y = 0, placed = false },
			-- The last changelog version the user opened. The app menu marks What's
			-- New while the running version is newer than this; opening the modal
			-- sets it. "0.0.0" rather than the shipping version so a first run
			-- shows the marker -- a new user is exactly who the notes are for.
			lastSeenVersion = "0.0.0",
			-- Note revisions can change without changing the client version.
			lastSeenChangelog = "",
			communityInvite = { lastShown = 0, disabled = false },
		},
		agent = {
			maxTurns = 60,
			-- Lifts the step limit and the turn deadline for the top-level
			-- conversation, so a long job runs until the model answers in prose
			-- instead of stopping mid-way with "I reached this session's step limit".
			-- What still bounds a runaway: the repeat breaker, each tool's own
			-- timeout, the provider retry cap, and Stop. Subagents keep their own
			-- turn and time budgets either way -- an unbounded child is the one
			-- thing here nobody is watching.
			unlimitedTurns = true,
			toolConcurrency = 8,
			toolTimeout = 45,
			-- Configured per-request budget in seconds. Native HTTP permits up to 900 seconds;
			-- Delta/executor transports and providers may impose a shorter limit.
			requestTimeout = 900,
			-- When enabled, adapters request an 86400-second budget and bypass the
			-- configured requestTimeout. The transport or executor may still cap the wait.
			requestUnlimited = true,
			-- Large contexts increase upload and prefill time under executor HTTP
			-- deadlines; lower this budget when even short replies time out.
			contextTokens = 48000,
			-- The share of a model's known context window at which older turns are
			-- summarised. contextTokens above is the hard ceiling; this is what makes
			-- compaction adapt to a small-window model without retuning that number.
			contextFraction = 0.5,
			keepTurns = 14,
			compaction = true,
			stream = true,
			temperature = 0.4,
			-- Reasoning depth: sent as `reasoning_effort` on chat completions and as
			-- `output_config.effort` on the Messages API. "high" is what the API itself
			-- uses when the field is absent, so this default changes nothing until it is
			-- moved, and "off" sends no field at all. Clamped per model, because the
			-- scales differ by generation -- "xhigh" did not exist before Opus 4.7.
			effort = "max",
			-- Manual capability claims, keyed by lowercased model id. No endpoint
			-- publishes what a relayed id can do, so this is the user's word against
			-- nothing: `forceReasoning` makes the adapters ask a model to think, and
			-- `forceContext` states its window, which both the badge and the context
			-- budget slider then read. Effort follows reasoning: a model forced to
			-- think gets the effort scale even where the table documents none.
			forceReasoning = {},
			forceContext = {},
			maxTokens = 128000,
			-- Characters, not tokens. Keep tool output bounded so a large response does
			-- not crowd out the user request and recent conversation. Tools that handle
			-- source and large datasets expose paging/slicing for retrieving more detail.
			resultCap = 32000,
			repeatLimit = 3,
			subagentDepth = 4,
			subagentTurns = 30,
			-- Live subagents anywhere in the tree. `toolConcurrency` bounds one batch,
			-- so it is what caps a parallel dispatch from the main conversation; this
			-- caps the whole tree, which nothing else did. Depth alone does not: a
			-- subagent's own batch is bounded separately, and two levels of that
			-- multiply rather than add.
			subagentConcurrency = 12,
			-- Seconds one subagent may run for. The tool that dispatches it derives its
			-- own timeout from this, so the two cannot drift apart -- when they did, the
			-- generic 25s tool timeout fired first and every finished report was thrown
			-- away by a caller that had already given up.
			subagentBudget = 900,
			-- Lifts every clock and counter on a dispatched subagent: no step limit, no
			-- wall-clock budget, and the call that dispatched it waits as long as the
			-- child takes rather than abandoning a report nobody is left to collect.
			--
			-- Separate from `unlimitedTurns` on purpose. That switch is for the turn
			-- someone is watching and deliberately does not reach a child; this is the
			-- decision to let a delegated job finish instead of stopping mid-way with "I
			-- reached this session's step limit", which is the one outcome that wastes the
			-- whole dispatch. What still bounds a child either way: the repeat breaker,
			-- each tool's own timeout, the provider retry cap, the depth and parallel
			-- ceilings, and Stop -- from the parent turn or from the Subagents panel.
			subagentUnlimited = true,
			-- Which tool preset a dispatch gets when the call does not name one. "full"
			-- hands a subagent every tool; permission mode still gates what actually runs,
			-- and a prompt raised inside a child is forwarded to the parent's stream.
			subagentPreset = "full",
			retries = 6,
			fallback = false,
			-- Tool families the model is not told about at all, keyed by group id. A
			-- permission rule decides whether a call is allowed; this decides whether the
			-- tool is offered, which is the coarser thing somebody who does not want the
			-- agent near remotes in this game is asking for.
			disabledGroups = {},
			-- The language the agent is asked to answer in, when one has been named.
			-- Empty means "whatever the conversation is in".
			--
			-- A plain string rather than a locale, because that is all the client can
			-- honestly act on. There used to be a grid of eleven languages behind it
			-- claiming to set the locale dates are formatted with as well; nothing read
			-- that half -- runtime/clock formats with a hardcoded en-us and English month
			-- names -- so ten of the eleven tiles did one thing and advertised two.
			replyLanguage = "",
			-- The user's own standing instructions, appended to the system prompt each
			-- turn. Empty means none. The system prompt itself is not editable -- it is
			-- this client's behaviour, and a prompt a user can silently rewrite is one
			-- nobody can debug -- so this is the whole of the personal half: one block,
			-- read back verbatim, placed after the built-in rules so it wins on conflict.
			customInstructions = "",
		},
		permissions = {
			mode = "ask",
			remember = true,
			rules = {},
		},
		providers = {
			active = "",
			list = {},
		},
		identity = {
			claudeUa = true,
			version = "2.0.14",
			extraHeaders = {},
		},
		memory = {
			enabled = true,
			entries = {},
		},
		-- The local web bridge. Off until it is asked for: it is a second way in to
		-- an agent that can run code, so enabling it should be a decision rather
		-- than a default. The token is regenerated by bridge/server.js on every
		-- start and pasted in here, so a stale one left in this file grants nothing.
		-- 8790 rather than 8787 because wrangler took that one as its default.
		bridge = {
			enabled = false,
			port = 8790,
			token = "",
			runtime = "game",
			requestTimeout = 180,
		},
		logs = {
			mirror = false,
			level = "info",
		},
		-- Infinite Yield as an internal command engine. "off" withholds the iy
		-- tools' engine entirely; "hidden" loads IY with its interface parked so
		-- the agent has every command and the user keeps the screen; "visible"
		-- loads it as IY draws itself. The mode is a request, not a state: it is
		-- applied on the next command, never at boot, because loading is a
		-- megabyte fetch and a GUI and a settings row should not spend that.
		iy = {
			mode = "hidden",
		},
		-- Markdown skills (.md playbooks) under skills/. The engine injects nothing
		-- into the system prompt -- the environment block carries names and
		-- one-line descriptions only, and a body is fetched by a tool call when a
		-- task matches. `disabled` is the set of switched-off filenames; an absent
		-- entry means enabled, so a file dropped in by hand works with no second
		-- step.
		skills = {
			disabled = {},
		},
		fs = {
			migrated = false,
		},
	}

	local M = {
		defaults = DEFAULTS,
		data = util.deepCopy(DEFAULTS),
		changed = signal.new("config"),
		loaded = false,
		dirty = false,
	}

	local flush

	local function mergedConfig(stored)
		stored = type(stored) == "table" and stored or {}
		local data = util.merge(DEFAULTS, stored)
		local version = tonumber(stored.version) or 0
		-- Migrate values that match known previous defaults. Non-default custom
		-- budgets are preserved, while existing installs receive the safer defaults.
		if version < 2 then
			local oldAgent = type(stored.agent) == "table" and stored.agent or {}
			if tonumber(oldAgent.contextTokens) == 1000000 then data.agent.contextTokens = 48000 end
			if tonumber(oldAgent.contextFraction) == 0.7 or tonumber(oldAgent.contextFraction) == 0.8 then data.agent.contextFraction = 0.5 end
			if tonumber(oldAgent.resultCap) == 128000 then data.agent.resultCap = 32000 end
		end
		data.version = 2
		return data
	end

	function M.load()
		local stored = fsx.readJson(FILE, nil)
		local priorVersion = type(stored) == "table" and (tonumber(stored.version) or 0) or 2
		M.data = type(stored) == "table" and mergedConfig(stored) or util.deepCopy(DEFAULTS)
		M.loaded = true
		M.changed:fire(nil, M.data)
		if type(stored) == "table" and priorVersion < 2 then M.save() end
		return M.data
	end

	function M.saveNow()
		if not fsx.enabled then
			M.dirty = false
			return false, "no filesystem"
		end
		local ok, err = fsx.writeJson(FILE, M.data)
		M.dirty = not ok
		if not ok then log.warn("config", "could not persist settings", err) end
		return ok, err
	end

	flush = clock.debounce(function()
		M.saveNow()
	end, 0.75)

	function M.save()
		M.dirty = true
		flush()
	end

	function M.get(path, fallback)
		local value = util.get(M.data, path)
		if value == nil then
			local default = util.get(DEFAULTS, path)
			if default ~= nil then return util.deepCopy(default) end
			return fallback
		end
		return value
	end

	-- Fires with the path so a subscriber can react to one setting rather than
	-- rebuilding on every keystroke of an unrelated field.
	function M.set(path, value, opts)
		opts = opts or {}
		util.set(M.data, path, value)
		if not opts.quiet then M.changed:fire(path, value) end
		if not opts.transient then M.save() end
		return value
	end

	-- Applies one validated snapshot. Persistence is attempted before replacing the
	-- live table, and subscribers see the complete new configuration in one event.
	function M.replace(snapshot)
		if type(snapshot) ~= "table" then return false, "configuration must be a table" end
		local nextData = mergedConfig(snapshot)
		if fsx.enabled then
			local ok = fsx.writeJson(FILE, nextData)
			if not ok then return false, "Could not save imported settings. Your current configuration is unchanged." end
		end
		M.data = nextData
		M.loaded = true
		M.dirty = false
		M.changed:fire(nil, M.data)
		-- These live accessibility/layout consumers listen for their exact paths.
		M.changed:fire("ui.layout", M.data.ui.layout)
		M.changed:fire("ui.reduceMotion", M.data.ui.reduceMotion)
		return true, fsx.enabled == true
	end

	function M.toggle(path)
		local value = M.get(path) ~= true
		M.set(path, value)
		return value
	end

	function M.reset(section)
		if not section or section == "ui" then
			local capture = env.loadedModules and env.loadedModules["runtime/remote_capture"]
			if capture then capture.stop("settings reset") end
		end
		if section then
			util.set(M.data, section, util.deepCopy(util.get(DEFAULTS, section)))
		else
			M.data = util.deepCopy(DEFAULTS)
		end
		M.changed:fire(section, nil)
		M.save()
	end

	return M
end
