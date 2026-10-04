# 🛠️ Build Your Own UI Library Using OzionUI

This guide teaches you how OzionUI works on the inside and how to use it as a
base to build **your own** library — whether that means rebranding it, cutting
it down, or extending it with brand-new element types.

Everything here references real, runnable code in [`OzionUI.lua`](OzionUI.lua).

---

## 0. The mental model

Every executor UI library ever made (Obsidian, Orion, Linoria, OzionUI) is the
same four ideas stacked on top of each other:

```
┌─────────────────────────────────────────────────────────┐
│ 1. INSTANCE FACTORY  — build GUI trees in one line      │
│ 2. ANIMATION LAYER   — a smart wrapper around TweenService│
│ 3. CONTAINERS        — Window → Tab → Section auto-layout│
│ 4. ELEMENTS          — rows that read config + fire callbacks│
└─────────────────────────────────────────────────────────┘
```

Master those four and you can build any UI library from scratch. Let's walk
through each one, then build a brand-new element, then publish.

---

## 1. The instance factory — `Create`

Roblox GUI code is normally 10 lines of `Instance.new` + assignments per
object. The factory collapses that to one:

```lua
-- OzionUI.lua — "Instance factory" section
local function Create(className, props)
    local instance = Instance.new(className)
    local parent = nil
    for key, value in pairs(props or {}) do
        if key == "Parent" then
            parent = value          -- parent LAST, after every property
        else
            instance[key] = value
        end
    end
    if parent ~= nil then instance.Parent = parent end
    return instance
end
```

Usage:

```lua
local label = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 20),
    BackgroundTransparency = 1,
    Text = "Hello",
    TextSize = 13,
    Font = Enum.Font.GothamMedium,
    TextColor3 = Color3.fromRGB(236, 236, 246),
    Parent = someFrame,
})
```

**Lesson:** always assign `Parent` last — instantiating an object *while* it's
already parented re-renders it for every property change, which stutters.
The whole library (window, every element, notifications) is built from this one
function plus tiny helpers `NewCorner`, `NewStroke`, `NewPadding`.

**Try it:** open `OzionUI.lua`, search for `local function NewStroke` — three
lines, and it also shows the theme binding trick we'll meet in section 5.

---

## 2. The animation layer — `Animate`

The naive way to tween is `TweenService:Create(...)` everywhere. The problem:
two tweens on the same object fight and flicker. OzionUI keeps **one active
tween per object** — starting a new one cancels the old automatically:

```lua
local ActiveTweens = setmetatable({}, { __mode = "k" })  -- weak keys = no leaks

local function Animate(object, duration, props, style, direction, delayTime, onComplete)
    local previous = ActiveTweens[object]
    if previous then
        for _, tween in ipairs(previous) do
            pcall(function() tween:Cancel() end)
        end
    end
    local info = TweenInfo.new(duration or 0.25,
        style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out,
        0, false, delayTime or 0)
    local tween = TweenService:Create(object, info, props)
    ActiveTweens[object] = { tween }
    if onComplete then
        tween.Completed:Connect(function(state)
            if state ~= Enum.PlaybackState.Cancelled then  -- don't fire on cancel
                onComplete()
            end
        end)
    end
    tween:Play()
    return tween
end
```

Three details worth stealing:

1. **Weak table** (`__mode = "k"`) — destroyed instances drop out of the
   registry automatically. No memory leaks, ever.
2. **The cancel guard** — `Completed` fires on `Cancel()` too; check the
   playback state before running your "done" callback.
3. **`delayTime` gives you cascades for free.** The dropdown's staggered items
   are one loop: `Animate(item, 0.2, {...}, nil, nil, 0.015 * index)`.

The `Back` easing style is the "cool factor" cheat code — it overshoots and
settles, which reads as *springy*:

```lua
Animate(knob, 0.3, { Position = UDim2.fromOffset(30, 10) }, Enum.EasingStyle.Back)
Animate(windowScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)  -- window open
```

There's also `AnimateLoop` for infinite ping-pong tweens (the keybind chip
pulse, the splash glow) — it deliberately does **not** register with the
manager so `Animate` can't cancel it.

