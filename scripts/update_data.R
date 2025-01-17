# COVID-19 Canada Open Data Working Group Data Update Script #
# Author: Jean-Paul R. Soucy #

# Download and process updated COVID-19 Canada data files from Google Drive

# Note: This script assumes the working directory is set to the root directory of the project
# This is most easily achieved by using the provided Covid19Canada.Rproj in RStudio

# Authentication: You must authenticate your Google account before running the rest of the script.
# You may be asked to give "Tidyverse API Packages" read/write access to your Google account.

# authenticate your Google account before running the rest of the script
library(googledrive) # interface with Google Drive
library(googlesheets4) # read from Google Sheets
if (file.exists("email.txt")) {
  # automatically read account name from email.txt, if present
  drive_auth(readLines("email.txt"))
  gs4_auth(readLines("email.txt"))
} else {
  # otherwise, prompt for authentication
  drive_auth()
  gs4_auth()
}

# load libraries
library(dplyr) # data manipulation
library(tidyr) # data manipulation
library(lubridate) # better dates

# load functions
source("scripts/update_data_funs.R")

# update time: current date and time in America/Toronto time zone
update_time <- with_tz(Sys.time(), tzone = "America/Toronto") %>%
  format.Date("%Y-%m-%d %H:%M %Z")
update_date <- as.Date(update_time)
cat(paste0(update_time, "\n"), file = "update_time.txt") # write update_time

# list files in Google Drive data folder
files <- drive_ls("Provincial_List/Automation")

# download sheets and load data

## cases
cases_cum <- sheets_load(files, "ts", "cases_timeseries_hr") %>%
  pivot_longer(
    cols = c(-province, -health_region),
    names_to = "date_report",
    values_to = "cumulative_cases") %>%
    filter(!is.na(cumulative_cases))

## mortality
mortality_cum <- sheets_load(files, "ts", "mortality_timeseries_hr") %>%
  pivot_longer(
    cols = c(-province, -health_region),
    names_to = "date_death_report",
    values_to = "cumulative_deaths") %>%
  filter(!is.na(cumulative_deaths))

## recovered
recovered_cum <- sheets_load(files, "ts", "recovered_timeseries_prov") %>%
  pivot_longer(
    cols = c(-province),
    names_to = "date_recovered",
    values_to = "cumulative_recovered") %>%
  filter(!is.na(cumulative_recovered))

## testing
testing_cum <- sheets_load(files, "ts", "testing_timeseries_prov") %>%
  pivot_longer(
    cols = c(-province),
    names_to = "date_testing",
    values_to = "cumulative_testing") %>%
  filter(!is.na(cumulative_testing))

## dvaccine
vaccine_distribution_cum <- sheets_load(files, "ts", "vaccine_distribution_timeseries_prov") %>%
  pivot_longer(
    cols = c(-province),
    names_to = "date_vaccine_distributed",
    values_to = "cumulative_dvaccine") %>%
  filter(!is.na(cumulative_dvaccine))

## avaccine
vaccine_administration_cum <- sheets_load(files, "ts", "vaccine_administration_timeseries_prov") %>%
  pivot_longer(
    cols = c(-province),
    names_to = "date_vaccine_administered",
    values_to = "cumulative_avaccine") %>%
  filter(!is.na(cumulative_avaccine))

## cvaccine
vaccine_completion_cum <- sheets_load(files, "ts", "vaccine_completion_timeseries_prov") %>%
  pivot_longer(
    cols = c(-province),
    names_to = "date_vaccine_completed",
    values_to = "cumulative_cvaccine") %>%
  filter(!is.na(cumulative_cvaccine))

# combine with manual data

## cases
cases_man <- sheets_load(files, "ts_manual", "cases_timeseries_hr") %>%
  pivot_longer(
    cols = c(-province, -health_region),
    names_to = "date_report",
    values_to = "cumulative_cases") %>%
  filter(date_report != "18-06-2021") %>%
  filter(!is.na(cumulative_cases))
cases_cum <- bind_rows(cases_cum, cases_man)

