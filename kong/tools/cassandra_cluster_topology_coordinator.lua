--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

local singletons = require "kong.singletons"
local DB = require "kong.db"
local pl_stringx = require "pl.stringx"
local ngx = ngx

local _M = {}

local function get_healthy_peer(peers)
  if type(peers) == "table" then
    for _, peer in ipairs(peers) do
      if peer.up then
        return peer.host
      end
    end
  end
  return nil
end

local function have_peer(host, peers)
  for _, peer in ipairs(peers) do
    if peer.host == host then
      return true
    end
  end
  return false
end

local function get_exclusive_peers(peers, peers2)
  local exclusive_peers = {}
  local i = 1
  for _, peer in ipairs(peers2) do
    if not have_peer(peer.host, peers) then
      exclusive_peers[i] = peer
      i = i+1
    end
  end
  return exclusive_peers
end

local function validate_backup_contact_points(backup_contact_points)
  if backup_contact_points == nil or backup_contact_points == "" or type(backup_contact_points) ~= "string" then
    return false
  end
  return true
end

local function get_backup_contact_points()
  local backup_contact_points = os.getenv("KONG_CASSANDRA_CONTACT_POINTS_ORIGIN")
  if not validate_backup_contact_points(backup_contact_points) then
    local err = "Failed to get primary cassandra contact points"
    return nil, err
  end

  ngx.log(ngx.DEBUG, "Primary cassandra contact points found with value: " .. backup_contact_points)
  backup_contact_points = setmetatable(pl_stringx.split(backup_contact_points, ","), nil)
  for i = 1, #backup_contact_points do
    backup_contact_points[i] = pl_stringx.strip(backup_contact_points[i])
  end
  return backup_contact_points
end

local function deep_copy_table(orig)
  local copy
  if type(orig) == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[deep_copy_table(orig_key)] = deep_copy_table(orig_value)
    end
    setmetatable(copy, deep_copy_table(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

function _M.refresh_cluster_topology()
  -- flag that is used to run this timer function only on one worker
  local lock_dict = ngx.shared.topology_coordinator_lock
  local lock, err = lock_dict:add("flag", ngx.worker.pid(), 30)
  if lock then
    ngx.log(ngx.DEBUG, "Refreshing Cassandra cluster topology")
    -- short sleep is added because it is needed to correctly lock
    -- only one worker in one ngx.timer.every interval
    ngx.sleep(2)
    -- get current list of Cassandra nodes that is stored in Kong memory
    local old_peers = kong.db.connector.cluster:get_peers()
    ngx.log(ngx.DEBUG, "Current list of Cassandra cluster peers: ")
    if type(old_peers) == "table" then
      for index, peer in pairs(old_peers) do
        ngx.log(ngx.DEBUG, tostring(index) .. " - " .. tostring(peer.host))
      end
    end

    local kong_conf_tmp = deep_copy_table(singletons.configuration)
    kong_conf_tmp.cassandra_contact_points = {}
    -- find healthy Cassandra node that will be used to initialize
    -- temporary db object
    local coordinator_peer = get_healthy_peer(old_peers)
    if not coordinator_peer then
      ngx.log(ngx.DEBUG, "Healthy cassandra peer not found." ..
        "Trying to recover using primarily set cassandra contact point")
      coordinator_peer, err = get_backup_contact_points()
      if not coordinator_peer then
        ngx.log(ngx.ERR, "Can not initialize db object - no cassandra contact point available. " ..
          "Error: " .. tostring(err))
        return
      end
      kong_conf_tmp.cassandra_contact_points = coordinator_peer
    else
      ngx.log(ngx.DEBUG, "Cassandra peer chosen to initialize db object: " .. coordinator_peer)
      kong_conf_tmp.cassandra_contact_points[1] = coordinator_peer
    end

    -- The use of "kong_cassandra_temp" is crucial here. It ensures that the main memory
    -- area of ngx.shared, which stores a list of available nodes, is not modified each
    -- time this function is called, but only when changes are actually required.
    local shm_name = "kong_cassandra_temp"

    -- Initialize temporary db objects that will be used to check current cluster status.
    -- When db object is created it retrieves (using cluster.lua:refresh() function)
    -- the list of available nodes in the cluster.
    local db_tmp = assert(DB.new(kong_conf_tmp, nil, shm_name))
    local ok, err_t = db_tmp:init_connector()

    if not ok then
      ngx.log(ngx.ERR, "Failed to initialize db object: " .. tostring(err_t))
      return
    end
    -- get list of actual peers in the Cassandra cluster
    local peers_tmp = db_tmp.connector.cluster:get_peers()
    ngx.log(ngx.DEBUG, "New list of Cassandra cluster peers: ")
    if type(peers_tmp) == "table" then
      for k, v in pairs(peers_tmp) do
        ngx.log(ngx.DEBUG, tostring(k) .. " - " .. tostring(v.host))
      end
    end

    -- find differences in cluster topology
    local peers_to_add = get_exclusive_peers(old_peers, peers_tmp)
    local peers_to_delete = get_exclusive_peers(peers_tmp, old_peers)

    if #peers_to_add + #peers_to_delete > 0 then
      -- add new peers to cluster
      if #peers_to_add > 0 then
        for _, peer in ipairs(peers_to_add) do
          kong.db.connector.cluster:add_peer(peer.host, peer.data_center, peer.release_version)
          ngx.log(ngx.NOTICE, "Adding new peer to cluster: " .. tostring(peer.host))
        end
      end

      -- delete peers that are no longer present in cluster
      if #peers_to_delete > 0 then
        for _, peer in ipairs(peers_to_delete) do
          kong.db.connector.cluster:delete_peer(peer.host)
          ngx.log(ngx.NOTICE, "Deleting peer from cluster: " .. tostring(peer.host))
        end
      end

      -- refresh loadbalancer on all workers
      local worker_events = singletons.worker_events
      local ok, err = worker_events.post("loadbalancer", "refresh", nil)
      if not ok then
        ngx.log(ngx.ERR, "Failed to refresh loadbalancer")
      end
    end

    local pid, err = lock_dict:get("flag")
    if pid == ngx.worker.pid() then
      lock_dict:delete("flag")
    else
      ngx.log(ngx.ERR, "Could not release timer lock")
    end
  else
    if err == "exists" then
      return
    else
      ngx.log(ngx.ERR, "Topology_coordinator_lock dict in unexpected condition: " .. err)
      return
    end
  end
end

return _M