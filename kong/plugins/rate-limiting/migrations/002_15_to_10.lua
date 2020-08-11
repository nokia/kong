return {
  postgres = {
    up = [[
    ]],

    teardown = function(connector)
      assert(connector:connect_migrations())
      assert(connector:query [[
        ALTER TABLE IF EXISTS ONLY "ratelimiting_metrics"
         DROP CONSTRAINT IF EXISTS "ratelimiting_metrics_pkey" CASCADE,
                   ADD PRIMARY KEY ("identifier", "period", "period_date", "service_id", "route_id");


        DO $$
        BEGIN
          ALTER TABLE IF EXISTS ONLY "ratelimiting_metrics" DROP "api_id";
        EXCEPTION WHEN UNDEFINED_COLUMN THEN
          -- Do nothing, accept existing state
        END$$;
      ]])
    end,
  },

  cassandra = {
    up = [[
    ]],

    teardown = function(connector)
      assert(connector:connect_migrations())
      assert(connector:query([[
        DROP TABLE IF EXISTS ratelimiting_metrics;
        CREATE TABLE IF NOT EXISTS ratelimiting_metrics (
          identifier  text,
          period      text,
          period_date timestamp,
          service_id  uuid,
          route_id    uuid,
          value       counter,
          PRIMARY KEY ((identifier, period, period_date, service_id, route_id))
        );
      ]]))
    end,
  },

  maria = {
    up = [[
    ]],

    teardown = function(connector)
      assert(connector:connect_migrations())
      assert(connector:query [[
        BEGIN NOT ATOMIC
        DECLARE `no_such_table` CONDITION FOR SQLSTATE '42S02';
        DECLARE EXIT HANDLER FOR `no_such_table`
          BEGIN
            -- Do nothing, accept existing state
          END;
        ALTER TABLE `ratelimiting_metrics` DROP PRIMARY KEY;
        ALTER TABLE `ratelimiting_metrics` ADD PRIMARY KEY (`identifier`, `period`, `period_date`, `service_id`, `route_id`);
        ALTER TABLE `ratelimiting_metrics` DROP COLUMN IF EXISTS `api_id`;
        END;
      ]])
    end,
  },
}
