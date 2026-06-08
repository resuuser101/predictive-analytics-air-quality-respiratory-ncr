# =====================================================================
# PURELY API-BASED LIVE & HISTORICAL NCR MONITORING DASHBOARD (SHINY)
# =====================================================================

library(shiny)
library(bslib)
library(fontawesome)
library(leaflet)
library(httr)
library(jsonlite)
library(tidyverse)
library(plotly)

format_timestamp <- function(x) {
  format(
    as.POSIXct(x, tz = "Asia/Manila"),
    "%b %d, %Y %I:%M:%S %p"
  )
}

# =====================================================================
# 1. BASE CONFIGURATION & GEOGRAPHY COORDINATES
# =====================================================================

API_KEY <- "41dd8dc4fcce362b374b9807aa39f964"

ncr_cities <- data.frame(
  City = c(
    "Manila", "Quezon City", "Caloocan", "Las Piñas", "Makati",
    "Malabon", "Mandaluyong", "Marikina", "Muntinlupa", "Navotas",
    "Parañaque", "Pasay", "Pasig", "Pateros", "San Juan",
    "Taguig", "Valenzuela"
  ),
  Lat = c(
    14.5995, 14.6760, 14.6500, 14.4505, 14.5547,
    14.6625, 14.5794, 14.6299, 14.3888, 14.6678,
    14.4793, 14.5378, 14.5734, 14.5454, 14.6042,
    14.5176, 14.7011
  ),
  Lon = c(
    120.9842, 121.0437, 120.9822, 120.9828, 121.0244,
    120.9501, 121.0359, 121.1021, 121.0433, 120.9455,
    121.0069, 120.9993, 121.0586, 121.0687, 121.0315,
    121.0509, 120.9830
  )
)

# =====================================================================
# AQI & RESILIENCE HELPERS
# =====================================================================

get_aqi_properties <- function(aqi_val) {
  switch(
    as.character(round(aqi_val)),
    "1" = list(label = "Good", color = "#00E400"),
    "2" = list(label = "Fair", color = "#FFFF00"),
    "3" = list(label = "Moderate", color = "#FF7E00"),
    "4" = list(label = "Poor", color = "#FF0000"),
    "5" = list(label = "Very Poor", color = "#7E0023"),
    list(label = "Unknown", color = "#CCCCCC")
  )
}

get_risk_level <- function(pm25){
  case_when(
    pm25 < 15 ~ "LOW",
    pm25 < 35 ~ "MODERATE",
    pm25 < 55 ~ "HIGH",
    TRUE ~ "CRITICAL"
  )
}

generate_recommendation <- function(pm25, aqi){
  if(pm25 > 55){ return("Issue Health Advisory and Restrict Heavy Vehicles") }
  if(pm25 > 35){ return("Implement Traffic Reduction Measures") }
  if(aqi >= 4){ return("Alert Hospitals and Vulnerable Groups") }
  return("Routine Monitoring")
}

# =====================================================================
# LIVE & HISTORICAL API FETCHERS
# =====================================================================

fetch_live_data <- function(cities_df, api_key) {
  live_storage <- list()
  for (i in seq_len(nrow(cities_df))) {
    city <- cities_df$City[i]
    lat <- cities_df$Lat[i]
    lon <- cities_df$Lon[i]
    
    aqi_url <- paste0("http://api.openweathermap.org/data/2.5/air_pollution?lat=", lat, "&lon=", lon, "&appid=", api_key)
    weather_url <- paste0("https://api.open-meteo.com/v1/forecast?latitude=", lat, "&longitude=", lon, "&current=temperature_2m,relative_humidity_2m,wind_speed_10m&timezone=Asia%2FManila")
    
    aqi_resp <- tryCatch(GET(aqi_url, timeout(10)), error = function(e) NULL)
    weather_resp <- tryCatch(GET(weather_url, timeout(10)), error = function(e) NULL)
    
    if (!is.null(aqi_resp) && !is.null(weather_resp) && status_code(aqi_resp) == 200 && status_code(weather_resp) == 200) {
      aqi_json <- fromJSON(content(aqi_resp, as = "text", encoding = "UTF-8"))
      weather_json <- fromJSON(content(weather_resp, as = "text", encoding = "UTF-8"))
      
      live_storage[[city]] <- data.frame(
        Timestamp = as.POSIXct(aqi_json$list$dt, origin = "1970-01-01", tz = "Asia/Manila"),
        City = city, Lat = lat, Lon = lon,
        AQI = aqi_json$list$main$aqi,
        PM25 = aqi_json$list$components$pm2_5,
        NO2 = aqi_json$list$components$no2,
        O3 = aqi_json$list$components$o3,
        Temperature = weather_json$current$temperature_2m,
        Wind_Speed = weather_json$current$wind_speed_10m,
        Humidity = weather_json$current$relative_humidity_2m
      )
    }
    Sys.sleep(0.05)
  }
  if (length(live_storage) == 0) return(NULL)
  bind_rows(live_storage)
}

