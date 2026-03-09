###############################################################################
### European Protest and Coercion Data Cleaning Script
### Prof. Ron Francisco Dataset (1980-1995)
### Created by: Assistant
### Purpose: Clean and standardize all protest/coercion data files
###############################################################################

### Clear environment
cat("\014")  # Clear console
rm(list = ls())

### Load required packages
required_packages <- c("foreign", "readr", "dplyr", "tidyr", "stringr", 
                      "lubridate", "DataCombine", "rio", "janitor")

# Install missing packages
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

### Set working directories
data_dir <- "~/Documents/GitHub/protest-coercion/analysis/data/"
output_dir <- "~/Documents/GitHub/protest-coercion/cleaned_data/"

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

###############################################################################
### 1. FILE INVENTORY AND STRUCTURE ANALYSIS
###############################################################################

cat("=== STEP 1: Analyzing file inventory and structure ===\n")

# Get list of all CSV files
csv_files <- list.files(data_dir, pattern = "\\.csv$", full.names = TRUE)
csv_files <- csv_files[!grepl("codebook", csv_files, ignore.case = TRUE)]

cat("Found", length(csv_files), "CSV files\n")
cat("Files found:\n")
print(basename(csv_files))

# Function to safely read headers
read_header_safe <- function(file_path) {
  tryCatch({
    first_line <- readLines(file_path, n = 1)
    return(strsplit(first_line, ",")[[1]])
  }, error = function(e) {
    cat("Error reading", file_path, ":", e$message, "\n")
    return(NULL)
  })
}

# Analyze headers across all files
headers_list <- list()
for (file in csv_files) {
  headers_list[[basename(file)]] <- read_header_safe(file)
}

# Remove NULL entries (files that couldn't be read)
headers_list <- headers_list[!sapply(headers_list, is.null)]

# Find unique column patterns
unique_headers <- unique(headers_list)
cat("\nFound", length(unique_headers), "unique header patterns:\n")

# Create header mapping for standardization
for (i in seq_along(unique_headers)) {
  cat("\nHeader Pattern", i, ":\n")
  cat(paste(unique_headers[[i]], collapse = " | "), "\n")
  cat("Files with this pattern:", 
      paste(names(headers_list)[sapply(headers_list, function(x) identical(x, unique_headers[[i]]))], 
            collapse = ", "), "\n")
}

###############################################################################
### 2. COLUMN NAME STANDARDIZATION
###############################################################################

cat("\n=== STEP 2: Standardizing column names ===\n")

# Create standardized column mapping
standardize_column_names <- function(colnames) {
  # Convert to lowercase and clean
  cleaned <- tolower(colnames)
  cleaned <- str_replace_all(cleaned, "[^a-z0-9]", "_")
  cleaned <- str_replace_all(cleaned, "_+", "_")
  cleaned <- str_replace(cleaned, "^_|_$", "")
  
  # Create standardized mapping - handle common patterns
  result <- cleaned
  
  # Map date columns
  result[cleaned %in% c("event_date", "protest_date", "date")] <- "date"
  
  # Map protester count columns
  result[str_detect(cleaned, "^.*protest.*$|^.*protesters.*$|^number_of_protesters$")] <- "n_protesters"
  
  # Map arrest columns
  result[str_detect(cleaned, "arrest|prot.*arrest|prot.*arr")] <- "protesters_arrested"
  
  # Map injury columns - protesters
  result[str_detect(cleaned, "prot.*inj|protesters.*inj|prot.*injured")] <- "protesters_injured"
  
  # Map death columns - protesters  
  result[str_detect(cleaned, "prot.*kill|death|protesters.*kill|protkill")] <- "protesters_killed"
  
  # Map property damage columns
  result[str_detect(cleaned, "prop.*dam|property.*dam")] <- "property_damage"
  
  # Map state actor columns
  result[str_detect(cleaned, "^.*state$|state.*actor|state.*force|^.*state.*$") & 
         !str_detect(cleaned, "inj|kill|target")] <- "state_actors"
  
  # Map state injured columns
  result[str_detect(cleaned, "state.*inj")] <- "state_injured"
  
  # Map state killed columns  
  result[str_detect(cleaned, "state.*kill")] <- "state_killed"
  
  # Map link date columns
  result[str_detect(cleaned, "link.*date|linked.*date")] <- "link_date"
  
  # Map story/source date columns
  result[str_detect(cleaned, "story.*date|source.*date")] <- "story_date"
  
  # Map no event columns
  result[str_detect(cleaned, "no.*event")] <- "no_event_found"
  
  # Handle remaining common columns
  result[cleaned == "day"] <- "day"
  result[cleaned == "action"] <- "action" 
  result[cleaned == "protester"] <- "protester"
  result[str_detect(cleaned, "state.*target|target.*state")] <- "state_target"
  result[cleaned == "target"] <- "state_target"
  result[cleaned == "agent"] <- "agent"
  result[cleaned == "event"] <- "event"
  result[cleaned == "country"] <- "country"
  result[cleaned == "location"] <- "location"
  result[cleaned == "issue"] <- "issue"
  result[str_detect(cleaned, "^time$|duration")] <- "time"
  result[cleaned == "osd"] <- "osd"
  result[cleaned == "source"] <- "source"
  
  # Handle numbered duplicates (like when there are two "injuries" columns)
  result <- make.names(result, unique = TRUE)
  
  return(result)
}

