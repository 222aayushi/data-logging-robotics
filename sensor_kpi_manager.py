# sensor_kpi_manager.py (Enhanced version with bug fixes and improvements)
import pymysql
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import logging
from typing import Optional, List, Dict, Any

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class SensorDataManager:
    def __init__(self, host='localhost', user='root', password='', database='sensor_analytics'):
        """Initialize the SensorDataManager with database connection parameters."""
        self.connection_config = {
            'host': host,
            'user': user,
            'password': password,
            'database': database,
            'cursorclass': pymysql.cursors.DictCursor,
            'autocommit': False
        }
        self.connection = None
        
    def connect(self) -> bool:
        """Establish database connection."""
        try:
            self.connection = pymysql.connect(**self.connection_config)
            logger.info("Database connection established successfully")
            return True
        except pymysql.MySQLError as err:
            logger.error(f"Database connection failed: {err}")
            return False
    
    def disconnect(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()
            logger.info("Database connection closed")
    
    def __enter__(self):
        """Context manager entry."""
        if self.connect():
            return self
        raise ConnectionError("Failed to establish database connection")
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.disconnect()
    
    def check_table_structure(self):
        """Check and display the sensors table structure."""
        if not self.connection:
            logger.error("No database connection available")
            return
            
        cursor = self.connection.cursor()
        try:
            cursor.execute("DESCRIBE sensors")
            columns = cursor.fetchall()
            logger.info("Sensors table structure:")
            for col in columns:
                logger.info(f"  {col['Field']} - {col['Type']}")
        except pymysql.MySQLError as err:
            logger.error(f"Error checking table structure: {err}")
        finally:
            cursor.close()
    
    def insert_sample_sensors(self) -> bool:
        """Insert sample sensor data into the sensors table."""
        if not self.connection:
            logger.error("No database connection available")
            return False
            
        cursor = self.connection.cursor()
        
        # First check what columns exist
        try:
            cursor.execute("DESCRIBE sensors")
            columns = [col['Field'] for col in cursor.fetchall()]
            logger.info(f"Available columns: {columns}")
        except pymysql.MySQLError as err:
            logger.error(f"Error checking table structure: {err}")
            return False
        
        # Prepare data based on your original structure (without sensor_type)
        sensors_data = [
            ('TEMP_001', 'DHT22', 'Adafruit', '2024-01-15', None, 'Warehouse A', 'Zone A', 1, 18.00000000, 73.00000000, 'active', -40.00, 85.00, 0.00, 100.00),
            ('HUM_001', 'HUM100', 'Sensirion', '2024-01-10', '2024-06-10', 'Storage', 'Zone B', 0, 18.00000000, 74.00000000, 'active', -40.00, 85.00, 0.00, 100.00),
            ('COMBO_001', 'BME280', 'Bosch', '2024-01-12', '2024-06-11', 'Research Lab', 'Zone C', 2, 19.00000000, 75.00000000, 'maintenance', -40.00, 85.00, 0.00, 100.00)
        ]
        
        insert_query = """
            INSERT IGNORE INTO sensors
            (sensor_id, model, manufacturer, installation_date, calibration_date, 
             location, zone, floor_level, coordinates_lat, coordinates_lng, status, 
             temperature_range_min, temperature_range_max, humidity_range_min, humidity_range_max)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        try:
            cursor.executemany(insert_query, sensors_data)
            self.connection.commit()
            logger.info(f"Inserted {cursor.rowcount} sample sensors")
            return True
        except pymysql.MySQLError as err:
            logger.error(f"Error inserting sensors: {err}")
            self.connection.rollback()
            return False
        finally:
            cursor.close()
    
    def generate_sensor_readings(self, days_back: int = 7, readings_per_day: int = 24) -> bool:
        """Generate random sensor readings for simulation."""
        if not self.connection:
            logger.error("No database connection available")
            return False
            
        cursor = self.connection.cursor()
        
        try:
            # Get active sensors with available columns
            cursor.execute("SELECT sensor_id, model, location FROM sensors WHERE status='active'")
            sensors = cursor.fetchall()
            
            if not sensors:
                logger.warning("No active sensors found")
                return False
            
            now = datetime.now()
            start_time = now - timedelta(days=days_back)
            total_readings = 0
            
            for sensor in sensors:
                # Determine sensor type from model name or sensor_id
                sensor_type = self._determine_sensor_type(sensor['sensor_id'], sensor['model'])
                
                for day in range(days_back):
                    for interval in range(readings_per_day):
                        timestamp = start_time + timedelta(days=day, hours=interval)
                        
                        # Generate readings based on inferred sensor type
                        temp = None
                        hum = None
                        
                        if sensor_type in ['temperature', 'combo']:
                            temp = round(random.uniform(18, 32), 2)
                            
                        if sensor_type in ['humidity', 'combo']:
                            hum = round(random.uniform(35, 75), 2)
                        
                        # Generate other metrics
                        quality = random.choices(['good', 'warning', 'error'], weights=[85, 12, 3])[0]
                        battery = round(random.uniform(15, 100), 1)
                        signal = random.randint(50, 100)
                        
                        cursor.execute("""
                            INSERT INTO sensor_logs 
                            (sensor_id, location, sensor_type, temperature, humidity, 
                             timestamp, data_quality, battery_level, signal_strength)
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                        """, (
                            sensor['sensor_id'], 
                            sensor['location'],
                            sensor_type,
                            temp, 
                            hum, 
                            timestamp.strftime('%Y-%m-%d %H:%M:%S'), 
                            quality, 
                            battery, 
                            signal
                        ))
                        total_readings += 1
            
            self.connection.commit()
            logger.info(f"Generated {total_readings} sensor readings for {len(sensors)} sensors")
            return True
            
        except pymysql.MySQLError as err:
            logger.error(f"Error generating sensor readings: {err}")
            self.connection.rollback()
            return False
        finally:
            cursor.close()
    
    def _determine_sensor_type(self, sensor_id: str, model: str) -> str:
        """Determine sensor type from sensor_id or model."""
        sensor_id_upper = sensor_id.upper()
        model_upper = model.upper()
        
        if 'TEMP' in sensor_id_upper or 'DHT' in model_upper:
            return 'temperature'
        elif 'HUM' in sensor_id_upper or 'HUM' in model_upper:
            return 'humidity'
        elif 'COMBO' in sensor_id_upper or 'BME' in model_upper:
            return 'combo'
        else:
            return 'combo'  # Default to combo type
    
    def simulate_anomalies(self, max_anomalies: int = 10) -> bool:
        """Simulate anomaly detections based on sensor readings."""
        if not self.connection:
            logger.error("No database connection available")
            return False
            
        cursor = self.connection.cursor()
        
        try:
            # Find readings that could be anomalous
            cursor.execute("""
                SELECT sensor_id, temperature, humidity, timestamp, sensor_type 
                FROM sensor_logs 
                WHERE data_quality='good' AND 
                      (temperature > 30 OR humidity > 65) 
                ORDER BY RAND() 
                LIMIT %s
            """, (max_anomalies,))
            
            samples = cursor.fetchall()
            anomalies_created = 0
            
            for row in samples:
                anomaly_type = None
                severity = 'low'
                threshold_value = None
                actual_value = None
                
                if row['temperature'] and row['temperature'] > 30:
                    anomaly_type = 'temperature_spike'
                    threshold_value = 30.0
                    actual_value = row['temperature']
                    severity = 'medium' if row['temperature'] < 35 else 'high'
                    
                elif row['humidity'] and row['humidity'] > 65:
                    anomaly_type = 'humidity_spike'
                    threshold_value = 65.0
                    actual_value = row['humidity']
                    severity = 'medium' if row['humidity'] < 80 else 'high'
                
                if anomaly_type:
                    deviation_score = round(abs(actual_value - threshold_value) / threshold_value * 100, 2)
                    
                    cursor.execute("""
                        INSERT INTO anomaly_detections 
                        (sensor_id, detection_timestamp, anomaly_type, severity, 
                         threshold_value, actual_value, deviation_score, description)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        row['sensor_id'],
                        row['timestamp'],
                        anomaly_type,
                        severity,
                        threshold_value,
                        actual_value,
                        deviation_score,
                        f"Detected {anomaly_type} - Value: {actual_value}, Threshold: {threshold_value}"
                    ))
                    anomalies_created += 1
            
            self.connection.commit()
            logger.info(f"⚠️ Created {anomalies_created} anomaly detections")
            return True
            
        except pymysql.MySQLError as err:
            logger.error(f"Error simulating anomalies: {err}")
            self.connection.rollback()
            return False
        finally:
            cursor.close()
    
    def show_latest_readings(self, limit: int = 20):
        """Display latest sensor readings."""
        if not self.connection:
            logger.error("No database connection available")
            return
            
        try:
            print("\n" + "="*80)
            print("LATEST SENSOR READINGS")
            print("="*80)
            
            query = """
                SELECT sensor_id, sensor_type, temperature, humidity, 
                       timestamp, data_quality, battery_level, signal_strength
                FROM sensor_logs 
                ORDER BY timestamp DESC 
                LIMIT %s
            """
            
            df = pd.read_sql(query, self.connection, params=(limit,))
            
            if df.empty:
                print("No sensor readings found.")
            else:
                # Format the display
                df['timestamp'] = pd.to_datetime(df['timestamp'])
                df['temperature'] = df['temperature'].apply(lambda x: f"{x:.1f}°C" if pd.notna(x) else "N/A")
                df['humidity'] = df['humidity'].apply(lambda x: f"{x:.1f}%" if pd.notna(x) else "N/A")
                df['battery_level'] = df['battery_level'].apply(lambda x: f"{x:.1f}%" if pd.notna(x) else "N/A")
                df['signal_strength'] = df['signal_strength'].apply(lambda x: f"{x}%" if pd.notna(x) else "N/A")
                
                print(df.to_string(index=False, max_colwidth=15))
                
        except Exception as err:
            logger.error(f"Error displaying latest readings: {err}")
    
    def show_daily_statistics(self, days: int = 7):
        """Display daily aggregated statistics."""
        if not self.connection:
            logger.error("No database connection available")
            return
            
        try:
            print("\n" + "="*80)
            print("DAILY SENSOR STATISTICS")
            print("="*80)
            
            query = """
                SELECT 
                    DATE(timestamp) as reading_date,
                    sensor_id,
                    sensor_type,
                    COUNT(*) as reading_count,
                    ROUND(AVG(temperature), 2) as avg_temp,
                    ROUND(MIN(temperature), 2) as min_temp,
                    ROUND(MAX(temperature), 2) as max_temp,
                    ROUND(AVG(humidity), 2) as avg_humidity,
                    ROUND(MIN(humidity), 2) as min_humidity,
                    ROUND(MAX(humidity), 2) as max_humidity,
                    ROUND(AVG(battery_level), 1) as avg_battery,
                    SUM(CASE WHEN data_quality = 'error' THEN 1 ELSE 0 END) as error_count
                FROM sensor_logs 
                WHERE timestamp >= DATE_SUB(NOW(), INTERVAL %s DAY)
                GROUP BY DATE(timestamp), sensor_id, sensor_type
                ORDER BY reading_date DESC, sensor_id
            """
            
            df = pd.read_sql(query, self.connection, params=(days,))
            
            if df.empty:
                print("No statistics available.")
            else:
                print(df.to_string(index=False))
                
        except Exception as err:
            logger.error(f"Error displaying daily statistics: {err}")
    
    def show_anomaly_summary(self, days: int = 7):
        """Display anomaly detection summary."""
        if not self.connection:
            logger.error("No database connection available")
            return
            
        try:
            print("\n" + "="*80)
            print("ANOMALY DETECTION SUMMARY")
            print("="*80)
            
            query = """
                SELECT 
                    sensor_id,
                    anomaly_type,
                    severity,
                    COUNT(*) as anomaly_count,
                    MAX(detection_timestamp) as latest_detection,
                    ROUND(AVG(deviation_score), 2) as avg_deviation
                FROM anomaly_detections 
                WHERE detection_timestamp >= DATE_SUB(NOW(), INTERVAL %s DAY)
                GROUP BY sensor_id, anomaly_type, severity
                ORDER BY anomaly_count DESC, latest_detection DESC
            """
            
            df = pd.read_sql(query, self.connection, params=(days,))
            
            if df.empty:
                print("No anomalies detected in the specified period.")
            else:
                print(df.to_string(index=False))
                
        except Exception as err:
            logger.error(f"Error displaying anomaly summary: {err}")

def main():
    """Main execution function."""
    # Configuration
    DB_CONFIG = {
        'host': 'localhost',
        'user': 'root',
        'password': 'A@yushi@123',  # Consider using environment variables for security
        'database': 'sensor_analytics'
    }
    
    try:
        # Use context manager for automatic connection handling
        with SensorDataManager(**DB_CONFIG) as manager:
            logger.info("Starting sensor data management operations...")
            
            # Check table structure first
            manager.check_table_structure()
            
            # Insert sample sensors
            if manager.insert_sample_sensors():
                logger.info("✓ Sample sensors inserted successfully")
            
            # Generate sensor readings
            if manager.generate_sensor_readings(days_back=7, readings_per_day=12):
                logger.info("✓ Sensor readings generated successfully")
            
            # Simulate anomalies
            if manager.simulate_anomalies(max_anomalies=8):
                logger.info("✓ Anomalies simulated successfully")
            
            # Display results
            manager.show_latest_readings(limit=15)
            manager.show_daily_statistics(days=7)
            manager.show_anomaly_summary(days=7)
            
            logger.info("✓ All operations completed successfully")
            
    except Exception as e:
        logger.error(f"Application error: {e}")
        return False
    
    return True

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)