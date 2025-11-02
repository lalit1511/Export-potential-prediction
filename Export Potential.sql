CREATE DATABASE Import_Trade_Database;
CREATE DATABASE Export_Trade_Database;
create database export_potential_2026_version;
select * from  `003_Export_Potential_Index_Project`.country_wise_export_data limit 1000;
select * from  `003_Export_Potential_Index_Project`.country_wise_import_data limit 1000;



-- Create table with limited rows in each subquery
CREATE TABLE Vijk_Terms_Table_2021_final
AS
WITH 
VIK_Table AS (
    SELECT `ReporterDesc` AS `Exporter`, `CmdCode` AS `HS_Codes`, SUM(`PrimaryValue`) AS `VIK`
    FROM country_wise_export_data
    WHERE `RefYear` = "2021" AND `FlowDesc` = "Export" AND `CmdCode` <> "Total"
    GROUP BY `ReporterDesc`, `CmdCode`
    LIMIT 10000
),
VK_Table AS (
    SELECT `CmdCode` AS `HS_Codes`, SUM(`PrimaryValue`) AS `VK`
    FROM country_wise_export_data
    WHERE `RefYear` = "2021" AND `FlowDesc` = "Export" AND `CmdCode` <> "Total"
    GROUP BY `CmdCode`
    LIMIT 10000
),
VIJ_Table AS (
    SELECT `ReporterDesc` AS `Exporter`, `PartnerDesc` AS `Importer`, SUM(`PrimaryValue`) AS `VIJ`
    FROM country_wise_export_data
    WHERE `RefYear` = "2021" AND `FlowDesc` = "Export" AND `CmdCode` <> "Total"
    GROUP BY `ReporterDesc`, `PartnerDesc`
    LIMIT 10000
),
VJK_Table AS (
    SELECT `ReporterDesc` AS `Importer`, `CmdCode` AS `HS_Codes`, SUM(`PrimaryValue`) AS `VJK`
    FROM country_wise_export_data
    WHERE `RefYear` = "2021" AND `FlowDesc` = "Import" AND `CmdCode` <> "Total"
    GROUP BY `ReporterDesc`, `CmdCode`
    LIMIT 10000
)

SELECT 
    b.Exporter,
    b.Importer,
    a.HS_Codes,
    a.VIK,
    b.VIJ,
    c.VJK,
    d.VK
FROM VIJ_Table AS b
JOIN VIK_Table AS a ON b.Exporter = a.Exporter
JOIN VJK_Table AS c ON b.Importer = c.Importer AND a.HS_Codes = c.HS_Codes
JOIN VK_Table AS d ON a.HS_Codes = d.HS_Codes;


CREATE TABLE Vijk_Equation_3_Table AS
WITH

-- Step 1: Add Global_Share and Export Amount
Share_Table AS (
    SELECT *, 
           CASE WHEN VK <> 0 THEN (VIK / VK) ELSE 0 END AS Global_Share,
           CASE WHEN VK <> 0 THEN ((VIK * VJK) / VK) ELSE 0 END AS Export_Amount
    FROM Vijk_Terms_Table_2021_final
),

-- Step 2: Sum over all products to get denominator
Sum_K_Table AS (
    SELECT Exporter, Importer, 
           SUM(Export_Amount) AS Summation_k_Value
    FROM Share_Table
    GROUP BY Exporter, Importer
),

-- Step 3: Merge for Equation 2
Data_Eq_2_Table AS (
    SELECT a.*, b.Summation_k_Value
    FROM Share_Table a
    JOIN Sum_K_Table b 
      ON a.Exporter = b.Exporter AND a.Importer = b.Importer
),

-- Step 4: Apply Equation 2
Vijk_Eq_2_Table AS (
    SELECT *, 
           CASE 
             WHEN Summation_k_Value <> 0 
             THEN (Global_Share * (VIJ / Summation_k_Value) * VJK) 
             ELSE 0 
           END AS Vijk_Eq_2
    FROM Data_Eq_2_Table
),

