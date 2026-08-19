/* ============================================================
   PROJECT  : Inventory Optimization & Replenishment System
   PURPOSE  : Database and raw-layer setup
   DATABASE : MySQL 8.0+
   ============================================================ */

-- ============================================================
-- 1. DATABASE INITIALIZATION
-- ============================================================

CREATE DATABASE IF NOT EXISTS inventory_optimization
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE inventory_optimization;


-- ============================================================
-- 2. RAW DATA TABLE
-- ============================================================
-- Stores the source dataset without analytical transformations.
-- Analytical logic will be built separately using SQL views.

DROP TABLE IF EXISTS inventory_raw;

CREATE TABLE inventory_raw (
    
    Date                       DATE            NOT NULL,
    SKU_ID                     VARCHAR(20)     NOT NULL,
    Warehouse_ID               VARCHAR(20)     NOT NULL,
    Supplier_ID                VARCHAR(20)     NOT NULL,
    Region                     VARCHAR(20)     NOT NULL,

    Units_Sold                 INT             NOT NULL,
    Inventory_Level            INT             NOT NULL,
    Supplier_Lead_Time_Days    INT             NOT NULL,
    Reorder_Point              INT             NOT NULL,
    Order_Quantity             INT             NOT NULL,

    Unit_Cost                  DECIMAL(10,2)   NOT NULL,
    Unit_Price                 DECIMAL(10,2)   NOT NULL,

    Promotion_Flag             TINYINT         NOT NULL,
    Stockout_Flag              TINYINT         NOT NULL,

    Demand_Forecast            DECIMAL(10,2)   NOT NULL,

    -- Basic domain validation
    CONSTRAINT chk_units_sold
        CHECK (Units_Sold >= 0),

    CONSTRAINT chk_inventory_level
        CHECK (Inventory_Level >= 0),

    CONSTRAINT chk_lead_time
        CHECK (Supplier_Lead_Time_Days > 0),

    CONSTRAINT chk_reorder_point
        CHECK (Reorder_Point >= 0),

    CONSTRAINT chk_order_quantity
        CHECK (Order_Quantity >= 0),

    CONSTRAINT chk_unit_cost
        CHECK (Unit_Cost > 0),

    CONSTRAINT chk_unit_price
        CHECK (Unit_Price > 0),

    CONSTRAINT chk_promotion_flag
        CHECK (Promotion_Flag IN (0,1)),

    CONSTRAINT chk_stockout_flag
        CHECK (Stockout_Flag IN (0,1)),

    CONSTRAINT chk_demand_forecast
        CHECK (Demand_Forecast >= 0)
);


-- ============================================================
-- 3. INDEXES
-- ============================================================
-- These support the analytical queries we will build later.

CREATE INDEX idx_inventory_date
    ON inventory_raw (Date);

CREATE INDEX idx_inventory_sku
    ON inventory_raw (SKU_ID);

CREATE INDEX idx_inventory_warehouse
    ON inventory_raw (Warehouse_ID);

CREATE INDEX idx_inventory_supplier
    ON inventory_raw (Supplier_ID);

CREATE INDEX idx_inventory_sku_warehouse
    ON inventory_raw (SKU_ID, Warehouse_ID);

CREATE INDEX idx_inventory_supplier_date
    ON inventory_raw (Supplier_ID, Date);


-- ============================================================
-- 4. DATABASE OBJECT CHECK
-- ============================================================

SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_ROWS
FROM information_schema.tables
WHERE TABLE_SCHEMA = 'inventory_optimization'
ORDER BY TABLE_NAME;


-- ============================================================
-- 5. TABLE STRUCTURE CHECK
-- ============================================================

DESCRIBE inventory_raw;