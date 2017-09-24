requireInjector = requireInjector or load(http.get('https://raw.githubusercontent.com/kepler155c/opus/develop/sys/apis/injector.lua').readAll())()
requireInjector(getfenv(1))

local Util = require('util')

local function syntax()
  printError('Syntax:')
  printError('Start a new session')
  print('monitorManager start [configFile] [monitor]')
  print()
  printError('Run programs in session')
  print('monitorManager run [program] [arguments]')
  print()
  error()
end

local args = { ... }
local UID = 0
local processes = { }
local parentTerm = term.current()
local configFile = args[1] or syntax()
local monitor = peripheral.find(args[2] or 'monitor') or syntax()
local defaultEnv = Util.shallowCopy(getfenv(1))

monitor.setTextScale(.5)
monitor.clear()

local monDim, termDim = { }, { }
monDim.width, monDim.height = monitor.getSize()
termDim.width, termDim.height = parentTerm.getSize()

local function saveConfig()
  local t = { }
  for _,process in pairs(processes) do
    if process.path and not process.isShell then
      table.insert(t, {
        x = process.x,
        y = process.y,
        width = process.width - 2,
        height = process.height - 3,
        path = process.path,
        args = process.args,
      })
    end
  end
  Util.writeTable(configFile, t)
end

local function write(win, x, y, text)
  win.setCursorPos(x, y)
  win.write(text)
end