###############################################################################
### 3. DATA LOADING AND STANDARDIZATION FUNCTION
###############################################################################

cat("\n=== STEP 3: Creating data loading and standardization function ===\n")

load_and_standardize_file <- function(file_path) {
  cat("Processing:", basename(file_path), "\n")
  
  # Extract country and period from filename
  filename <- basename(file_path)
  filename_clean <- str_replace(filename, "\\.csv$", "")
  
  # Parse country and period
  if (str_detect(filename_clean, "\\d{2}-\\d{2}$")) {
    parts <- str_split(filename_clean, "(?=\\d{2}-\\d{2}$)")[[1]]
    country <- parts[1]
    period <- parts[2]
  } else if (str_detect(filename_clean, "\\d{2}-\\d{4}$")) {
    parts <- str_split(filename_clean, "(?=\\d{2}-\\d{4}$)")[[1]]
    country <- parts[1] 
    period <- parts[2]
  } else {
    # Special cases
    country <- str_replace(filename_clean, "\\d{2,4}.*", "")
    period <- str_extract(filename_clean, "\\d{2,4}.*")
  }
  
  tryCatch({
    # Read the file
    data <- read_csv(file_path, 
                    col_types = cols(.default = col_character()),
                    locale = locale(encoding = "latin1"),
                    na = c("", "NA", "na", "N/A"))
    
    # Standardize column names
    original_names <- names(data)
    names(data) <- standardize_column_names(original_names)
    
    # Add metadata columns
    data$source_file <- filename
    data$extracted_country <- country
    data$extracted_period <- period
    
    # Handle 'no event' indicator
    no_event_col <- ifelse(is.null(data$no_event_found), "", 
                          ifelse(is.na(data$no_event_found), "", data$no_event_found))
    data$has_event <- !str_detect(no_event_col, "no event")
    
    cat("  - Loaded", nrow(data), "rows,", ncol(data), "columns\n")
    cat("  - Country:", country, ", Period:", period, "\n")
    cat("  - Events:", sum(data$has_event, na.rm = TRUE), "/ Total:", nrow(data), "\n")
    
    return(data)
    
  }, error = function(e) {
    cat("  - ERROR loading file:", e$message, "\n")
    return(NULL)
  })
}

###############################################################################
### 4. LOAD ALL FILES
###############################################################################

cat("\n=== STEP 4: Loading all data files ===\n")

all_data_list <- list()
for (file in csv_files) {
  result <- load_and_standardize_file(file)
  if (!is.null(result)) {
    all_data_list[[basename(file)]] <- result
  }
}

cat("\nSuccessfully loaded", length(all_data_list), "files\n")

###############################################################################
### 5. HARMONIZE COLUMNS ACROSS FILES
###############################################################################

cat("\n=== STEP 5: Harmonizing columns across all files ===\n")

# Get all unique column names
all_columns <- unique(unlist(lapply(all_data_list, names)))
cat("Total unique columns found:", length(all_columns), "\n")

# Identify core columns that should be in every file
core_columns <- c("date", "day", "action", "protester", "state_target", "agent", 
                 "event", "country", "location", "issue", "link_date", "time",
                 "n_protesters", "protesters_arrested", "protesters_injured", 
                 "protesters_killed", "property_damage", "state_actors",
                 "state_injured", "state_killed", "osd", "source", "story_date",
                 "no_event_found", "source_file", "extracted_country", 
                 "extracted_period", "has_event")

