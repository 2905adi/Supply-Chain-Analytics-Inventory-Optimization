USE inventory_optimization;

-- ============================================================
-- 02_data_validation.sql
-- Supply Chain Inventory Optimization
-- Data quality, integrity and structural validation
-- ============================================================


-- ============================================================
-- 1. Basic Dataset Validation
-- ============================================================

SELECT
    COUNT(*) AS total_rows
FROM inventory_raw;


SELECT
    MIN(Date) AS start_date,
    MAX(Date) AS end_date,
    COUNT(DISTINCT Date) AS unique_dates,
    COUNT(DISTINCT SKU_ID) AS unique_skus,
    COUNT(DISTINCT Warehouse_ID) AS unique_warehouses,
    COUNT(DISTINCT Supplier_ID) AS unique_suppliers,
    COUNT(DISTINCT Region) AS unique_regions
FROM inventory_raw;


-- ============================================================
-- 2. NULL / Missing Value Validation
-- ============================================================

SELECT
    SUM(Date IS NULL) AS missing_date,
    SUM(SKU_ID IS NULL) AS missing_sku,
    SUM(Warehouse_ID IS NULL) AS missing_warehouse,
    SUM(Supplier_ID IS NULL) AS missing_supplier,
    SUM(Region IS NULL) AS missing_region,
    SUM(Units_Sold IS NULL) AS missing_units_sold,
    SUM(Inventory_Level IS NULL) AS missing_inventory,
    SUM(Supplier_Lead_Time_Days IS NULL) AS missing_lead_time,
    SUM(Reorder_Point IS NULL) AS missing_reorder_point,
    SUM(Order_Quantity IS NULL) AS missing_order_quantity,
    SUM(Unit_Cost IS NULL) AS missing_unit_cost,
    SUM(Unit_Price IS NULL) AS missing_unit_price,
    SUM(Promotion_Flag IS NULL) AS missing_promotion_flag,
    SUM(Stockout_Flag IS NULL) AS missing_stockout_flag,
    SUM(Demand_Forecast IS NULL) AS missing_forecast
FROM inventory_raw;


-- ============================================================
-- 3. Duplicate Record Validation
-- ============================================================

SELECT
    COUNT(*) AS duplicate_full_rows
FROM (
    SELECT
        Date,
        SKU_ID,
        Warehouse_ID,
        Supplier_ID,
        Region,
        Units_Sold,
        Inventory_Level,
        Supplier_Lead_Time_Days,
        Reorder_Point,
        Order_Quantity,
        Unit_Cost,
        Unit_Price,
        Promotion_Flag,
        Stockout_Flag,
        Demand_Forecast
    FROM inventory_raw
    GROUP BY
        Date,
        SKU_ID,
        Warehouse_ID,
        Supplier_ID,
        Region,
        Units_Sold,
        Inventory_Level,
        Supplier_Lead_Time_Days,
        Reorder_Point,
        Order_Quantity,
        Unit_Cost,
        Unit_Price,
        Promotion_Flag,
        Stockout_Flag,
        Demand_Forecast
    HAVING COUNT(*) > 1
) AS duplicate_records;


-- Business-key validation:
-- One record should represent Date × SKU × Warehouse.

SELECT
    Date,
    SKU_ID,
    Warehouse_ID,
    COUNT(*) AS record_count
FROM inventory_raw
GROUP BY
    Date,
    SKU_ID,
    Warehouse_ID
HAVING COUNT(*) > 1;


-- ============================================================
-- 4. Business Rule Validation
-- ============================================================

SELECT
    SUM(Units_Sold < 0) AS negative_demand,
    SUM(Inventory_Level < 0) AS negative_inventory,
    SUM(Supplier_Lead_Time_Days <= 0) AS invalid_lead_time,
    SUM(Reorder_Point < 0) AS negative_reorder_point,
    SUM(Order_Quantity < 0) AS negative_order_quantity,
    SUM(Unit_Cost <= 0) AS invalid_unit_cost,
    SUM(Unit_Price <= 0) AS invalid_unit_price,
    SUM(Promotion_Flag NOT IN (0, 1)) AS invalid_promotion_flag,
    SUM(Stockout_Flag NOT IN (0, 1)) AS invalid_stockout_flag,
    SUM(Demand_Forecast < 0) AS negative_forecast
