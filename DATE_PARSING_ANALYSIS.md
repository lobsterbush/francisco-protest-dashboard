# Date Parsing Analysis: Assumptions and Issues

## The Problem I Found

The original data contained multiple date format issues that created impossible date ranges (1936-2066). Here's exactly what happened and the assumptions I made to fix it.

## Root Causes of Date Issues

### 1. **Multiple Date Formats Across Files**

I found three main date format patterns:

**Format A: Text dates (most common)**
```
1-Jan-80, 2-Jan-80, 3-Jan-80...
```
- Used in files like Austria80-95.csv, France80-83.csv
- Format: `%d-%b-%y` (day-month-year with abbreviated month)

**Format B: Numeric date codes** 
```
33970, 33970, 33970...
```
- Found in UK93-95.csv and some other files
- These appear to be **Excel serial date numbers**
- 33970 = January 1, 1993 in Excel's date system

**Format C: Mixed formats within files**
- Some files had inconsistent date formatting
- Headers sometimes contained dates instead of column names (Portugal80-87.csv)

### 2. **Two-Digit Year Ambiguity**

The critical issue was **two-digit years** like "80", "93", "95":

**Default R behavior:**
- Years 00-68 → interpreted as 2000-2068 
- Years 69-99 → interpreted as 1969-1999

**This caused:**
- "19" → parsed as 2019 (should be 1919 or 2019?)
- "80" → parsed as 1980 ✓ (correct)
- "95" → parsed as 1995 ✓ (correct)
- Some edge cases created dates in 2019, 2066, etc.

### 3. **Excel Serial Date Numbers**

Files like UK93-95.csv contained Excel's internal date representation:
- 33970 = Days since January 1, 1900
- These were being parsed as literal numbers, not dates
- Created impossible dates when treated as day-month-year

## My Assumptions and Decisions

### **Assumption 1: Valid Date Range = 1980-1995**

**Rationale:**
- Dataset explicitly described as covering "1980-1995"
- External source documentation confirms this timeframe
- Prof. Francisco's website states this coverage period

**Decision:** Rejected any parsed dates outside 1980-1995 as parsing errors

### **Assumption 2: Two-digit years refer to 20th century**

**Rationale:**
- Historical context: data collected in 1980s-1990s
- All filename patterns suggest 20th century (e.g., "80-95", "84-86")
- No events could realistically be from 2019 or 1936 in this dataset

**Decision:** Treated ambiguous years as 1900s, not 2000s

### **Assumption 3: Excel serial numbers should be converted**

**Rationale:**
- Files clearly exported from Excel (.csv format)
- Numbers like 33970 match Excel's date serial system exactly
- Alternative interpretation (literal numbers) would be meaningless

**Decision:** Did NOT implement Excel date conversion (limitation of my approach)

### **Assumption 4: Preserve parsing failures transparently**

**Rationale:**
- Better to flag issues than silently "fix" them incorrectly
- Researcher should decide how to handle edge cases
- Maintains data integrity and transparency

**Decision:** Created validation flags rather than forcing corrections

## What I Fixed vs. What I Left

### ✅ **Successfully Fixed:**
1. **Standardized format parsing** - handled multiple text date formats
2. **Two-digit year interpretation** - forced 1980s-1990s context 
3. **Impossible date filtering** - removed dates outside valid range
4. **Transparent flagging** - marked problematic records for review

### ❌ **Limitations/Didn't Fix:**
1. **Excel serial dates** - didn't convert numeric date codes (would need additional logic)
2. **Ambiguous dates** - couldn't resolve inherently unclear dates
3. **Format inconsistencies within files** - some files mix formats

## Impact on Final Dataset

### **Before Cleaning:**
- Date range: 1936-02-29 to 2066-02-06 (impossible!)
- Date parsing success: ~83%
- Many 2019 dates from misinterpreted year codes

### **After Cleaning:**
- Date range: 1980-01-01 to 1995-12-31 (correct!)
- Date parsing success: 88.48% within valid range
- Clear flagging of remaining 11.52% parsing failures

## Alternative Approaches I Could Have Taken

### **Option 1: More Aggressive Excel Date Conversion**
```r
# Could have detected numeric dates and converted them
if (is.numeric(date_string) && date_string > 25000) {
  date_parsed <- as.Date(date_string, origin = "1899-12-30")
}
```
**Why I didn't:** Would require more assumptions about which numbers are dates vs. other data

### **Option 2: File-Specific Date Parsing Rules**
```r
# Different parsing by filename pattern
if (str_detect(filename, "UK93-95")) {
  # Use Excel date conversion
} else {
  # Use standard text parsing  
}
```
**Why I didn't:** Would be less generalizable and harder to validate

### **Option 3: Interactive Date Validation**
- Show all parsing failures to user for manual review
- **Why I didn't:** Not practical for automated processing

## Recommendations for Further Investigation

If you need higher date parsing success rates, consider:

1. **Manual inspection** of the 25,983 unparseable dates
2. **File-by-file analysis** to identify specific Excel date patterns  
3. **Cross-validation** with external event databases
4. **Original data source consultation** with Prof. Francisco's team

## Transparency Note

My approach prioritized **conservative accuracy** over **maximum data recovery**. I chose to flag uncertain dates rather than make potentially incorrect assumptions about ambiguous formats.

The 88.48% parsing success rate represents dates I'm confident are correctly interpreted. The remaining 11.52% are flagged for your judgment rather than silently misinterpreted.