-- ============================================================
--  CPU0.lua  --  "logoOS"  : tiny phone OS for Retro Gadgets
--  Hardware: VideoChip0 (touch screen recommended)
--  Boot screen draws "logo" dead center. Then: home + 4 apps.
-- ============================================================

local vid  = gdt.VideoChip0
local font = gdt.ROM.System.SpriteSheets["StandardFont"]

-- glyph metrics -- tweak these two if text spacing looks off
local CW, CH = 6, 10

local W, H = vid.Width, vid.Height

-- ------------------------------------------------------------
-- theme
-- ------------------------------------------------------------
local accents = {
	Color(0, 220, 180),
	Color(255, 90, 140),
	Color(255, 190, 60),
	Color(120, 150, 255),
}
local accentIdx = 1

local th = {
	bg    = Color(10, 10, 16),
	panel = Color(26, 26, 38),
	line  = Color(48, 48, 66),
	text  = Color(235, 235, 245),
	dim   = Color(120, 120, 145),
}
local function AC() return accents[accentIdx] end

-- ------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------
local function v(x, y) return vec2(math.floor(x), math.floor(y)) end
local function tw(s) return #s * CW end

local function text(x, y, s, c, bg)
	vid:DrawText(v(x, y), font, s, c or th.text, bg or color.clear)
end

local function ctext(y, s, c, bg)
	text((W - tw(s)) * 0.5, y, s, c, bg)
end

local function box(x, y, w, h, c)
	vid:FillRect(v(x, y), v(w, h), c)
end

local function frame(x, y, w, h, c)
	vid:DrawRect(v(x, y), v(w, h), c)
end

local function ring(cx, cy, r, c, from, to)
	from, to = from or 0, to or 1
	local steps = math.max(12, math.floor(r * 6))
	for i = 0, steps do
		local f = i / steps
		if f >= from and f <= to then
			local a = f * math.pi * 2 - math.pi * 0.5
			vid:SetPixel(v(cx + math.cos(a) * r, cy + math.sin(a) * r), c)
		end
	end
end

local function clamp(n, a, b) return n < a and a or (n > b and b or n) end

-- ------------------------------------------------------------
-- input
-- ------------------------------------------------------------
local touch = { down = false, prev = false, pressed = false, released = false, pos = vec2(0, 0) }

local function pollTouch()
	touch.prev = touch.down
	touch.down = vid.TouchState and true or false
	if touch.down then touch.pos = vid.TouchPosition end
	touch.pressed  = touch.down and not touch.prev
	touch.released = touch.prev and not touch.down
end

-- optional physical button, ignored if the gadget has none
local function anyButton()
	local ok, c = pcall(function() return gdt.Button0 end)
	if ok and c then return c.ButtonDown == true end
	return false
end

local function hit(x, y, w, h)
	local p = touch.pos
	return p.X >= x and p.X < x + w and p.Y >= y and p.Y < y + h
end

local function tap(x, y, w, h)
	return touch.pressed and hit(x, y, w, h)
end

-- ------------------------------------------------------------
-- clock (uptime driven, offset so it starts at 09:41)
-- ------------------------------------------------------------
local t, dt = 0, 0
local startSeconds = 9 * 3600 + 41 * 60

local function clockParts()
	local s = math.floor(startSeconds + t)
	return math.floor(s / 3600) % 24, math.floor(s / 60) % 60, s % 60
end

local function pad(n) return (n < 10 and "0" or "") .. n end

local function clockShort()
	local hh, mm = clockParts()
	return pad(hh) .. ":" .. pad(mm)
end

-- ------------------------------------------------------------
-- apps
-- ------------------------------------------------------------
local paint = { pts = {}, size = 1 }

local apps = {}

apps[1] = {
	name = "LOGO",
	glyph = "L",
	draw = function(top)
		local cx, cy = W * 0.5, top + (H - top) * 0.5
		local pulse = 3 + math.sin(t * 2) * 2
		ring(cx, cy, 26 + pulse, AC(), 0, (t * 0.35) % 1)
		ring(cx, cy, 20 + pulse * 0.5, th.line)
		ctext(cy - CH * 0.5, "logo", AC())
		ctext(cy + 22, "v1.0", th.dim)
	end,
}

apps[2] = {
	name = "CLOCK",
	glyph = "C",
	draw = function(top)
		local hh, mm, ss = clockParts()
		local cx, cy = W * 0.5, top + (H - top) * 0.45
		ring(cx, cy, 24, th.line)
		ring(cx, cy, 24, AC(), 0, ss / 60)
		local big = pad(hh) .. ":" .. pad(mm)
		ctext(cy - CH * 0.5, big, th.text)
		ctext(cy + 30, ":" .. pad(ss) .. "  uptime " .. math.floor(t) .. "s", th.dim)
	end,
}

