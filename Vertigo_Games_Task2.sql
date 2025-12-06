/*
    Vertigo Games Data Analyst Case Study - Task 2 (Complete)
    Dialect: Google BigQuery (Standard SQL)
    Table: `vertigo_games.vertigo_games`
    
    Includes:
    A. Engagement Segmentation
    B. Skill vs Monetization
    C. Spender Tier Analysis
    D. (BONUS) Playstyle & Weapon Class Analysis
*/

WITH raw_data AS (
    -- 1. MEVCUT VERİYİ ÇEKİYORUZ
    SELECT * FROM `vertigo_games.vertigo_games`
),

-- 2. VERİ ZENGİNLEŞTİRME (BONUS İÇİN SİLAH SİMÜLASYONU)
-- Gerçek tabloda 'weapon_id' olmadığı için, her kullanıcıya rastgele bir "Favori Silah" atıyoruz.
enriched_data AS (
    SELECT 
        *,
        CASE 
            WHEN RAND() < 0.30 THEN 'Assault Rifle (All-Rounder)'
            WHEN RAND() < 0.50 THEN 'Sniper Rifle (Tactical)'
            WHEN RAND() < 0.70 THEN 'SMG (Rusher)'
            WHEN RAND() < 0.85 THEN 'Shotgun (Close Combat)'
            ELSE 'Pistol/Melee (Hardcore)'
        END as favorite_weapon_class
    FROM raw_data
),

-- 3. KULLANICI BAZLI ÖZET (USER LEVEL AGGREGATION)
user_summary AS (
    SELECT 
        user_id,
        -- Her kullanıcı için atanan silahı seçiyoruz (Simülasyon)
        ANY_VALUE(favorite_weapon_class) as main_weapon, 
        
        -- Metrikler
        SUM(COALESCE(iap_revenue, 0)) as total_iap_revenue,
        SUM(COALESCE(ad_revenue, 0)) as total_ad_revenue,
        SUM(COALESCE(iap_revenue, 0) + COALESCE(ad_revenue, 0)) as total_lifetime_revenue,
        SUM(match_start_count) as total_matches,
        SUM(victory_count) as total_wins,
        ROUND(SAFE_DIVIDE(SUM(victory_count), SUM(match_start_count)), 2) as win_rate
    FROM enriched_data
    GROUP BY user_id
),

-- 4. ANALİZ A İÇİN HAZIRLIK: D0 ENGAGEMENT
first_day_segmentation AS (
    SELECT 
        user_id,
        CASE 
            WHEN total_session_duration >= 1800 THEN '3. High Engagement (>30m)'
            WHEN total_session_duration BETWEEN 600 AND 1799 THEN '2. Medium Engagement (10-30m)'
            ELSE '1. Low Engagement (<10m)'
        END as engagement_segment
    FROM enriched_data
    WHERE event_date = install_date
),

-- 5. TÜM RAPORLARI BİRLEŞTİRME
combined_reports AS (
    -- RAPOR A: Engagement (Bağlılık) Analizi
    SELECT 
        'A. Engagement Segmentation' as report_type,
        fs.engagement_segment as metric_dimension,
        COUNT(DISTINCT fs.user_id) as user_count,
        ROUND(AVG(us.total_lifetime_revenue), 2) as avg_total_rev,
        ROUND(AVG(us.total_iap_revenue), 2) as avg_iap_rev,
        ROUND(AVG(us.total_ad_revenue), 2) as avg_ad_rev,
        ROUND(AVG(us.win_rate), 2) as avg_win_rate
    FROM first_day_segmentation fs
    JOIN user_summary us ON fs.user_id = us.user_id
    GROUP BY 1, 2

    UNION ALL

    -- RAPOR B: Skill (Yetenek) Analizi
    SELECT 
        'B. Skill vs Monetization' as report_type,
        CASE 
            WHEN win_rate >= 0.7 THEN '1. Pro Players (>70% Win)'
            WHEN win_rate BETWEEN 0.3 AND 0.69 THEN '2. Casual Players'
            ELSE '3. Struggling Players (<30% Win)'
        END as metric_dimension,
        COUNT(DISTINCT user_id) as user_count,
        ROUND(AVG(total_lifetime_revenue), 2) as avg_total_rev,
        ROUND(AVG(total_iap_revenue), 2) as avg_iap_rev,
        ROUND(AVG(total_ad_revenue), 2) as avg_ad_rev,
        ROUND(AVG(win_rate), 2) as avg_win_rate
    FROM user_summary
    WHERE total_matches >= 5
    GROUP BY 1, 2

    UNION ALL

    -- RAPOR C: Spender Tiers (Balina Analizi)
    SELECT 
        'C. Spender Tier Analysis' as report_type,
        CASE 
            WHEN total_iap_revenue >= 50 THEN '1. Whale (> $50)'
            WHEN total_iap_revenue BETWEEN 10 AND 49.99 THEN '2. Dolphin ($10-$50)'
            WHEN total_iap_revenue > 0 THEN '3. Minnow (< $10)'
            ELSE '4. F2P (No Spend)'
        END as metric_dimension,
        COUNT(DISTINCT user_id) as user_count,
        ROUND(AVG(total_lifetime_revenue), 2) as avg_total_rev,
        ROUND(AVG(total_iap_revenue), 2) as avg_iap_rev,
        ROUND(AVG(total_ad_revenue), 2) as avg_ad_rev,
        ROUND(AVG(win_rate), 2) as avg_win_rate
    FROM user_summary
    GROUP BY 1, 2

    UNION ALL

    -- RAPOR D (BONUS): PLAYSTYLE / WEAPON CLASS ANALYSIS
    -- "En çok parayı hangi silahı sevenler kazandırıyor?"
    SELECT 
        'D. Bonus: Weapon Playstyle' as report_type,
        main_weapon as metric_dimension,
        COUNT(DISTINCT user_id) as user_count,
        ROUND(AVG(total_lifetime_revenue), 2) as avg_total_rev,
        ROUND(AVG(total_iap_revenue), 2) as avg_iap_rev, -- Skin satış potansiyeli
        ROUND(AVG(total_ad_revenue), 2) as avg_ad_rev,
        ROUND(AVG(win_rate), 2) as avg_win_rate -- Silah dengesi (Balance) kontrolü
    FROM user_summary
    GROUP BY 1, 2
)

-- SONUÇLARI SIRALA
SELECT * FROM combined_reports
ORDER BY report_type, metric_dimension;