# Dynamic Historical Loader Engine
fetch_historical_api_data <- function(cities_df, api_key, days_back = 30) {
  hist_storage <- list()
  
  # Calculate Unix Epoch range boundaries dynamically
  end_time <- as.integer(Sys.time())
  start_time <- as.integer(Sys.time() - (days_back * 24 * 60 * 60))
  
  # Calculate matching string dates for open-meteo archive
  start_date_str <- format(Sys.Date() - days_back, "%Y-%m-%d")
  end_date_str <- format(Sys.Date() - 1, "%Y-%m-%d")
  
  for (i in seq_len(nrow(cities_df))) {
    city <- cities_df$City[i]
    lat <- cities_df$Lat[i]
    lon <- cities_df$Lon[i]
    
    # 1. Pull Historical Pollution Layer via OpenWeatherMap API
    poll_url <- paste0("http://api.openweathermap.org/data/2.5/air_pollution/history?lat=", lat, "&lon=", lon, "&start=", start_time, "&end=", end_time, "&appid=", api_key)
    poll_resp <- tryCatch(GET(poll_url, timeout(15)), error = function(e) NULL)
    
    # 2. Pull Matching Historical Meteorological Profile via Open-Meteo Archive API
    meteo_url <- paste0("https://archive-api.open-meteo.com/v1/archive?latitude=", lat, "&longitude=", lon, "&start_date=", start_date_str, "&end_date=", end_date_str, "&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m&timezone=Asia%2FManila")
    meteo_resp <- tryCatch(GET(meteo_url, timeout(15)), error = function(e) NULL)
    
    if (!is.null(poll_resp) && !is.null(meteo_resp) && status_code(poll_resp) == 200 && status_code(meteo_resp) == 200) {
      p_json <- fromJSON(content(poll_resp, as = "text", encoding = "UTF-8"))$list
      m_json <- fromJSON(content(meteo_resp, as = "text", encoding = "UTF-8"))$hourly
      
      if (length(p_json) > 0 && length(m_json$time) > 0) {
        # Format Pollution Component Arrays
        df_poll <- data.frame(
          Timestamp = as.POSIXct(p_json$dt, origin = "1970-01-01", tz = "Asia/Manila"),
          City = city,
          AQI = p_json$main$aqi,
          PM25 = p_json$components$pm2_5,
          NO2 = p_json$components$no2,
          O3 = p_json$components$o3
        ) %>% mutate(Join_Key = format(Timestamp, "%Y-%m-%d %H:00"))
        
        # Format Weather Matrices Component Arrays
        df_meteo <- data.frame(
          Timestamp = as.POSIXct(gsub("T", " ", m_json$time), tz = "Asia/Manila"),
          Temperature = m_json$temperature_2m,
          Wind_Speed = m_json$wind_speed_10m,
          Humidity = m_json$relative_humidity_2m
        ) %>% mutate(Join_Key = format(Timestamp, "%Y-%m-%d %H:00"))
        
        # Merge relational data profiles into reactive system memory
        city_merged <- inner_join(df_poll, df_meteo, by = "Join_Key") %>%
          select(Timestamp = Timestamp.x, City, AQI, PM25, NO2, O3, Temperature, Wind_Speed, Humidity)
        
        hist_storage[[city]] <- city_merged
      }
    }
    Sys.sleep(0.1) # Cooperative query buffering throttling
  }
  if (length(hist_storage) == 0) return(NULL)
  bind_rows(hist_storage)
}

# =====================================================================
# USER INTERFACE
# =====================================================================

