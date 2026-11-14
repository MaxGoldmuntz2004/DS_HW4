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