## mortality
mortality_man <- sheets_load(files, "ts_manual", "mortality_timeseries_hr") %>%
  pivot_longer(
    cols = c(-province, -health_region),
    names_to = "date_death_report",
    values_to = "cumulative_deaths") %>%
  filter(date_death_report != "18-06-2021") %>%
  filter(!is.na(cumulative_deaths))
mortality_cum <- bind_rows(mortality_cum, mortality_man)

## cvaccine
vaccine_completion_man <- sheets_load(files, "ts_manual", "vaccine_completion_timeseries_prov") %>%
  pivot_longer(
    cols = c(-province),
    names_to = "date_vaccine_completed",
    values_to = "cumulative_cvaccine") %>%
  filter(date_vaccine_completed != "18-06-2021") %>%
  filter(!is.na(cumulative_cvaccine))
vaccine_completion_cum <- bind_rows(vaccine_completion_cum, vaccine_completion_man)

# convert dates to standard format for manipulation
convert_dates("cases_cum", "mortality_cum", "recovered_cum", "testing_cum", "vaccine_administration_cum", "vaccine_distribution_cum", "vaccine_completion_cum", date_format_out = "%Y-%m-%d")

# convert value columns to numeric
convert_values("cases_cum", "mortality_cum", "recovered_cum", "testing_cum", "vaccine_administration_cum", "vaccine_distribution_cum", "vaccine_completion_cum")

# combine data with old data

# load other files

## province names and short names
map_prov <- read.csv("other/prov_map.csv",
                     stringsAsFactors = FALSE)

## health regions
map_hr <- read.csv("other/hr_map.csv",
                   stringsAsFactors = FALSE)

# define parameters

## provinces and health regions
provs <- map_prov$province
hrs <- map_hr$health_region

## min dates
date_min_cases <- min(cases_cum$date_report)
date_min_mortality <- min(mortality_cum$date_death_report)
date_min_recovered <- min(recovered_cum$date_recovered)
date_min_testing <- min(testing_cum$date_testing)
date_min_vaccine_administration <- min(vaccine_administration_cum$date_vaccine_administered)
date_min_vaccine_distribution <- min(vaccine_distribution_cum$date_vaccine_distributed)
date_min_vaccine_completion <- min(vaccine_completion_cum$date_vaccine_completed)

# create time series

## cases time series
cases_ts_hr <- create_ts(cases_cum, "cases", "hr", date_min_cases)
cases_ts_prov <- create_ts(cases_cum, "cases", "prov", date_min_cases)
cases_ts_canada <- create_ts(cases_cum, "cases", "canada", date_min_cases)

## mortality time series
mortality_ts_hr <- create_ts(mortality_cum, "mortality", "hr", date_min_mortality)
mortality_ts_prov <- create_ts(mortality_cum, "mortality", "prov", date_min_mortality)
mortality_ts_canada <- create_ts(mortality_cum, "mortality", "canada", date_min_mortality)

## recovered time series
recovered_ts_prov <- create_ts(recovered_cum, "recovered", "prov", date_min_recovered)
recovered_ts_canada <- create_ts(recovered_cum, "recovered", "canada", date_min_recovered)

## testing time series
testing_ts_prov <- create_ts(testing_cum, "testing", "prov", date_min_testing)
testing_ts_canada <- create_ts(testing_cum, "testing", "canada", date_min_testing)

## add legacy "testing_info" column
testing_ts_prov <- testing_ts_prov %>%
  left_join(
    read.csv("https://raw.githubusercontent.com/ccodwg/Covid19Canada/master/timeseries_prov/testing_timeseries_prov.csv", stringsAsFactors = FALSE) %>%
      select(province, date_testing, testing_info) %>%
      mutate(date_testing = as.Date(date_testing, "%d-%m-%Y")),
    by = c("province", "date_testing")
  ) %>%
  replace_na(list(testing_info = ""))
testing_ts_canada <- testing_ts_canada %>%
  left_join(
    read.csv("https://raw.githubusercontent.com/ccodwg/Covid19Canada/master/timeseries_canada/testing_timeseries_canada.csv", stringsAsFactors = FALSE) %>%
      select(province, date_testing, testing_info) %>%
      mutate(date_testing = as.Date(date_testing, "%d-%m-%Y")),
    by = c("province", "date_testing")
  ) %>%
  replace_na(list(testing_info = ""))