apps[3] = {
	name = "PAINT",
	glyph = "P",
	draw = function(top)
		local barH = 12
		local canvasY, canvasH = top, H - top - barH

		for i = 1, #paint.pts do
			local p = paint.pts[i]
			if paint.size <= 1 then
				vid:SetPixel(v(p.x, p.y), p.c)
			else
				vid:FillCircle(v(p.x, p.y), paint.size, p.c)
			end
		end

		if touch.down and hit(0, canvasY, W, canvasH) then
			paint.pts[#paint.pts + 1] = { x = touch.pos.X, y = touch.pos.Y, c = AC() }
			if #paint.pts > 1800 then table.remove(paint.pts, 1) end
		end

		-- toolbar
		box(0, H - barH, W, barH, th.panel)
		text(3, H - barH + 2, "CLR", th.text)
		text(W * 0.5 - 10, H - barH + 2, "SIZE" .. paint.size, th.text)
		text(W - tw("COL") - 3, H - barH + 2, "COL", AC())

		if tap(0, H - barH, 26, barH) then paint.pts = {} end
		if tap(W * 0.5 - 14, H - barH, 34, barH) then
			paint.size = paint.size % 3 + 1
		end
		if tap(W - 26, H - barH, 26, barH) then
			accentIdx = accentIdx % #accents + 1
		end
	end,
}

apps[4] = {
	name = "SYS",
	glyph = "S",
	draw = function(top)
		local y = top + 6
		local lines = {
			"logoOS 1.0",
			"cpu   CPU0",
			"video " .. W .. "x" .. H,
			"font  " .. CW .. "x" .. CH,
			"pts   " .. #paint.pts,
		}
		for i = 1, #lines do
			text(6, y, lines[i], i == 1 and AC() or th.dim)
			y = y + CH
		end

		y = y + 6
		text(6, y, "accent", th.text)
		for i = 1, #accents do
			local bx = 6 + (i - 1) * 14
			box(bx, y + CH + 2, 10, 10, accents[i])
			if i == accentIdx then frame(bx - 2, y + CH, 14, 14, th.text) end
			if tap(bx - 2, y + CH, 14, 14) then accentIdx = i end
		end

		local bx, by = 6, H - 22
		box(bx, by, W - 12, 14, th.panel)
		text(bx + 4, by + 3, "WIPE CANVAS", th.text)
		if tap(bx, by, W - 12, 14) then paint.pts = {} end
	end,
}

-- ------------------------------------------------------------
-- chrome
-- ------------------------------------------------------------
local STATUS_H = 11
local NAV_H = 11

local function statusBar(title)
	box(0, 0, W, STATUS_H, th.panel)
	box(0, STATUS_H, W, 1, th.line)
	text(3, 2, title, AC())

	local c = clockShort()
	text(W * 0.5 - tw(c) * 0.5, 2, c, th.text)

	-- battery, slow fake drain
	local pct = 1 - ((t * 0.004) % 1)
	local bw = 14
	frame(W - bw - 4, 3, bw, 6, th.dim)
	box(W - bw - 3, 4, math.max(1, (bw - 2) * pct), 4, pct > 0.2 and AC() or Color(255, 60, 60))
end

local function navBar(label)
	local y = H - NAV_H
	box(0, y, W, NAV_H, th.panel)
	box(0, y - 1, W, 1, th.line)
	ctext(y + 2, label, th.dim)
end

-- ------------------------------------------------------------
-- state machine
-- ------------------------------------------------------------
local state = "boot"
local stateT = 0
local current = 1

local function setState(s)
	state, stateT = s, 0
end

local function drawBoot()
	vid:Clear(th.bg)
	local cx, cy = W * 0.5, H * 0.5

	local grow = clamp(stateT / 0.6, 0, 1)
	ring(cx, cy - 6, 22 * grow, th.line)
	ring(cx, cy - 6, 22 * grow, AC(), 0, clamp((stateT - 0.3) / 1.2, 0, 1))

	if stateT > 0.35 then
		ctext(cy - 6 - CH * 0.5, "logo", AC())
	end

	if stateT > 1.0 then
		local p = clamp((stateT - 1.0) / 1.0, 0, 1)
		local bw = math.floor(W * 0.5)
		local bx = math.floor((W - bw) * 0.5)
		frame(bx, cy + 26, bw, 5, th.line)
		box(bx + 1, cy + 27, math.max(0, (bw - 2) * p), 3, AC())
	end

	if stateT > 2.2 or touch.pressed or anyButton() then setState("home") end
end

local function drawHome()
	vid:Clear(th.bg)
	statusBar("home")

	local top = STATUS_H + 4
	local cols = 2
	local cellW = math.floor((W - 12) / cols)
	local cellH = 34

	for i = 1, #apps do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local x = 6 + col * cellW
		local y = top + row * (cellH + 4)

		box(x, y, cellW - 6, 22, th.panel)
		frame(x, y, cellW - 6, 22, th.line)
		text(x + (cellW - 6) * 0.5 - CW * 0.5, y + 6, apps[i].glyph, AC())
		text(x, y + 24, apps[i].name, th.dim)

		if tap(x, y, cellW - 6, 32) then
			current = i
			setState("app")
		end
	end

	navBar("tap an app")
end

local function drawApp()
	vid:Clear(th.bg)
	local app = apps[current]
	statusBar(app.name)
	app.draw(STATUS_H + 2)
	navBar("< home")

	if tap(0, H - NAV_H, W, NAV_H) or anyButton() then setState("home") end
end

-- ------------------------------------------------------------
-- main
-- ------------------------------------------------------------
function init()
	W, H = vid.Width, vid.Height
end

function update()
	local now = gdt.CPU0.Time
	dt = math.max(0, now - t)
	t = now
	stateT = stateT + dt

	pollTouch()

	if state == "boot" then
		drawBoot()
	elseif state == "home" then
		drawHome()
	else
		drawApp()
	end
end