# Function to harmonize columns
harmonize_columns <- function(data, target_columns) {
  # Add missing columns
  for (col in target_columns) {
    if (!col %in% names(data)) {
      data[[col]] <- NA_character_
    }
  }
  
  # Reorder columns
  data <- data[, target_columns, drop = FALSE]
  
  return(data)
}

# Harmonize all datasets
cat("Harmonizing column structure...\n")
for (i in seq_along(all_data_list)) {
  all_data_list[[i]] <- harmonize_columns(all_data_list[[i]], core_columns)
}

###############################################################################
### 6. COMBINE ALL DATA
###############################################################################

cat("\n=== STEP 6: Combining all datasets ===\n")

# Combine all data
combined_data <- bind_rows(all_data_list)
cat("Combined dataset has", nrow(combined_data), "rows and", ncol(combined_data), "columns\n")

###############################################################################
### 7. DATE CLEANING AND VALIDATION  
###############################################################################

cat("\n=== STEP 7: Cleaning and validating dates ===\n")

# Function to parse dates flexibly
parse_date_flexible <- function(date_strings) {
  date_strings <- str_trim(date_strings)
  
  # Try multiple date formats
  formats <- c("%d-%b-%y", "%d-%b-%Y", "%m/%d/%y", "%m/%d/%Y", 
              "%Y-%m-%d", "%d.%m.%y", "%d.%m.%Y")
  
  result <- as.Date(rep(NA, length(date_strings)))
  
  for (format in formats) {
    remaining <- is.na(result)
    if (sum(remaining) > 0) {
      parsed <- as.Date(date_strings[remaining], format = format)
      result[remaining] <- parsed
    }
  }
  
  return(result)
}

# Parse dates
cat("Parsing dates...\n")
combined_data$date_parsed <- parse_date_flexible(combined_data$date)

# Check date parsing success
success_rate <- mean(!is.na(combined_data$date_parsed), na.rm = TRUE)
cat("Date parsing success rate:", round(success_rate * 100, 2), "%\n")

# Extract year, month, day
combined_data$year <- year(combined_data$date_parsed)
combined_data$month <- month(combined_data$date_parsed)
combined_data$day_of_month <- day(combined_data$date_parsed)

# Validate date ranges
cat("Date range:", min(combined_data$date_parsed, na.rm = TRUE), "to", 
    max(combined_data$date_parsed, na.rm = TRUE), "\n")

# Flag problematic dates
combined_data$date_flag <- case_when(
  is.na(combined_data$date_parsed) ~ "unparseable",
  combined_data$year < 1980 ~ "too_early",
  combined_data$year > 1995 ~ "too_late",
  TRUE ~ "ok"
)

table(combined_data$date_flag)

###############################################################################
### 8. NUMERIC VARIABLE CLEANING
###############################################################################

cat("\n=== STEP 8: Cleaning numeric variables ===\n")

# Define numeric columns
numeric_cols <- c("n_protesters", "protesters_arrested", "protesters_injured",
                 "protesters_killed", "state_actors", "state_injured", "state_killed")

# Function to clean numeric variables
clean_numeric <- function(x) {
  # Remove non-numeric characters except digits, decimal points, and minus signs
  x <- str_replace_all(x, "[^0-9.-]", "")
  x <- as.numeric(x)
  # Replace negative values with 0 (they don't make sense for counts)
  x[x < 0] <- 0
  return(x)
}

# Clean numeric variables
for (col in numeric_cols) {
  if (col %in% names(combined_data)) {
    cat("Cleaning", col, "...")
    combined_data[[paste0(col, "_numeric")]] <- clean_numeric(combined_data[[col]])
    cat("Done\n")
  }
}

# Summary statistics for numeric variables
cat("\nNumeric variable summaries:\n")
for (col in paste0(numeric_cols, "_numeric")) {
  if (col %in% names(combined_data)) {
    cat(str_replace(col, "_numeric", ""), ":\n")
    print(summary(combined_data[[col]]))
    cat("\n")
  }
}

###############################################################################
### 9. DATA VALIDATION AND QUALITY CHECKS
###############################################################################

cat("\n=== STEP 9: Data validation and quality checks ===\n")

# Create validation flags
combined_data$validation_flags <- ""

