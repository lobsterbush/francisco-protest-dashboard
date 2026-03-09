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
library(WDI)

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

## ── 11. Country-year panel with lags + WDI covariates (for models tab) ─────

### WDI country → ISO-2 mapping (only countries present in Francisco data)
country_iso2 <- c(
  "Albania"              = "AL",
  "Austria"              = "AT",
  "Belgium"              = "BE",
  "Bulgaria"             = "BG",
  "Cyprus"               = "CY",
  "Czech Republic"       = "CZ",
  "Czechoslovakia"       = NA_character_,  # not in WDI
  "Denmark"              = "DK",
  "Finland"              = "FI",
  "France"               = "FR",
  "West Germany (FRG)"   = "DE",  # WDI uses DEU for all Germany
  "East Germany (GDR)"   = NA_character_,  # not in WDI
  "Greece"               = "GR",
  "Hungary"              = "HU",
  "Iceland"              = "IS",
  "Ireland"              = "IE",
  "Italy"                = "IT",
  "Luxembourg"           = "LU",
  "Netherlands"          = "NL",
  "Northern Ireland"     = "GB",  # proxy: UK
  "Norway"               = "NO",
  "Poland"               = "PL",
  "Portugal"             = "PT",
  "Romania"              = "RO",
  "Slovakia"             = "SK",
  "Spain"                = "ES",
  "Sweden"               = "SE",
  "Switzerland"          = "CH",
  "United Kingdom"       = "GB"
)

cat("Downloading WDI data...\n")
wdi_raw <- tryCatch(
  WDI(
    country   = na.omit(unique(country_iso2)),
    indicator = c(
      gdp_pc    = "NY.GDP.PCAP.KD",    # GDP per capita, constant 2015 USD
      unemp     = "SL.UEM.TOTL.ZS",   # Unemployment, % total labour force
      pop       = "SP.POP.TOTL",       # Population, total
      trade     = "NE.TRD.GNFS.ZS",   # Trade (imports + exports, % of GDP)
      inflation = "FP.CPI.TOTL.ZG",   # Inflation, consumer prices (annual %)
      urban     = "SP.URB.TOTL.IN.ZS" # Urban population (% of total)
    ),
    start = 1979, end = 1996, extra = FALSE
  ),
  error = function(e) {
    warning("WDI download failed: ", e$message, ". Continuing without WDI covariates.")
    NULL
  }
)

if (!is.null(wdi_raw)) {
  wdi <- wdi_raw |>
    select(iso2c, year, gdp_pc, unemp, pop, trade, inflation, urban) |>
    rename(wdi_iso2 = iso2c)

  # Build reverse map: iso2 → all Francisco country names using that code
  iso2_to_countries <- split(
    names(country_iso2),
    country_iso2
  )

  # Expand: for each Francisco country, attach matching WDI rows
  cy_wdi_key <- tibble(
    country  = names(country_iso2),
    wdi_iso2 = unname(country_iso2)
  ) |> filter(!is.na(wdi_iso2))

  wdi_merged <- cy_wdi_key |>
    left_join(wdi, by = "wdi_iso2", relationship = "many-to-many") |>
    select(country, year, gdp_pc, unemp, pop, trade, inflation, urban)

  cat("WDI rows merged:", nrow(wdi_merged), "\n")
} else {
  wdi_merged <- tibble(
    country = character(), year = integer(),
    gdp_pc = numeric(), unemp = numeric(), pop = numeric(),
    trade = numeric(), inflation = numeric(), urban = numeric()
  )
}

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
  ungroup() |>
  left_join(wdi_merged, by = c("country", "year")) |>
  mutate(
    log_gdp_pc = log(gdp_pc + 1),
    log_pop    = log(pop    + 1)
  )

## ── 11c. Manually coded political & structural variables ──────────────────────
## All are country-year level (time-varying where relevant).

# Countries that were part of the Soviet bloc at any point 1980-1995
eastern_bloc_countries <- c(
  "Albania", "Bulgaria", "Czechoslovakia", "Czech Republic",
  "East Germany (GDR)", "Hungary", "Poland", "Romania", "Slovakia"
)

# EEC/EU accession year (year country joined the European Communities / EU)
eu_accession <- c(
  "Belgium"            = 1957, "France"           = 1957,
  "West Germany (FRG)" = 1957, "Italy"            = 1957,
  "Luxembourg"         = 1957, "Netherlands"      = 1957,
  "Denmark"            = 1973, "Ireland"          = 1973,
  "United Kingdom"     = 1973, "Northern Ireland" = 1973,
  "Greece"             = 1981, "Portugal"         = 1986,
  "Spain"              = 1986, "Austria"          = 1995,
  "Finland"            = 1995, "Sweden"           = 1995
)

# NATO accession year (for countries present in the Francisco data)
nato_accession <- c(
  "Belgium"            = 1949, "Denmark"          = 1949,
  "France"             = 1949, "West Germany (FRG)"= 1955,
  "Greece"             = 1952, "Iceland"          = 1949,
  "Italy"              = 1949, "Luxembourg"       = 1949,
  "Netherlands"        = 1949, "Norway"           = 1949,
  "Portugal"           = 1949, "Spain"            = 1982,
  "United Kingdom"     = 1949, "Northern Ireland" = 1949
)

# Year of first free multiparty elections (communist rule ended before this year)
communist_end <- c(
  "Albania"            = 1992,  # first free elections March 1992
  "Bulgaria"           = 1990,  # communist party fell November 1989
  "Czechoslovakia"     = 1990,  # Velvet Revolution November 1989
  "East Germany (GDR)" = 1990,  # absorbed into FRG October 1990
  "Hungary"            = 1990,  # free elections April 1990
  "Poland"             = 1990,  # Solidarity government from August 1989
  "Romania"            = 1990   # Ceaușescu fell December 1989
)

cy_model <- cy_model |>
  mutate(
    eastern_bloc     = as.integer(country %in% eastern_bloc_countries),
    eu_member        = as.integer(
      country %in% names(eu_accession) & year >= eu_accession[country]
    ),
    nato_member      = as.integer(
      country %in% names(nato_accession) & year >= nato_accession[country]
    ),
    communist_regime = as.integer(
      country %in% names(communist_end) & year < communist_end[country]
    ),
    post_transition  = as.integer(
      country %in% names(communist_end) & year >= communist_end[country]
    )
  )

cat("cy_model columns:", paste(names(cy_model), collapse = ", "), "\n")
cat("Eastern bloc obs:", sum(cy_model$eastern_bloc, na.rm = TRUE), "\n")
cat("Communist regime obs:", sum(cy_model$communist_regime, na.rm = TRUE), "\n")
cat("EU member obs:", sum(cy_model$eu_member, na.rm = TRUE), "\n")

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
