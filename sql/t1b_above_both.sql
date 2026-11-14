-- T1b. How many ratings are above BOTH the user's mean and the movie's mean?
-- Required columns (one row):
--   n_ratings, n_above_both, share_above_both, share_above_both_20plus
-- share_above_both_20plus: the same share, counting only ratings of movies
-- that have at least 20 ratings.
-- Build on T1a in a CTE; filter or count outside it.
--
-- Prediction (commit before running): share_above_both is about ______.

-- YOUR QUERY HERE
WITH RatingMeans AS (
    SELECT
        user_id,
        movie_id,
        rating,
        AVG(rating) OVER (PARTITION BY user_id) AS user_mean,
        AVG(rating) OVER (PARTITION BY movie_id) AS movie_mean,
        COUNT(rating) OVER (PARTITION BY movie_id) AS movie_count
    FROM ratings
)
SELECT
    SUM(CASE WHEN rating > user_mean AND rating > movie_mean THEN 1 ELSE 0 END) AS n_above_both,
    CAST(SUM(CASE WHEN rating > user_mean AND rating > movie_mean THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) AS share_above_both,
    CAST(SUM(CASE WHEN rating > user_mean AND rating > movie_mean AND movie_count >= 20 THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(SUM(CASE WHEN movie_count >= 20 THEN 1 ELSE 0 END), 0) AS share_above_both_20plus,
    COUNT(*) AS n_ratings
FROM RatingMeans;