---

## 3. Containers — Window → Tabs → Sections

The layout uses zero manual positioning. Everything is auto-layout:

```
ScreenGui
└─ Main (CanvasGroup — lets us fade the WHOLE window at once)
   ├─ Topbar (title, subtitle, minimize, close)      ← drag handle
   └─ Body (CanvasGroup — fades out when minimized)
      ├─ Sidebar
      │  └─ TabButtons ScrollingFrame
      │     ├─ Glow (the sliding pill, child of each tab button)
      │     └─ Tab buttons × N
      └─ Content (CanvasGroup — cross-fades between tabs)
         └─ Tab frames × N (ScrollingFrame, one visible at a time)
            └─ Section cards (Frame, AutomaticSize = Y)
               └─ Element rows (UIListLayout stacks them)
```

Three Roblox features do all the heavy lifting:

| Feature | What it buys you |
|---|---|
| `AutomaticSize = Enum.AutomaticSize.Y` | sections grow to fit their elements |
| `AutomaticCanvasSize` | scroll frames grow their canvas to fit content |
| `UIListLayout` | elements stack with padding — never compute a Y position |

**The sliding tab pill** (`Window:SelectTab`) is a nice trick: instead of one
shared indicator (which fights with scrolling and layouts), each tab button
owns a `Glow` frame. When you select a tab, its glow *starts at the old tab's
offset* and animates to zero — pure illusion of a pill flying between tabs:

```lua
tab._glow.Position = UDim2.new(0, 0, 0, (previous._order - tab._order) * 40)
Animate(tab._glow, 0.32, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
```

**CanvasGroup** is the modern secret weapon: it flattens a whole branch into
one texture, so `GroupTransparency` fades *everything at once* (window
open/close, tab cross-fade, minimize, popovers, toasts). OzionUI probes for it
once (`local CanGroup = pcall(function() Instance.new("CanvasGroup") end)`)
and falls back to plain Frames so it still runs on ancient executors.

**Dragging with inertia** — most libraries set `Position` 1:1 with the mouse.
OzionUI stores a *target* and lets the frame lerp toward it every frame:

```lua
-- in the RenderStepped loop
main.Position = main.Position:Lerp(window._targetPos, math.min(dt * 18, 1))
```

That one line is the difference between "rigid" and "buttery".

---

## 4. Anatomy of an element

Every element is the same pattern. Here's `AddToggle` reduced to its skeleton:

```lua
local function AddToggle(ctx, cfg)
    -- ctx = { Container (the section card), Window, Order }
    -- 1. STATE from config
    local on = cfg.Default == true

    -- 2. BUILD the row (factory + auto-layout)
    local row = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })

    -- 3. WIRE interactions
    row.MouseButton1Click:Connect(function() Set(not on) end)

    -- 4. SET function: update visuals + fire callback (always pcall'd)
    local function Set(value)
        on = value == true
        Animate(knob, 0.3, { Position = on and ON or OFF }, Enum.EasingStyle.Back)
        MarkConfigDirty(ctx.Window)                 -- config autosave
        SafeCallback(cfg.Callback, on)              -- pcall-wrapped
    end

    -- 5. RETURN an element table with Get/Set
    local element = { Type = "Toggle", Get = function() return on end, Set = Set }
    RegisterFlag(ctx, cfg.Flag, element)            -- opts into configs
    return element
end
```

Because every element follows this shape, the config system (`SaveConfig`,
`LoadConfig`, autosave) works on *all of them for free* — it just calls
`element.Get()` to serialize and `element.Set(v)` to apply.

---

## 5. The theme engine (the part everyone gets wrong)

Hardcoding colors is why most homemade UI libraries can't be re-themed.
OzionUI uses **bindings** — a registry of (object, property, evaluator):

```lua
-- static binding:  always the theme's Accent
BindTheme(fill, "BackgroundColor3", "Accent")

-- dynamic binding: depends on element state
BindTheme(track, "BackgroundColor3", function()
    return on and Theme.Accent or Theme.ToggleOff
end)
```

