--[[
© 2020 Nokia
Licensed under the Apache License 2.0
SPDX-License-Identifier: Apache-2.0
--]]

return {
  postgres = {
    up = [[
    ]],
  },

  cassandra = {
    up = [[
    ]],
  },

  maria = {
    up = [[
      DROP FUNCTION IF EXISTS `upsert_ttl`;

      DROP TRIGGER IF EXISTS `services_sync_tags_trigger_delete`;
      DROP TRIGGER IF EXISTS `services_sync_tags_trigger_insert`;
      DROP TRIGGER IF EXISTS `services_sync_tags_trigger_update`;

      CREATE TRIGGER `services_sync_tags_trigger_delete`
      AFTER DELETE ON `services` FOR EACH ROW BEGIN
        DELETE FROM `tags` WHERE `entity_id` = OLD.`id`;
      END;

      CREATE TRIGGER `services_sync_tags_trigger_insert`
      AFTER INSERT ON `services` FOR EACH ROW BEGIN
        INSERT INTO `tags` VALUES (NEW.`id`, 'services', NEW.`tags`);
      END;

      CREATE TRIGGER `services_sync_tags_trigger_update`
      AFTER UPDATE ON `services` FOR EACH ROW BEGIN
        IF !(NEW.`tags` <=> OLD.`tags`) THEN
          INSERT INTO `tags` VALUES (NEW.`id`, 'services', NEW.`tags`) ON DUPLICATE KEY UPDATE `tags`=NEW.`tags`;
        END IF;
      END;


      DROP TRIGGER IF EXISTS `routes_sync_tags_trigger_delete`;
      DROP TRIGGER IF EXISTS `routes_sync_tags_trigger_insert`;
      DROP TRIGGER IF EXISTS `routes_sync_tags_trigger_update`;

      CREATE TRIGGER `routes_sync_tags_trigger_delete`
      AFTER DELETE ON `routes` FOR EACH ROW BEGIN
        DELETE FROM `tags` WHERE `entity_id` = OLD.`id`;
      END;

      CREATE TRIGGER `routes_sync_tags_trigger_insert`
      AFTER INSERT ON `routes` FOR EACH ROW BEGIN
        INSERT INTO `tags` VALUES (NEW.`id`, 'routes', NEW.`tags`);
      END;

      CREATE TRIGGER `routes_sync_tags_trigger_update`
      AFTER UPDATE ON `routes` FOR EACH ROW BEGIN
        IF !(NEW.`tags` <=> OLD.`tags`) THEN
          INSERT INTO `tags` VALUES (NEW.`id`, 'routes', NEW.`tags`) ON DUPLICATE KEY UPDATE `tags`=NEW.`tags`;
        END IF;
      END;


      DROP TRIGGER IF EXISTS `certificates_sync_tags_trigger_delete`;
      DROP TRIGGER IF EXISTS `certificates_sync_tags_trigger_insert`;
      DROP TRIGGER IF EXISTS `certificates_sync_tags_trigger_update`;

      CREATE TRIGGER `certificates_sync_tags_trigger_delete`
      AFTER DELETE ON `certificates` FOR EACH ROW BEGIN
        DELETE FROM `tags` WHERE `entity_id` = OLD.`id`;
      END;

      CREATE TRIGGER `certificates_sync_tags_trigger_insert`
      AFTER INSERT ON `certificates` FOR EACH ROW BEGIN
        INSERT INTO `tags` VALUES (NEW.`id`, 'certificates', NEW.`tags`);
      END;

      CREATE TRIGGER `certificates_sync_tags_trigger_update`
      AFTER UPDATE ON `certificates` FOR EACH ROW BEGIN
        IF !(NEW.`tags` <=> OLD.`tags`) THEN
          INSERT INTO `tags` VALUES (NEW.`id`, 'certificates', NEW.`tags`) ON DUPLICATE KEY UPDATE `tags`=NEW.`tags`;
        END IF;
      END;


      DROP TRIGGER IF EXISTS `snis_sync_tags_trigger_delete`;
      DROP TRIGGER IF EXISTS `snis_sync_tags_trigger_insert`;
      DROP TRIGGER IF EXISTS `snis_sync_tags_trigger_update`;

      CREATE TRIGGER `snis_sync_tags_trigger_delete`
      AFTER DELETE ON `snis` FOR EACH ROW BEGIN
        DELETE FROM `tags` WHERE `entity_id` = OLD.`id`;
      END;

      CREATE TRIGGER `snis_sync_tags_trigger_insert`
      AFTER INSERT ON `snis` FOR EACH ROW BEGIN
        INSERT INTO `tags` VALUES (NEW.`id`, 'snis', NEW.`tags`);
      END;

      CREATE TRIGGER `snis_sync_tags_trigger_update`
      AFTER UPDATE ON `snis` FOR EACH ROW BEGIN
        IF !(NEW.`tags` <=> OLD.`tags`) THEN
          INSERT INTO `tags` VALUES (NEW.`id`, 'snis', NEW.`tags`) ON DUPLICATE KEY UPDATE `tags`=NEW.`tags`;
        END IF;
      END;


      DROP TRIGGER IF EXISTS `consumers_sync_tags_trigger_delete`;
      DROP TRIGGER IF EXISTS `consumers_sync_tags_trigger_insert`;
      DROP TRIGGER IF EXISTS `consumers_sync_tags_trigger_update`;

      CREATE TRIGGER `consumers_sync_tags_trigger_delete`
      AFTER DELETE ON `consumers` FOR EACH ROW BEGIN
        DELETE FROM `tags` WHERE `entity_id` = OLD.`id`;
      END;

      CREATE TRIGGER `consumers_sync_tags_trigger_insert`
      AFTER INSERT ON `consumers` FOR EACH ROW BEGIN
        INSERT INTO `tags` VALUES (NEW.`id`, 'consumers', NEW.`tags`);
      END;

      CREATE TRIGGER `consumers_sync_tags_trigger_update`
      AFTER UPDATE ON `consumers` FOR EACH ROW BEGIN
        IF !(NEW.`tags` <=> OLD.`tags`) THEN
          INSERT INTO `tags` VALUES (NEW.`id`, 'consumers', NEW.`tags`) ON DUPLICATE KEY UPDATE `tags`=NEW.`tags`;
        END IF;
      END;


      DROP TRIGGER IF EXISTS `plugins_sync_tags_trigger_delete`;
      DROP TRIGGER IF EXISTS `plugins_sync_tags_trigger_insert`;
      DROP TRIGGER IF EXISTS `plugins_sync_tags_trigger_update`;

      CREATE TRIGGER `plugins_sync_tags_trigger_delete`
      AFTER DELETE ON `plugins` FOR EACH ROW BEGIN
        DELETE FROM `tags` WHERE `entity_id` = OLD.`id`;
      END;

      CREATE TRIGGER `plugins_sync_tags_trigger_insert`
      AFTER INSERT ON `plugins` FOR EACH ROW BEGIN
        INSERT INTO `tags` VALUES (NEW.`id`, 'plugins', NEW.`tags`);
      END;

      CREATE TRIGGER `plugins_sync_tags_trigger_update`
      AFTER UPDATE ON `plugins` FOR EACH ROW BEGIN
        IF !(NEW.`tags` <=> OLD.`tags`) THEN
          INSERT INTO `tags` VALUES (NEW.`id`, 'plugins', NEW.`tags`) ON DUPLICATE KEY UPDATE `tags`=NEW.`tags`;
        END IF;
      END;


      DROP TRIGGER IF EXISTS `upstreams_sync_tags_trigger_delete`;
      DROP TRIGGER IF EXISTS `upstreams_sync_tags_trigger_insert`;
      DROP TRIGGER IF EXISTS `upstreams_sync_tags_trigger_update`;

      CREATE TRIGGER `upstreams_sync_tags_trigger_delete`
      AFTER DELETE ON `upstreams` FOR EACH ROW BEGIN
        DELETE FROM `tags` WHERE `entity_id` = OLD.`id`;
      END;

      CREATE TRIGGER `upstreams_sync_tags_trigger_insert`
      AFTER INSERT ON `upstreams` FOR EACH ROW BEGIN
        INSERT INTO `tags` VALUES (NEW.`id`, 'upstreams', NEW.`tags`);
      END;

      CREATE TRIGGER `upstreams_sync_tags_trigger_update`
      AFTER UPDATE ON `upstreams` FOR EACH ROW BEGIN
        IF !(NEW.`tags` <=> OLD.`tags`) THEN
          INSERT INTO `tags` VALUES (NEW.`id`, 'upstreams', NEW.`tags`) ON DUPLICATE KEY UPDATE `tags`=NEW.`tags`;
        END IF;
      END;


      DROP TRIGGER IF EXISTS `targets_sync_tags_trigger_delete`;
      DROP TRIGGER IF EXISTS `targets_sync_tags_trigger_insert`;
      DROP TRIGGER IF EXISTS `targets_sync_tags_trigger_update`;

      CREATE TRIGGER `targets_sync_tags_trigger_delete`
      AFTER DELETE ON `targets` FOR EACH ROW BEGIN
        DELETE FROM `tags` WHERE `entity_id` = OLD.`id`;
      END;

      CREATE TRIGGER `targets_sync_tags_trigger_insert`
      AFTER INSERT ON `targets` FOR EACH ROW BEGIN
        INSERT INTO `tags` VALUES (NEW.`id`, 'targets', NEW.`tags`);
      END;

      CREATE TRIGGER `targets_sync_tags_trigger_update`
      AFTER UPDATE ON `targets` FOR EACH ROW BEGIN
        IF !(NEW.`tags` <=> OLD.`tags`) THEN
          INSERT INTO `tags` VALUES (NEW.`id`, 'targets', NEW.`tags`) ON DUPLICATE KEY UPDATE `tags`=NEW.`tags`;
        END IF;
      END;
    ]],
  }
}