-- Step 5: Calculate Normalization Factor (Fix: HS_Codes instead of CmdCode)
Data_Eq_3_Table AS (
    SELECT Importer, HS_Codes,
           SUM(
             CASE 
               WHEN Summation_k_Value <> 0 
               THEN (Global_Share * (VIJ / Summation_k_Value)) 
               ELSE 0 
             END
           ) AS Normalization_Factor
    FROM Vijk_Eq_2_Table
    GROUP BY Importer, HS_Codes
),

-- Step 6: Merge back for Equation 3
All_Data_Joined_Table AS (
    SELECT a.*, 
           CASE 
             WHEN b.Normalization_Factor <> 0 
             THEN (1 / b.Normalization_Factor) 
             ELSE 0 
           END AS Normalization_Factor_Final
    FROM Vijk_Eq_2_Table a
    JOIN Data_Eq_3_Table b 
      ON a.Importer = b.Importer AND a.HS_Codes = b.HS_Codes
)

-- Final Step: Apply Vijk Equation 3
SELECT *, 
       (Vijk_Eq_2 * Normalization_Factor_Final) AS Vijk_Eq_3
FROM All_Data_Joined_Table;

-- Msik

CREATE TABLE Supply_MSik_Table AS
WITH

-- Step 1: Get GDP ratio gdp_i
gdp_table AS (
    SELECT 
        `Column1`,
        `gdp_2021`, 
        `gdp_2026`, 
        CASE 
            WHEN `gdp_2021` <> 0 THEN (`gdp_2026` / `gdp_2021`) 
            ELSE 0 
        END AS `gdp_i`
    FROM final_gdp_table
),


vijk_gdp_table AS (
    SELECT 
        a.*, 
        b.`gdp_2021`,
        b.`gdp_2026`,
        b.`gdp_i`
    FROM vijk_equation_3_table a
    JOIN gdp_table b 
        ON a.`Exporter` = b.`Column1`
),

numerator_table AS (
    SELECT 
        *, 
        (`Vik` * `gdp_i`) AS `Numerator_MSik`
    FROM vijk_gdp_table
),

-- Step 4: Sum numerator over all exporters for each product (HS_Code) to get denominator
denominator_table AS (
    SELECT 
        `HS_Codes`, 
        SUM(`Numerator_MSik`) AS `Denominator_MSik`
    FROM numerator_table
    GROUP BY `HS_Codes`
),

-- Step 5: Join back numerator and denominator
final_data_table AS (
    SELECT 
        a.*, 
        b.`Denominator_MSik`
    FROM numerator_table a
    JOIN denominator_table b 
        ON a.`HS_Codes` = b.`HS_Codes`
)

-- Final Step: Calculate MSik
SELECT 
    *, 
    CASE 
        WHEN `Denominator_MSik` <> 0 THEN (`Numerator_MSik` / `Denominator_MSik`) 
        ELSE 0 
    END AS `MSik`
FROM final_data_table;



CREATE TABLE Supply_TBik_Table AS
WITH 
import_table AS (
  SELECT 
    PartnerDesc AS Importer, 
    CmdCode AS HS_Codes, 
    SUM(PrimaryValue) AS Total_Imports_2021
  FROM country_wise_import_data
  WHERE RefYear = "2021"
    AND FlowDesc = "Import"
    AND CmdCode <> "Total"
  GROUP BY Importer, HS_Codes
),
export_table AS (
  SELECT 
    ReporterDesc AS Exporter, 
    CmdCode AS HS_Codes, 
    SUM(PrimaryValue) AS Total_Exports_2021
  FROM country_wise_export_data
  WHERE RefYear = "2021"
    AND FlowDesc = "Export"
    AND CmdCode <> "Total"
  GROUP BY Exporter, HS_Codes
),
ratio_table AS (
  SELECT 
    a.Exporter, 
    a.HS_Codes, 
    a.Total_Exports_2021, 
    b.Total_Imports_2021, 
    (a.Total_Exports_2021 / b.Total_Imports_2021) AS export_import_ratio
  FROM export_table AS a
  LEFT JOIN import_table AS b 
    ON a.Exporter = b.Importer 
    AND a.HS_Codes = b.HS_Codes
),
cleaned_ratio_table AS (
  SELECT *, 
    IF(export_import_ratio IS NULL, Total_Exports_2021, export_import_ratio) AS Cleaned_Export_Import_Ratio
  FROM ratio_table
)

