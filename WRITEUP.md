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