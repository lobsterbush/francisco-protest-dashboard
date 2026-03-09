# Francisco European Protest & Coercion Dashboard

**Author:** Charles Crabtree, Senior Lecturer, School of Social Sciences, Monash University and K-Club Professor, University College, Korea University.

A public interactive dashboard built in honor of Prof. Ron Francisco's pioneering work compiling the European Protest and Coercion Data — one of the most detailed daily-resolution datasets on political contention and state repression ever assembled.

## Overview

The dashboard provides four views of the data:

| Tab | Contents |
|-----|----------|
| **Overview** | Summary statistics, protest/repression timeline, top countries, action types, and issue categories |
| **Trends** | Country- and year-filter controls; per-country annual time series; scatter of protest vs. repression; comparative bar charts |
| **Events** | Searchable, sortable, and downloadable table of all ~88,000 coded events with date, country, action type, issue, location, and participant counts |
| **Models** | Point-and-click model builder: choose dependent variable, independent variables, fixed effects (country/year), estimator (OLS / logit / Poisson), and sample; returns coefficient plot, model summary, and tidy coefficient table |

## Data

- **Source:** Prof. Ron Francisco, University of Kansas — [ronfran.ku.edu/data](https://ronfran.ku.edu/data/index.html)
- **Coverage:** 29 European countries (including East/West Germany, Northern Ireland, and UK as separate units), 1980–1995, daily resolution
- **Raw records:** ~205,000 country-days; ~88,600 coded events

## Requirements

```r
install.packages(c(
  "shiny", "bslib", "dplyr", "tidyr", "ggplot2", "ggthemes",
  "plotly", "DT", "fixest", "broom", "scales", "stringr",
  "lubridate", "readr", "here", "purrr"
))
```

## Replication

1. Clone this repository.
2. Place the raw source data in `enhanced_cleaned_data/protest_coercion_enhanced_parsed.csv`  
   (download from [ronfran.ku.edu/data](https://ronfran.ku.edu/data/index.html) and run the cleaning pipeline in the original project, or request the pre-cleaned file).
3. From the project root, regenerate the dashboard data:
   ```r
   Rscript R/01_prep_data.R
   ```
4. Launch the app:
   ```r
   shiny::runApp()
   ```

## Deployment

**Live dashboard:** https://ndpn46-charles-crabtree.shinyapps.io/francisco-protest-coercion/

**Landing page (GitHub Pages):** https://lobsterbush.github.io/francisco-protest-dashboard/

To re-deploy:
```r
rsconnect::deployApp(account = "ndpn46-charles-crabtree", server = "shinyapps.io")
```

## License

Data is the work of Ron Francisco; see the original source for terms of use. Dashboard code is MIT licensed.
