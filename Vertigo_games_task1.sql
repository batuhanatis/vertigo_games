WITH parameters AS (
    SELECT 
        20000 AS daily_installs,
        10.0 AS assumed_arppu,
        -- Variant A Metrics
        0.0305 AS var_a_purchase_ratio,
        9.80 AS var_a_ecpm,
        2.3 AS var_a_imps_dau,
        -- Variant B Metrics
        0.0315 AS var_b_purchase_ratio,
        10.80 AS var_b_ecpm,
        1.6 AS var_b_imps_dau
    FROM DUAL
),

-- 1. SABÝT VERÝ NOKTALARI (ANCHORS)
-- D0 her zaman 1.0 (100%) kabul edilir.
anchors AS (
    SELECT 0 as day, 1.00 as ret_a, 1.00 as ret_b FROM DUAL UNION ALL
    SELECT 1, 0.53, 0.48 FROM DUAL UNION ALL
    SELECT 3, 0.27, 0.25 FROM DUAL UNION ALL
    SELECT 7, 0.17, 0.19 FROM DUAL UNION ALL
    SELECT 14, 0.06, 0.09 FROM DUAL
),

-- 2. SEGMENTLERÝN OLUÞTURULMASI VE K (Decay Rate) HESABI
-- Her aralýk için (Örn: D1->D3) bir düþüþ katsayýsý (k) hesaplanýr.
segments AS (
    SELECT 
        day as start_day,
        LEAD(day, 1, 30) OVER (ORDER BY day) as end_day, -- Sonraki nokta yoksa D30'a uzat
        ret_a as start_ret_a,
        LEAD(ret_a, 1) OVER (ORDER BY day) as end_ret_a,
        ret_b as start_ret_b,
        LEAD(ret_b, 1) OVER (ORDER BY day) as end_ret_b
    FROM anchors
),
segments_with_k AS (
    SELECT 
        start_day,
        end_day,
        start_ret_a,
        start_ret_b,
        -- K Katsayýsý Formülü: k = -LN(R_end / R_start) / (Day_end - Day_start)
        -- D14 sonrasý (end_ret NULL ise) bir önceki segmentin K deðerini kullanacaðýz (Lag logic aþaðýda uygulanacak) veya doðrudan hesapta handle edeceðiz.
        CASE 
            WHEN end_ret_a IS NOT NULL THEN -LN(end_ret_a / start_ret_a) / (end_day - start_day)
            ELSE NULL -- Son segment için placeholder
        END as raw_k_a,
        CASE 
            WHEN end_ret_b IS NOT NULL THEN -LN(end_ret_b / start_ret_b) / (end_day - start_day)
            ELSE NULL
        END as raw_k_b
    FROM segments
    WHERE start_day < 30 -- D30 öncesi segmentler
),
-- D14-D30 arasý için son bilinen K deðerini taþýma (Last Observation Carried Forward)
final_segments AS (
    SELECT 
        start_day,
        end_day,
        start_ret_a,
        start_ret_b,
        -- Eðer K null ise (D14-D30 arasý), D7-D14 arasýndaki K'yi kullan (Decay trendini devam ettir)
        COALESCE(raw_k_a, LAG(raw_k_a) OVER (ORDER BY start_day)) as k_a,
        COALESCE(raw_k_b, LAG(raw_k_b) OVER (ORDER BY start_day)) as k_b
    FROM segments_with_k
),

-- 3. GÜNLERÝ OLUÞTURMA (0-30)
days_sequence AS (
    SELECT LEVEL - 1 AS current_day
    FROM DUAL
    CONNECT BY LEVEL <= 31
),

-- 4. YENÝ KULLANICI KAYNAÐI FORMÜLLERÝ (Task 1e - Sabit Formül)
new_source_curve AS (
    SELECT 
        d.current_day,
        CASE 
            WHEN d.current_day = 0 THEN 1.0 
            ELSE 0.58 * EXP(-0.12 * (d.current_day - 1)) 
        END as new_ret_a,
        CASE 
            WHEN d.current_day = 0 THEN 1.0 
            ELSE 0.52 * EXP(-0.10 * (d.current_day - 1)) 
        END as new_ret_b
    FROM days_sequence d
),

