# Predictive Analytics for Air Quality and Respiratory Health Risk Assessment in Philippine Urban Communities (NCR)

This repository contains the complete data analytics pipeline, research documentation, and interactive web application for **ITE 030 - Data Analytics** at the **Technological Institute of the Philippines (Quezon City)**.

The project features a **Purely API-Based Live & Historical Monitoring Dashboard** built using R Shiny to address spatial-temporal air degradation and public health vulnerabilities across the 17 Local Government Units (LGUs) in Metro Manila.

---

##  Authors (Group Members)
* **Leader:** Olediana, John Michael M.
* **Member:** Celso, Paula Alexandra C.
* **Member:** Domingo, Kyle Archie R.
* **Member:** Emia, Corazon G.
* **Member:** Sumayod, Lee Andre B.

* **Course Section:** IT33S4  
* **Instructor:** Ms. Nila D. Santiago  
* **Submission Date:** June 2026

---

##  Project Objectives & Student Outcomes
Designed in partial fulfillment of the academic requirements for data analytics pipelines:
1. **Develop predictive models** by applying advanced data analytics techniques and smoothing algorithms in R.
2. **Implement an end-to-end analytics pipeline** handling live data acquisition, restructuring, modeling, and interactive map visualization.
3. **Analyze a complex computing problem** (Student Outcome 1.1) to target localized public health exposure patterns.
4. **Apply principles of computing** (Student Outcome 1.2) to construct automated data pipelines and dashboard systems.

---

##  System Architecture & Dashboard Features
The application (`app.R`) bypasses traditional static datasets by programmatically weaving real-time metrics with historical reanalysis records across multiple API sources.

### Key Components:
* **Live Spatial Map Layer:** Uses `leaflet` to plot custom interactive markers mapping ambient criteria pollutants across the 17 administrative centers of NCR.
* **Dynamic Historical Loader Engine:** Pulls longitudinal arrays (7, 14, or 30 days back) using Unix Epoch boundaries to join criteria pollution elements with physical meteorological matrices.
* **Urban Intervention Center:** An automated recommendation system mapping live $PM_{2.5}$ densities to specific clinical/municipal triggers (e.g., *Alert Hospitals*, *Restrict Heavy Vehicles*).
* **Trend Analysis Matrix:** Generates an interactive `plotly` time-series visualization featuring LOESS smoothing regression lines to isolate seasonal transitions and weather correlations.

---

##  Data Source Details
The application establishes automated HTTP GET requests using `httr` and `jsonlite` to feed system memory without local data replication constraints:

| Data Layer | Primary Provider / Source Endpoint | Format / Resolution |
| :--- | :--- | :--- |
| **Criteria Atmospheric Pollutants** | **OpenWeatherMap Air Pollution API** <br> `api.openweathermap.org/data/2.5/air_pollution` | Live & Historical JSON arrays ($PM_{2.5}$, $NO_2$, $O_3$, $AQI$) |
| **Meteorological Matrices Profile** | **Open-Meteo Climate Archive API** <br> `archive-api.open-meteo.com/v1/archive` | Hourly scientific historical reanalysis data (Temperature, Wind Speed, Relative Humidity) |

---

##  How to Get Your Own OpenWeatherMap API Key

The live and historical air pollution features of this dashboard require a free access token (API Key) from OpenWeatherMap. Follow these steps to get your own:

1. **Create an Account:**
   * Go to the [OpenWeatherMap Registration Page](https://home.openweathermap.org/users/sign_up).
   * Fill out the form with your details, then create your account.

2. **Verify Your Email:**
   * Check your inbox for a confirmation email from OpenWeatherMap and click the verification link. *Note: Your API key will not activate until your email is verified.*

3. **Locate Your API Key:**
   * Log into your account on the OpenWeatherMap dashboard.
   * Click on your username in the top-right corner and select **"My API keys"** from the dropdown menu.
   * You will see a default key automatically generated for you. Copy this alphanumeric string.

4. **Activate Your Key:**
   * **Important:** New API keys can take anywhere from **1 to 2 hours** to be activated by OpenWeatherMap's infrastructure. If the dashboard shows a connection error initially, please allow some time for activation.

5. **Use it in the Dashboard:**
   * Run the `app.R` file in RStudio.
   * Paste your copied token into the **"OpenWeatherMap API Key:"** box inside the dashboard's left Control Panel sidebar.

---

##  Installation & Local Execution

To host or interact with this dashboard locally, ensure you have R or RStudio installed alongside the required package dependencies.

### 1. Clone the Repository
```bash
git clone [https://github.com/resuuser101/predictive-analytics-air-quality-respiratory-ncr.git](https://github.com/resuuser101/predictive-analytics-air-quality-respiratory-ncr.git)
cd predictive-analytics-air-quality-respiratory-ncr
