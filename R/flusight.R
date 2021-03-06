#' Tools for working with FluSight forecasts
#'
#'These functions are used to convert an original FluSight-formatted csv file to \code{predx} data frame.
#'
#'Note that if point forecasts (optional in the FluSight challenge) are included but are NAs, they will be removed (NA is not allowed in the Point class).
#'
#' @param file A csv file formatted for the FluSight forecasting challenge.
#'
#' @return A \code{predx} data frame.
#'
#' @export
#' @importFrom magrittr '%>%'
#'
#' @examples
#' csv_tempfile <- tempfile('EW42-Hist-Avg-2018-10-29', fileext='.csv')
#' write.csv(flusightdemo, csv_tempfile, row.names=F)
#' import_flusight_csv(csv_tempfile)
#' @name flusight

#' @export
#' @rdname flusight
import_flusight_csv <- function(file) {
  team <- stringr::str_extract(file,
    "(?<=EW\\d{1,2}-).*(?=-\\d{4}-\\d{2}-\\d{2})")
  mmwr_week <- stringr::str_extract(file, "(?<=EW)\\d{1,2}")
  submission_date <- stringr::str_extract(file, "\\d{4}-\\d{2}-\\d{2}")
  read.csv(file, stringsAsFactors=F) %>%
    dplyr::mutate(
      team = team,
      mmwr_week = as.numeric(mmwr_week),
      submission_date = submission_date
    ) %>%
    prep_flusight() %>%
    import_csv()
}

#' @export
#' @rdname flusight
export_flusight_csv <- function(x, dir=NULL, overwrite=F) {
  team <- unique(x$team)
  mmwr_week <- unique(x$mmwr_week)
  submission_date <- unique(x$submission_date)
  if (length(team) != 1 | length(mmwr_week) != 1 | length(submission_date) != 1) {
    stop(paste('x contains more than one team, mmwr_week, or submission_date.',
      'These variables are not included in the FluSight template'))
  }
  forecast_name <- paste0('EW', mmwr_week, '_', team, '_', as.character(submission_date))
  x <- as.predx_df(x) %>%
    export_csv() %>%
    dplyr::mutate(
      type = ifelse(predx_class %in% c('BinLwr', 'BinCat'), 'Bin', NA),
      type = ifelse(predx_class == 'Point', 'Point', type),
      bin_start_incl = ifelse(unit == 'percent' & type == 'Bin',
          sprintf("%.1f", lwr), NA),
      bin_start_incl = ifelse(unit == 'week' & type == 'Bin',
          ifelse(cat == "none", "none", paste0(cat, ".0")), bin_start_incl),
      bin_end_notincl = ifelse(unit == 'percent' & type == 'Bin',
          sprintf("%.1f", lwr + 0.1), NA),
      bin_end_notincl = ifelse(unit == 'percent' & type == 'Bin' & lwr == 13,
          sprintf("%.1f", 100), bin_end_notincl),
      bin_end_notincl = ifelse(unit == 'week' & type == 'Bin',
        recode_flusight_bin_end_notincl(cat), bin_end_notincl),
      value = ifelse(predx_class %in% c('BinLwr', 'BinCat'), prob, NA),
      value = ifelse(predx_class %in% c('Point'), point, value)
      ) %>%
    dplyr::select(location, target, type, unit, bin_start_incl, bin_end_notincl, value)
  if (!is.null(dir)) {
    filename <- paste0(stringr::str_remove('dir', '/$'), '/', forecast_name, '.csv')
    if (!overwrite & file.exists(filename)) {
      stop(paste0('"', filename, '" already exists. Use "overwrite = T" to replace.'))
    } else {
      write.csv(x, filename, row.names = F)
    }
  } else {
    return(x)
  }
}

#' @export
#' @rdname flusight
to_flusight_pkg_format <- function(x) {
  mmwr_week <- as.numeric(x$mmwr_week[1])
  x <- export_flusight_csv(x) %>%
    dplyr::mutate(
      bin_start_incl = ifelse(stringr::str_detect(bin_start_incl, '^\\d+$'),
        paste0(bin_start_incl, '.0'), bin_start_incl),
      forecast_week = mmwr_week
    )
  return(x)
}