-- Final SELECT from last CTE
SELECT *, 
  IF(Cleaned_Export_Import_Ratio < 1, Cleaned_Export_Import_Ratio, 1) AS TBik 
FROM cleaned_ratio_table;


CREATE TABLE Supply_GTAik_Table AS
WITH

-- Step 1: Join tariff and elasticity values with MSik table
tariff_elasticity_table AS (
  SELECT 
    a.Exporter,
    a.HS_Codes,
    b.`Tariff_%`,
    c.`Substitution Elasticity`
  FROM Supply_MSik_Table AS a
  LEFT JOIN final_tariff_table AS b 
    ON a.Exporter = b.ReportingCountry AND a.HS_Codes = b.HS_Codes
  LEFT JOIN final_substitution_elasticity_table AS c 
    ON a.HS_Codes = c.CmdCode
),

-- Step 2: Calculate average tariff by exporter-product (Tariff_ik)
tariff_ik_table AS (
  SELECT 
    Exporter,
    HS_Codes,
    AVG(`Tariff_%`) AS Av_Tariff_ik
  FROM tariff_elasticity_table
  GROUP BY Exporter, HS_Codes
),

-- Step 3: Calculate average tariff by product (Tariff_k)
tariff_k_table AS (
  SELECT 
    HS_Codes,
    AVG(`Tariff_%`) AS Av_Tariff_k
  FROM tariff_elasticity_table
  GROUP BY HS_Codes
),

-- Step 4: Merge everything
final_table AS (
  SELECT 
    a.Exporter,
    a.HS_Codes,
    a.`Tariff_%`,
    a.`Substitution Elasticity`,
    b.Av_Tariff_ik,
    c.Av_Tariff_k
  FROM tariff_elasticity_table AS a
  LEFT JOIN tariff_ik_table AS b 
    ON a.Exporter = b.Exporter AND a.HS_Codes = b.HS_Codes
  LEFT JOIN tariff_k_table AS c 
    ON a.HS_Codes = c.HS_Codes
)

-- Final Step: Compute GTAik
SELECT *, 
  POW((1 + Av_Tariff_ik) / (1 + Av_Tariff_k), `Substitution Elasticity`) AS GTAik
FROM final_table;



CREATE TABLE Demand_Mjk_Table AS
WITH

-- Step 1: Base Vjk table
-- Step 1: Base Vjk table
vjk_table AS (
  SELECT 
    Importer, 
    HS_Codes, 
    SUM(Vjk) AS Vjk
  FROM vijk_equation_3_table
  GROUP BY Importer, HS_Codes
),


-- Step 2: GDP growth ratios
gdp_table AS (
  SELECT 
    Column1, 
    gdp_2020, 
    gdp_2021, 
    gdp_2026,
    CASE 
      WHEN gdp_2021 <> 0 THEN gdp_2026 / gdp_2021 
      ELSE 0 
    END AS gdp_j,
    CASE 
      WHEN gdp_2020 <> 0 THEN ((gdp_2021 - gdp_2020) / gdp_2020) * 100 
      ELSE 0 
    END AS gdp_change_2021
  FROM final_gdp_table
),

-- Step 3: Population ratios
pop_table AS (
  SELECT 
    country, 
    pop_2021, 
    pop_2026,
    CASE 
      WHEN pop_2021 <> 0 THEN pop_2026 / pop_2021 
      ELSE 0 
    END AS pop_j
  FROM final_population_table
),

-- Step 4: Revenue Elasticity Table
revenue_elasticity_table AS (
  SELECT 
    country, 
    Revenue_Elasticity 
  FROM revenue_elasticity
),

