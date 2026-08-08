import pandas as pd
import numpy as np
import os
# ==========================================
# 0. SETUP DYNAMIC FILE PATHS (Best Practice)
# ==========================================
# Get the folder where this script is located (the 'scripts' folder)
script_dir = os.path.dirname(os.path.abspath(__file__))
# Build the exact paths to the raw_data folder
orders_path = os.path.join(script_dir, '..', 'raw_data', 'olist_orders_dataset.csv')
products_path = os.path.join(script_dir, '..', 'raw_data', 'olist_products_dataset.csv')
# Build the exact paths for the cleaned_data folder (for exporting later)
out_orders_path = os.path.join(script_dir, '..', 'cleaned_data', 'cleaned_orders.csv')
out_products_path = os.path.join(script_dir, '..', 'cleaned_data', 'cleaned_products.csv')
# ==========================================
# 1. LOAD THE DATA
# ==========================================
print("Loading data...")
orders_df = pd.read_csv(orders_path)
products_df = pd.read_csv(products_path)
# ==========================================
# 2. INSPECT THE DATA
# ==========================================
print("\n--- ORDERS TABLE MISSING VALUES ---")
print(orders_df.isnull().sum())
print("\n--- PRODUCTS TABLE MISSING VALUES ---")
print(products_df.isnull().sum())
# ==========================================
# 3. CLEAN THE ORDERS TABLE
# ==========================================
print("\nCleaning Orders Table...")
# Convert delivery timestamp columns to proper datetime.
# Missing values become NaT (SQL NULL on export) rather than a fake date -
# these orders were never approved/shipped/delivered, and treating that as
# a real 1900 date would corrupt any delivery-time or on-time-rate measure.
columns_to_fill_orders = [
    'order_approved_at', 
    'order_delivered_carrier_date', 
    'order_delivered_customer_date'
]
orders_df[columns_to_fill_orders] = orders_df[columns_to_fill_orders].apply(pd.to_datetime, errors='coerce')
# ==========================================
# 4. CLEAN THE PRODUCTS TABLE
# ==========================================
print("Cleaning Products Table...")
# Fill missing text with 'Unknown' and missing numbers with 0
products_df['product_category_name'] = products_df['product_category_name'].fillna('Unknown')
numeric_columns_products = [
    'product_name_lenght', 
    'product_description_lenght', 
    'product_photos_qty', 
    'product_weight_g',
    'product_length_cm', 
    'product_height_cm', 
    'product_width_cm'
]
products_df[numeric_columns_products] = products_df[numeric_columns_products].fillna(0)
# ==========================================
# 5. EXPORT THE CLEANED DATA
# ==========================================
print("\nExporting cleaned data to CSV...")
orders_df.to_csv(out_orders_path, index=False)
products_df.to_csv(out_products_path, index=False)
print("Data cleaning complete! Files saved in 'cleaned_data' folder.")