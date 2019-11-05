## ----setup, include = FALSE----------------------------------------------
knitr::opts_chunk$set(
  echo = TRUE,
  collapse = TRUE,
  comment = "#>",
  fig.height = 5,
  fig.width = 8,
  fig.align = "center",
  cache = FALSE
)
library(gravitas)
library(dplyr)
library(ggplot2)
library(tsibble)
library(lvplot)

## ----readdata------------------------------------------------------------
library(gravitas)
library(tibble)
glimpse(cricket)

## ----hierarchy2----------------------------------------------------------

hierarchy_model <- tibble::tibble(
  units = c("index", "over", "inning", "match"),
  convert_fct = c(1, 20, 2, 1))

knitr::kable(hierarchy_model, format = "markdown")


## ----crickread-----------------------------------------------------------
cricket_tsibble <- cricket %>%
  mutate(data_index = row_number()) %>%
  as_tsibble(index = data_index)

## ----cricex--------------------------------------------------------------
cricket_tsibble %>%
  filter(batting_team %in% c("Mumbai Indians",
                             "Chennai Super Kings"))%>%
  prob_plot("inning", "over",
  hierarchy_model,
  response = "runs_per_over",
  plot_type = "lv")

## ----exwicket------------------------------------------------------------
cricket_tsibble %>%
  gran_advice("wicket",
            "over",
            hierarchy_model)

## ----exdot---------------------------------------------------------------
cricket_tsibble %>%
  gran_advice("dot_balls",
            "over",
            hierarchy_model)

## ----exdotplot-----------------------------------------------------------
cricket_tsibble %>% 
  filter(dot_balls %in% c(0, 1, 2)) %>%
  prob_plot("dot_balls",
            "over",
            hierarchy_model,
            response = "runs_per_over",
            plot_type = "quantile",
            quantile_prob = c(0.1, 0.25, 0.5, 0.75, 0.9))



## ----exwicketplot--------------------------------------------------------
cricket_tsibble %>% 
  filter(wicket %in% c(0, 1)) %>%
  prob_plot("wicket",
            "over",
            hierarchy_model,
            response = "runs_per_over",
            plot_type = "quantile",
            quantile_prob = c(0.1, 0.25, 0.5, 0.75, 0.9))