-- Step 5: Combine All Data
data_table AS (
  SELECT 
    a.*,
    b.gdp_2020,
    b.gdp_2021,
    b.gdp_2026,
    b.gdp_j,
    b.gdp_change_2021,
    c.pop_2021,
    c.pop_2026,
    c.pop_j,
    d.revenue_elasticity
  FROM vjk_table AS a
  LEFT JOIN gdp_table AS b ON a.Importer = b.Column1
  LEFT JOIN pop_table AS c ON a.Importer = c.country
  LEFT JOIN revenue_elasticity_table AS d ON a.Importer = d.country
)

-- Step 6: Final Mjk Calculation
SELECT *,
  CASE 
    WHEN pop_j <> 0 THEN (Vjk * POW((gdp_j / pop_j), revenue_elasticity) * pop_j)
    ELSE 0 
  END AS Mjk
FROM data_table;








-- Calculating Market Tariff Advantage (MTAijk)

CREATE TABLE `Demand_MTAijk_Table` AS
WITH

-- Step 1: Join tariff and elasticity info
`final_tariff_elasticity_table` AS (
  SELECT 
    a.`Exporter`,
    a.`Importer`,
    a.`HS_Codes`,
    b.`Tariff_%`,
    c.`Substitution Elasticity`
  FROM `vijk_equation_3_table` AS a
  LEFT JOIN `geo_cepii` AS b 
    ON a.`Exporter` = b.`ReportingCountry` AND a.`HS_Codes` = b.`HS_Codes`
  LEFT JOIN `final_substitution_elasticity_table` AS c 
    ON a.`HS_Codes` = c.`CmdCode`
),

-- Step 2: Average tariff by Importer + Product (Tariff_jk)
`tariff_jk_table` AS (
  SELECT 
    `Importer`,
    `HS_Codes`, 
    AVG(`Tariff_%`) AS `Av_Tariff_jk`
  FROM `final_tariff_elasticity_table`
  GROUP BY `Importer`, `HS_Codes`
),

-- Step 3: Average tariff by Exporter + Importer + Product (Tariff_ijk)
`tariff_ijk_table` AS (
  SELECT 
    `Exporter`,
    `Importer`,
    `HS_Codes`,
    `Substitution Elasticity`,
    AVG(`Tariff_%`) AS `Av_Tariff_ijk`
  FROM `final_tariff_elasticity_table`
  GROUP BY `Exporter`, `Importer`, `HS_Codes`, `Substitution Elasticity`
),

-- Step 4: Merge tariffs for final calculation
`data_table` AS (
  SELECT 
    a.`Exporter`,
    a.`Importer`,
    a.`HS_Codes`,
    a.`Substitution Elasticity`,
    a.`Av_Tariff_ijk`,
    b.`Av_Tariff_jk`
  FROM `tariff_ijk_table` AS a
  LEFT JOIN `tariff_jk_table` AS b 
    ON a.`Importer` = b.`Importer` AND a.`HS_Codes` = b.`HS_Codes`
)

-- Final Step: Calculate MTAijk
SELECT *,
  POW((1 + `Av_Tariff_jk`) / (1 + `Av_Tariff_ijk`), `Substitution Elasticity`) AS `MTAijk`
FROM `data_table`;




CREATE TABLE Demand_DFijk_Table AS
WITH 

-- Step 1: Attach coordinates for Exporter and Importer
distance_ij_table AS (
  SELECT 
    a.Exporter,
    a.Importer,
    a.HS_Codes,

    -- Exporter coordinates
    exp_geo.lat AS exporter_lat,
    exp_geo.lon AS exporter_lon,

    -- Importer coordinates
    imp_geo.lat AS importer_lat,
    imp_geo.lon AS importer_lon,

    -- Calculate distance using Haversine formula (in km)
    (6371 * ACOS(
        COS(RADIANS(exp_geo.lat)) 
        * COS(RADIANS(imp_geo.lat)) 
        * COS(RADIANS(imp_geo.lon) - RADIANS(exp_geo.lon)) 
        + SIN(RADIANS(exp_geo.lat)) 
        * SIN(RADIANS(imp_geo.lat))
    )) AS distance_ij

  FROM vijk_equation_3_table AS a
  LEFT JOIN geo_cepii AS exp_geo 
    ON a.Exporter = exp_geo.country
  LEFT JOIN geo_cepii AS imp_geo 
    ON a.Importer = imp_geo.country
),