ui <- page_sidebar(
  title = "NCR Live Environmental Air Quality Dashboard",
  theme = bs_theme(version = 5, bootswatch = "lux"),
  
  sidebar = sidebar(
    title = "Control Panel",
    passwordInput("api_key_input", "OpenWeatherMap API Key:", value = API_KEY),
    
    selectInput("metric_view", "Select Map Overlay Metric:",
                choices = c("Air Quality Index (AQI)" = "AQI", "PM2.5 (µg/m³)" = "PM25",
                            "Nitrogen Dioxide (NO2)" = "NO2", "Ozone (O3)" = "O3",
                            "Temperature (°C)" = "Temperature")),
    
    selectInput("hist_window", "Historical Analytics Range:",
                choices = c("Last 7 Days" = 7, "Last 14 Days" = 14, "Last 30 Days" = 30),
                selected = 14),
    
    selectInput("refresh_rate", "Auto Refresh Live Panel:",
                choices = c("Manual Only" = 0, "Every 1 Minute" = 60000, "Every 5 Minutes" = 300000),
                selected = 300000),
    
    actionButton("refresh_btn", "Force Sync Now", class = "btn-primary w-100 mt-2"),
    actionButton("fetch_hist_btn", "Fetch Historical API Data", class = "btn-success w-100 mt-2"),
    
    hr(),
    p("Data Sources: Pure API Connections (OpenWeatherMap & Open-Meteo)", style = "font-size:0.85rem;color:gray;")
  ),
  
  layout_columns(
    value_box(title = "Regional Alert Status", value = textOutput("alert_status"), theme = "warning"),
    value_box(title = "Total Active Monitoring Cities", value = textOutput("box_total_cities"), theme = "primary"),
    value_box(title = "Average AQI Category", value = textOutput("box_avg_aqi"), theme = "success"),
    value_box(title = "Peak PM2.5 Recorded", value = textOutput("box_peak_pollution"), theme = "danger")
  ),
  
  navset_card_pill(
    nav_panel("Urban Intervention Center", tableOutput("intervention_table")),
    nav_panel("Pollution Hotspots (API-Sourced)", uiOutput("hotspot_view_manager")),
    nav_panel("Live Spatial Map Layer", leafletOutput("live_map", height = "650px")),
    nav_panel("Regional Analytics Summary Matrix", tableOutput("live_table_summary")),
    nav_panel("Historical Performance Trends",
              layout_sidebar(
                sidebar = sidebar(
                  selectInput("hist_city", "Target LGU Area:", choices = ncr_cities$City),
                  selectInput("hist_metric", "Analytical Target Parameter:", choices = c("AQI", "PM25", "NO2", "O3", "Temperature"))
                ),
                uiOutput("historical_plot_view_manager")
              )
    )
  )
)

# =====================================================================
# SERVER
# =====================================================================