-- 5. PIECEWISE EXPONENTIAL HESAPLAMA
-- Her günü, ait olduðu segmentle eþleþtirip formülü uygula
daily_retention_curve AS (
    SELECT 
        d.current_day,
        -- Variant A Calculation: R(x) = R_start * EXP(-k * (x - x_start))
        fs.start_ret_a * EXP(-fs.k_a * (d.current_day - fs.start_day)) as retention_a,
        -- Variant B Calculation
        fs.start_ret_b * EXP(-fs.k_b * (d.current_day - fs.start_day)) as retention_b
    FROM days_sequence d
    JOIN final_segments fs ON d.current_day >= fs.start_day AND d.current_day < fs.end_day
    UNION ALL
    -- D30 (Tam sýnýr) için manuel ekleme (Join mantýðý < end_day olduðu için 30 dýþarýda kalabilir)
    SELECT 
        30 as current_day,
        start_ret_a * EXP(-k_a * (30 - start_day)) as retention_a,
        start_ret_b * EXP(-k_b * (30 - start_day)) as retention_b
    FROM final_segments WHERE end_day = 30
),

-- 6. KÜMÜLATÝF ÇARPANLAR (DAU Katsayýlarý)
daily_multipliers AS (
    SELECT 
        rc.current_day,
        SUM(rc.retention_a) OVER (ORDER BY rc.current_day) as dau_coef_a,
        SUM(rc.retention_b) OVER (ORDER BY rc.current_day) as dau_coef_b,
        SUM(nsc.new_ret_a) OVER (ORDER BY rc.current_day) as new_dau_coef_a,
        SUM(nsc.new_ret_b) OVER (ORDER BY rc.current_day) as new_dau_coef_b
    FROM daily_retention_curve rc
    JOIN new_source_curve nsc ON rc.current_day = nsc.current_day
    WHERE rc.current_day > 0
),

-- 7. SENARYO HESAPLAMALARI
scenarios AS (
    SELECT 
        m.current_day as day,
        
        -- Base DAU
        (p.daily_installs * m.dau_coef_a) as base_dau_a,
        (p.daily_installs * m.dau_coef_b) as base_dau_b,
        
        -- Base Revenue
        ((p.daily_installs * m.dau_coef_a) * ((p.var_a_imps_dau * p.var_a_ecpm / 1000.0) + (p.var_a_purchase_ratio * p.assumed_arppu))) as base_rev_a,
        ((p.daily_installs * m.dau_coef_b) * ((p.var_b_imps_dau * p.var_b_ecpm / 1000.0) + (p.var_b_purchase_ratio * p.assumed_arppu))) as base_rev_b,
        
        -- Scenario D (SALE): +1% Purchase Rate during Day 15-25
        CASE WHEN m.current_day BETWEEN 15 AND 25 THEN 0.01 ELSE 0.0 END as sale_boost,
        
        -- Scenario E (NEW SOURCE): Day 20+ Mix
        CASE 
            WHEN m.current_day < 20 THEN (p.daily_installs * m.dau_coef_a)
            ELSE (12000 * m.dau_coef_a) + (8000 * m.new_dau_coef_a)
        END as mixed_dau_a,
        CASE 
            WHEN m.current_day < 20 THEN (p.daily_installs * m.dau_coef_b)
            ELSE (12000 * m.dau_coef_b) + (8000 * m.new_dau_coef_b)
        END as mixed_dau_b
    FROM daily_multipliers m
    CROSS JOIN parameters p
)

-- 8. FÝNAL RAPOR

SELECT 
    s.day,
    ROUND(s.base_dau_a) as DAU_A,
    ROUND(s.base_dau_b) as DAU_B,
    ROUND(SUM(s.base_rev_a) OVER (ORDER BY s.day), 2) as Cum_Rev_A,
    ROUND(SUM(s.base_rev_b) OVER (ORDER BY s.day), 2) as Cum_Rev_B,
    -- Sale Scenario Revenue
    ROUND(SUM(s.base_dau_a * ((p.var_a_imps_dau * p.var_a_ecpm / 1000.0) + ((p.var_a_purchase_ratio + s.sale_boost) * p.assumed_arppu))) OVER (ORDER BY s.day), 2) as Cum_Rev_A_Sale,
    ROUND(SUM(s.base_dau_b * ((p.var_b_imps_dau * p.var_b_ecpm / 1000.0) + ((p.var_b_purchase_ratio + s.sale_boost) * p.assumed_arppu))) OVER (ORDER BY s.day), 2) as Cum_Rev_B_Sale,
    -- New Source Scenario Revenue
    ROUND(SUM(s.mixed_dau_a * ((p.var_a_imps_dau * p.var_a_ecpm / 1000.0) + (p.var_a_purchase_ratio * p.assumed_arppu))) OVER (ORDER BY s.day), 2) as Cum_Rev_A_NewSource,
    ROUND(SUM(s.mixed_dau_b * ((p.var_b_imps_dau * p.var_b_ecpm / 1000.0) + (p.var_b_purchase_ratio * p.assumed_arppu))) OVER (ORDER BY s.day), 2) as Cum_Rev_B_NewSource
FROM scenarios s
CROSS JOIN parameters p
ORDER BY s.day
;
