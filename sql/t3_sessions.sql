WITH Lags AS (
    SELECT 
        user_id, 
        rating, 
        timestamp,
        LAG(timestamp) OVER (PARTITION BY user_id ORDER BY timestamp, movie_id) as prev_ts
    FROM ratings
),
NewSessionFlags AS (
    SELECT 
        user_id, 
        timestamp,
        CASE WHEN prev_ts IS NULL OR (timestamp - prev_ts) > 1800 THEN 1 ELSE 0 END AS is_new_session
    FROM Lags
),
SessionIDs AS (
    SELECT 
        user_id, 
        timestamp,
        SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS session_no
    FROM NewSessionFlags
)
SELECT 
    user_id, 
    session_no, 
    COUNT(*) AS n_ratings, 
    MIN(timestamp) AS start_time, 
    MAX(timestamp) - MIN(timestamp) AS duration
FROM SessionIDs 
GROUP BY user_id, session_no;