local function redraw()
  monitor.clear()
  for k,process in ipairs(processes) do
    process.container.redraw()
    process:focus(k == #processes)
  end
end

local function focusProcess(process)
  if #processes > 0 then
    processes[#processes]:focus(false)
  end

  for k,v in pairs(processes) do
    if v == self then
      table.remove(processes, k)
      break
    end
  end

  table.insert(processes, process)
  process:focus(true)
end

local Process = { }

function Process:focus(focused)
  if focused then
    self.titleBar.setBackgroundColor(colors.green)
  else
    self.titleBar.setBackgroundColor(colors.gray)
  end
  self.titleBar.clear()
  self.titleBar.setTextColor(colors.black)
  write(self.titleBar, 2, 1, self.title)
  write(self.titleBar, self.width - 3, 1, '*')

  if focused then
    self.window.restoreCursor()
  end
end

function Process:drawSizers()
  self.container.setBackgroundColor(colors.black)
  self.container.setTextColor(colors.white)

  if self.showSizers then
    write(self.container, 1, 1, '\135')
    write(self.container, self.width, 1, '\139')
    write(self.container, 1, self.height, '\141')
    write(self.container, self.width, self.height, '\142')

    self.container.setTextColor(colors.yellow)
    write(self.container, 1, 3, '+')
    write(self.container, 1, 5, '-')
    write(self.container, 3, 1, '+')
    write(self.container, 5, 1, '-')

    local str = string.format('%d x %d', self.width - 2, self.height - 3)
    write(self.container, (self.width - #str) / 2, 1, str)

  else
    write(self.container, 1, 1, string.rep(' ', self.width))
    write(self.container, self.width, 1, ' ')
    write(self.container, 1, self.height, ' ')
    write(self.container, self.width, self.height, ' ')
    write(self.container, 1, 3, ' ')
    write(self.container, 1, 5, ' ')
  end
end

function Process:new(args)
  args.env = args.env or Util.shallowCopy(defaultEnv)
  args.width = args.width or termDim.width
  args.height = args.height or termDim.height

  UID = UID + 1
  self.uid = UID

  self.x = args.x or 1
  self.y = args.y or 1
  self.width = args.width + 2
  self.height = args.height + 3
  self.path = args.path
  self.args = args.args  or { }
  self.title = args.title or 'shell'

  self:adjustDimensions()

  self.container = window.create(monitor, self.x, self.y, self.width, self.height, true)
  self.titleBar = window.create(self.container, 2, 2, self.width - 2, 1, true)
  self.window = window.create(self.container, 2, 3, args.width, args.height, true)

  self.terminal = self.window

  self.co = coroutine.create(function()

    local result, err

    if args.fn then
      result, err = Util.runFunction(args.env, args.fn, table.unpack(self.args))
    elseif args.path then
      result, err = os.run(args.env, args.path, table.unpack(self.args))
    end

    if not result and err ~= 'Terminated' then
      if err then
        printError(tostring(err))
        os.sleep(3)
      end
    end
    for k,v in pairs(processes) do
      if v == self then
        table.remove(processes, k)
        break
      end
    end
    --saveConfig()
    redraw()
  end)

  local previousTerm = term.current()
  self:resume()
  term.redirect(previousTerm)

  return tab
end

function Process:adjustDimensions()

  self.width = math.min(self.width, monDim.width)
  self.height = math.min(self.height, monDim.height)

  self.x = math.max(1, self.x)
  self.y = math.max(1, self.y)
  self.x = math.min(self.x, monDim.width - self.width + 1)
  self.y = math.min(self.y, monDim.height - self.height + 1)
end

function Process:reposition()

  self:adjustDimensions()
  self.container.reposition(self.x, self.y, self.width, self.height)
  self.container.setBackgroundColor(colors.black)
  self.container.clear()

  self.titleBar.reposition(2, 2, self.width - 2, 1)
  self.window.reposition(2, 3, self.width - 2, self.height - 3)

  redraw()
end

function Process:resizeClick(x, y)
  if x == 1 and y == 3 then
    self.height = self.height + 1
  elseif x == 1 and y == 5 then
    self.height = self.height - 1
  elseif x == 3 and y == 1 then
    self.width = self.width + 1
  elseif x == 5 and y == 1 then
    self.width = self.width - 1
  else
    return
  end
  self:reposition()
  self:resume('term_resize')
  self:drawSizers()
  saveConfig()
end

function Process:resume(event, ...)
  if coroutine.status(self.co) == 'dead' then
    return
  end

  if not self.filter or self.filter == event or event == "terminate" then
    term.redirect(self.terminal)

    local ok, result = coroutine.resume(self.co, event, ...)
    self.terminal = term.current()
    if ok then
      self.filter = result
    else
      printError(result)
    end
    return ok, result
  end
end

function getProcessAt(x, y)
  for k = #processes, 1, -1 do
    local process = processes[k]
    if x >= process.x and 
       y >= process.y and
       x <= process.x + process.width - 1 and
       y <= process.y + process.height - 1 then
      return k, process
    end
  end
end

defaultEnv.multishell = { }

function defaultEnv.multishell.getFocus()
  return processes[#processes].uid
end

function defaultEnv.multishell.setFocus(uid)
  local process, key = Util.find(processes, 'uid', uid)

  if process then
    if processes[#processes] ~= process then
      focusProcess(process)
    end
    return true
  end
  return false
end

function defaultEnv.multishell.getTitle(uid)
  local process = Util.find(processes, 'uid', uid)
  if process then
    return process.title
  end
end

function defaultEnv.multishell.setTitle(uid, title)
  local process = Util.find(processes, 'uid', uid)
  if process then
    process.title = title or ''
    process:focus(processs == processes[#processes])
  end
end

function defaultEnv.multishell.getCurrent()
  return processes[#processes].uid
end

function defaultEnv.multishell.getCount()
  return Util.size(processes)
end

function defaultEnv.multishell.launch(env, file, ...)
  return defaultEnv.multishell.openTab({
    path  = file,
    env   = env,
    title = 'shell',
    args  = { ... },
  })
end

function defaultEnv.multishell.openTab(tabInfo)
  local process = setmetatable({ }, { __index = Process })

  table.insert(processes, process)
  process:new(tabInfo)
  focusProcess(process)
  saveConfig()

  return process.uid
end

if fs.exists(configFile) then
  local config = Util.readTable(configFile)
  if config then
    for _,v in pairs(config) do
      local process = setmetatable({ }, { __index = Process })
      table.insert(processes, process)
      process:new(v)
      process:focus(false)
    end
  end
end

local function addShell()

  UID = UID + 1

  local process = setmetatable({
    x = monDim.width - 8,
    y = monDim.height,
    width = 9,
    height = 1,
    isShell = true,
    uid = UID,
  }, { __index = Process })

  table.insert(processes, 1, process)

  function process:focus(focused)
    self.window.setVisible(focused)
    if focused then
      self.window.restoreCursor()
      self.container.setTextColor(colors.green)
      self.container.setBackgroundColor(colors.black)
    else
      parentTerm.clear()
      parentTerm.setCursorBlink(false)
      self.container.setTextColor(colors.lightGray)
      self.container.setBackgroundColor(colors.black)
    end
    write(self.container, 1, 1, '[ shell ]')
  end

  function process:resizeClick()
  end

  function process:drawSizers()
  end

  process.container = window.create(monitor, process.x, process.y, process.width, process.height, true)
  process.window    = window.create(parentTerm, 1, 1, termDim.width, termDim.height, true)
  process.terminal  = process.window

  process.co = coroutine.create(function()
    while true do
      os.run(defaultEnv, shell.resolveProgram('shell'))
    end
  end)

  process:focus(false)
  local previousTerm = term.current()
  process:resume()
  term.redirect(previousTerm)
end

addShell()

processes[#processes]:focus(true)

while true do

  local event = { os.pullEventRaw() }

  if event[1] == 'terminate' then
    term.redirect(parentTerm)
    break

  elseif event[1] == "monitor_touch" then
    local x, y = event[3], event[4]

    local key, process = getProcessAt(x, y)
    if process then
      if key ~= #processes then
        focusProcess(process)
      end

      x = x - process.x + 1
      y = y - process.y + 1

      if y == 2 then -- title bar
        if x == process.width - 2 then
          process:resume('terminate')
        else
          process.showSizers = not process.showSizers
          process:drawSizers()
        end

      elseif x == 1 or y == 1 then -- sizers
        process:resizeClick(x, y)

      elseif x > 1 and x < process.width then
        if process.showSizers then
          process.showSizers = false
          process:drawSizers()
        end
        process:resume('mouse_click', 1, x - 1, y - 2)
        process:resume('mouse_up',    1, x - 1, y - 2)
      end
    else
      process = processes[#processes]
      if process and process.showSizers then
        process.x = math.floor(x - (process.width) / 2)
        process.y = y
        process:reposition()
        process:drawSizers()
        saveConfig()
      end
    end

  elseif event[1] == "char" or
         event[1] == "key" or
         event[1] == "key_up" or
         event[1] == "paste" then

    local focused = processes[#processes]
    if focused then
      focused:resume(unpack(event))
    end

  else
    for _,process in pairs(Util.shallowCopy(processes)) do
      process:resume(unpack(event))
    end
    if processes[#processes] then
      processes[#processes].window.restoreCursor()
    end
  end
end
