-- Creating or replacing a dynamic table that refreshes every hour
create or replace dynamic table DW_CP.PUBLIC.GP_STATISTICS_GAME_CASINO_DAILY_2023_NEW_USER_OVERALL(
    AGGREGATED_AT,
    GP_ID,
    BRAND_ID,
    SITE_ID,
    NICKNAME,
    REQUESTED_EXCHANGE_RATE,
    CATEGORY_ID,
    GENERAL_GAME_TYPE,
    GAME_TYPE,
    GGR,
    BET,
    BET_COUNT,
    USER_CLASSIFICATION,
    IDENTIFYING_NEW_USERS
) 
target_lag = '1 hour' 
refresh_mode = AUTO 
initialize = ON_SCHEDULE 
warehouse = DT_CP_WH 
as

-- Step 1: Aggregate casino game statistics at the daily level
WITH DailyAggregated AS (
    SELECT 
        DATE_TRUNC('day', cp.AGGREGATED_AT) AS AGGREGATED_AT,
        cp.GP_ID,
        cp.BRAND_ID,
        cp.SITE_ID,
        cp.NICKNAME,
        MAX(cp.REQUESTED_EXCHANGE_RATE) AS REQUESTED_EXCHANGE_RATE,  -- Using the highest exchange rate of the day
        cp.CATEGORY_ID,
        cp.GENERAL_GAME_TYPE,
        cp.GAME_TYPE,
        SUM(cp.GGR) AS GGR,    -- Total daily revenue
        SUM(cp.BET) AS BET,    -- Total daily bet amount
        SUM(cp.BET_COUNT) AS BET_COUNT  -- Total daily bet count
    FROM DW_CP.PUBLIC.GP_STATISTICS_GAME_CASINO_DAILY_2023_PRESENT AS cp
    WHERE cp.AGGREGATED_AT >= '2023-01-01'  -- Filtering for records from 2023 onwards
    GROUP BY 
        DATE_TRUNC('day', cp.AGGREGATED_AT),
        cp.GP_ID,
        cp.BRAND_ID,
        cp.SITE_ID,
        cp.NICKNAME,
        cp.CATEGORY_ID,
        cp.GENERAL_GAME_TYPE,
        cp.GAME_TYPE
),

-- Step 2: Identify first and previous month of play for each user
MonthlyActivity AS (
    SELECT 
        da.GP_ID,
        DATE_TRUNC('month', da.AGGREGATED_AT) AS MONTH,
        MIN(DATE_TRUNC('month', da.AGGREGATED_AT)) OVER (PARTITION BY da.GP_ID) AS first_play_month,  -- First recorded month of activity
        LAG(DATE_TRUNC('month', da.AGGREGATED_AT), 1) OVER 
            (PARTITION BY da.GP_ID ORDER BY DATE_TRUNC('month', da.AGGREGATED_AT)) AS previous_month_play  -- Previous month's activity
    FROM DailyAggregated AS da
    GROUP BY da.GP_ID, DATE_TRUNC('month', da.AGGREGATED_AT)
),

-- Step 3: Classify users based on their first play and return behavior
ClassifiedUsers AS (
    SELECT 
        da.AGGREGATED_AT,
        da.GP_ID,
        da.BRAND_ID,
        da.SITE_ID,
        da.NICKNAME,
        da.REQUESTED_EXCHANGE_RATE,
        da.CATEGORY_ID,
        da.GENERAL_GAME_TYPE,
        da.GAME_TYPE,
        da.GGR,
        da.BET,
        da.BET_COUNT,

        -- Assigning user categories based on play history
        CASE 
            WHEN ma.first_play_month = DATE_TRUNC('month', da.AGGREGATED_AT) 
                THEN 'New User'
            WHEN ma.first_play_month = DATEADD('month', -1, DATE_TRUNC('month', da.AGGREGATED_AT)) 
                THEN 'Previous Month’s New Users - Returned'
            WHEN ma.previous_month_play = DATEADD('month', -1, DATE_TRUNC('month', da.AGGREGATED_AT)) 
                 AND ma.first_play_month < DATEADD('month', -1, DATE_TRUNC('month', da.AGGREGATED_AT)) 
                THEN 'Previous Month’s Existing Users - Returned'
            ELSE 'Re-Engaged Users'
        END AS USER_CLASSIFICATION,

        -- Identifying whether the user is new or existing
        CASE 
            WHEN ma.first_play_month = DATE_TRUNC('month', da.AGGREGATED_AT) 
                THEN 'New User'
            ELSE 'Existing User'
        END AS IDENTIFYING_NEW_USERS

    FROM DailyAggregated da
    JOIN MonthlyActivity ma 
        ON da.GP_ID = ma.GP_ID 
        AND DATE_TRUNC('month', da.AGGREGATED_AT) = ma.MONTH
)

-- Step 4: Output the final dataset with daily aggregates and user classifications
SELECT 
    AGGREGATED_AT,  
    GP_ID, 
    BRAND_ID, 
    SITE_ID, 
    NICKNAME, 
    REQUESTED_EXCHANGE_RATE, 
    CATEGORY_ID, 
    GENERAL_GAME_TYPE, 
    GAME_TYPE, 
    GGR, 
    BET, 
    BET_COUNT, 
    USER_CLASSIFICATION, 
    IDENTIFYING_NEW_USERS
FROM ClassifiedUsers
ORDER BY AGGREGATED_AT; 
