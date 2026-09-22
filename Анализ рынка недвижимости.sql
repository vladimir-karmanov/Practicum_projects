/* Проект первого модуля: анализ данных для агентства недвижимости
 *
 * Автор: Карманов Владимир
 * Дата: 26.01.2026
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
), -- Определяются верхние и нижние пределы для параметров
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats AS f
    LEFT JOIN real_estate.advertisement AS a using(id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
              AND first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
    ), -- Здесь выбираются id объявлений, которые соответствуют условиям по аномальным значениям и попадают в диапазон дат с 2015 по 2018 год.
-- Продолжите запрос здесь
days AS (
	SELECT id,
    CASE
        WHEN days_exposition IS NULL THEN 'non category'
        WHEN days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
        WHEN days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
        WHEN days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
        ELSE '181+ days'
    END AS activity_category
FROM real_estate.advertisement
), -- Категории по длительности
prepared_data AS (
    SELECT f.id, d.activity_category,
        CASE 
            WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            WHEN t.type = 'город' THEN 'ЛенОбл'
            ELSE 'Не города'
        END AS region
    FROM real_estate.flats f
        LEFT JOIN real_estate.advertisement AS a USING(id)
        LEFT JOIN days AS d USING(id)
        LEFT JOIN real_estate.city AS c USING(city_id)
        LEFT JOIN real_estate.type AS t ON f.type_id =t.type_id 
    WHERE 
        f.id IN (SELECT id FROM filtered_id)
)
 -- Здесь подготавливаются данные для финального вывода, включая категорию активности и регион
SELECT region AS Регион, activity_category AS Длителньость_активности, count(*) AS Количество_объявлений, round(avg((a.last_price/f.total_area))::NUMERIC, 2) AS Средняя_стоимость_кв_метра,
        round(AVG(total_area)::NUMERIC, 2) AS Средняя_площадь,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms)  AS Медиана_комнат,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony)  AS Медиана_балконов,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor)  AS Медиана_этажей    
FROM prepared_data AS pd
LEFT JOIN real_estate.advertisement AS a using(id)--Для нахождения средней стоимости
LEFT JOIN real_estate.flats AS f using(id)--Тоже для стоимости
GROUP BY region, activity_category
ORDER BY region DESC;


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    -- Определение пределов для фильтрации аномальных значений
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    -- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные
    SELECT id
    FROM real_estate.flats AS f
    LEFT JOIN real_estate.advertisement AS a USING (id)
    LEFT JOIN real_estate.city AS c ON f.city_id = c.city_id
    LEFT JOIN real_estate.type AS t ON f.type_id = t.type_id 
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
             AND first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
             AND t.type = 'город'
),
publication_stats AS (
    -- Статистика по месяцам публикации
    SELECT
        EXTRACT(MONTH FROM first_day_exposition) AS publication_month,
        COUNT(*) AS count_ads,
        round(AVG(last_price / total_area)::NUMERIC, 2) AS avg_price_sqm,
        round(AVG(total_area)::NUMERIC,2) AS avg_area
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f USING (id)
    JOIN filtered_id AS fi USING (id)  
    GROUP BY publication_month 
),
removal_stats AS (
    -- Статистика по месяцам снятия объявления
    SELECT
        EXTRACT(MONTH FROM (first_day_exposition + INTERVAL '1 DAY' * days_exposition)) AS removal_month,
        COUNT(*) AS count_ads,
        round(AVG(last_price / total_area)::NUMERIC,2) AS avg_price_sqm,
        round(AVG(total_area)::NUMERIC,2) AS avg_area
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f USING (id)
    JOIN filtered_id AS fi USING (id) 
    GROUP BY removal_month
)
SELECT 
    ps.publication_month AS month,
    ps.count_ads AS published_count,
    ps.avg_price_sqm AS published_avg_price,
    ps.avg_area AS published_avg_area,
    rs.count_ads AS removed_count,
    rs.avg_price_sqm AS removed_avg_price,
    rs.avg_area AS removed_avg_area
FROM publication_stats AS ps
LEFT JOIN removal_stats AS rs ON ps.publication_month = rs.removal_month
ORDER BY month;

-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
