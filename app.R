## -----------------------------------------------------------------------------
## app.R — Francisco European Protest & Coercion Dashboard
## Four tabs: Overview · Trends · Events · Models
## Run with: shiny::runApp()
## -----------------------------------------------------------------------------

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggthemes)
library(plotly)
library(DT)
library(fixest)
library(broom)
library(scales)
library(stringr)

## ── Load pre-processed data ────────────────────────────────────────────

dd <- readRDS("data/dashboard_data.rds")

events         <- dd$events
cy             <- dd$cy
cy_model       <- dd$cy_model
annual         <- dd$annual
country_totals <- dd$country_totals
actions        <- dd$actions
issues         <- dd$issues
summ           <- dd$summary

all_countries <- summ$countries
YEAR_MIN      <- 1980L
YEAR_MAX      <- 1995L

## ── Theme helpers ─────────────────────────────────────────────────────────────

PROTEST_COL    <- "#c0392b"  # warm red
REPRESSION_COL <- "#2c3e50"  # dark slate
BOTH_COL       <- "#8e44ad"  # purple

base_theme <- function() {
  theme_tufte(base_size = 13) +
    theme(
      axis.title      = element_text(size = 12),
      axis.text       = element_text(size = 11),
      legend.text     = element_text(size = 11),
      plot.title      = element_text(size = 14, face = "bold"),
      plot.subtitle   = element_text(size = 11, color = "grey40"),
      plot.caption    = element_text(size = 9, color = "grey50")
    )
}

fmt_big <- function(x) format(round(x), big.mark = ",", scientific = FALSE)

## ── UI ────────────────────────────────────────────────────────────────────────