#' @rdname flusight
prep_flusight <- function(x) {
  names(x) <- tolower(names(x))
  # assign appropriate predx classes
  dplyr::mutate(x,
    predx_class = NA,
    predx_class = ifelse(type == 'Point',
      'Point', predx_class),
    predx_class = ifelse(type == 'Bin' &
      target %in% c('Season onset', 'Season peak week'),
      'BinCat', predx_class),
    predx_class = ifelse(type == 'Bin' &
      target %in% c('Season peak percentage',
      '1 wk ahead', '2 wk ahead', '3 wk ahead', '4 wk ahead'),
      'BinLwr', predx_class)
    ) %>%
  # create variables needed for each component
  dplyr::mutate(
    point = ifelse(predx_class == 'Point', value, NA),
    prob = ifelse(predx_class %in% c('BinCat', 'BinLwr'), value, NA),
    cat = ifelse(predx_class == 'BinCat', bin_start_incl, NA),
    lwr = ifelse(predx_class == 'BinLwr', bin_start_incl, NA)
    ) %>%
  # normalize probabilities where needed
  dplyr::group_by(location, target, predx_class) %>%
  dplyr::mutate(sum_prob = sum(prob)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(
    prob = ifelse(!is.na(prob) & 0.9 <= sum_prob & sum_prob <= 1.1,
      prob / sum_prob, prob)
    ) %>%
  dplyr::select(-sum_prob, -type, -bin_start_incl, -bin_end_notincl, -value) %>%
  dplyr::filter(!(predx_class == 'Point' & is.na(point)))
}

#' @export
#' @rdname flusight
flusight_ilinet_expected <- function() {
  list(
    list(
      target = c("Season peak percentage", "1 wk ahead", "2 wk ahead",
        "3 wk ahead", "4 wk ahead"),
      location = c("HHS Region 1", "HHS Region 10", "HHS Region 2", "HHS Region 3",
        "HHS Region 4", "HHS Region 5", "HHS Region 6", "HHS Region 7",
        "HHS Region 8", "HHS Region 9", "US National"),
      predx_class = "BinLwr",
      lwr = c(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2,
        1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2, 2.1, 2.2, 2.3, 2.4, 2.5,
        2.6, 2.7, 2.8, 2.9, 3, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8,
        3.9, 4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 5, 5.1,
        5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 6, 6.1, 6.2, 6.3, 6.4,
        6.5, 6.6, 6.7, 6.8, 6.9, 7, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7,
        7.8, 7.9, 8, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 9,
        9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 10, 10.1, 10.2,
        10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 11, 11.1, 11.2, 11.3,
        11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 12, 12.1, 12.2, 12.3, 12.4,
        12.5, 12.6, 12.7, 12.8, 12.9, 13)
    ),
    list(
      target = "Season peak week",
      location = c("HHS Region 1", "HHS Region 10", "HHS Region 2", "HHS Region 3",
        "HHS Region 4", "HHS Region 5", "HHS Region 6", "HHS Region 7",
        "HHS Region 8", "HHS Region 9", "US National"),
      predx_class = "BinCat",
      cat = c("40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
        "50", "51", "52", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20")
      ),
    list(
      target = "Season onset",
      location = c("HHS Region 1", "HHS Region 10", "HHS Region 2", "HHS Region 3",
        "HHS Region 4", "HHS Region 5", "HHS Region 6", "HHS Region 7",
        "HHS Region 8", "HHS Region 9", "US National"),
      predx_class = "BinCat",
      cat = c("40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
        "50", "51", "52", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20",
        "none")
      ),
    list(
      target = c("Season peak percentage", "1 wk ahead", "2 wk ahead",
        "3 wk ahead", "4 wk ahead", "Season onset", "Season peak week"),
      location = c("HHS Region 1", "HHS Region 10", "HHS Region 2", "HHS Region 3",
        "HHS Region 4", "HHS Region 5", "HHS Region 6", "HHS Region 7",
        "HHS Region 8", "HHS Region 9", "US National"),
      predx_class = "Point"
      )
  )
}

#' @export
#' @rdname flusight
flusight_state_ilinet_expected <- function() {
  list(
    list(
      target = c("Season peak percentage", "1 wk ahead", "2 wk ahead", "3 wk ahead", "4 wk ahead"),
      location = c("Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado",
          "Connecticut", "Delaware", "District of Columbia", "Georgia",
          "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky",
          "Louisiana", "Maine", "Maryland", "Massachusetts", "Michigan",
          "Minnesota", "Mississippi", "Missouri", "Montana", "Nebraska",
          "Nevada", "New Hampshire", "New Jersey", "New Mexico", "New York",
          "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon",
          "Pennsylvania", "Puerto Rico", "Rhode Island", "South Carolina",
          "South Dakota", "Tennessee", "Texas", "Utah", "Vermont", "Virgin Islands",
          "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
          ),
      predx_class = "BinLwr",
      lwr = c(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2,
        1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2, 2.1, 2.2, 2.3, 2.4, 2.5,
        2.6, 2.7, 2.8, 2.9, 3, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8,
        3.9, 4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 5, 5.1,
        5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 6, 6.1, 6.2, 6.3, 6.4,
        6.5, 6.6, 6.7, 6.8, 6.9, 7, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7,
        7.8, 7.9, 8, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 9,
        9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 10, 10.1, 10.2,
        10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 11, 11.1, 11.2, 11.3,
        11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 12, 12.1, 12.2, 12.3, 12.4,
        12.5, 12.6, 12.7, 12.8, 12.9, 13)
    ),
    list(
      target = c("Season peak week"),
      location = c("Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado",
          "Connecticut", "Delaware", "District of Columbia", "Georgia",
          "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky",
          "Louisiana", "Maine", "Maryland", "Massachusetts", "Michigan",
          "Minnesota", "Mississippi", "Missouri", "Montana", "Nebraska",
          "Nevada", "New Hampshire", "New Jersey", "New Mexico", "New York",
          "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon",
          "Pennsylvania", "Puerto Rico", "Rhode Island", "South Carolina",
          "South Dakota", "Tennessee", "Texas", "Utah", "Vermont", "Virgin Islands",
          "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
          ),
      predx_class = c("BinCat"),
      cat = c("40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
        "50", "51", "52", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20")
    ),
    list(
      target = c("Season peak percentage", "1 wk ahead", "2 wk ahead",
        "3 wk ahead", "4 wk ahead", "Season peak week"),
      location = c("Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado",
          "Connecticut", "Delaware", "District of Columbia", "Georgia",
          "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky",
          "Louisiana", "Maine", "Maryland", "Massachusetts", "Michigan",
          "Minnesota", "Mississippi", "Missouri", "Montana", "Nebraska",
          "Nevada", "New Hampshire", "New Jersey", "New Mexico", "New York",
          "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon",
          "Pennsylvania", "Puerto Rico", "Rhode Island", "South Carolina",
          "South Dakota", "Tennessee", "Texas", "Utah", "Vermont", "Virgin Islands",
          "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
          ),
      predx_class = "Point"
      )
  )
}

#' @export
#' @rdname flusight
flusight_hospitalization_expected <- function() {
  list(
    list(
      target = c("Season peak percentage", "1 wk ahead", "2 wk ahead", "3 wk ahead", "4 wk ahead"),
      location = c("Overall", "0-4 yr", "5-17 yr", "18-49 yr", "50-64 yr", "65+ yr"),
      predx_class = "BinLwr",
      lwr = c(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2,
        1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2, 2.1, 2.2, 2.3, 2.4, 2.5,
        2.6, 2.7, 2.8, 2.9, 3, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8,
        3.9, 4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 5, 5.1,
        5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 6, 6.1, 6.2, 6.3, 6.4,
        6.5, 6.6, 6.7, 6.8, 6.9, 7, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7,
        7.8, 7.9, 8, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 9,
        9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 10, 10.1, 10.2,
        10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 11, 11.1, 11.2, 11.3,
        11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 12, 12.1, 12.2, 12.3, 12.4,
        12.5, 12.6, 12.7, 12.8, 12.9, 13)
    ),
    list(
      target = c("Season peak week"),
      location = c("Overall", "0-4 yr", "5-17 yr", "18-49 yr", "50-64 yr", "65+ yr"),
      predx_class = "BinCat",
      cat = c("40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
        "50", "51", "52", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20")
    ),
    list(
      target = c("Season peak percentage", "1 wk ahead", "2 wk ahead", "3 wk ahead",
        "4 wk ahead", "Season peak week"),
      location = c("Overall", "0-4 yr", "5-17 yr", "18-49 yr", "50-64 yr", "65+ yr"),
      predx_class = "Point"
    )
  )
}

#' @rdname flusight
recode_flusight_bin_end_notincl <- function(x) {
  dplyr::recode(x,
    `40` = "41.0",
    `41` = "42.0",
    `42` = "43.0",
    `43` = "44.0",
    `44` = "45.0",
    `45` = "46.0",
    `46` = "47.0",
    `47` = "48.0",
    `48` = "49.0",
    `49` = "50.0",
    `50` = "51.0",
    `51` = "52.0",
    `52` = "53.0",
    `1` = "2.0",
    `2` = "3.0",
    `3` = "4.0",
    `4` = "5.0",
    `5` = "6.0",
    `6` = "7.0",
    `7` = "8.0",
    `8` = "9.0",
    `9` = "10.0",
    `10` = "11.0",
    `11` = "12.0",
    `12` = "13.0",
    `13` = "14.0",
    `14` = "15.0",
    `15` = "16.0",
    `16` = "17.0",
    `17` = "18.0",
    `18` = "19.0",
    `19` = "20.0",
    `20` = "21.0",
    none = "none"
  )
}

