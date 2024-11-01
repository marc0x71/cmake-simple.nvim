local uv = vim.uv
local windows_listener = require('cmake-simple.lib.listener.window_listener')
local notification_listener = require('cmake-simple.lib.listener.notification_listener')
local writer_listener = require('cmake-simple.lib.listener.writer_listener')

local command = {}

function command:new(tmpname)
  local o = {
    name = "CMake",
    command = "cmake",
    success_message = "Done",
    failure_message = "Failed",
    log_filename = tmpname
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function command:_execute_task(args, on_progress, on_complete)
  local handle;
  local stdin = nil;
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  handle, _ = uv.spawn(self.command, {args = args, stdio = {stdin, stdout, stderr}}, function(status, _)
    uv.close(handle)
    vim.schedule(function() on_complete(status) end)
  end)

  uv.read_start(stdout, function(err, data)
    assert(not err, err)
    if data then for line in data:gmatch("[^\r\n]+") do vim.schedule(function() on_progress("out", line) end) end end
  end)
  uv.read_start(stderr, function(err, data)
    assert(not err, err)
    if data then for line in data:gmatch("[^\r\n]+") do vim.schedule(function() on_progress("err", line) end) end end
  end)
end

function command:execute(args, action, on_terminate)
  local win_listener = windows_listener:new(action)
  local ntf_listener = notification_listener:new(action)
  local wrt_listener = writer_listener:new(self.log_filename)

  local full_command = self.command .. table.concat(args, " ")
  win_listener:update("start", full_command)
  ntf_listener:update("start", full_command)
  wrt_listener:update("start", full_command)

  local on_progress = function(line_type, line)
    win_listener:update(line_type, line)
    ntf_listener:update(line_type, line)
    wrt_listener:update(line_type, line)
  end

  local on_complete = function(status)
    if (status == 0) then
      win_listener:success()
      ntf_listener:success()
      wrt_listener:success()
    else
      win_listener:failure()
      ntf_listener:failure()
      wrt_listener:failure()
    end
    on_terminate(status)
  end
  self:_execute_task(args, on_progress, on_complete)
end

return command

