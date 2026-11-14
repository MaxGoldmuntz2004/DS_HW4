## Task 1: A rating in context

Prediction:
This query returns 100,000 rows because window functions calculate aggregates without collapsing the result set, preserving exactly one row for every rating.

Result:
```
--- t1
n_above_both  share_above_both  share_above_both_20plus  n_ratings
45232           0.45232                 0.460408     100000
wrote output/t1.json
```
Explanation:

Two Partitions: Window functions evaluate independently without collapsing rows, allowing multiple PARTITION BY clauses to append different statistics to the exact same row.

One Rating Constraint: A single rating equals its movie's mean. Since a rating cannot be strictly greater than itself, it never counts as "above both," which naturally drives the overall share down.

Window Rewrite: The window function replaced the GROUP BY genre_id CTE and the subsequent JOIN. The original chain needed these steps because standard aggregates collapse rows, forcing us to calculate the genre mean in a separate table and join it back to the movies.

## Task 2: Top three per occupation"

Prediction: ROW_NUMBER will return at most 3 rows per occupation because it forces a strict sequence. RANK may return more than 3 rows for an occupation if multiple movies tie for 3rd place, because it assigns the same rank to ties.

Result:All checks passed. 3 rows per occupation for ROW_NUMBER, ties handled differently in RANK.

Explanation:

Tie-Breaker & Ties: I used movie_id ASC to break ties in ROW_NUMBER. RANK returns more rows overall because it assigns the exact same rank to ties (a tie for 3rd place returns 4 rows). ROW_NUMBER strictly cuts off at 3 rows.

Missing Occupations: Some occupations have fewer than three rows because they do not have three distinct movies that meet the 20-rating minimum threshold.

Top Picks Page: I would use ROW_NUMBER for a web page. UI layouts expect exactly 3 items, and returning extra rows due to a tie could break the design.

DENSE_RANK Rule: DENSE_RANK is best for finding the "top 3 distinct rating scores". If the top scores are 5.0, 5.0, and 4.8, RANK skips 2nd place (1, 1, 3), ROW_NUMBER splits the 5.0 tie (1, 2, 3), but DENSE_RANK correctly groups ties without skipping numbers (1, 1, 2).

## Task 3: Sessions and frames
Prediction: Removing the ROWS frame for the session flags will not change the answer because the flag is just 1 or 0; evaluating tied timestamps together yields the same running sum. However, the frames will give different results for the running mean because the default frame averages tied timestamps simultaneously, while the explicit ROWS frame averages them sequentially row-by-row. Both agree on the last value because both frames ultimately include all preceding rows.

Result: 2793 sessions, max 737 ratings per session. Frames disagreed on 49,787 rows, all due to tied timestamps.

Explanation:

Session Default Frame: Removing the explicit ROWS frame does not change the session answer. The default frame (RANGE) evaluates identical timestamps together, but since the flag is just 1 or 0, processing ties as a group doesn't alter the running sum of session IDs.

30-Minute Rule Example: This rule could falsely split a real session if a user rates a movie, spends 2 hours watching another movie, and then rates it (>30 min gap, but they were continuously using the app). It could falsely combine sessions if a user bulk-rates a bunch of movies they watched over the past week all at once.

Running Mean Differences: The frames gave different results on 49,787 rows. All of these differing rows share a timestamp with another rating. The default RANGE frame averages tied timestamps simultaneously, while the ROWS frame averages them strictly sequentially row-by-row.

Last Value Agreement: The calculations agree on the last value for all 943 users because by the time the window reaches a user's final rating, both frames encompass the exact same set of data (all of the user's preceding rows).


## Task 4: Two indexes for four queries
Prediction:

A_profile: Will use a pre-existing primary key index on user_id before and after, so performance won't change much.

B_movie_page: Will do a full table SCAN before, and use the new movie_id index for a SEARCH after.

C_recent: Will SCAN before, and use the new timestamp index for a SEARCH after.

D_month: Will SCAN before and after, because strftime() prevents the index from being used directly.

Result:
```
--- t4
wrote output/t4.json
A_profile         0.059 ms ->     0.054 ms   ['SEARCH ratings USING INDEX sqlite_autoindex_ratings_1 (user_id=?)', 'USE TEMP B-TREE FOR ORDER BY']
B_movie_page      1.569 ms ->     0.025 ms   ['SEARCH ratings USING INDEX idx_ratings_movie_id (movie_id=?)']
C_recent          1.395 ms ->     0.015 ms   ['SEARCH ratings USING COVERING INDEX idx_ratings_timestamp (timestamp>?)']
D_month           9.754 ms ->     9.327 ms   ['SCAN ratings USING COVERING INDEX idx_ratings_timestamp']
D_rewrite         2.023 ms ->     0.142 ms   ['SEARCH ratings USING COVERING INDEX idx_ratings_timestamp (timestamp>? AND timestamp<?)']
```

Explanation:

A_profile: Did not speed up significantly because it was already incredibly fast. SQLite automatically created an index (sqlite_autoindex_ratings_1) for the primary key on user_id, so it was already doing a fast SEARCH before we added anything. It still uses a TEMP B-TREE for the ORDER BY clause.

B_movie_page & C_recent: Both saw massive speedups (dropping from ~1.5ms to ~0.02ms). The new movie_id and timestamp indexes allowed SQLite to switch from a full table SCAN to a highly efficient SEARCH.

D_month: Stayed very slow (~9.3ms). Using a function like strftime() directly on the timestamp column in the WHERE clause blinds the database to the index. SQLite is forced to execute the function on every single row in a full SCAN.

D_rewrite: Replaced the strftime() function with raw timestamp boundaries (timestamp >= ? AND timestamp < ?). By keeping the timestamp column bare, SQLite can finally utilize the index for a rapid SEARCH, dropping execution time down to ~0.14ms.


## Task 5: Recommendation
I recommend adding two new indexes to our database: one for the movie ID and one for the timestamp. However, we should leave out creating a new index for the user ID. The database automatically maintains a built-in index for user IDs, meaning the user profile page is already loading as efficiently as possible.

Adding indexes for the movie ID and timestamp acts like an alphabetical index at the back of a textbook, allowing the database to jump straight to the relevant data instead of reading every single row. In our tests, the movie ID index made the movie page load over 60 times faster, dropping from 1.64 milliseconds to just 0.02 milliseconds. The timestamp index similarly sped up our recent ratings query, reducing its time from 1.42 milliseconds to 0.01 milliseconds.

The main risk of adding these indexes is the overhead they introduce. They consume additional hard drive space to store the shortcut lists. Furthermore, every time a user submits a new rating, the database must take extra time to update both indexes, which can slightly slow down the process of saving new data.