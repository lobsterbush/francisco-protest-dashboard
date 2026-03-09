###############################################################################
### Enhanced European Protest and Coercion Data Cleaning Script
### With Excel Serial Date Conversion
### Created by: Assistant
### Purpose: Maximize date parsing success rate while maintaining accuracy
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
output_dir <- "~/Documents/GitHub/protest-coercion/enhanced_cleaned_data/"

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

###############################################################################
### ENHANCED DATE PARSING FUNCTIONS
###############################################################################

cat("=== STEP 1: Setting up enhanced date parsing ===\n")

# Function to detect if a string is likely an Excel serial date
is_excel_serial_date <- function(x) {
  # Convert to numeric, return FALSE if conversion fails
  num_x <- suppressWarnings(as.numeric(x))
  if (all(is.na(num_x))) return(FALSE)
  
  # Excel dates are typically between 1 (1900-01-01) and 50000 (2037-xx-xx)
  # For our 1980-1995 range, expect roughly 29220-35060
  return(!is.na(num_x) & num_x >= 25000 & num_x <= 50000)
}

# Enhanced date parsing function
parse_date_enhanced <- function(date_strings, filename = "") {
  date_strings <- str_trim(date_strings)
  result <- as.Date(rep(NA, length(date_strings)))
  parsing_method <- rep("failed", length(date_strings))
  
  cat("  Processing", length(date_strings), "dates from", filename, "\n")
  
  # Method 1: Try standard text date formats first
  text_formats <- c("%d-%b-%y", "%d-%b-%Y", "%m/%d/%y", "%m/%d/%Y", 
                   "%Y-%m-%d", "%d.%m.%y", "%d.%m.%Y", "%d-%m-%y", "%d/%m/%y")
  
  for (format in text_formats) {
    remaining <- is.na(result)
    if (sum(remaining) > 0) {
      parsed <- suppressWarnings(as.Date(date_strings[remaining], format = format))
      valid_parsed <- !is.na(parsed)
      
      if (sum(valid_parsed) > 0) {
        # Force two-digit years to 20th century for historical context
        year_vals <- year(parsed[valid_parsed])
        # If year is > 2000 and original had 2-digit year, assume 1900s
        needs_correction <- year_vals > 2000 & nchar(str_extract(date_strings[remaining][valid_parsed], "\\d{2}$")) == 2
        if (sum(needs_correction, na.rm = TRUE) > 0) {
          corrected_years <- year_vals[needs_correction] - 100
          # Only apply correction if it puts us in valid range
          valid_correction <- corrected_years >= 1980 & corrected_years <= 1995
          if (sum(valid_correction, na.rm = TRUE) > 0) {
            year(parsed[valid_parsed][needs_correction][valid_correction]) <- corrected_years[valid_correction]
          }
        }
        
        result[remaining][valid_parsed] <- parsed[valid_parsed]
        parsing_method[remaining][valid_parsed] <- paste0("text_", format)
      }
    }
  }
  
  # Method 2: Try Excel serial date conversion
  remaining <- is.na(result)
  if (sum(remaining) > 0) {
    remaining_strings <- date_strings[remaining]
    excel_candidates <- is_excel_serial_date(remaining_strings)
    
    if (sum(excel_candidates) > 0) {
      cat("    Found", sum(excel_candidates), "potential Excel serial dates\n")
      excel_numbers <- as.numeric(remaining_strings[excel_candidates])
      
      # Excel epoch is 1900-01-01, but Excel has a leap year bug for 1900
      # Standard conversion: days since 1899-12-30
      excel_epoch <- as.Date("1899-12-30")
      excel_dates <- excel_epoch + excel_numbers
      
      # Validate that converted dates are reasonable
      valid_excel <- !is.na(excel_dates) & 
                    year(excel_dates) >= 1980 & 
                    year(excel_dates) <= 1995
      
      if (sum(valid_excel) > 0) {
        cat("    Successfully converted", sum(valid_excel), "Excel dates\n")
        result[remaining][excel_candidates][valid_excel] <- excel_dates[valid_excel]
        parsing_method[remaining][excel_candidates][valid_excel] <- "excel_serial"
      }
    }
  }
  
  # Method 3: Try alternative Excel epoch (some systems use 1904-01-01)
  remaining <- is.na(result)
  if (sum(remaining) > 0) {
    remaining_strings <- date_strings[remaining]
    excel_candidates <- is_excel_serial_date(remaining_strings)
    
    if (sum(excel_candidates) > 0) {
      excel_numbers <- as.numeric(remaining_strings[excel_candidates])
      excel_epoch_1904 <- as.Date("1904-01-01")
      excel_dates_1904 <- excel_epoch_1904 + excel_numbers
      
      valid_excel_1904 <- !is.na(excel_dates_1904) & 
                         year(excel_dates_1904) >= 1980 & 
                         year(excel_dates_1904) <= 1995
      
      if (sum(valid_excel_1904) > 0) {
        cat("    Successfully converted", sum(valid_excel_1904), "Excel dates (1904 system)\n")
        result[remaining][excel_candidates][valid_excel_1904] <- excel_dates_1904[valid_excel_1904]
        parsing_method[remaining][excel_candidates][valid_excel_1904] <- "excel_1904"
      }
    }
  }
  
  # Final validation: ensure all results are in valid range
  valid_range <- !is.na(result) & year(result) >= 1980 & year(result) <= 1995
  result[!valid_range] <- NA_Date_
  parsing_method[!valid_range] <- "out_of_range"
  
  success_rate <- mean(!is.na(result)) * 100
  cat("    Date parsing success rate:", round(success_rate, 2), "%\n")
  
  return(list(
    dates = result,
    methods = parsing_method,
    success_rate = success_rate
  ))
}

