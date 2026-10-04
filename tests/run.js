/*
 * Headless test runner for OzionUI.
 *
 *   node tests/run.js
 *
 * Boots a Lua 5.4 VM (wasmoon), installs the Roblox API mock from
 * tests/mock_roblox.lua, executes the single-file OzionUI.lua bundle exactly
 * the way an executor would and drives it through tests/suite.lua.
 * Exits non-zero when anything throws.
 */

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const FILES = [
  "OzionUI.lua",
  "tests/mock_roblox.lua",
  "tests/suite.lua",
  "Example.lua",
  "examples/Template.lua",
];

(async () => {
  let LuaFactory;
  try {
    ({ LuaFactory } = require("wasmoon"));
  } catch (e) {
    console.error("wasmoon is not installed.  Run:  npm install wasmoon");
    process.exit(2);
  }

  const sources = {};
  for (const file of FILES) {
    const full = path.join(ROOT, file);
    if (!fs.existsSync(full)) {
      console.warn(`(skipping missing file: ${file})`);
      continue;
    }
    sources[file] = fs.readFileSync(full, "utf8");
  }

  const lua = await new LuaFactory().createEngine();
  lua.global.set("FILES", sources);

  const bootstrap = `
    local function chunk(name)
      local source = FILES[name]
      assert(source, "no source for " .. name)
      local fn, err = load(source, "@" .. name)
      if not fn then error("syntax error in " .. name .. ": " .. tostring(err), 0) end
      return fn
    end
    _G.LOAD_CHUNK = chunk
    return chunk("tests/suite.lua")()
  `;

  try {
    await lua.doString(bootstrap);
  } catch (err) {
    console.error("\n\u001b[31mFAILED\u001b[0m\n");
    console.error(err.message || err);
    process.exit(1);
  } finally {
    lua.global.close();
  }
})();
