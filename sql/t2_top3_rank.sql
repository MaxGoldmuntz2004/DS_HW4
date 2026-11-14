WITH OccRatings AS (
    SELECT 
        u.occupation, 
        r.movie_id, 
        AVG(r.rating) as avg_rating
    FROM ratings r 
    JOIN users u USING (user_id)
    GROUP BY u.occupation, r.movie_id
    HAVING COUNT(r.rating) >= 20
),
RankedMovies AS (
    SELECT 
        occupation, 
        movie_id, 
        avg_rating,
        RANK() OVER (PARTITION BY occupation ORDER BY avg_rating DESC) as rk
    FROM OccRatings
)
SELECT occupation, movie_id, avg_rating 
FROM RankedMovies 
WHERE rk <= 3;