###############################################################################
### LOAD AND PROCESS FILES WITH ENHANCED PARSING
###############################################################################

cat("\n=== STEP 2: Loading files with enhanced date parsing ===\n")

# Get list of all CSV files
csv_files <- list.files(data_dir, pattern = "\\.csv$", full.names = TRUE)
csv_files <- csv_files[!grepl("codebook", csv_files, ignore.case = TRUE)]

cat("Found", length(csv_files), "CSV files\n")

# Enhanced loading function
load_and_standardize_file_enhanced <- function(file_path) {
  filename <- basename(file_path)
  cat("Processing:", filename, "\n")
  
  # Extract country and period from filename
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
    
    # Standardize column names (reuse the function from before)
    original_names <- names(data)
    names(data) <- standardize_column_names(original_names)
    
    # Enhanced date parsing
    date_col <- data$date
    if (is.null(date_col)) {
      # Try alternative date column names
      date_candidates <- names(data)[str_detect(names(data), "date|Date")]
      if (length(date_candidates) > 0) {
        date_col <- data[[date_candidates[1]]]
      }
    }
    
    if (!is.null(date_col)) {
      parsing_results <- parse_date_enhanced(date_col, filename)
      data$date_parsed <- parsing_results$dates
      data$date_parsing_method <- parsing_results$methods
      data$file_success_rate <- parsing_results$success_rate
    } else {
      data$date_parsed <- NA_Date_
      data$date_parsing_method <- "no_date_column"
      data$file_success_rate <- 0
    }
    
    # Add metadata columns
    data$source_file <- filename
    data$extracted_country <- country
    data$extracted_period <- period
    
    # Handle 'no event' indicator
    no_event_col <- ifelse(is.null(data$no_event_found), "", 
                          ifelse(is.na(data$no_event_found), "", data$no_event_found))
    data$has_event <- !str_detect(no_event_col, "no event")
    
    # Create validation flags
    data$year_parsed <- year(data$date_parsed)
    data$date_flag <- case_when(
      is.na(data$date_parsed) ~ "unparseable",
      data$year_parsed < 1980 ~ "too_early", 
      data$year_parsed > 1995 ~ "too_late",
      TRUE ~ "ok"
    )
    
    cat("  - Loaded", nrow(data), "rows,", ncol(data), "columns\n")
    cat("  - Country:", country, ", Period:", period, "\n")
    cat("  - Date success:", round(parsing_results$success_rate, 2), "%\n")
    cat("  - Events:", sum(data$has_event, na.rm = TRUE), "/ Total:", nrow(data), "\n")
    
    return(data)
    
  }, error = function(e) {
    cat("  - ERROR loading file:", e$message, "\n")
    return(NULL)
  })
}

# Column standardization function (reuse from previous script)
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
### PROCESS ALL FILES
###############################################################################

cat("\n=== STEP 3: Processing all files ===\n")

all_data_list <- list()
parsing_summary <- data.frame(
  file = character(),
  success_rate = numeric(),
  total_rows = numeric(),
  parsed_dates = numeric(),
  stringsAsFactors = FALSE
)

for (file in csv_files) {
  result <- load_and_standardize_file_enhanced(file)
  if (!is.null(result)) {
    all_data_list[[basename(file)]] <- result
    
    # Add to parsing summary
    parsing_summary <- rbind(parsing_summary, data.frame(
      file = basename(file),
      success_rate = result$file_success_rate[1],
      total_rows = nrow(result),
      parsed_dates = sum(!is.na(result$date_parsed)),
      stringsAsFactors = FALSE
    ))
  }
}

cat("\nSuccessfully loaded", length(all_data_list), "files\n")

# Print parsing summary
cat("\n=== PARSING SUCCESS SUMMARY ===\n")
parsing_summary <- parsing_summary %>% arrange(desc(success_rate))
print(parsing_summary)

cat("Overall statistics:\n")
cat("- Average success rate:", round(mean(parsing_summary$success_rate), 2), "%\n")
cat("- Best performing files:", round(max(parsing_summary$success_rate), 2), "%\n")
cat("- Files with <50% success:", sum(parsing_summary$success_rate < 50), "\n")

###############################################################################
### COMBINE AND CLEAN DATA
###############################################################################

cat("\n=== STEP 4: Combining and final cleaning ===\n")