server <- function(input, output, session) {
  
  # Reactive Trigger for Live Metrics
  live_trigger <- reactive({
    input$refresh_btn
    if (as.numeric(input$refresh_rate) > 0) {
      invalidateLater(as.numeric(input$refresh_rate), session)
    }
    Sys.time()
  })
  
  live_dataset <- reactive({
    live_trigger()
    key <- ifelse(input$api_key_input == "", API_KEY, input$api_key_input)
    withProgress(message = 'Syncing Live Ambient Channels Across NCR...', value = 0.5, {
      fetch_live_data(ncr_cities, key)
    })
  })
  
  # Re-Engineered Reactive Historical API Storage Loop
  historical_data <- reactive({
    input$fetch_hist_btn
    # Isolate variables to prevent premature reactivity trigger bugs
    isolate({
      key <- ifelse(input$api_key_input == "", API_KEY, input$api_key_input)
      days <- as.numeric(input$hist_window)
      
      withProgress(message = paste('Extracting Historical Log-Piles (', days, 'Days Range)...'), value = 0.2, {
        fetch_historical_api_data(ncr_cities, key, days_back = days)
      })
    })
  })
  
  # KPI Render Pipelines
  output$alert_status <- renderText({
    df <- live_dataset(); req(df)
    max_pm <- max(df$PM25, na.rm = TRUE)
    if(max_pm > 55){ "CRITICAL" } else if(max_pm > 35){ "HIGH RISK" } else if(max_pm > 15){ "MODERATE" } else { "NORMAL" }
  })
  
  output$box_total_cities <- renderText({ df <- live_dataset(); req(df); nrow(df) })
  
  output$box_avg_aqi <- renderText({
    df <- live_dataset(); req(df)
    avg_aqi <- round(mean(df$AQI, na.rm = TRUE))
    get_aqi_properties(avg_aqi)$label
  })
  
  output$box_peak_pollution <- renderText({
    df <- live_dataset(); req(df)
    paste0(round(max(df$PM25, na.rm = TRUE), 2), " µg/m³")
  })
  
  output$live_map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      setView(lng = 121.0437, lat = 14.5995, zoom = 11)
  })
  
  observe({
    df <- live_dataset(); req(df)
    metric_col <- input$metric_view
    vals <- df[[metric_col]]
    
    if (metric_col == "AQI") {
      colors_vec <- sapply(df$AQI, function(x) get_aqi_properties(x)$color)
      radius_vals <- df$AQI * 6 + 4
    } else {
      pal <- colorNumeric("YlOrRd", domain = vals)
      colors_vec <- pal(vals)
      radius_vals <- log(vals + 2) * 5 + 3
    }
    
    popup_templates <- paste0(
      "<h5><b>", df$City, "</b></h5>",
      "<b>AQI:</b> ", df$AQI, "<br>",
      "<b>PM2.5:</b> ", round(df$PM25, 2), "<br>",
      "<b>NO2:</b> ", round(df$NO2, 2), "<br>",
      "<b>O3:</b> ", round(df$O3, 2), "<br>",
      "<b>Temperature:</b> ", df$Temperature, " °C<br>",
      "<b>Humidity:</b> ", df$Humidity, "%<br>",
      "<b>Wind:</b> ", df$Wind_Speed, " km/h<br>",
      "<b>Risk Level:</b> ", sapply(df$PM25, get_risk_level), "<br>",
      "<b>Recommended Action:</b> ", mapply(generate_recommendation, df$PM25, df$AQI)
    )
    
    leafletProxy("live_map", data = df) %>%
      clearMarkers() %>% clearControls() %>%
      addCircleMarkers(lng = ~Lon, lat = ~Lat, radius = radius_vals, color = colors_vec,
                       fillColor = colors_vec, fillOpacity = 0.75, weight = 1, popup = popup_templates)
  })
  
  output$intervention_table <- renderTable({
    df <- live_dataset(); req(df)
    df %>%
      mutate(Risk_Level = sapply(PM25, get_risk_level),
             Recommendation = mapply(generate_recommendation, PM25, AQI)) %>%
      select(City, AQI, PM25, Risk_Level, Recommendation) %>%
      arrange(desc(PM25))
  })
  
  # Dynamic UI Render Management Elements (Prevents Null Crashes)
  output$hotspot_view_manager <- renderUI({
    if (input$fetch_hist_btn == 0) {
      return(h4("Please click the 'Fetch Historical API Data' button to pull historical timelines.", style="padding:20px; color:gray;"))
    }
    tableOutput("hotspot_table")
  })
  
  output$historical_plot_view_manager <- renderUI({
    if (input$fetch_hist_btn == 0) {
      return(h4("Please sync data from the cloud using the historical retrieval tool.", style="padding:20px; color:gray;"))
    }
    plotlyOutput("historical_trend_plot")
  })
  
  output$hotspot_table <- renderTable({
    df_hist <- historical_data(); req(df_hist)
    df_hist %>%
      group_by(City) %>%
      summarise(Average_PM2.5_ug_m3 = round(mean(PM25, na.rm = TRUE), 2),
                Average_AQI_Index = round(mean(AQI, na.rm = TRUE), 2)) %>%
      arrange(desc(Average_PM2.5_ug_m3))
  })
  
  output$live_table_summary <- renderTable({
    df <- live_dataset(); req(df)
    df %>%
      mutate(Timestamp = format_timestamp(Timestamp)) %>%
      select(City, Timestamp, AQI, PM25, NO2, O3, Temperature, Wind_Speed, Humidity) %>%
      arrange(desc(AQI), desc(PM25))
  })
  
  output$historical_trend_plot <- renderPlotly({
  df_hist <- historical_data(); req(df_hist)
  filtered_hist <- df_hist %>% filter(City == input$hist_city)
  req(nrow(filtered_hist) > 0)
  
  # 1. Create a clean, human-readable string for the hover tooltips
  filtered_hist <- filtered_hist %>% 
    mutate(Tooltip_Time = format_timestamp(Timestamp))
  
  # 2. Build the plot, adding the custom 'text' aesthetic for hover logic
  p <- ggplot(filtered_hist, aes(
    x = Timestamp, 
    y = .data[[input$hist_metric]],
    text = paste0("Time: ", Tooltip_Time, "<br>", input$hist_metric, ": ", round(.data[[input$hist_metric]], 2))
  )) +
    geom_line(alpha = 0.4, color = "#2C3E50", aes(group = 1)) +
    # We add 'aes(group = 1)' to geom_smooth so it shares the global hover text context gracefully
    geom_smooth(method = "loess", se = FALSE, color = "#E74C3C", size = 1, aes(group = 1)) +
    labs(x = "Timeline Target Interval", y = paste("Observed Value:", input$hist_metric)) +
    theme_minimal()
  
  # 3. Convert to plotly and specify that ONLY our custom 'text' should be shown in the tooltip
  ggplotly(p, tooltip = "text") %>% 
    layout(
      xaxis = list(
        type = "date",
        tickformat = "%b %d, %Y\n%I:%M %p"
      )
    )
})
}

# =====================================================================
# RUN APPLICATION ENVIRONMENT LAYER
# =====================================================================

shinyApp(ui = ui, server = server)