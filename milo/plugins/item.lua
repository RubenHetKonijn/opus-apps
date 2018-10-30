local Ansi = require('ansi')
local Milo = require('milo')
local UI   = require('ui')
local Util = require('util')

local colors = _G.colors
local device = _G.device

local context = Milo:getContext()

-- TODO: allow change of machine

local itemPage = UI.Page {
  titleBar = UI.TitleBar {
    title = 'Limit Resource',
    previousPage = true,
    event = 'form_cancel',
  },
  form = UI.Form {
    x = 1, y = 2, height = 10, ex = -1,
    [1] = UI.TextEntry {
      width = 7,
      formLabel = 'Min', formKey = 'low', help = 'Craft if below min'
    },
    [2] = UI.TextEntry {
      width = 7,
      formLabel = 'Max', formKey = 'limit', help = 'Eject if above max'
    },
--[[
    [3] = UI.Chooser {
      width = 7,
      formLabel = 'Autocraft', formKey = 'auto',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Craft until out of ingredients'
    },
]]
    [4] = UI.Checkbox {
      formLabel = 'Ignore Dmg', formKey = 'ignoreDamage',
      help = 'Ignore damage of item'
    },
    [5] = UI.Checkbox {
      formLabel = 'Ignore NBT', formKey = 'ignoreNbtHash',
      help = 'Ignore NBT of item'
    },
    [6] = UI.Button {
      x = 2, y = -2, width = 10,
      formLabel = 'Machine',
      event = 'select_machine',
      text = 'Configure',
    },
    infoButton = UI.Button {
      x = 2, y = -2,
      event = 'show_info',
      text = 'Info',
    },
  },
  rsControl = UI.SlideOut {
    backgroundColor = colors.cyan,
    titleBar = UI.TitleBar {
      title = "Redstone Control",
    },
    form = UI.Form {
      y = 2,
      [1] = UI.Chooser {
        width = 7,
        formLabel = 'RS Control', formKey = 'rsControl',
        nochoice = 'No',
        choices = {
          { name = 'Yes', value = true },
          { name = 'No', value = false },
        },
        help = 'Control via redstone'
      },
      [2] = UI.Chooser {
        width = 25,
        formLabel = 'RS Device', formKey = 'rsDevice',
        --choices = devices,
        help = 'Redstone Device'
      },
      [3] = UI.Chooser {
        width = 10,
        formLabel = 'RS Side', formKey = 'rsSide',
        --nochoice = 'No',
        choices = {
          { name = 'up', value = 'up' },
          { name = 'down', value = 'down' },
          { name = 'east', value = 'east' },
          { name = 'north', value = 'north' },
          { name = 'west', value = 'west' },
          { name = 'south', value = 'south' },
        },
        help = 'Output side'
      },
    },
  },
  machines = UI.SlideOut {
    backgroundColor = colors.cyan,
    titleBar = UI.TitleBar {
      title = 'Select Machine',
      previousPage = true,
    },
    grid = UI.ScrollingGrid {
      y = 2, ey = -4,
      disableHeader = true,
      values = context.config.remoteDefaults,
      columns = {
        { heading = 'Name', key = 'displayName'},
      },
      sortColumn = 'displayName',
    },
    button1 = UI.Button {
      x = -14, y = -2,
      text = 'Ok', event = 'set_machine',
    },
    button2 = UI.Button {
      x = -9, y = -2,
      text = 'Cancel', event = 'cancel_machine',
    },
  },
  info = UI.SlideOut {
    titleBar = UI.TitleBar {
      title = "Information",
    },
    textArea = UI.TextArea {
      x = 2, ex = -2, y = 3, ey = -4,
      backgroundColor = colors.black,
    },
    cancel = UI.Button {
      ex = -2, y = -2, width = 6,
      text = 'Okay',
      event = 'hide_info',
    },
  },
  statusBar = UI.StatusBar { }
}

function itemPage:enable(item)
  self.item = Util.shallowCopy(item)

  self.form:setValues(self.item)
  self.titleBar.title = item.displayName or item.name

  UI.Page.enable(self)
  self:focusFirst()
end

function itemPage.machines.grid:isRowValid(_, value)
  return value.mtype == 'machine'
end

function itemPage.machines.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  row.displayName = row.displayName or row.name
  return row
end

function itemPage.rsControl:enable()
  local devices = self.form[1].choices
  Util.clear(devices)
  for _,dev in pairs(device) do
    if dev.setOutput then
      table.insert(devices, { name = dev.name, value = dev.name })
    end
  end

  if Util.size(devices) == 0 then
    table.insert(devices, { name = 'None found', values = '' })
  end

  UI.SlideOut.enable(self)
end

function itemPage.rsControl:eventHandler(event)
  if event.type == 'form_cancel' then
    self:hide()
  elseif event.type == 'form_complete' then
    self:hide()
  else
    return UI.SlideOut.eventHandler(self, event)
  end
  return true
end

function itemPage:eventHandler(event)
  if event.type == 'form_cancel' then
    UI:setPreviousPage()

  elseif event.type == 'show_rs' then
    self.rsControl:show()

  elseif event.type == 'select_machine' then
    self.machines.grid:update()
    self.machines.grid:setIndex(1)
    self.machines:show()

  elseif event.type == 'set_machine' then
    --TODO save machine
    self.machines:hide()

  elseif event.type == 'cancel_machine' then
    self.machines:hide()

  elseif event.type == 'show_info' then
    local value =
      string.format('%s%s%s\n%s\n',
        Ansi.orange, self.item.displayName, Ansi.reset,
        self.item.name)

    if self.item.nbtHash then
      value = value .. self.item.nbtHash .. '\n'
    end

    value = value .. string.format('\n%sDamage:%s %s',
      Ansi.yellow, Ansi.reset, self.item.damage)

    if self.item.maxDamage and self.item.maxDamage > 0 then
      value = value .. string.format(' (max: %s)', self.item.maxDamage)
    end

    if self.item.maxCount then
      value = value .. string.format('\n%sStack Size: %s%s',
        Ansi.yellow, Ansi.reset, self.item.maxCount)
    end

    self.info.textArea.value = value
    self.info:show()

  elseif event.type == 'hide_info' then
    self.info:hide()

  elseif event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
    self.statusBar:draw()

  elseif event.type == 'form_complete' then
    local values = self.form.values
    local originalKey = Milo:uniqueKey(self.item)

    local filtered = Util.shallowCopy(values)
    filtered.low = tonumber(filtered.low)
    filtered.limit = tonumber(filtered.limit)

    if filtered.auto ~= true then
      filtered.auto = nil
    end

    if filtered.rsControl ~= true then
      filtered.rsControl = nil
      filtered.rsSide = nil
      filtered.rsDevice = nil
    end

    if filtered.ignoreDamage == true then
      filtered.damage = 0
    else
      filtered.ignoreDamage = nil
    end

    if filtered.ignoreNbtHash == true then
      filtered.nbtHash = nil
    else
      filtered.ignoreNbtHash = nil
    end
    context.resources[originalKey] = nil
    context.resources[Milo:uniqueKey(filtered)] = filtered

    filtered.count = nil
    Milo:saveResources()

    UI:setPreviousPage()

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

UI:addPage('item', itemPage)
