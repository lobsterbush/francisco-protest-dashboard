## -----------------------------------------------------------------------------
## 01_prep_data.R
## Prepare Ron Francisco's European Protest & Coercion Data for the dashboard.
## Outputs: data/dashboard_data.rds (list of pre-aggregated data frames)
## Run from project root: Rscript R/01_prep_data.R
## -----------------------------------------------------------------------------

library(here)
library(dplyr)
library(tidyr)
library(lubridate)
library(stringr)
library(readr)
library(purrr)

set.seed(42)

## ── 1. Read raw enhanced-parsed CSV ─────────────────────────────────────────

raw <- read_csv(
  here("enhanced_cleaned_data", "protest_coercion_enhanced_parsed.csv"),
  col_types = cols(.default = "c"),
  show_col_types = FALSE
)

cat("Raw rows:", nrow(raw), "\n")

## ── 2. Select and coerce core columns ───────────────────────────────────────

dat <- raw |>
  transmute(
    date          = suppressWarnings(as_date(date_parsed)),
    year          = as.integer(year_clean),
    month         = as.integer(month_clean),
    country       = str_trim(extracted_country),
    action        = str_trim(str_to_lower(action)),
    issue         = str_trim(str_to_lower(issue)),
    location      = str_trim(location),
    event_text    = str_trim(event),
    has_event     = (has_event == "TRUE"),
    n_protesters  = suppressWarnings(as.numeric(n_protesters_numeric)),
    state_actors  = suppressWarnings(as.numeric(state_actors_numeric)),
    arrested      = suppressWarnings(as.numeric(protesters_arrested_numeric)),
    p_injured     = suppressWarnings(as.numeric(protesters_injured_numeric)),
    p_killed      = suppressWarnings(as.numeric(protesters_killed_numeric)),
    s_injured     = suppressWarnings(as.numeric(state_injured_numeric)),
    s_killed      = suppressWarnings(as.numeric(state_killed_numeric)),
    source_file   = source_file
  ) |>
  filter(!is.na(date), year >= 1980, year <= 1995)

cat("After date filter:", nrow(dat), "\n")

## ── 3. Standardise country display names ────────────────────────────────────

country_labels <- c(
  "FRG"            = "West Germany (FRG)",
  "GDR"            = "East Germany (GDR)",
  "UK"             = "United Kingdom",
  "NorthernIreland"= "Northern Ireland",
  "Romania "       = "Romania",   # trailing space in source
  "Czech"          = "Czech Republic"
)

dat <- dat |>
  mutate(country = recode(country, !!!country_labels))

## ── 4. Derived indicators ────────────────────────────────────────────────────

dat <- dat |>
  mutate(
    n_protesters = replace_na(n_protesters, 0),
    state_actors = replace_na(state_actors, 0),
    protest_day  = has_event & n_protesters > 0,
    repression_day = has_event & state_actors > 0,
    both_day     = protest_day & repression_day
  )

## ── 5. Events-only table (for the Events tab) ───────────────────────────────

events <- dat |>
  filter(has_event) |>
  select(date, year, country, action, issue, location,
         n_protesters, state_actors, arrested, p_injured, p_killed,
         event_text) |>
  mutate(
    action   = na_if(action, "na"),
    issue    = na_if(issue, "na"),
    location = na_if(location, "NA")
  ) |>
  arrange(date)

cat("Event rows:", nrow(events), "\n")

## ── 6. Country-year panel ────────────────────────────────────────────────────

cy <- dat |>
  group_by(country, year) |>
  summarise(
    total_days        = n(),
    protest_days      = sum(protest_day, na.rm = TRUE),
    repression_days   = sum(repression_day, na.rm = TRUE),
    both_days         = sum(both_day, na.rm = TRUE),
    total_protesters  = sum(n_protesters, na.rm = TRUE),
    total_agents      = sum(state_actors, na.rm = TRUE),
    total_arrested    = sum(arrested, na.rm = TRUE),
    protest_rate      = protest_days / total_days,
    repression_rate   = repression_days / total_days,
    .groups = "drop"
  )

## ── 7. Annual totals (all countries pooled) ──────────────────────────────────

annual <- dat |>
  group_by(year) |>
  summarise(
    protest_days    = sum(protest_day, na.rm = TRUE),
    repression_days = sum(repression_day, na.rm = TRUE),
    both_days       = sum(both_day, na.rm = TRUE),
    protesters      = sum(n_protesters, na.rm = TRUE),
    agents          = sum(state_actors, na.rm = TRUE),
    n_events        = sum(has_event, na.rm = TRUE),
    .groups = "drop"
  )

## ── 8. Country totals ─────────────────────────────────────────────────────────

country_totals <- cy |>
  group_by(country) |>
  summarise(
    protest_days    = sum(protest_days),
    repression_days = sum(repression_days),
    both_days       = sum(both_days),
    protesters      = sum(total_protesters),
    agents          = sum(total_agents),
    years_covered   = n_distinct(year),
    .groups = "drop"
  ) |>
  arrange(desc(protest_days))

## ── 9. Action-type frequencies ───────────────────────────────────────────────

actions <- events |>
  filter(!is.na(action), action != "") |>
  count(action, sort = TRUE) |>
  slice_head(n = 30) |>
  mutate(action = str_to_title(action))

## ── 10. Issue frequencies ─────────────────────────────────────────────────────

issues <- events |>
  filter(!is.na(issue), issue != "") |>
  count(issue, sort = TRUE) |>
  slice_head(n = 30) |>
  mutate(issue = str_to_title(issue))

## ── 11. Country-year panel with lags (for models tab) ────────────────────────

cy_model <- cy |>
  arrange(country, year) |>
  group_by(country) |>
  mutate(
    lag_protest_days    = lag(protest_days),
    lag_repression_days = lag(repression_days),
    lag_protesters      = lag(total_protesters),
    lag_agents          = lag(total_agents),
    year_trend          = year - 1980
  ) |>
  ungroup()

## ── 12. Summary stats (for Overview cards) ───────────────────────────────────

summary_stats <- list(
  total_events      = nrow(events),
  total_countries   = n_distinct(dat$country),
  year_range        = paste(min(dat$year), max(dat$year), sep = "–"),
  total_protesters  = sum(events$n_protesters, na.rm = TRUE),
  repression_events = sum(events$state_actors > 0, na.rm = TRUE),
  protest_events    = sum(events$n_protesters > 0, na.rm = TRUE),
  countries         = sort(unique(dat$country))
)

## ── 13. Save ─────────────────────────────────────────────────────────────────

dashboard_data <- list(
  events        = events,
  cy            = cy,
  cy_model      = cy_model,
  annual        = annual,
  country_totals= country_totals,
  actions       = actions,
  issues        = issues,
  summary       = summary_stats
)

saveRDS(dashboard_data, here("data", "dashboard_data.rds"))
cat("Saved data/dashboard_data.rds\n")
cat("Summary:\n")
cat("  Events:", nrow(events), "\n")
cat("  Countries:", summary_stats$total_countries, "\n")
cat("  Years:", summary_stats$year_range, "\n")
cat("  Total protesters:", format(summary_stats$total_protesters, big.mark = ","), "\n")
