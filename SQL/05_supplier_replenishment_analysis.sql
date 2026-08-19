USE inventory_optimization;

-- ============================================================
-- 05_supplier_replenishment_analysis.sql
-- Supplier performance and replenishment efficiency
-- ============================================================


-- 1. Overall replenishment performance

SELECT
    COUNT(*) AS total_records,
    SUM(Order_Quantity > 0) AS replenishment_events,
    ROUND(100 * AVG(Order_Quantity > 0), 2) AS replenishment_rate,
    ROUND(AVG(NULLIF(Order_Quantity, 0)), 2) AS avg_order_quantity,
    ROUND(AVG(Supplier_Lead_Time_Days), 2) AS avg_lead_time
FROM inventory_raw;


-- 2. Supplier performance profile

SELECT
    Supplier_ID,
    COUNT(DISTINCT SKU_ID) AS sku_count,
    COUNT(DISTINCT Warehouse_ID) AS warehouse_count,
    ROUND(AVG(Supplier_Lead_Time_Days), 2) AS avg_lead_time,
    ROUND(AVG(NULLIF(Order_Quantity, 0)), 2) AS avg_order_quantity,
    SUM(Order_Quantity > 0) AS replenishment_events,
    ROUND(AVG(Unit_Cost), 2) AS avg_unit_cost
FROM inventory_raw
GROUP BY Supplier_ID
ORDER BY avg_lead_time DESC;


-- 3. Supplier replenishment efficiency

SELECT
    Supplier_ID,
    ROUND(SUM(Units_Sold), 0) AS total_demand,
    ROUND(SUM(Order_Quantity), 0) AS total_replenished,
    SUM(Order_Quantity > 0) AS replenishment_events,
    ROUND(
        SUM(Order_Quantity) / NULLIF(SUM(Units_Sold), 0), 3
    ) AS replenishment_ratio,
    CASE
        WHEN SUM(Order_Quantity) / NULLIF(SUM(Units_Sold), 0) < 0.90
            THEN 'Under-Replenishment'
        WHEN SUM(Order_Quantity) / NULLIF(SUM(Units_Sold), 0) <= 1.05
            THEN 'Balanced'
        ELSE 'Over-Replenishment'
    END AS replenishment_status
FROM inventory_raw
GROUP BY Supplier_ID
ORDER BY replenishment_ratio DESC;


-- 4. Supplier lead-time risk

SELECT
    Supplier_ID,
    ROUND(AVG(Supplier_Lead_Time_Days), 2) AS avg_lead_time,
    ROUND(STDDEV(Supplier_Lead_Time_Days), 2) AS lead_time_std,
    MIN(Supplier_Lead_Time_Days) AS min_lead_time,
    MAX(Supplier_Lead_Time_Days) AS max_lead_time,
    CASE
        WHEN AVG(Supplier_Lead_Time_Days) >= 10
            THEN 'High Risk'
        WHEN AVG(Supplier_Lead_Time_Days) >= 6
            THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS lead_time_risk
FROM inventory_raw
GROUP BY Supplier_ID
ORDER BY avg_lead_time DESC;


-- 5. SKU-Warehouse replenishment gaps

SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(AVG(Units_Sold), 2) AS avg_daily_demand,
    ROUND(SUM(Order_Quantity), 0) AS total_replenished,
    SUM(Order_Quantity > 0) AS replenishment_events,
    ROUND(
        SUM(Order_Quantity) /
        NULLIF(SUM(Units_Sold), 0), 3
    ) AS replenishment_ratio
FROM inventory_raw
GROUP BY SKU_ID, Warehouse_ID
HAVING
    SUM(Order_Quantity) /
    NULLIF(SUM(Units_Sold), 0) < 0.90
    OR
    SUM(Order_Quantity) /
    NULLIF(SUM(Units_Sold), 0) > 1.05
ORDER BY replenishment_ratio;


-- 6. High-risk supplier-SKU combinations

SELECT
    Supplier_ID,
    SKU_ID,
    Warehouse_ID,
    ROUND(AVG(Supplier_Lead_Time_Days), 2) AS avg_lead_time,
    ROUND(AVG(Units_Sold), 2) AS avg_daily_demand,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory,
    ROUND(
        AVG(Inventory_Level) /
        NULLIF(AVG(Units_Sold), 0), 2
    ) AS days_of_cover,
    CASE
        WHEN AVG(Inventory_Level) /
             NULLIF(AVG(Units_Sold), 0)
             < AVG(Supplier_Lead_Time_Days)
            THEN 'Immediate Attention'
        WHEN AVG(Inventory_Level) /
             NULLIF(AVG(Units_Sold), 0)
             < AVG(Supplier_Lead_Time_Days) * 1.5
            THEN 'Monitor'
        ELSE 'Stable'
    END AS supply_risk
FROM inventory_raw
GROUP BY Supplier_ID, SKU_ID, Warehouse_ID
HAVING
    AVG(Inventory_Level) /
    NULLIF(AVG(Units_Sold), 0)
    < AVG(Supplier_Lead_Time_Days) * 1.5
ORDER BY days_of_cover;