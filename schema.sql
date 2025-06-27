CREATE DATABASE  IF NOT EXISTS `sensor_analytics` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `sensor_analytics`;
-- MySQL dump 10.13  Distrib 8.0.42, for macos15 (arm64)
--
-- Host: localhost    Database: sensor_analytics
-- ------------------------------------------------------
-- Server version	8.0.42

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `anomaly_detections`
--

DROP TABLE IF EXISTS `anomaly_detections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `anomaly_detections` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `sensor_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `detection_timestamp` datetime NOT NULL,
  `anomaly_type` enum('temperature_spike','temperature_drop','humidity_spike','humidity_drop','sensor_offline','data_quality_issue') COLLATE utf8mb4_unicode_ci NOT NULL,
  `severity` enum('low','medium','high','critical') COLLATE utf8mb4_unicode_ci NOT NULL,
  `threshold_value` decimal(10,4) DEFAULT NULL,
  `actual_value` decimal(10,4) DEFAULT NULL,
  `deviation_score` decimal(8,4) DEFAULT NULL COMMENT 'Statistical deviation score',
  `description` text COLLATE utf8mb4_unicode_ci,
  `resolved` tinyint(1) DEFAULT '0',
  `resolved_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sensor_detection` (`sensor_id`,`detection_timestamp`),
  KEY `idx_severity` (`severity`),
  KEY `idx_resolved` (`resolved`),
  KEY `idx_anomaly_type` (`anomaly_type`),
  CONSTRAINT `anomaly_detections_ibfk_1` FOREIGN KEY (`sensor_id`) REFERENCES `sensors` (`sensor_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Anomaly detection results for analytics pipeline';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `kpi_metrics`
--

DROP TABLE IF EXISTS `kpi_metrics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `kpi_metrics` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `metric_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `metric_category` enum('temperature','humidity','system','quality') COLLATE utf8mb4_unicode_ci NOT NULL,
  `sensor_id` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'NULL for system-wide metrics',
  `location` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `time_period` enum('hourly','daily','weekly','monthly') COLLATE utf8mb4_unicode_ci NOT NULL,
  `period_start` datetime NOT NULL,
  `period_end` datetime NOT NULL,
  `metric_value` decimal(15,6) NOT NULL,
  `unit` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_value` decimal(15,6) DEFAULT NULL,
  `status` enum('good','warning','critical') COLLATE utf8mb4_unicode_ci DEFAULT 'good',
  `calculated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_kpi_unique` (`metric_name`,`sensor_id`,`location`,`time_period`,`period_start`),
  KEY `idx_metric_period` (`metric_name`,`time_period`,`period_start`),
  KEY `idx_sensor_metrics` (`sensor_id`,`metric_category`),
  KEY `idx_location_metrics` (`location`,`metric_category`),
  CONSTRAINT `kpi_metrics_ibfk_1` FOREIGN KEY (`sensor_id`) REFERENCES `sensors` (`sensor_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Pre-calculated KPI metrics for dashboard performance';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `report_generations`
--

DROP TABLE IF EXISTS `report_generations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `report_generations` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `report_type` enum('daily','weekly','monthly','custom','anomaly') COLLATE utf8mb4_unicode_ci NOT NULL,
  `report_period_start` datetime NOT NULL,
  `report_period_end` datetime NOT NULL,
  `generated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `file_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file_format` enum('pdf','html','csv') COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('pending','completed','failed') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `error_message` text COLLATE utf8mb4_unicode_ci,
  `generated_by` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'system',
  PRIMARY KEY (`id`),
  KEY `idx_report_type_period` (`report_type`,`report_period_start`),
  KEY `idx_generated_at` (`generated_at`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Track automated report generation';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sensor_logs`
--

DROP TABLE IF EXISTS `sensor_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sensor_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `sensor_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `location` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sensor_type` enum('temperature','humidity','combined') COLLATE utf8mb4_unicode_ci NOT NULL,
  `temperature` decimal(5,2) DEFAULT NULL COMMENT 'Temperature in Celsius',
  `humidity` decimal(5,2) DEFAULT NULL COMMENT 'Relative humidity percentage (0-100)',
  `timestamp` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `data_quality` enum('good','warning','error') COLLATE utf8mb4_unicode_ci DEFAULT 'good',
  `battery_level` decimal(3,1) DEFAULT NULL COMMENT 'Battery percentage (0-100)',
  `signal_strength` int DEFAULT NULL COMMENT 'Signal strength in dBm',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sensor_timestamp` (`sensor_id`,`timestamp`),
  KEY `idx_location_timestamp` (`location`,`timestamp`),
  KEY `idx_timestamp_only` (`timestamp`),
  KEY `idx_sensor_type` (`sensor_type`),
  KEY `idx_data_quality` (`data_quality`),
  KEY `idx_analytics_composite` (`sensor_id`,`location`,`timestamp`,`data_quality`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Primary table for storing sensor readings with analytics optimization';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sensors`
--

DROP TABLE IF EXISTS `sensors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sensors` (
  `sensor_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `model` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `manufacturer` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `installation_date` date NOT NULL,
  `calibration_date` date DEFAULT NULL,
  `location` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `zone` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Building zone or area',
  `floor_level` int DEFAULT NULL,
  `coordinates_lat` decimal(10,8) DEFAULT NULL,
  `coordinates_lng` decimal(11,8) DEFAULT NULL,
  `status` enum('active','inactive','maintenance') COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `temperature_range_min` decimal(5,2) DEFAULT '-40.00',
  `temperature_range_max` decimal(5,2) DEFAULT '85.00',
  `humidity_range_min` decimal(5,2) DEFAULT '0.00',
  `humidity_range_max` decimal(5,2) DEFAULT '100.00',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`sensor_id`),
  KEY `idx_location` (`location`),
  KEY `idx_status` (`status`),
  KEY `idx_zone` (`zone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Sensor metadata and configuration';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary view structure for view `v_daily_stats`
--

DROP TABLE IF EXISTS `v_daily_stats`;
/*!50001 DROP VIEW IF EXISTS `v_daily_stats`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_daily_stats` AS SELECT 
 1 AS `sensor_id`,
 1 AS `location`,
 1 AS `zone`,
 1 AS `reading_date`,
 1 AS `reading_count`,
 1 AS `avg_temperature`,
 1 AS `min_temperature`,
 1 AS `max_temperature`,
 1 AS `std_temperature`,
 1 AS `avg_humidity`,
 1 AS `min_humidity`,
 1 AS `max_humidity`,
 1 AS `std_humidity`,
 1 AS `avg_battery_level`,
 1 AS `error_count`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_latest_readings`
--

DROP TABLE IF EXISTS `v_latest_readings`;
/*!50001 DROP VIEW IF EXISTS `v_latest_readings`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_latest_readings` AS SELECT 
 1 AS `sensor_id`,
 1 AS `location`,
 1 AS `zone`,
 1 AS `temperature`,
 1 AS `humidity`,
 1 AS `timestamp`,
 1 AS `data_quality`,
 1 AS `battery_level`,
 1 AS `signal_strength`*/;
SET character_set_client = @saved_cs_client;

--
-- Final view structure for view `v_daily_stats`
--

/*!50001 DROP VIEW IF EXISTS `v_daily_stats`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_daily_stats` AS select `sl`.`sensor_id` AS `sensor_id`,`s`.`location` AS `location`,`s`.`zone` AS `zone`,cast(`sl`.`timestamp` as date) AS `reading_date`,count(0) AS `reading_count`,avg(`sl`.`temperature`) AS `avg_temperature`,min(`sl`.`temperature`) AS `min_temperature`,max(`sl`.`temperature`) AS `max_temperature`,std(`sl`.`temperature`) AS `std_temperature`,avg(`sl`.`humidity`) AS `avg_humidity`,min(`sl`.`humidity`) AS `min_humidity`,max(`sl`.`humidity`) AS `max_humidity`,std(`sl`.`humidity`) AS `std_humidity`,avg(`sl`.`battery_level`) AS `avg_battery_level`,sum((case when (`sl`.`data_quality` = 'error') then 1 else 0 end)) AS `error_count` from (`sensor_logs` `sl` join `sensors` `s` on((`sl`.`sensor_id` = `s`.`sensor_id`))) group by `sl`.`sensor_id`,`s`.`location`,`s`.`zone`,cast(`sl`.`timestamp` as date) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_latest_readings`
--

/*!50001 DROP VIEW IF EXISTS `v_latest_readings`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_latest_readings` AS select `sl`.`sensor_id` AS `sensor_id`,`s`.`location` AS `location`,`s`.`zone` AS `zone`,`sl`.`temperature` AS `temperature`,`sl`.`humidity` AS `humidity`,`sl`.`timestamp` AS `timestamp`,`sl`.`data_quality` AS `data_quality`,`sl`.`battery_level` AS `battery_level`,`sl`.`signal_strength` AS `signal_strength` from ((`sensor_logs` `sl` join `sensors` `s` on((`sl`.`sensor_id` = `s`.`sensor_id`))) join (select `sensor_logs`.`sensor_id` AS `sensor_id`,max(`sensor_logs`.`timestamp`) AS `max_timestamp` from `sensor_logs` group by `sensor_logs`.`sensor_id`) `latest` on(((`sl`.`sensor_id` = `latest`.`sensor_id`) and (`sl`.`timestamp` = `latest`.`max_timestamp`)))) where (`s`.`status` = 'active') */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-06-27 13:25:06
