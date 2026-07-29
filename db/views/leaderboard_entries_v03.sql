SELECT users.id AS id,
       users.username AS username,
       COUNT(players.id) AS games_played,
       COUNT(players.id) FILTER (WHERE players.winner) AS games_won,
       CASE WHEN COUNT(players.id) > 0 THEN
         RANK() OVER (
           ORDER BY COUNT(players.id) FILTER (WHERE players.winner) DESC
         )
       END AS rank,
       CASE WHEN COUNT(players.id) >= 5 THEN
         ROUND(
           COUNT(players.id) FILTER (WHERE players.winner)::numeric
             / COUNT(players.id) * 100
         )::integer
       END AS win_percentage,
       COALESCE(
         SUM(EXTRACT(EPOCH FROM (games.ended_at - games.started_at))),
         0
       )::double precision AS time_played
FROM users
LEFT JOIN players ON players.user_id = users.id
LEFT JOIN games ON games.id = players.game_id
               AND games.started_at IS NOT NULL
               AND games.ended_at IS NOT NULL
GROUP BY users.id, users.username