FROM inventory_raw;


-- ============================================================
-- 5. Commercial Logic Validation
-- ============================================================

SELECT
    SUM(Unit_Price <= Unit_Cost) AS non_positive_margin,
    SUM(Order_Quantity > 0 AND Inventory_Level = 0)
        AS replenishment_at_zero_inventory
FROM inventory_raw;


-- ============================================================
-- 6. Date × SKU × Warehouse Coverage
-- ============================================================

SELECT
    COUNT(DISTINCT Date)
        * COUNT(DISTINCT SKU_ID)
        * COUNT(DISTINCT Warehouse_ID)
        AS expected_rows,

    COUNT(*) AS actual_rows,

    CASE
        WHEN
            COUNT(DISTINCT Date)
            * COUNT(DISTINCT SKU_ID)
            * COUNT(DISTINCT Warehouse_ID)
            = COUNT(*)
        THEN 'COMPLETE'
        ELSE 'INCOMPLETE'
    END AS coverage_status

FROM inventory_raw;


-- ============================================================
-- 7. Category / Flag Distribution
-- ============================================================

SELECT
    Promotion_Flag,
    COUNT(*) AS records,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM inventory_raw
GROUP BY Promotion_Flag
ORDER BY Promotion_Flag;


SELECT
    Stockout_Flag,
    COUNT(*) AS records,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM inventory_raw
GROUP BY Stockout_Flag
ORDER BY Stockout_Flag;


-- ============================================================
-- 8. Dimension Integrity Checks
-- ============================================================

SELECT
    'SKU' AS dimension,
    COUNT(DISTINCT SKU_ID) AS unique_values
FROM inventory_raw

UNION ALL

SELECT
    'Warehouse',
    COUNT(DISTINCT Warehouse_ID)
FROM inventory_raw

UNION ALL

SELECT
    'Supplier',
    COUNT(DISTINCT Supplier_ID)
FROM inventory_raw

UNION ALL

SELECT
    'Region',
    COUNT(DISTINCT Region)
FROM inventory_raw;


-- ============================================================
-- 9. Warehouse-Level Data Quality Profile
-- ============================================================

SELECT
    Warehouse_ID,
    COUNT(*) AS observations,
    COUNT(DISTINCT SKU_ID) AS active_skus,
    COUNT(DISTINCT Supplier_ID) AS suppliers,
    ROUND(AVG(Units_Sold), 2) AS avg_daily_demand,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory,
    ROUND(AVG(Reorder_Point), 2) AS avg_reorder_point,
    ROUND(AVG(Order_Quantity), 2) AS avg_order_quantity,
    ROUND(AVG(Unit_Cost * Inventory_Level), 2)
        AS avg_inventory_value
FROM inventory_raw
GROUP BY Warehouse_ID
ORDER BY avg_inventory_value DESC;


-- ============================================================
-- 10. SKU-Level Data Quality Profile
-- ============================================================

SELECT
    SKU_ID,
    COUNT(DISTINCT Warehouse_ID) AS warehouse_count,
    ROUND(SUM(Units_Sold), 0) AS total_units_sold,
    ROUND(AVG(Units_Sold), 2) AS avg_daily_demand,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory,
    ROUND(AVG(Unit_Cost * Inventory_Level), 2)
        AS avg_inventory_value,
    ROUND(AVG(Unit_Price - Unit_Cost), 2)
        AS unit_margin
FROM inventory_raw
GROUP BY SKU_ID
ORDER BY avg_inventory_value DESC
LIMIT 15;


-- ============================================================
-- 11. Final Validation Summary
-- ============================================================

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT Date) AS dates,
    COUNT(DISTINCT SKU_ID) AS skus,
    COUNT(DISTINCT Warehouse_ID) AS warehouses,
    COUNT(DISTINCT Supplier_ID) AS suppliers,
    COUNT(DISTINCT Region) AS regions,
    SUM(Stockout_Flag = 1) AS stockout_records,
    SUM(Promotion_Flag = 1) AS promotion_records,
    SUM(Order_Quantity > 0) AS replenishment_records
FROM inventory_raw;



