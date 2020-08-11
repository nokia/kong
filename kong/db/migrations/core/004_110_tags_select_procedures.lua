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
      CREATE OR REPLACE PROCEDURE `page_for_tag_first` (tag TEXT, `limit` BIGINT)
        BEGIN
          SET @resultQuery = CONCAT('SELECT `entity_id`, `entity_name` FROM `tags` WHERE JSON_CONTAINS(`tags`, ''["' , tag , '"]'') ORDER BY `entity_id` LIMIT ' , `limit` , ';');

          PREPARE stmt FROM @resultQuery;
          EXECUTE stmt;
        END;

      CREATE OR REPLACE PROCEDURE `page_for_tag_next` (entity_id VARCHAR(36), tag TEXT, `limit` BIGINT)
        BEGIN
          SET @resultQuery = CONCAT('SELECT `entity_id`, `entity_name` FROM `tags` WHERE `entity_id`>''' , entity_id , ''' AND JSON_CONTAINS(`tags`, ''["' , tag , '"]'') ORDER BY `entity_id` LIMIT ' , `limit` , ';');

          PREPARE stmt FROM @resultQuery;
          EXECUTE stmt;
        END;

      CREATE OR REPLACE PROCEDURE `page_first`(`limit` BIGINT)
        BEGIN
          DECLARE i INT DEFAULT 0;
          DECLARE max_length INT;
          SET @resultQuery = NULL;
          SET max_length = (SELECT MAX(JSON_LENGTH(`tags`)) AS `max_length` FROM `tags`);

          WHILE i < max_length DO
            IF @resultQuery IS NOT NULL THEN
              SET @resultQuery = CONCAT(' (SELECT `entity_id`, `entity_name`, REPLACE(JSON_EXTRACT(`tags`,CONCAT(''$['',' , i , ', '']'')), ''"'', '''') AS `tag`, ', i+1 ,' AS `ordinality` FROM `tags` WHERE JSON_EXTRACT(`tags`,CONCAT(''$['',', i , ', '']'')) IS NOT NULL) UNION ' , @resultQuery);
            ELSE
              SET @resultQuery = CONCAT(' (SELECT `entity_id`, `entity_name`, REPLACE(JSON_EXTRACT(`tags`,CONCAT(''$['',' , i , ', '']'')), ''"'', '''') AS `tag`, ', i+1 ,' AS `ordinality` FROM `tags` WHERE JSON_EXTRACT(`tags`,CONCAT(''$['',', i , ', '']'')) IS NOT NULL) ORDER BY `entity_id` LIMIT ' , `limit`);
            END IF;
            SET i = i + 1;
          END WHILE;

          IF @resultQuery IS NULL THEN
            SELECT `entity_id`, `entity_name`, 0 AS `tag`, 0 AS `ordinality` FROM `tags` WHERE 1=0;
          ELSE
            PREPARE stmt FROM @resultQuery;
            EXECUTE stmt;
          END IF;
        END;

      CREATE OR REPLACE PROCEDURE `page_next`(entity_id_1 VARCHAR(36), entity_id_2 VARCHAR(36), ordinality BIGINT, `limit` BIGINT)
        BEGIN
          DECLARE i INT DEFAULT 0;
          DECLARE max_length INT;
          SET @resultQuery = SELECT `entity_id`, `entity_name`, 0 AS `tag`, 0 AS `ordinality` FROM `tags` WHERE 1=0;
          SET max_length = (SELECT MAX(JSON_LENGTH(`tags`)) AS `max_length` FROM `tags`);

          WHILE i < max_length DO
            IF @resultQuery IS NOT NULL THEN
              SET @resultQuery = CONCAT(' (SELECT `entity_id`, `entity_name`, REPLACE(JSON_EXTRACT(`tags`,CONCAT(''$['',' , i , ', '']'')), ''"'', '''') AS `tag`, ', i+1 ,' AS `ordinality` FROM `tags` WHERE JSON_EXTRACT(`tags`,CONCAT(''$['',', i , ', '']'')) IS NOT NULL AND `entity_id`>''' , entity_id_1 , ''' OR (`entity_id`=''' , entity_id_2 , ''' AND ' , i+1 , '>' , ordinality , ')) UNION ' , @resultQuery);
            ELSE
              SET @resultQuery = CONCAT(' (SELECT `entity_id`, `entity_name`, REPLACE(JSON_EXTRACT(`tags`,CONCAT(''$['',' , i , ', '']'')), ''"'', '''') AS `tag`, ', i+1 ,' AS `ordinality` FROM `tags` WHERE JSON_EXTRACT(`tags`,CONCAT(''$['',', i , ', '']'')) IS NOT NULL AND `entity_id`>''' , entity_id_1 , ''' OR (`entity_id`=''' , entity_id_2 , ''' AND ' , i+1 , '>' , ordinality , ')) ORDER BY `entity_id` LIMIT ' , `limit`);
            END IF;
            SET i = i + 1;
          END WHILE;

          IF @resultQuery IS NULL THEN
            SELECT `entity_id`, `entity_name`, 0 AS `tag`, 0 AS `ordinality` FROM `tags` WHERE 1=0;
          ELSE
            PREPARE stmt FROM @resultQuery;
            EXECUTE stmt;
          END IF;
        END;
    ]],
    }
}