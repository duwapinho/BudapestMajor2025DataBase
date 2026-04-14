--how much a given map has been played?
select Count(*) as times_played, gm.map_name
from dbo.match_map mm
JOIN dbo.game_map gm 
on gm.map_id = mm.map_id 
group by gm.map_name;
--best performance on everymap.
WITH best_performances AS (
    SELECT gm.map_name,p.nickname, pms.rating,pms.kills, pms.deaths, pms.adr,
        CASE WHEN pms.team_id = m.team1_id THEN t2.team_name
        ELSE t1.team_name
        END AS opponent,
        ROW_NUMBER() OVER (
            PARTITION BY gm.map_name
            ORDER BY pms.rating DESC
        ) AS bp
    FROM dbo.player_map_stats pms
    JOIN dbo.player p
        ON p.player_id = pms.player_id
    JOIN dbo.match_map mm
        ON mm.match_map_id = pms.match_map_id
    JOIN dbo.matches m
        ON m.match_id = mm.match_id
    JOIN dbo.game_map gm
        ON gm.map_id = mm.map_id
    JOIN dbo.team t1
        ON t1.team_id = m.team1_id
    JOIN dbo.team t2
        ON t2.team_id = m.team2_id
)
SELECT
 map_name,nickname,rating,kills,deaths,adr,opponent
FROM best_performances
WHERE bp = 1
ORDER BY map_name;
--best 5 players according to rating
SELECT TOP 5 p.nickname,t.team_name,
    COUNT(*) AS maps_played,
    AVG(pms.rating) AS avg_rating
FROM dbo.player_map_stats pms
JOIN dbo.player p 
    ON p.player_id = pms.player_id
JOIN dbo.team t 
    ON t.team_id = pms.team_id
JOIN dbo.match_map mm 
    ON mm.match_map_id = pms.match_map_id
JOIN dbo.matches m 
    ON m.match_id = mm.match_id
GROUP BY  p.nickname,t.team_name
HAVING COUNT(*) >= 5
ORDER BY avg_rating DESC;

--5 worst players according to rating
SELECT TOP 5 p.nickname, t.team_name,
    COUNT(*) AS maps_played,
    AVG(pms.rating) AS avg_rating
FROM dbo.player_map_stats pms
JOIN dbo.player p 
ON p.player_id = pms.player_id
JOIN dbo.team t 
ON t.team_id = pms.team_id
JOIN dbo.match_map mm 
ON mm.match_map_id = pms.match_map_id
JOIN dbo.matches m 
ON m.match_id = mm.match_id
GROUP BY p.nickname,t.team_name
HAVING COUNT(*) >= 5
ORDER BY avg_rating ASC;

--win rate for every team.
SELECT t.team_name, COUNT(*) AS maps_played,
    SUM(CASE WHEN mm.winner_team_id = t.team_id THEN 1
        ELSE 0 END) AS maps_won,
    SUM(CASE WHEN mm.winner_team_id <> t.team_id THEN 1
        ELSE 0
    END) AS maps_lost,
    CAST(100.0 * SUM(CASE WHEN mm.winner_team_id = t.team_id THEN 1 ELSE 0
        END) / COUNT(*)
        AS DECIMAL(5,2)
    ) AS win_rate
FROM dbo.match_map mm
JOIN dbo.matches m
    ON m.match_id = mm.match_id
JOIN dbo.team t
    ON t.team_id = m.team1_id
    OR t.team_id = m.team2_id
WHERE m.tournament_id = 1
GROUP BY t.team_name, t.team_id
ORDER BY win_rate DESC, maps_won DESC;
--Stage 1 records for every team
SELECT
    t.team_name,
    COUNT(*) AS matches_played,
    SUM(CASE 
        WHEN m.winner_team_id = t.team_id THEN 1
        ELSE 0
    END) AS matches_won,
    SUM(CASE 
        WHEN m.winner_team_id <> t.team_id THEN 1
        ELSE 0
    END) AS matches_lost,
    CONCAT( SUM(CASE WHEN m.winner_team_id = t.team_id THEN 1 ELSE 0 END),
        '-',
        SUM(CASE WHEN m.winner_team_id <> t.team_id THEN 1 ELSE 0 END)
    ) AS record
FROM dbo.matches m
JOIN dbo.team t
    ON t.team_id = m.team1_id
    OR t.team_id = m.team2_id
WHERE m.stage_id = 11
GROUP BY t.team_id, t.team_name
ORDER BY matches_won DESC, matches_lost ASC, t.team_name;

--best player according to rating from every team 
WITH player_avg AS (
    SELECT p.player_id,p.nickname,t.team_id,t.team_name,
    AVG(pms.rating) AS avg_rating,
    COUNT(*) AS maps_played
    FROM dbo.player_map_stats pms
    JOIN dbo.player p 
        ON p.player_id = pms.player_id
    JOIN dbo.team t 
        ON t.team_id = pms.team_id
    JOIN dbo.match_map mm 
        ON mm.match_map_id = pms.match_map_id
    JOIN dbo.matches m 
        ON m.match_id = mm.match_id
    GROUP BY  p.player_id,p.nickname, t.team_id, t.team_name
),
ranked_players AS (
    SELECT*,
     ROW_NUMBER() OVER (
         PARTITION BY team_id
          ORDER BY avg_rating DESC
        ) AS rn
    FROM player_avg
)
SELECT team_name, nickname,avg_rating
FROM ranked_players
WHERE rn = 1
ORDER BY team_name;
--how many players from different nations? 
SELECT country as Country, COUNT(*) AS Players
FROM dbo.player
GROUP BY country
ORDER BY Players DESC;

--kd ratio 
SELECT TOP 10 p.nickname,
SUM(pms.kills) AS total_kills,
SUM(pms.deaths) AS total_deaths,
     CAST(
        1.0 * SUM(pms.kills) / NULLIF(SUM(pms.deaths), 0)
        AS DECIMAL(5,2)
    ) AS kd_ratio
FROM dbo.player_map_stats pms
JOIN dbo.player p 
    ON p.player_id = pms.player_id
JOIN dbo.match_map mm 
    ON mm.match_map_id = pms.match_map_id
JOIN dbo.matches m 
    ON m.match_id = mm.match_id
GROUP BY p.nickname
HAVING SUM(pms.deaths) > 0
ORDER BY kd_ratio DESC;
--roles and how many players 
SELECT position, COUNT(*) AS players_count
FROM dbo.player
GROUP BY position
ORDER BY players_count DESC;
--how many matches were played on a given day
SELECT m.match_date, COUNT(*) AS matches_played
FROM dbo.matches m
GROUP BY m.match_date
ORDER BY m.match_date;

--players birthdate 
SELECT
    SUM(CASE WHEN YEAR(birth_date) BETWEEN 1981 AND 1990 THEN 1 ELSE 0 END) AS '1981-1990',
    SUM(CASE WHEN YEAR(birth_date) BETWEEN 1991 AND 2000 THEN 1 ELSE 0 END) AS '1991-2000',
    SUM(CASE WHEN YEAR(birth_date) >= 2001 THEN 1 ELSE 0 END) AS '2001+'
FROM dbo.player;