# Flag 1: Missing key information
combined_data$validation_flags <- ifelse(
  is.na(combined_data$date_parsed), 
  paste0(combined_data$validation_flags, "missing_date;"), 
  combined_data$validation_flags
)

# Flag 2: Inconsistent country information
combined_data$validation_flags <- ifelse(
  !is.na(combined_data$country) & 
  !is.na(combined_data$extracted_country) &
  tolower(combined_data$country) != tolower(combined_data$extracted_country),
  paste0(combined_data$validation_flags, "country_mismatch;"),
  combined_data$validation_flags
)

# Flag 3: Logical inconsistencies in numbers
if ("protesters_arrested_numeric" %in% names(combined_data) & 
    "n_protesters_numeric" %in% names(combined_data)) {
  combined_data$validation_flags <- ifelse(
    combined_data$protesters_arrested_numeric > combined_data$n_protesters_numeric & 
    !is.na(combined_data$protesters_arrested_numeric) &
    !is.na(combined_data$n_protesters_numeric),
    paste0(combined_data$validation_flags, "arrests_exceed_protesters;"),
    combined_data$validation_flags
  )
}

# Flag 4: Events without dates in valid range
combined_data$validation_flags <- ifelse(
  combined_data$has_event & combined_data$date_flag != "ok",
  paste0(combined_data$validation_flags, "event_bad_date;"),
  combined_data$validation_flags
)

# Summary of validation issues
validation_summary <- combined_data %>%
  filter(validation_flags != "") %>%
  separate_rows(validation_flags, sep = ";") %>%
  filter(validation_flags != "") %>%
  count(validation_flags) %>%
  arrange(desc(n))

cat("Validation issues found:\n")
print(validation_summary)

###############################################################################
### 10. CREATE ANALYSIS-READY DATASETS
###############################################################################

cat("\n=== STEP 10: Creating analysis-ready datasets ===\n")

# Dataset 1: All data with cleaning flags
write_csv(combined_data, file.path(output_dir, "protest_coercion_all_data.csv"))
cat("Saved complete dataset with all observations\n")

# Dataset 2: Events only (excluding 'no event' days)
events_only <- combined_data %>%
  filter(has_event == TRUE, date_flag == "ok") %>%
  select(-no_event_found, -has_event)

write_csv(events_only, file.path(output_dir, "protest_coercion_events_only.csv"))
cat("Saved events-only dataset with", nrow(events_only), "observations\n")

