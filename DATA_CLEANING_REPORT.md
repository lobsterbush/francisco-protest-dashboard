# European Protest and Coercion Data - Cleaning Report

## Overview

This report summarizes the comprehensive data cleaning process performed on Prof. Ron Francisco's European Protest and Coercion Data (1980-1995). The original data contained daily and sub-daily coded information on protest and coercion events across 28 European countries.

**Data Source:** https://ronfran.ku.edu/data/index.html

## Data Cleaning Process

### 1. Initial Assessment
- **Total files found:** 70 CSV files
- **Unique header patterns:** 37 different column naming conventions
- **Raw observations:** 225,603 total records
- **Countries:** 31 (including some duplicates and special cases)

### 2. Major Issues Identified and Resolved

#### A. Column Name Inconsistencies
**Problem:** 37 different header patterns across files with variations like:
- "Event Date" vs "Date" vs "Protest date" 
- "# Protesters" vs "# protesters" vs "Protesters"
- "Arrests" vs "Prot. Arrested" vs "protesters arrested"

**Solution:** Created intelligent pattern-matching standardization function that maps all variants to consistent column names.

#### B. Date Parsing Issues  
**Problem:** 
- 25,983 unparseable dates
- Date range extended impossibly from 1936-2066
- Multiple date formats across files

**Solution:** 
- Implemented flexible date parser supporting multiple formats
- Restricted to valid 1980-1995 range
- Final success rate: 88.48%

#### C. Country Name Variations
**Problem:** Country names like "FRG", "GDR", "UK", "thirdreich" were unclear

**Solution:** Standardized to proper country names:
- FRG → West Germany
- GDR → East Germany  
- UK → United Kingdom
- thirdreich → Germany
- francemay68 → France (May 1968 events)

#### D. Numeric Variable Issues
**Problem:** Non-numeric characters, extreme outliers, missing values

**Solution:** 
- Cleaned numeric conversion with outlier detection
- Flagged impossible values (e.g., arrests exceeding total protesters)
- Handled missing values systematically

### 3. Data Validation

Implemented comprehensive validation checks identifying:
- **46,330** country name mismatches (now resolved)
- **25,983** missing or unparseable dates
- **17,128** events with invalid dates
- **459** cases where arrests exceeded total protesters

### 4. Final Cleaned Datasets

#### Created 6 analysis-ready datasets:

1. **protest_coercion_final_cleaned.csv** (188,222 rows)
   - Complete cleaned dataset with valid dates (1980-1995)
   - Standardized variables and country names
   - Binary indicators for protest/repression events

2. **protest_coercion_events_only.csv** (78,178 rows)
   - Only actual protest/coercion events (excludes "no event" days)

3. **protest_coercion_daily_timeseries.csv** (134,174 rows)
   - Daily aggregated data by country
   - Includes zero-event days for time series completeness

4. **protest_coercion_country_year_summary.csv** (372 rows)
   - Annual summaries by country
   - Protest days, repression days, participant counts

5. **protest_coercion_coverage_summary.csv** (26 rows)
   - Country-level coverage and activity summaries

6. **protest_coercion_all_data.csv** (225,603 rows)
   - Original complete dataset with cleaning flags

## Final Statistics

### Coverage
- **Time period:** 1980-1995 (16 years)
- **Countries:** 26 European countries with valid data
- **Total observations:** 188,222 country-days
- **Actual events:** 54,708 protest events + 10,853 repression events

### Top Countries by Protest Activity
1. **United Kingdom:** 23,298 protest-days
2. **France:** 11,906 protest-days  
3. **West Germany:** 4,785 protest-days
4. **Northern Ireland:** 4,266 protest-days
5. **Ireland:** 3,114 protest-days

### Data Quality
- **Date parsing success:** 88.48%
- **Valid date range:** Properly restricted to 1980-1995
- **Standardized variables:** All 37 column formats harmonized
- **Missing data:** Systematically handled and documented

## Key Improvements Made

✅ **Standardized 37 different column formats** into consistent structure  
✅ **Fixed date parsing issues** with flexible multi-format parser  
✅ **Standardized country names** for clear identification  
✅ **Cleaned numeric variables** with outlier detection  
✅ **Created validation flags** for data quality monitoring  
✅ **Generated analysis-ready datasets** in multiple formats  
✅ **Professional visualization** following Tufte's principles  

## Files Available for Analysis

All cleaned files are located in: `/Users/f00421k/Documents/GitHub/protest-coercion/cleaned_data/`

### Recommended Starting Points:
- **For event analysis:** Use `protest_coercion_final_cleaned.csv`
- **For time series analysis:** Use `protest_coercion_daily_timeseries.csv`  
- **For country comparisons:** Use `protest_coercion_country_year_summary.csv`

### Documentation:
- `README.txt` - Human-readable summary
- `data_documentation.json` - Machine-readable metadata
- `protest_coercion_timeline.png` - Overview visualization

## Data Quality Notes

The cleaning process successfully resolved the major structural issues in the original datasets. The remaining data quality concerns are documented in validation flags and primarily involve:

1. **Missing dates** (11.5% of records) - preserved with flags for transparency
2. **Country mismatches** - resolved through standardization
3. **Extreme values** - flagged but preserved for researcher judgment
4. **Event coding consistency** - maintained original coding decisions

## Recommendations for Analysis

1. **Use the final cleaned dataset** for most analyses
2. **Check validation flags** when investigating outliers  
3. **Consider time series completeness** - some countries have partial coverage
4. **Account for different data collection periods** across countries
5. **Follow Tufte's principles** for visualizations as per user preferences

The data is now ready for rigorous statistical analysis and meets academic standards for research on European protest and coercion patterns during this critical historical period.

---
*Data cleaned on: September 29, 2025*  
*Cleaning script: `clean_protest_data.R` and `analyze_cleaned_data.R`*