# Identify core columns for harmonization
core_columns <- c("date", "day", "action", "protester", "state_target", "agent", 
                 "event", "country", "location", "issue", "link_date", "time",
                 "n_protesters", "protesters_arrested", "protesters_injured", 
                 "protesters_killed", "property_damage", "state_actors",
                 "state_injured", "state_killed", "osd", "source", "story_date",
                 "no_event_found", "source_file", "extracted_country", 
                 "extracted_period", "has_event", "date_parsed", 
                 "date_parsing_method", "file_success_rate", "year_parsed", "date_flag")

# Function to harmonize columns
harmonize_columns <- function(data, target_columns) {
  # Add missing columns
  for (col in target_columns) {
    if (!col %in% names(data)) {
      data[[col]] <- NA_character_
    }
  }
  
  # Reorder columns to target columns first, then any extras
  extra_cols <- setdiff(names(data), target_columns)
  data <- data[, c(target_columns, extra_cols), drop = FALSE]
  
  return(data)
}

# Harmonize all datasets
cat("Harmonizing column structure...\n")
for (i in seq_along(all_data_list)) {
  all_data_list[[i]] <- harmonize_columns(all_data_list[[i]], core_columns)
}

# Combine all data
combined_data <- bind_rows(all_data_list)
cat("Combined dataset has", nrow(combined_data), "rows and", ncol(combined_data), "columns\n")

# Clean numeric variables
numeric_cols <- c("n_protesters", "protesters_arrested", "protesters_injured",
                 "protesters_killed", "state_actors", "state_injured", "state_killed")

clean_numeric <- function(x) {
  x <- str_replace_all(x, "[^0-9.-]", "")
  x <- as.numeric(x)
  x[x < 0] <- 0  # Replace negative values with 0
  return(x)
}

for (col in numeric_cols) {
  if (col %in% names(combined_data)) {
    combined_data[[paste0(col, "_numeric")]] <- clean_numeric(combined_data[[col]])
  }
}

# Final statistics
cat("\n=== ENHANCED PARSING RESULTS ===\n")
overall_success <- mean(!is.na(combined_data$date_parsed)) * 100
cat("Overall date parsing success rate:", round(overall_success, 2), "%\n")

date_flag_table <- table(combined_data$date_flag)
print(date_flag_table)

method_table <- table(combined_data$date_parsing_method)
cat("\nParsing methods used:\n")
print(method_table)

# Show improvement over basic parsing
cat("\nComparison with basic parsing:\n")
cat("- Enhanced parsing success:", round(overall_success, 2), "%\n")
cat("- Previous parsing success: 88.48%\n")
cat("- Improvement:", round(overall_success - 88.48, 2), "percentage points\n")

###############################################################################
### SAVE ENHANCED DATASETS
###############################################################################

cat("\n=== STEP 5: Saving enhanced datasets ===\n")

# Dataset 1: Complete enhanced dataset
write_csv(combined_data, file.path(output_dir, "protest_coercion_enhanced_all_data.csv"))
cat("Saved: protest_coercion_enhanced_all_data.csv\n")

# Dataset 2: Successfully parsed dates only
parsed_data <- combined_data %>%
  filter(date_flag == "ok") %>%
  mutate(
    year_clean = year(date_parsed),
    month_clean = month(date_parsed),
    day_clean = day(date_parsed)
  )

write_csv(parsed_data, file.path(output_dir, "protest_coercion_enhanced_parsed.csv"))
cat("Saved: protest_coercion_enhanced_parsed.csv with", nrow(parsed_data), "rows\n")

# Dataset 3: Events only with parsed dates
events_parsed <- parsed_data %>%
  filter(has_event == TRUE)

write_csv(events_parsed, file.path(output_dir, "protest_coercion_enhanced_events.csv"))
cat("Saved: protest_coercion_enhanced_events.csv with", nrow(events_parsed), "rows\n")

# Dataset 4: Parsing method breakdown
method_breakdown <- combined_data %>%
  group_by(source_file, date_parsing_method) %>%
  summarise(count = n(), .groups = "drop") %>%
  pivot_wider(names_from = date_parsing_method, values_from = count, values_fill = 0) %>%
  mutate(total = rowSums(select(., -source_file), na.rm = TRUE)) %>%
  arrange(desc(total))

write_csv(method_breakdown, file.path(output_dir, "parsing_method_breakdown.csv"))
cat("Saved: parsing_method_breakdown.csv\n")

# Dataset 5: Files with Excel date recovery
excel_recovery <- parsing_summary %>%
  left_join(
    combined_data %>% 
      filter(str_detect(date_parsing_method, "excel")) %>% 
      group_by(source_file) %>% 
      summarise(excel_dates_recovered = n(), .groups = "drop"),
    by = c("file" = "source_file")
  ) %>%
  mutate(excel_dates_recovered = ifelse(is.na(excel_dates_recovered), 0, excel_dates_recovered)) %>%
  arrange(desc(excel_dates_recovered))

write_csv(excel_recovery, file.path(output_dir, "excel_date_recovery_summary.csv"))
cat("Saved: excel_date_recovery_summary.csv\n")

cat("\nEnhanced data cleaning completed successfully!\n")
cat("Files saved to:", output_dir, "\n")
cat("Key improvement: Date parsing success increased from 88.48% to", round(overall_success, 2), "%\n")