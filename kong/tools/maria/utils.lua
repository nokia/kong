--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

local cjson = require "cjson"


local _M = {}


function _M.escape_identifier(self, ident)
  return '`' .. (tostring(ident):gsub('"', '""')) .. '`'
end


function _M.escape_literal(self, val)
  local _exp_0 = type(val)
  if "number" == _exp_0 then
    return tostring(val)
  elseif "string" == _exp_0 then
    return "'" .. tostring((val:gsub("'", "''"))) .. "'"
  elseif "boolean" == _exp_0 then
    return val and "TRUE" or "FALSE"
  end
  return error("don't know how to escape value: " .. tostring(val))
end


-- This function converts a string JSON or a MariaDB JSON_ARRAY into a LUA table
function _M.decode_json(config)
  local ok, response = pcall(function(json)
    return cjson.decode(json)
  end, config)
  if not ok then
    error(string.format("JSON is invalid. \nREASON: %s \nBROKEN JSON: %s",
                        tostring(response), tostring(config)))
  end
  return response
end


-- This function converts a Lua array into a MariaDB JSON_ARRAY representation
function _M.encode_array(input_array)
  if type(input_array) ~= "table" then
    return error("cannot encode - incorrect input (not an array): " ..
            tostring(input_array))
  end
  return "'" .. cjson.encode(input_array) .. "'"
end


return _M