-- Step 2: Calculate log of distance
distance_with_log AS (
  SELECT 
    *,
    LOG(distance_ij) AS log_distance_ij
  FROM distance_ij_table
),

-- Step 3: Average log distance by Importer & HS Code
distance_jk_table AS (
  SELECT 
    Importer,
    HS_Codes,
    AVG(log_distance_ij) AS Av_distance_jk
  FROM distance_with_log
  GROUP BY Importer, HS_Codes
),

-- Step 4: Merge average distance back
data_table AS (
  SELECT 
    a.Exporter,
    a.Importer,
    a.HS_Codes,
    a.log_distance_ij,
    b.Av_distance_jk
  FROM distance_with_log AS a
  LEFT JOIN distance_jk_table AS b 
    ON a.Importer = b.Importer AND a.HS_Codes = b.HS_Codes
)

-- Step 5: Final DFijk calculation
SELECT 
  *,
  EXP(-1 * ABS(Av_distance_jk - log_distance_ij)) AS DFijk
FROM data_table;



CREATE TABLE _final_demand_table AS
WITH 

-- Step 1: Merge Demand MTAijk, Mjk, and DFijk
data_table AS (
  SELECT 
    a.*,
    b.`gdp_2020`, 
    b.`gdp_2021`, 
    b.`gdp_2026`, 
    b.`gdp_j`, 
    b.`gdp_change_2021`, 
    b.`pop_2021`, 
    b.`pop_2026`, 
    b.`pop_j`, 
    b.`revenue_elasticity`,
    b.`Mjk`, 
    c.`log_distance_ij`, 
    c.`Av_distance_jk`, 
    c.`DFijk`
  FROM `demand_mtaijk_table` AS a
  LEFT JOIN `demand_mjk_table` AS b 
    ON a.`Importer` = b.`Importer` 
    AND a.`HS_Codes` = b.`HS_Codes`
  LEFT JOIN `demand_dfijk_table` AS c 
    ON a.`Exporter` = c.`Exporter` 
    AND a.`Importer` = c.`Importer` 
    AND a.`HS_Codes` = c.`HS_Codes`
)

-- Step 2: Final Demand Calculation
SELECT 
  *,
  (`Mjk` * `MTAijk` * `DFijk`) AS `Demand_ijk`
FROM data_table;





SHOW COLUMNS FROM supply_msik_table;
SHOW COLUMNS FROM supply_tbik_table;
SHOW COLUMNS FROM supply_gtaik_table;
SHOW COLUMNS FROM vijk_equation_3_table;

CREATE TABLE `_final_supply_table` AS
WITH  
-- Step 1: Base MSik (Market Share)
msik AS (
    SELECT
        `Exporter`,
        `Importer`,
        `HS_Codes`,
        `MSik`
    FROM `supply_msik_table`
),

-- Step 2: TBik (Trade Balance Index) — No Importer column
tbik AS (
    SELECT
        `Exporter`,
        `HS_Codes`,
        `TBik`
    FROM `supply_tbik_table`
),

-- Step 3: GTAik (Tariff Advantage on Supply Side) — No Importer column
gtaik AS (
    SELECT
        `Exporter`,
        `HS_Codes`,
        `GTAik`
    FROM `supply_gtaik_table`
),

-- Step 4: Vijk values for reference — Has Importer
vijk AS (
    SELECT
        `Exporter`,
        `Importer`,
        `HS_Codes`,
        `Vijk_Eq_3` AS `Vijk`
    FROM `vijk_equation_3_table`
)