`BindTheme` applies immediately **and** stores the evaluator. When the theme
changes, `ApplyTheme` walks the registry and re-evaluates every binding —
which is why `OzionUI:SetTheme("Ocean")` recolors every open window instantly,
and why rainbow mode can push a new accent 30 times a second. Bindings whose
instance was destroyed get purged automatically.

**Rule of thumb:** never write `BackgroundColor3 = someColor` in an element.
Bind it. (The only exceptions are the color-picker chip and preview — those
show the *user's chosen color*, not a theme color.)

---

## 6. Hands-on: add a brand-new element — `AddProgressBar`

Let's build an element OzionUI doesn't have. ~60 lines, everything you've
learned. Drop this anywhere **above** `local ElementFactories = {` in
`OzionUI.lua`:

```lua
-- ===== ProgressBar ==========================================================
local function AddProgressBar(ctx, cfg)
    local window = ctx.Window
    local progress = math.clamp(cfg.Default or 0, 0, 100)

    -- row: transparent, 44px tall
    local row = Create("Frame", {
        Name = "ProgressBar",
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = NextOrder(ctx),
        Parent = ctx.Container,
    })

    -- title left, percentage right
    local title = Create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 2),
        Size = UDim2.new(1, -70, 0, 16),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or "Progress"),
        TextSize = 13, Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    BindTheme(title, "TextColor3", "Text")

    local percent = Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 2),
        Size = UDim2.new(0, 50, 0, 16),
        BackgroundTransparency = 1,
        Text = math.floor(progress + 0.5) .. "%",
        TextSize = 12, Font = FONT_BODY,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })
    BindTheme(percent, "TextColor3", "SubText")

    -- the bar itself
    local track = Create("Frame", {
        Position = UDim2.new(0, 12, 0, 24),
        Size = UDim2.new(1, -24, 0, 8),
        BorderSizePixel = 0,
        Parent = row,
    })
    NewCorner(track, 4)
    BindTheme(track, "BackgroundColor3", "SliderTrack")

    local fill = Create("Frame", {
        Size = UDim2.new(progress / 100, 0, 1, 0),
        BorderSizePixel = 0,
        Parent = track,
    })
    NewCorner(fill, 4)
    BindTheme(fill, "BackgroundColor3", "Accent")   -- theme-aware!

    -- shimmer: a light stripe sliding across the fill, forever
    local shimmer = Create("Frame", {
        Size = UDim2.new(0.25, 0, 1, 0),
        BackgroundTransparency = 0.75,
        BorderSizePixel = 0,
        Parent = fill,
    })
    NewCorner(shimmer, 4)
    BindTheme(shimmer, "BackgroundColor3", "Text")
    shimmer.Position = UDim2.new(-0.3, 0, 0, 0)
    AnimateLoop(shimmer, { Position = UDim2.new(1, 0, 0, 0) }, 1.2)

    local function Set(value)
        progress = math.clamp(tonumber(value) or 0, 0, 100)
        Animate(fill, 0.35, { Size = UDim2.new(progress / 100, 0, 1, 0) },
            Enum.EasingStyle.Quint)
        percent.Text = math.floor(progress + 0.5) .. "%"
        SafeCallback(cfg.Callback, progress)
    end

    local element = {
        Type = "ProgressBar",
        Get = function() return progress end,
        Set = Set,
    }
    RegisterFlag(ctx, cfg.Flag, element)
    return element
end
```

Then register it so sections/tabs get the method:

```lua
local ElementFactories = {
    ...
    ProgressBar = AddProgressBar,   -- ← add this line
}

-- and inside AttachElementAPI:
function holder:AddProgressBar(cfg) return AddElement(ctx, "ProgressBar", cfg) end
```

Use it:

```lua
local Section = Tab:AddSection({ Title = "Loading" })
local bar = Section:AddProgressBar({ Title = "Downloading assets", Default = 0 })
task.spawn(function()
    for i = 0, 100 do
        bar:Set(i)
        task.wait(0.05)
    end
end)
```

Congratulations — you just extended the library. The config system, theming,
auto-layout and (via `test/`) automated testing all picked it up for free.
Run `python3 test/run_tests.py` and add a step that exercises it if you want
the same safety net OzionUI's own elements have.

**Exercise ideas, in increasing difficulty:**
1. `AddImage` — an `ImageLabel` with rounded corners + fade-in on creation.
2. `AddButtonMenu` — a button that expands into sub-buttons (steal the
   dropdown's height-tween pattern).
3. A draggable floating HUD widget (steal the window's `MakeDraggableArea`
   + lerp loop pattern).

---

## 7. Rebranding OzionUI into *your* library

The fastest path — 10 minutes:

1. **Fork/copy the repo**, rename `OzionUI.lua` → `YourNameUI.lua`.
2. **Find & replace** the string `OzionUI` with your brand (safe: it only
   appears in gui names, comments and the default title).
3. Change the identity block:
   - `local VERSION = "1.0.0"` → your version
   - `DefaultTheme` colors → your palette (change `Accent` + `Background` at
     minimum — that alone makes it look completely different)
   - The splash: `ShowSplash(screenGui, cfg.Title or "OZION UI", ...)` and the
     `logo` label font/size in the splash
   - `FONT_TITLE / FONT_BODY / FONT_SMALL` — try `Enum.Font.GothamBlack` for
     titles, `Enum.Font.Ubuntu` for body, instant personality change
4. Tune the motion to your taste:
   - window open snap: `Animate(mainScale, 0.35, ... Back)` — 0.25 = snappier
   - tab glide: the `0.32` in `Window:SelectTab`
   - drag feel: the `* 18` in the drag lerp (higher = tighter follow)
   - rainbow speed: `* 0.25` in `InstallFrameLoop`
5. Add your own elements (section 6) and/or delete the ones you don't need by
   removing them from `ElementFactories` + `AttachElementAPI`.
6. Rename `GUIDE.md`/`README.md` credit, ship it.

---

## 8. Publishing & loading from an executor

1. Push `YourNameUI.lua` to a **public** GitHub repo.
2. The raw URL is your loader:

```lua
local YourUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/YourNameUI.lua"
))()
```

Notes:

- `main` is the branch name — match yours.
- Update the URL in your scripts after renaming; **the library returns a
  table**, so `loadstring(...)()`'s trailing `()` is mandatory.
- For local testing without hosting: `loadstring(readfile("YourNameUI.lua"))()`.
- Version your library (`VERSION`) and mention breaking changes — people
  hotlink your raw URL forever.

---

## 9. Compatibility cheat sheet (why the code looks the way it does)

| Guard in OzionUI | Reason |
|---|---|
| `gethui()` → `syn.protect_gui` → `CoreGui` → `PlayerGui` | each executor hides GUIs differently; this chain works everywhere |
| `pcall(Instance.new, "CanvasGroup")` probe + Frame fallback | pre-2022 clients/executors lack CanvasGroup |
| `if type(writefile) == "function"` | configs silently disable when the executor has no filesystem |
| callbacks inside `pcall` (`SafeCallback`) | a broken user script can't freeze your UI |
| `math.clamp or fallback`, `table.find or fallback` | the file also parses on plain Lua — that's how the headless test suite runs it |
| connections tracked in `window._connections` / `Library._connections` | `Destroy()` unhooks everything — no ghost input handlers |
| `IgnoreGuiInset = true` on ScreenGuis | makes `UserInputService:GetMouseLocation()` match `AbsolutePosition` (needed for ripples & slider math) |

---

## 10. Where to go next

- Read `AddDropdown` — the most complex element: state, multi-select, height
  tween + staggered children, all at once.
- Read `Library:Notification` — auto-sizing layout, enter/exit choreography,
  progress-bar-driven lifetime.
- Read `test/harness.lua` — a full mock of Roblox's instance/enum/tween/input
  API in ~1000 lines of plain Lua. Understanding it means you can test ANY
  Roblox script without opening Roblox.
- Skim the Obsidian library itself and compare: same API, different internals.
  That comparison is a masterclass in library design.

Now go build something obnoxiously animated. 🚀