# Dataset 3: Daily time series (including no-event days for completeness)
daily_timeseries <- combined_data %>%
  filter(date_flag == "ok") %>%
  # Create binary indicators
  mutate(
    has_protest = ifelse(has_event & !is.na(n_protesters_numeric) & n_protesters_numeric > 0, 1, 0),
    has_repression = ifelse(has_event & !is.na(state_actors_numeric) & state_actors_numeric > 0, 1, 0)
  ) %>%
  # Aggregate to daily level by country
  group_by(extracted_country, date_parsed, year, month, day_of_month) %>%
  summarise(
    n_events = sum(has_event, na.rm = TRUE),
    n_protests = sum(has_protest, na.rm = TRUE),
    n_repression = sum(has_repression, na.rm = TRUE),
    total_protesters = sum(n_protesters_numeric, na.rm = TRUE),
    total_state_actors = sum(state_actors_numeric, na.rm = TRUE),
    total_arrested = sum(protesters_arrested_numeric, na.rm = TRUE),
    total_injured = sum(protesters_injured_numeric, na.rm = TRUE),
    total_killed = sum(protesters_killed_numeric, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(daily_timeseries, file.path(output_dir, "protest_coercion_daily_timeseries.csv"))
cat("Saved daily time series dataset with", nrow(daily_timeseries), "observations\n")

###############################################################################
### 11. CREATE DATA DOCUMENTATION
###############################################################################

cat("\n=== STEP 11: Creating data documentation ===\n")

# Create documentation
documentation <- list(
  "Dataset Information" = list(
    "Source" = "European Protest and Coercion Data by Prof. Ron Francisco",
    "URL" = "https://ronfran.ku.edu/data/index.html", 
    "Coverage" = "28 European countries, 1980-1995",
    "Cleaned by" = "Automated R script",
    "Date cleaned" = Sys.Date()
  ),
  
  "Files Created" = list(
    "protest_coercion_all_data.csv" = paste("Complete dataset with all", nrow(combined_data), "observations including no-event days"),
    "protest_coercion_events_only.csv" = paste("Events only dataset with", nrow(events_only), "protest/coercion events"),
    "protest_coercion_daily_timeseries.csv" = paste("Daily aggregated time series with", nrow(daily_timeseries), "country-days")
  ),
  
  "Countries Included" = sort(unique(combined_data$extracted_country[!is.na(combined_data$extracted_country)])),
  
  "Data Quality Issues" = validation_summary,
  
  "Variables" = list(
    "Date variables" = c("date_parsed", "year", "month", "day_of_month"),
    "Event description" = c("action", "protester", "state_target", "location", "issue"), 
    "Numeric measures" = paste0(numeric_cols, "_numeric"),
    "Flags" = c("has_event", "date_flag", "validation_flags")
  )
)

# Save documentation as JSON
jsonlite::write_json(documentation, file.path(output_dir, "data_documentation.json"), 
                    pretty = TRUE, auto_unbox = TRUE)

# Create readable text documentation
sink(file.path(output_dir, "README.txt"))
cat("EUROPEAN PROTEST AND COERCION DATA - CLEANED VERSION\n")
cat("==================================================\n\n")

cat("DATA SOURCE:\n")
cat("Prof. Ron Francisco's European Protest and Coercion Data\n")
cat("URL: https://ronfran.ku.edu/data/index.html\n")
cat("Coverage: 28 European countries, 1980-1995\n")
cat("Cleaned on:", as.character(Sys.Date()), "\n\n")

cat("FILES CREATED:\n")
cat("1. protest_coercion_all_data.csv - Complete dataset (", nrow(combined_data), " rows)\n")
cat("2. protest_coercion_events_only.csv - Events only (", nrow(events_only), " rows)\n") 
cat("3. protest_coercion_daily_timeseries.csv - Daily aggregated (", nrow(daily_timeseries), " rows)\n\n")

cat("COUNTRIES INCLUDED:\n")
countries <- sort(unique(combined_data$extracted_country[!is.na(combined_data$extracted_country)]))
for (i in seq_along(countries)) {
  cat(i, ".", countries[i], "\n")
}

cat("\nDATE COVERAGE:\n")
cat("From:", as.character(min(combined_data$date_parsed, na.rm = TRUE)), "\n")
cat("To:", as.character(max(combined_data$date_parsed, na.rm = TRUE)), "\n")

cat("\nDATA QUALITY NOTES:\n")
if (nrow(validation_summary) > 0) {
  for (i in 1:nrow(validation_summary)) {
    cat("- ", validation_summary$validation_flags[i], ": ", validation_summary$n[i], " cases\n")
  }
} else {
  cat("No major data quality issues detected.\n")
}

cat("\nKEY VARIABLES:\n")
cat("- date_parsed: Standardized date\n")
cat("- extracted_country: Country name from filename\n") 
cat("- has_event: TRUE if actual protest/coercion event\n")
cat("- n_protesters_numeric: Number of protesters\n")
cat("- state_actors_numeric: Number of state actors/forces\n")
cat("- validation_flags: Data quality warnings\n")

sink()

cat("Documentation saved to README.txt and data_documentation.json\n")

###############################################################################
### 12. SUMMARY STATISTICS
###############################################################################

cat("\n=== STEP 12: Final summary statistics ===\n")

cat("FINAL CLEANING SUMMARY:\n")
cat("=======================\n")
cat("Total observations processed:", nrow(combined_data), "\n")
cat("Actual events:", sum(combined_data$has_event, na.rm = TRUE), "\n")
cat("No-event days:", sum(!combined_data$has_event, na.rm = TRUE), "\n")
cat("Countries:", length(unique(combined_data$extracted_country)), "\n")
cat("Date range:", as.character(min(combined_data$date_parsed, na.rm = TRUE)), 
    "to", as.character(max(combined_data$date_parsed, na.rm = TRUE)), "\n")
cat("Files with validation issues:", 
    length(unique(combined_data$source_file[combined_data$validation_flags != ""])), "\n")

cat("\nData cleaning completed successfully!\n")
cat("Cleaned datasets saved to:", output_dir, "\n")

# Following user preferences for professional visualizations (Tufte's principles)
cat("\nNote: All visualizations should follow Tufte's principles as per user preferences.\n")