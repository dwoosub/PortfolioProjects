-- This script creates a dynamic table to track new user retention in casino games.
-- It identifies first-time players for each game and checks if they return
-- on specific days (1, 2, 3, 7, 14, and 30 days after their first game).

CREATE OR REPLACE DYNAMIC TABLE DW_CP.PUBLIC.NEW_USER_RETENTION(
    AGGREGATED_AT,  -- The timestamp of the gameplay session
    NETWORK,  -- The network identifier
    BRAND_ID,  -- The brand associated with the player
    SITE_ID,  -- The site where the player played
    GP_ID,  -- Unique player ID
    COUNTRY_ID,  -- Player's country
    GAME_TYPE,  -- Type of game played
    IS_NEW_USER_FOR_GAME,  -- Indicates if this is the user's first time playing this game
    DAY1_RETENTION_FROM_AGGREGATED_AT,  -- Played again 1 day later?
    DAY2_RETENTION_FROM_AGGREGATED_AT,  -- Played again 2 days later?
    DAY3_RETENTION_FROM_AGGREGATED_AT,  -- Played again 3 days later?
    DAY7_RETENTION_FROM_AGGREGATED_AT,  -- Played again 7 days later?
    DAY14_RETENTION_FROM_AGGREGATED_AT,  -- Played again 14 days later?
    DAY30_RETENTION_FROM_AGGREGATED_AT  -- Played again 30 days later?
) 
TARGET_LAG = '1 hour'  -- Table updates every hour
REFRESH_MODE = AUTO  -- Automatically refreshes when new data is available
INITIALIZE = ON_SCHEDULE  -- Ensures updates follow a set schedule
WAREHOUSE = DT_CP_WH  -- Uses this warehouse for processing
AS

-- Step 1: Find the first time each user played a specific game\ 
WITH first_time_per_game AS (
    SELECT 
        GP_ID,  -- Player ID
        GAME_TYPE,  -- The game they played
        MIN(AGGREGATED_AT) AS FIRST_GAME_PLAY  -- Earliest recorded play for this game
    FROM DW_WAREHOUSE.PUBLIC.gp_statistics_game_casino
    GROUP BY GP_ID, GAME_TYPE
)

-- Step 2: Identify new users and check their retention
SELECT
    t1.AGGREGATED_AT,
    t1.NETWORK,
    t1.BRAND_ID,
    t1.SITE_ID,
    t1.GP_ID,
    t1.COUNTRY_ID,
    t1.GAME_TYPE,

    -- Check if this is the user's first time playing this game
    CASE 
        WHEN t1.AGGREGATED_AT = f.FIRST_GAME_PLAY THEN TRUE 
        ELSE FALSE 
    END AS IS_NEW_USER_FOR_GAME,

    -- Check if the user played the same game on specific days after their first game
    CASE WHEN t2.GP_ID IS NOT NULL THEN TRUE ELSE FALSE END AS DAY1_RETENTION_FROM_AGGREGATED_AT,
    CASE WHEN t3.GP_ID IS NOT NULL THEN TRUE ELSE FALSE END AS DAY2_RETENTION_FROM_AGGREGATED_AT,
    CASE WHEN t4.GP_ID IS NOT NULL THEN TRUE ELSE FALSE END AS DAY3_RETENTION_FROM_AGGREGATED_AT,
    CASE WHEN t5.GP_ID IS NOT NULL THEN TRUE ELSE FALSE END AS DAY7_RETENTION_FROM_AGGREGATED_AT,
    CASE WHEN t6.GP_ID IS NOT NULL THEN TRUE ELSE FALSE END AS DAY14_RETENTION_FROM_AGGREGATED_AT,
    CASE WHEN t7.GP_ID IS NOT NULL THEN TRUE ELSE FALSE END AS DAY30_RETENTION_FROM_AGGREGATED_AT   

FROM DW_WAREHOUSE.PUBLIC.gp_statistics_game_casino AS t1

-- Join to get first-time users per game type
INNER JOIN first_time_per_game AS f 
    ON t1.GP_ID = f.GP_ID 
    AND t1.GAME_TYPE = f.GAME_TYPE 
    AND t1.AGGREGATED_AT = f.FIRST_GAME_PLAY

-- Step 3: Check if the user played again on different days

-- 1-day retention: Did the user play the same game again 1 day later?
LEFT JOIN DW_WAREHOUSE.PUBLIC.gp_statistics_game_casino AS t2 
    ON t1.NETWORK = t2.NETWORK 
    AND t1.GP_ID = t2.GP_ID 
    AND t1.GAME_TYPE = t2.GAME_TYPE 
    AND t2.AGGREGATED_AT = DATEADD(day, 1, t1.AGGREGATED_AT)

-- 2-day retention
LEFT JOIN DW_WAREHOUSE.PUBLIC.gp_statistics_game_casino AS t3 
    ON t1.NETWORK = t3.NETWORK 
    AND t1.GP_ID = t3.GP_ID 
    AND t1.GAME_TYPE = t3.GAME_TYPE 
    AND t3.AGGREGATED_AT = DATEADD(day, 2, t1.AGGREGATED_AT)

-- 3-day retention
LEFT JOIN DW_WAREHOUSE.PUBLIC.gp_statistics_game_casino AS t4 
    ON t1.NETWORK = t4.NETWORK 
    AND t1.GP_ID = t4.GP_ID 
    AND t1.GAME_TYPE = t4.GAME_TYPE 
    AND t4.AGGREGATED_AT = DATEADD(day, 3, t1.AGGREGATED_AT)

-- 7-day retention
LEFT JOIN DW_WAREHOUSE.PUBLIC.gp_statistics_game_casino AS t5 
    ON t1.NETWORK = t5.NETWORK 
    AND t1.GP_ID = t5.GP_ID 
    AND t1.GAME_TYPE = t5.GAME_TYPE 
    AND t5.AGGREGATED_AT = DATEADD(day, 7, t1.AGGREGATED_AT)

-- 14-day retention
LEFT JOIN DW_WAREHOUSE.PUBLIC.gp_statistics_game_casino AS t6 
    ON t1.NETWORK = t6.NETWORK 
    AND t1.GP_ID = t6.GP_ID 
    AND t1.GAME_TYPE = t6.GAME_TYPE 
    AND t6.AGGREGATED_AT = DATEADD(day, 14, t1.AGGREGATED_AT)

-- 30-day retention
LEFT JOIN DW_WAREHOUSE.PUBLIC.gp_statistics_game_casino AS t7 
    ON t1.NETWORK = t7.NETWORK 
    AND t1.GP_ID = t7.GP_ID 
    AND t1.GAME_TYPE = t7.GAME_TYPE 
    AND t7.AGGREGATED_AT = DATEADD(day, 30, t1.AGGREGATED_AT);
