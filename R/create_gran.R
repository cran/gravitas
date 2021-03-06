#' Build dynamic temporal granularities
#'
#' Create time granularities that accommodate for periodicities in data, both single and multiple order up.
#' Periodic ones might include time granularities like minute of the day, hour
#'  of the week  and aperiodic calendar categorizations may include day of the month or
#' week of the quarter. For non-temporal data, supports
#' only periodic deconstructions.
#'
#' @param .data A tsibble object.
#' @param gran1 the granularity to be created. For temporal data, any
#' combination of "second", "minute", "qhour", "hhour", "hour", "day", "week", "fortnight
#' ,"month", "quarter", "semester" or "year" can be chosen in the form of finer
#'  to coarser unit. For example, for the granularity hour of the week, value is
#' "hour_week".
#' @param label Logical. TRUE will display the month as an ordered factor of
#' character string such as "January", "February". FALSE will display the month
#'  as an ordered factor such as 1 to 12, where 1 stands for January and 12 for
#' December.
#' @param abbr logical. FALSE will display abbreviated labels.
#' @param hierarchy_tbl A hierarchy table specifying the hierarchy of units
#' and their relationships.
#' @param ... Other arguments passed on to individual methods.
#' @return A tsibble with an additional column of granularity.
#
#' @examples
#'library(dplyr)
#'library(ggplot2)
#'library(lvplot)
#' # Search for granularities
#' smart_meter10 %>%
#'   search_gran(highest_unit = "week")
#'
#' # Screen harmonies from the search list
#'\dontrun{
#' smart_meter10 %>%
#'   harmony(
#'     ugran = "day",
#'     filter_in = "wknd_wday"
#'   )
#'}
#' # visualize probability distribution of
#' # the harmony pair (wknd_wday, hour_day)
#' smart_meter10 %>%
#' dplyr::filter(customer_id == "10017936") %>%
#'   prob_plot(
#'     gran1 = "wknd_wday",
#'     gran2 = "hour_day",
#'     response = "general_supply_kwh",
#'     plot_type = "quantile",
#'     quantile_prob = c(0.1, 0.25, 0.5, 0.75, 0.9)
#'   ) +
#'   scale_y_sqrt()
#'
#'#' # Compute granularities for non-temporal data
#'
#'library(tsibble)
#' cricket_tsibble <- cricket %>%
#' mutate(data_index = row_number()) %>%
#' as_tsibble(index = data_index)
#'
#' hierarchy_model <- tibble::tibble(
#'   units = c("index", "over", "inning", "match"),
#'   convert_fct = c(1, 20, 2, 1)
#' )
#' cricket_tsibble %>%
#'   create_gran(
#'     "over_inning",
#'     hierarchy_model
#'   )
#'
#'   cricket_tsibble %>%
#'   filter(batting_team %in% c("Mumbai Indians",
#'                              "Chennai Super Kings"))%>%
#'   prob_plot("inning", "over",
#'   hierarchy_model,
#'   response = "runs_per_over",
#'   plot_type = "lv")
#'
#' # Validate if given column in the data set
#' # equals computed granularity
#' validate_gran(cricket_tsibble,
#'   gran = "over_inning",
#'   hierarchy_tbl = hierarchy_model,
#'   validate_col = "over"
#' )
#' @export
create_gran <- function(.data, gran1 = NULL, hierarchy_tbl = NULL,
                        label = TRUE,
                        abbr = TRUE, ...) {

  # data must be tsibble
  if (!tsibble::is_tsibble(.data)) {
    stop("must use tsibble")
  }


  # gran1 must be provided


  if (is.null(gran1)) {
    stop("Provide the granularity that
         needs to be computed")
  }


  # column treated as granularities
  events <- match(gran1, names(.data))
  if (!is.na(events)) {
    .data[[gran1]] <- as.factor(.data[[gran1]])
    return(.data)
  }

  x <- .data[[rlang::as_string(tsibble::index(.data))]]

  if (!tsibble::is_tsibble(.data)) {
    stop("must use tsibble")
  }

  if (is.null(gran1)) {
    stop("gran1 must be supplied")
  }


  if (any(class(x) %in% c("POSIXct", "POSIXt", "yearmonth", "Date", "yearweek", "yearquarter"))) {
    temp_create_gran(.data, gran1, label,  ...)
  } else {
    if (is.null(hierarchy_tbl)) {
      stop("Hierarchy table must be provided
           when class of index of the tsibble
           is not date-time")
    }

    units <- hierarchy_tbl$units
    convert_fct <- hierarchy_tbl$convert_fct


    gran1_split <- stringr::str_split(gran1, "_", 2) %>% unlist()
    lgran <- gran1_split[1]
    ugran <- gran1_split[2]

    if (!(lgran %in% units)) {
      stop("lower part of granularity must be
           listed as an element in the hierarchy table")
    }
    if (!(ugran %in% units)) {
      stop("upper part of granularity must be
           listed as an element in the hierarchy table")
    }

    data_mutate <- .data %>% dplyr::mutate(L1 = dynamic_build_gran(
      x,
      lgran,
      ugran,
      hierarchy_tbl,
      ...
    ))


    data_mutate$L1 <- factor(data_mutate$L1)
    # names <- levels(data_mutate$L1)
    data_mutate %>%
      dplyr::mutate(
        !!gran1 := L1
      ) %>%
      dplyr::select(-L1)
  }
}


dynamic_build_gran <- function(x, lgran = NULL, ugran = NULL, hierarchy_tbl = NULL, ...) {
  if (dynamic_g_order(lgran, ugran, hierarchy_tbl) < 0) {
    stop("granularities should be of the form
         finer to coarser.
         Try swapping the order of the units.")
  }


  if (dynamic_g_order(lgran, ugran, hierarchy_tbl) == 0) {
    stop("Units should be distinct to form a granularity.")
  }


  if (any(class(x) %in% c("POSIXct", "POSIXt", "yearmonth", "Date", "yearweek", "yearquarter"))) {
    value <- build_gran(x, lgran = lgran, ugran = ugran, ...)
  }
  else {
    if (dynamic_g_order(lgran, ugran, hierarchy_tbl) == 1) {
      value <- create_single_gran(x, lgran, hierarchy_tbl)
    }
    else {
      lgran_ordr1 <- dynamic_g_order(lgran, hierarchy_tbl = hierarchy_tbl, order = 1)
      value <- dynamic_build_gran(x,
                                  lgran,
                                  ugran = lgran_ordr1,
                                  hierarchy_tbl
      ) +
        dynamic_gran_convert(
          lgran,
          lgran_ordr1,
          hierarchy_tbl
        ) *
        (dynamic_build_gran(
          x,
          lgran_ordr1,
          ugran,
          hierarchy_tbl
        ) - 1)
    }
  }
  return(value)
}


#' Validate created granularities with existing columns

#' @param .data A tsibble object.
#' @param gran the granularity to be created for validation.
#' @param hierarchy_tbl A hierarchy table.
#' @param validate_col A column in the data which acts as validator.
#' @param ... Other arguments passed on to individual methods.
#' @return A tsibble with an additional column of granularity.
#'
#' @examples
#' library(dplyr)
#' library(tsibble)
#' cricket_tsibble <- cricket %>%
#'   mutate(data_index = row_number()) %>%
#'   as_tsibble(index = data_index)
#'
#' hierarchy_model <- tibble::tibble(
#'   units = c("index", "ball", "over", "inning", "match"),
#'   convert_fct = c(1, 6, 20, 2, 1)
#' )
#' cricket_tsibble %>% validate_gran(
#'   gran = "over_inning",
#'   hierarchy_tbl = hierarchy_model,
#'   validate_col = "over"
#' )
#' @export
validate_gran <- function(.data,
                          gran = NULL,
                          hierarchy_tbl = NULL,
                          validate_col = NULL,
                          ...) {
  x <- .data[[rlang::as_string(tsibble::index(.data))]]

  gran_split <- stringr::str_split(gran, "_", 2) %>%
    unlist() %>%
    unique()
  lgran <- gran_split[1]
  ugran <- gran_split[2]

  all_gran <- search_gran(.data,
                          hierarchy_tbl = hierarchy_tbl
  )

  if (!(gran %in% all_gran)) # which granularity needs to be checked
  {
    stop("granularity to be validated needs
         to be one that can be formed from the hierarchy table.")
  }
  if (!(validate_col %in% names(.data))) # column of data which has the
    #granularity
  {
    stop("validate_col should be one of the
         columns of the data")
  }

  gran_data <- dynamic_build_gran(x, lgran, ugran, hierarchy_tbl)

  data_col <- .data[[validate_col]]

  if (all.equal(data_col, gran_data) == TRUE) {
    return(TRUE)
  } else {
    (FALSE)
  }
}


create_single_gran <- function(x,
                               lgran = NULL,
                               hierarchy_tbl = NULL,
                               ...) {
  units <- hierarchy_tbl$units
  convert_fct <- hierarchy_tbl$convert_fct

  if (any(class(x) %in% c("POSIXct", "POSIXt", "yearmonth", "Date", "yearweek", "yearquarter"))) {
    ugran <- g_order(lgran, order = 1)
    value <- build_gran(x,
                        lgran = lgran,
                        ugran = ugran,
                        ...
    )
  }
  else {
    ugran <- dynamic_g_order(lgran,
                             hierarchy_tbl = hierarchy_tbl,
                             order = 1
    )
    index_lower_gran <- match(lgran, units)
    if (all(is.na(index_lower_gran))) {
      stop("linear granularity to be created should be one of the units present in the hierarchy table.")
    }

    linear_gran <- ceiling(x / (dynamic_gran_convert(
      units[1],
      lgran,
      hierarchy_tbl
    )))

    denom <- dynamic_gran_convert(
      lgran,
      ugran,
      hierarchy_tbl
    )

    circular_gran <- dplyr::if_else(
      linear_gran %% denom == 0,
      denom,
      linear_gran %% denom
    )

    value <- circular_gran
  }
  return(value)
}
