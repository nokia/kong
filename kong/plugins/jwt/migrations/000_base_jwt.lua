return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "jwt_secrets" (
        "id"              UUID                         PRIMARY KEY,
        "created_at"      TIMESTAMP WITHOUT TIME ZONE  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"     UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "key"             TEXT                         UNIQUE,
        "secret"          TEXT,
        "algorithm"       TEXT,
        "rsa_public_key"  TEXT
      );

      CREATE INDEX IF NOT EXISTS "jwt_secrets_consumer_id" ON "jwt_secrets" ("consumer_id");
      CREATE INDEX IF NOT EXISTS "jwt_secrets_secret"      ON "jwt_secrets" ("secret");
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS jwt_secrets(
        id             uuid PRIMARY KEY,
        created_at     timestamp,
        consumer_id    uuid,
        algorithm      text,
        rsa_public_key text,
        key            text,
        secret         text
      );
      CREATE INDEX IF NOT EXISTS ON jwt_secrets(key);
      CREATE INDEX IF NOT EXISTS ON jwt_secrets(secret);
      CREATE INDEX IF NOT EXISTS ON jwt_secrets(consumer_id);
    ]],
  },

  maria = {
    up = [[
      CREATE TABLE IF NOT EXISTS `jwt_secrets` (
        `id`              VARCHAR(36),
        `created_at`      TIMESTAMP(0)  DEFAULT NOW(0),
        `consumer_id`     VARCHAR(36),
        `key`             VARCHAR(255),
        `secret`          TEXT,
        `algorithm`       TEXT,
        `rsa_public_key`  TEXT,

        PRIMARY KEY (`id`),
        FOREIGN KEY (`consumer_id`) REFERENCES `consumers` (`id`) ON DELETE CASCADE,
        UNIQUE  KEY (`key`)
      ) ENGINE = InnoDB DEFAULT CHARSET = utf8;
    ]],
  },
}
