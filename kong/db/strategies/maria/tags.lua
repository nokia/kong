--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

local cjson         = require "cjson"
local cjson_safe    = require "cjson.safe"
local encode_base64 = ngx.encode_base64
local decode_base64 = ngx.decode_base64
local fmt           = string.format


local Tags = {}

local sql_templates = {
  page_first = [[
  CALL page_first(%s);
  ]],
  page_next  = [[
  CALL page_next(%s, %s, %s, %s);
  ]],
  page_for_tag_first = [[
  CALL page_for_tag_first(%s, %s);
  ]],
  page_for_tag_next  = [[
  CALL page_for_tag_next(%s, %s, %s);
  ]],
}

local function page(self, size, token, options, tag)
  local limit = size + 1

  local sql
  local args

  local tag_literal
  if tag then
    tag_literal = self:escape_literal(tag)
  end

  if token then
    local token_decoded = decode_base64(token)
    if not token_decoded then
      return nil, self.errors:invalid_offset(token, "bad base64 encoding")
    end

    token_decoded = cjson_safe.decode(token_decoded)
    if not token_decoded then
      return nil, self.errors:invalid_offset(token, "bad json encoding")
    end

    local entity_id_delimeter = self:escape_literal(token_decoded[1])

    if tag then
      sql = sql_templates.page_for_tag_next
      args = {
        entity_id_delimeter,
        tag_literal, limit
      }
    else
      sql = sql_templates.page_next
      local ordinality_delimeter = self:escape_literal(token_decoded[2])
      args = {
        entity_id_delimeter, entity_id_delimeter,
        ordinality_delimeter, limit
      }
    end
  else
    if tag then
      sql = sql_templates.page_for_tag_first
      args = { tag_literal, limit  }
    else
      sql = sql_templates.page_first
      args = { limit }
    end
  end

  sql = fmt(sql, unpack(args))

  local res, err = self.connector:query(sql)

  if not res then
    return nil, self.errors:database_error(err)
  end

  local rows = kong.table.new(size, 0)

  local last_ordinality

  for i = 1, limit do
    local row = res[i]
    if not row then
      break
    end

    if i == limit then
      row = res[size]
      local offset = {
        row.entity_id,
        last_ordinality
      }

      offset = cjson.encode(offset)
      offset = encode_base64(offset, true)

      return rows, nil, offset
    end

    last_ordinality = row.ordinality
    row.ordinality = nil

    if tag then
      row.tag = tag
    end
    rows[i] = self.expand(row)
  end

  return rows

end

function Tags:page_by_tag(tag, size, token, options)
  return page(self, size, token, options, tag)
end

-- Overwrite the page function for /tags
function Tags:page(size, token, options)
  return page(self, size, token, options)
end


return Tags