## active cases time series
active_ts_prov <- create_ts_active(cases_ts_prov, recovered_ts_prov, mortality_ts_prov, "prov")
active_ts_canada <- create_ts_active(cases_ts_canada, recovered_ts_canada, mortality_ts_canada, "canada")

## vaccine administration time series
vaccine_administration_ts_prov <- create_ts(vaccine_administration_cum, "vaccine_administration", "prov", date_min_vaccine_administration)
vaccine_administration_ts_canada <- create_ts(vaccine_administration_cum, "vaccine_administration", "canada", date_min_vaccine_administration)

## vaccine distribution time series
vaccine_distribution_ts_prov <- create_ts(vaccine_distribution_cum, "vaccine_distribution", "prov", date_min_vaccine_distribution)
vaccine_distribution_ts_canada <- create_ts(vaccine_distribution_cum, "vaccine_distribution", "canada", date_min_vaccine_distribution)

## vaccine completion time series
vaccine_completion_ts_prov <- create_ts(vaccine_completion_cum, "vaccine_completion", "prov", date_min_vaccine_completion)
vaccine_completion_ts_canada <- create_ts(vaccine_completion_cum, "vaccine_completion", "canada", date_min_vaccine_completion)

# convert dates to non-standard date format for writing
convert_dates("cases_ts_canada", "mortality_ts_canada", "recovered_ts_canada", "testing_ts_canada", "active_ts_canada",
              "cases_ts_prov", "mortality_ts_prov", "recovered_ts_prov", "testing_ts_prov", "active_ts_prov",
              "cases_ts_hr", "mortality_ts_hr",
              "vaccine_administration_ts_prov", "vaccine_administration_ts_canada",
              "vaccine_distribution_ts_prov", "vaccine_distribution_ts_canada",
              "vaccine_completion_ts_prov", "vaccine_completion_ts_canada",
              date_format_out = "%d-%m-%Y")

# write time series files
write.csv(cases_ts_prov, "timeseries_prov/cases_timeseries_prov.csv", row.names = FALSE)
write.csv(cases_ts_hr, "timeseries_hr/cases_timeseries_hr.csv", row.names = FALSE)
write.csv(cases_ts_canada, "timeseries_canada/cases_timeseries_canada.csv", row.names = FALSE)
write.csv(mortality_ts_prov, "timeseries_prov/mortality_timeseries_prov.csv", row.names = FALSE)
write.csv(mortality_ts_hr, "timeseries_hr/mortality_timeseries_hr.csv", row.names = FALSE)
write.csv(mortality_ts_canada, "timeseries_canada/mortality_timeseries_canada.csv", row.names = FALSE)
write.csv(recovered_ts_prov, "timeseries_prov/recovered_timeseries_prov.csv", row.names = FALSE)
write.csv(recovered_ts_canada, "timeseries_canada/recovered_timeseries_canada.csv", row.names = FALSE)
write.csv(testing_ts_prov, "timeseries_prov/testing_timeseries_prov.csv", row.names = FALSE)
write.csv(testing_ts_canada, "timeseries_canada/testing_timeseries_canada.csv", row.names = FALSE)
write.csv(active_ts_prov, "timeseries_prov/active_timeseries_prov.csv", row.names = FALSE)
write.csv(active_ts_canada, "timeseries_canada/active_timeseries_canada.csv", row.names = FALSE)
write.csv(vaccine_administration_ts_prov, "timeseries_prov/vaccine_administration_timeseries_prov.csv", row.names = FALSE)
write.csv(vaccine_administration_ts_canada, "timeseries_canada/vaccine_administration_timeseries_canada.csv", row.names = FALSE)
write.csv(vaccine_distribution_ts_prov, "timeseries_prov/vaccine_distribution_timeseries_prov.csv", row.names = FALSE)
write.csv(vaccine_distribution_ts_canada, "timeseries_canada/vaccine_distribution_timeseries_canada.csv", row.names = FALSE)
write.csv(vaccine_completion_ts_prov, "timeseries_prov/vaccine_completion_timeseries_prov.csv", row.names = FALSE)
write.csv(vaccine_completion_ts_canada, "timeseries_canada/vaccine_completion_timeseries_canada.csv", row.names = FALSE)