-- Step 5: Merge all supply-side metrics
SELECT
    msik.`Exporter`,
    msik.`Importer`,
    msik.`HS_Codes`,
    msik.`MSik`,
    tbik.`TBik`,
    gtaik.`GTAik`,
    vijk.`Vijk`
FROM msik
LEFT JOIN tbik
    ON msik.`Exporter` = tbik.`Exporter`
    AND msik.`HS_Codes` = tbik.`HS_Codes`
LEFT JOIN gtaik
    ON msik.`Exporter` = gtaik.`Exporter`
    AND msik.`HS_Codes` = gtaik.`HS_Codes`
LEFT JOIN vijk
    ON msik.`Exporter` = vijk.`Exporter`
    AND msik.`Importer` = vijk.`Importer`
    AND msik.`HS_Codes` = vijk.`HS_Codes`;




CREATE TABLE `_final_supply_demand_easiness_table` AS
WITH supply_demand_joined AS (
    SELECT
        a.*,
        b.`Substitution Elasticity` AS `substitution_elasticity_j`,
        b.`Av_Tariff_jk`,
        b.`Av_Tariff_ijk`,
        b.`MTAijk`,
        b.`gdp_2020` AS `gdp_2020_j`,
        b.`gdp_2021` AS `gdp_2021_j`,
        b.`gdp_2026` AS `gdp_2026_j`,
        b.`gdp_j`,
        b.`gdp_change_2021`,
        b.`pop_2021`,
        b.`pop_2026`,
        b.`pop_j`,
        b.`revenue_elasticity`,
        b.`Mjk`,
        b.`log_distance_ij`,
        b.`Av_distance_jk`,
        b.`DFijk`,
        b.`Demand_ijk`
    FROM `_final_supply_table` AS a
    LEFT JOIN `_final_demand_table` AS b
        ON a.`Exporter` = b.`Exporter`
        AND a.`Importer` = b.`Importer`
        AND a.`HS_Codes` = b.`HS_Codes`
),
easiness_denominator AS (
    SELECT
        `Exporter`,
        `Importer`,
        SUM(`MSik` * `Demand_ijk`) AS `Easiness_Denominator`
    FROM supply_demand_joined
    GROUP BY `Exporter`, `Importer`
)
SELECT
    sd.*,
    ed.`Easiness_Denominator`,
    CASE
        WHEN ed.`Easiness_Denominator` <> 0
        THEN (sd.`Vijk` / ed.`Easiness_Denominator`)
        ELSE 0
    END AS `Easiness_ij`
FROM supply_demand_joined AS sd
LEFT JOIN easiness_denominator AS ed
    ON sd.`Exporter` = ed.`Exporter`
    AND sd.`Importer` = ed.`Importer`;

-- Calculating Export Potential 2026.

CREATE TABLE `_Export_Potential_2026_Table` AS
WITH data_table AS (
    SELECT
        *,
        (`MSik` * `Demand_ijk` * `Easiness_ij`) AS `Export_Potential_2026`
    FROM `_final_supply_demand_easiness_table`
),
data_table_2 AS (
    SELECT
        *,
        (`Export_Potential_2026` - IF(`Vijk` < `Export_Potential_2026`, `Vijk`, `Export_Potential_2026`)) AS `Unrealized_Potential`
    FROM data_table
),
data_table_3 AS (
    SELECT
        `ReporterDesc` AS `Exporter`,
        `PartnerDesc` AS `Importer`,
        `CmdCode` AS `HS_Codes`,
        `PrimaryValue` AS `TradeValue`
    FROM `country_wise_export_data`
    WHERE `FlowDesc` = 'Export'
)
SELECT
    a.*,
    b.`TradeValue`
FROM data_table_2 AS a
LEFT JOIN data_table_3 AS b
    ON a.`Exporter` = b.`Exporter`
    AND a.`Importer` = b.`Importer`
    AND a.`HS_Codes` = b.`HS_Codes`;