ui <- page_navbar(
  title = "Francisco Protest & Coercion Data",
  theme = bs_theme(
    bg         = "#fafafa",
    fg         = "#1a1a1a",
    primary    = "#0066cc",
    secondary  = "#2A7347",
    success    = "#2A7347",
    danger     = "#c0392b",
    base_font  = font_google("Plus Jakarta Sans"),
    code_font  = font_google("JetBrains Mono")
  ),
  header = tags$head(
    tags$link(rel = "stylesheet", href = "custom.css"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")
  ),

  ## ── TAB 1: Overview ──────────────────────────────────────────────────────────
  nav_panel(
    "Overview",
    icon = icon("chart-line"),

    div(class = "hero-section",
      div(class = "hero-eyebrow", "A tribute to Ron Francisco's life work"),
      h2("European Protest & Coercion Data"),
      p(class = "hero-subtitle",
        "The most comprehensive daily-resolution record of political contention and state repression
         in modern Europe. Compiled by Prof. Ron Francisco (University of Kansas), this dataset covers",
        strong("29 countries"), "across", strong("16 years (1980\u20131995)"),
        "and", strong(paste0(fmt_big(summ$total_events), " coded events")),
        "\u2014 including strikes, occupations, demonstrations, bombings, arrests, and much more."
      ),
      div(class = "hero-attribution",
        "Data source: ",
        tags$a("ronfran.ku.edu/data", href = "https://ronfran.ku.edu/data/index.html",
               target = "_blank"),
        " · Dashboard by Charles Crabtree (Monash University / Korea University).",
        " Cite as: Francisco, R. (2000). ", em("European Protest and Coercion Data"), ".",
        " University of Kansas."
      )
    ),

    ## Summary cards
    div(class = "cards-row",
      div(class = "stat-card",
        div(class = "stat-value", fmt_big(summ$total_events)),
        div(class = "stat-label", "Coded Events")
      ),
      div(class = "stat-card",
        div(class = "stat-value", summ$total_countries),
        div(class = "stat-label", "Countries")
      ),
      div(class = "stat-card",
        div(class = "stat-value", "16"),
        div(class = "stat-label", "Years (1980–1995)")
      ),
      div(class = "stat-card protest-card",
        div(class = "stat-value", fmt_big(summ$protest_events)),
        div(class = "stat-label", "Protest Events")
      ),
      div(class = "stat-card repression-card",
        div(class = "stat-value", fmt_big(summ$repression_events)),
        div(class = "stat-label", "Repression Events")
      )
    ),

    fluidRow(
      column(8,
        div(class = "panel-box",
          h4("Protest & Repression Over Time (All Countries)"),
          plotlyOutput("overview_timeline", height = "340px")
        )
      ),
      column(4,
        div(class = "panel-box",
          h4("Top Countries by Protest Days"),
          plotlyOutput("overview_country_bar", height = "340px")
        )
      )
    ),

    fluidRow(
      column(6,
        div(class = "panel-box",
          h4("Top 15 Action Types"),
          plotlyOutput("overview_actions", height = "300px")
        )
      ),
      column(6,
        div(class = "panel-box",
          h4("Top 15 Issue Categories"),
          plotlyOutput("overview_issues", height = "300px")
        )
      )
    )
  ),

  ## ── TAB 2: Trends ─────────────────────────────────────────────────────────────
  nav_panel(
    "Trends",
    icon = icon("chart-bar"),

    fluidRow(
      column(3,
        div(class = "sidebar-box",
          h5("Filters"),
          selectInput("trends_country",
            "Country (one or more)",
            choices  = c("All countries" = "all", all_countries),
            selected = "all",
            multiple = TRUE,
            selectize = TRUE
          ),
          sliderInput("trends_years", "Year Range",
            min = YEAR_MIN, max = YEAR_MAX,
            value = c(YEAR_MIN, YEAR_MAX),
            sep = "", step = 1
          ),
          radioButtons("trends_metric", "Metric",
            choices = c(
              "Protest days"    = "protest_days",
              "Repression days" = "repression_days",
              "Both (overlap)"  = "both_days",
              "Protest rate"    = "protest_rate",
              "Repression rate" = "repression_rate"
            ),
            selected = "protest_days"
          )
        )
      ),
      column(9,
        div(class = "panel-box",
          h4("Annual Trends by Country"),
          plotlyOutput("trends_ts", height = "380px")
        ),
        fluidRow(
          column(6,
            div(class = "panel-box",
              h4("Protest vs. Repression (Country-Year Scatter)"),
              plotlyOutput("trends_scatter", height = "300px")
            )
          ),
          column(6,
            div(class = "panel-box",
              h4("Country Comparison (Selected Period)"),
              plotlyOutput("trends_bar", height = "300px")
            )
          )
        )
      )
    )
  ),

  ## ── TAB 3: Events ─────────────────────────────────────────────────────────────
  nav_panel(
    "Events",
    icon = icon("table"),

    fluidRow(
      column(3,
        div(class = "sidebar-box",
          h5("Filter Events"),
          selectInput("ev_country", "Country",
            choices  = c("All" = "all", all_countries),
            selected = "all",
            multiple = TRUE,
            selectize = TRUE
          ),
          sliderInput("ev_years", "Year Range",
            min = YEAR_MIN, max = YEAR_MAX,
            value = c(YEAR_MIN, YEAR_MAX),
            sep = "", step = 1
          ),
          checkboxInput("ev_protest_only",
            "Protest events only (protesters > 0)", FALSE),
          checkboxInput("ev_repression_only",
            "Repression events only (state actors > 0)", FALSE),
          hr(),
          div(class = "filter-note",
            strong(textOutput("ev_row_count", inline = TRUE)),
            " events match"
          )
        )
      ),
      column(9,
        div(class = "panel-box",
          h4("Searchable Event Records"),
          p(class = "table-note",
            "Use the Search box to find events by keyword. Click column headers to sort."),
          DTOutput("events_table")
        )
      )
    )
  ),

  ## ── TAB 4: Models ─────────────────────────────────────────────────────────────
  nav_panel(
    "Models",
    icon = icon("calculator"),

    fluidRow(
      column(3,
        div(class = "sidebar-box",
          h5("Model Specification"),

          selectInput("mod_dv", "Dependent Variable",
            choices = c(
              "Protest days (count)"      = "protest_days",
              "Repression days (count)"   = "repression_days",
              "Protest rate (0–1)"        = "protest_rate",
              "Repression rate (0–1)"     = "repression_rate",
              "Total protesters (count)"  = "total_protesters",
              "Total agents (count)"      = "total_agents"
            )
          ),

          checkboxGroupInput("mod_ivs", "Independent Variables",
            choices = c(
              # Francisco lags
              "Lagged protest days"         = "lag_protest_days",
              "Lagged repression days"      = "lag_repression_days",
              "Lagged protesters"           = "lag_protesters",
              "Lagged agents"               = "lag_agents",
              "Year trend"                  = "year_trend",
              # Economic (WDI)
              "GDP per capita (log)"        = "log_gdp_pc",
              "Unemployment rate (%)"       = "unemp",
              "Population (log)"            = "log_pop",
              "Trade openness (% GDP)"      = "trade",
              "Inflation (CPI, %)"          = "inflation",
              "Urban population (%)"        = "urban",
              # Political & structural
              "Eastern bloc country"        = "eastern_bloc",
              "Communist regime"            = "communist_regime",
              "Post-transition"             = "post_transition",
              "EU/EEC member"               = "eu_member",
              "NATO member"                 = "nato_member"
            ),
            selected = c("lag_protest_days", "lag_repression_days")
          ),

          checkboxGroupInput("mod_fe", "Fixed Effects",
            choices = c(
              "Country FE"  = "country",
              "Year FE"     = "year"
            ),
            selected = "country"
          ),

          selectInput("mod_family", "Estimator",
            choices = c(
              "OLS (linear)"             = "ols",
              "Logit (binary outcome)"   = "logit",
              "Poisson (count outcome)"  = "poisson"
            )
          ),

          selectInput("mod_country", "Country Subset",
            choices  = c("All countries" = "all", all_countries),
            selected = "all",
            multiple = TRUE,
            selectize = TRUE
          ),

          sliderInput("mod_years", "Year Range",
            min = YEAR_MIN, max = YEAR_MAX,
            value = c(YEAR_MIN, YEAR_MAX),
            sep = "", step = 1
          ),

          actionButton("run_model", "Run Model",
            class = "btn-run",
            icon  = icon("play")
          )
        )
      ),
      column(9,
        div(class = "panel-box",
          h4("Coefficient Plot"),
          plotlyOutput("mod_coef_plot", height = "360px"),
          hr(),
          h4("Model Summary"),
          verbatimTextOutput("mod_summary"),
          hr(),
          h4("Coefficient Table"),
          DTOutput("mod_table")
        )
      )
    )
  ),

  nav_spacer(),
  nav_item(
    tags$a(
      icon("github"), " GitHub",
      href   = "https://github.com/lobsterbush/francisco-protest-dashboard",
      target = "_blank",
      class  = "nav-link"
    )
  )
)

## ── Server ───────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  ## ── Overview plots ──────────────────────────────────────────────────────────

  output$overview_timeline <- renderPlotly({
    p <- annual |>
      pivot_longer(c(protest_days, repression_days),
                   names_to = "type", values_to = "days") |>
      mutate(type = recode(type,
        protest_days    = "Protest days",
        repression_days = "Repression days"
      )) |>
      ggplot(aes(year, days, color = type)) +
      geom_line(linewidth = 1.1) +
      geom_point(size = 2) +
      scale_color_manual(values = c("Protest days" = PROTEST_COL,
                                     "Repression days" = REPRESSION_COL)) +
      scale_x_continuous(breaks = seq(1980, 1995, 2)) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Country-days", color = NULL) +
      base_theme() +
      theme(legend.position = "bottom")
    ggplotly(p, tooltip = c("x", "y", "colour")) |>
      layout(legend = list(orientation = "h", x = 0, y = -0.15))
  })

  output$overview_country_bar <- renderPlotly({
    p <- country_totals |>
      slice_head(n = 15) |>
      mutate(country = reorder(country, protest_days)) |>
      ggplot(aes(protest_days, country)) +
      geom_col(fill = PROTEST_COL, width = 0.7) +
      scale_x_continuous(labels = comma) +
      labs(x = "Protest days (1980–1995)", y = NULL) +
      base_theme()
    ggplotly(p, tooltip = c("x", "y")) |> config(displayModeBar = FALSE)
  })

  output$overview_actions <- renderPlotly({
    p <- actions |>
      slice_head(n = 15) |>
      mutate(action = reorder(action, n)) |>
      ggplot(aes(n, action)) +
      geom_col(fill = "#2980b9", width = 0.7) +
      scale_x_continuous(labels = comma) +
      labs(x = "Events", y = NULL) +
      base_theme()
    ggplotly(p, tooltip = c("x", "y")) |> config(displayModeBar = FALSE)
  })

  output$overview_issues <- renderPlotly({
    p <- issues |>
      slice_head(n = 15) |>
      mutate(issue = reorder(issue, n)) |>
      ggplot(aes(n, issue)) +
      geom_col(fill = "#27ae60", width = 0.7) +
      scale_x_continuous(labels = comma) +
      labs(x = "Events", y = NULL) +
      base_theme()
    ggplotly(p, tooltip = c("x", "y")) |> config(displayModeBar = FALSE)
  })

  ## ── Trends reactive data ─────────────────────────────────────────────────────

  trends_cy <- reactive({
    d <- cy |>
      filter(year >= input$trends_years[1], year <= input$trends_years[2])
    if (!("all" %in% input$trends_country) && length(input$trends_country) > 0) {
      d <- d |> filter(country %in% input$trends_country)
    }
    d
  })

  output$trends_ts <- renderPlotly({
    d    <- trends_cy()
    met  <- input$trends_metric
    ylab <- switch(met,
      protest_days    = "Protest days",
      repression_days = "Repression days",
      both_days       = "Days with both protest & repression",
      protest_rate    = "Protest rate (days / total)",
      repression_rate = "Repression rate (days / total)"
    )
    col_single <- switch(met,
      protest_days    = PROTEST_COL,
      repression_days = REPRESSION_COL,
      both_days       = BOTH_COL,
      protest_rate    = PROTEST_COL,
      repression_rate = REPRESSION_COL
    )

    n_countries <- length(unique(d$country))
    use_color   <- n_countries <= 12

    p <- d |>
      ggplot(aes(
        x     = year,
        y     = .data[[met]],
        group = country,
        color = if (use_color) country else NULL,
        text  = paste0(country, "\n", year, ": ", round(.data[[met]], 2))
      )) +
      geom_line(alpha = if (use_color) 0.9 else 0.35,
                linewidth = if (use_color) 0.9 else 0.5,
                color = if (!use_color) col_single else NULL) +
      scale_x_continuous(breaks = seq(1980, 1995, 2)) +
      scale_y_continuous(labels = if (grepl("rate", met)) percent_format(accuracy = 1) else comma) +
      labs(x = NULL, y = ylab, color = NULL) +
      base_theme() +
      theme(legend.position = if (use_color) "right" else "none")

    ggplotly(p, tooltip = "text") |>
      layout(legend = list(orientation = "v"))
  })

  output$trends_scatter <- renderPlotly({
    d <- trends_cy()
    p <- d |>
      ggplot(aes(protest_days, repression_days,
                 color = country,
                 text  = paste0(country, " (", year, ")\nProtest: ", protest_days, "\nRepression: ", repression_days))) +
      geom_point(alpha = 0.55, size = 2) +
      scale_x_continuous(labels = comma) +
      scale_y_continuous(labels = comma) +
      labs(x = "Protest days", y = "Repression days", color = NULL) +
      base_theme() +
      theme(legend.position = "none")
    ggplotly(p, tooltip = "text") |> config(displayModeBar = FALSE)
  })

  output$trends_bar <- renderPlotly({
    d <- trends_cy() |>
      group_by(country) |>
      summarise(protest_days = sum(protest_days),
                repression_days = sum(repression_days),
                .groups = "drop") |>
      pivot_longer(c(protest_days, repression_days),
                   names_to = "type", values_to = "days") |>
      mutate(type = recode(type,
        protest_days    = "Protest",
        repression_days = "Repression"
      ))
    p <- d |>
      ggplot(aes(reorder(country, days), days, fill = type)) +
      geom_col(position = "dodge", width = 0.7) +
      scale_fill_manual(values = c("Protest" = PROTEST_COL,
                                    "Repression" = REPRESSION_COL)) +
      scale_y_continuous(labels = comma) +
      coord_flip() +
      labs(x = NULL, y = "Days", fill = NULL) +
      base_theme() +
      theme(legend.position = "top")
    ggplotly(p, tooltip = c("x", "y", "fill")) |> config(displayModeBar = FALSE)
  })

  ## ── Events tab ──────────────────────────────────────────────────────────────

  events_filtered <- reactive({
    d <- events |>
      filter(year >= input$ev_years[1], year <= input$ev_years[2])
    if (!("all" %in% input$ev_country) && length(input$ev_country) > 0) {
      d <- d |> filter(country %in% input$ev_country)
    }
    if (isTRUE(input$ev_protest_only))    d <- d |> filter(n_protesters > 0)
    if (isTRUE(input$ev_repression_only)) d <- d |> filter(state_actors > 0)
    d
  })

  output$ev_row_count <- renderText({
    fmt_big(nrow(events_filtered()))
  })

  output$events_table <- renderDT({
    d <- events_filtered() |>
      select(
        Date       = date,
        Year       = year,
        Country    = country,
        Action     = action,
        Issue      = issue,
        Location   = location,
        Protesters = n_protesters,
        `State Actors` = state_actors,
        Arrested   = arrested,
        `P. Injured` = p_injured,
        `P. Killed` = p_killed,
        Description = event_text
      ) |>
      mutate(
        Protesters    = ifelse(Protesters == 0, NA_real_, Protesters),
        `State Actors`= ifelse(`State Actors` == 0, NA_real_, `State Actors`),
        Action = str_to_title(Action),
        Issue  = str_to_title(Issue)
      )

    datatable(
      d,
      rownames  = FALSE,
      filter    = "top",
      extensions = c("Buttons", "Scroller"),
      options   = list(
        dom        = "Bfrtip",
        buttons    = list("csv", "excel"),
        scrollY    = 500,
        scrollX    = TRUE,
        deferRender = TRUE,
        scroller   = TRUE,
        pageLength = 50,
        columnDefs = list(
          list(width = "250px", targets = 11)   # Description
        )
      ),
      class = "compact stripe hover"
    ) |>
      formatCurrency(c("Protesters", "State Actors"),
                     currency = "", digits = 0, mark = ",") |>
      formatStyle(
        "Protesters",
        background = styleColorBar(c(0, max(events$n_protesters, na.rm = TRUE)),
                                   "#fadbd8"),
        backgroundSize = "100% 90%",
        backgroundRepeat = "no-repeat",
        backgroundPosition = "center"
      )
  }, server = TRUE)

  ## ── Models tab ──────────────────────────────────────────────────────────────

  model_result <- eventReactive(input$run_model, {
    dv      <- input$mod_dv
    ivs     <- input$mod_ivs
    fe_vars <- input$mod_fe
    family  <- input$mod_family

    if (length(ivs) == 0) {
      showNotification("Select at least one independent variable.", type = "warning")
      return(NULL)
    }

    # Filter data
    d <- cy_model |>
      filter(year >= input$mod_years[1], year <= input$mod_years[2])
    if (!("all" %in% input$mod_country) && length(input$mod_country) > 0) {
      d <- d |> filter(country %in% input$mod_country)
    }
    d <- d |> drop_na(all_of(c(dv, ivs)))

    if (nrow(d) < 10) {
      showNotification("Too few observations after filtering. Widen the scope.", type = "error")
      return(NULL)
    }

    # Build fixest formula
    fe_str  <- if (length(fe_vars) > 0) paste(fe_vars, collapse = " + ") else "0"
    rhs     <- paste(ivs, collapse = " + ")
    fml_str <- paste0(dv, " ~ ", rhs, " | ", fe_str)
    fml     <- as.formula(fml_str)

    fit <- tryCatch({
      if (family == "ols") {
        feols(fml, data = d, vcov = "hetero")
      } else if (family == "logit") {
        feglm(fml, data = d, family = "logit", vcov = "hetero")
      } else {
        feglm(fml, data = d, family = "poisson", vcov = "hetero")
      }
    }, error = function(e) {
      showNotification(paste("Model error:", e$message), type = "error")
      NULL
    })

    fit
  })

  output$mod_summary <- renderPrint({
    fit <- model_result()
    if (is.null(fit)) {
      cat("Run a model to see results here.\n")
    } else {
      summary(fit)
    }
  })

  output$mod_table <- renderDT({
    fit <- model_result()
    if (is.null(fit)) return(NULL)
    td <- tidy(fit, conf.int = TRUE) |>
      mutate(across(where(is.numeric), \(x) round(x, 4))) |>
      rename(
        Term       = term,
        Estimate   = estimate,
        `Std. Error` = std.error,
        Statistic  = statistic,
        `p-value`  = p.value,
        `CI Lower` = conf.low,
        `CI Upper` = conf.high
      )
    datatable(td, rownames = FALSE,
              options = list(dom = "t", pageLength = 20),
              class   = "compact stripe")
  }, server = FALSE)

  output$mod_coef_plot <- renderPlotly({
    fit <- model_result()
    if (is.null(fit)) {
      return(plotly_empty(type = "scatter") |>
               layout(title = "Run a model to see results"))
    }
    td <- tidy(fit, conf.int = TRUE) |>
      filter(!str_starts(term, "FE")) |>
      mutate(
        significant = p.value < 0.05,
        term        = str_replace_all(term, "_", " ") |> str_to_title()
      )

    p <- td |>
      ggplot(aes(
        x    = estimate,
        y    = reorder(term, estimate),
        xmin = conf.low,
        xmax = conf.high,
        color = significant,
        text  = paste0(term, "\nEst: ", round(estimate, 3),
                       "\n95% CI: [", round(conf.low, 3), ", ", round(conf.high, 3), "]",
                       "\np = ", round(p.value, 4))
      )) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "grey60", linewidth = 0.6) +
      geom_errorbarh(height = 0.25, linewidth = 0.7) +
      geom_point(size = 3) +
      scale_color_manual(
        values = c("TRUE" = PROTEST_COL, "FALSE" = "grey50"),
        labels = c("TRUE" = "p < 0.05", "FALSE" = "p ≥ 0.05"),
        name   = NULL
      ) +
      labs(x = "Coefficient estimate", y = NULL) +
      base_theme() +
      theme(legend.position = "bottom")

    ggplotly(p, tooltip = "text") |>
      layout(legend = list(orientation = "h", x = 0, y = -0.2))
  })
}

## ── Launch ───────────────────────────────────────────────────────────────────

shinyApp(ui, server)
