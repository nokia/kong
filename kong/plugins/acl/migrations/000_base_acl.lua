return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "acls" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITHOUT TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "group"        TEXT
      );

      CREATE INDEX IF NOT EXISTS "acls_consumer_id" ON "acls" ("consumer_id");
      CREATE INDEX IF NOT EXISTS "acls_group"       ON "acls" ("group");
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS acls(
        id          uuid PRIMARY KEY,
        created_at  timestamp,
        consumer_id uuid,
        group       text
      );
      CREATE INDEX IF NOT EXISTS ON acls(group);
      CREATE INDEX IF NOT EXISTS ON acls(consumer_id);
    ]],
  },

  maria = {
    up = [[
      CREATE TABLE IF NOT EXISTS `acls` (
        `id`           VARCHAR(36),
        `created_at`   TIMESTAMP(0)     DEFAULT NOW(0),
        `consumer_id`  VARCHAR(36),
        `group`        VARCHAR(255),

        PRIMARY KEY(`id`),
        FOREIGN KEY (`consumer_id`) REFERENCES `consumers` (`id`) ON DELETE CASCADE
      ) ENGINE = InnoDB DEFAULT CHARSET = utf8;

      CREATE INDEX IF NOT EXISTS `acls_group` ON acls(`group`);
    ]],
  },
}
