#' Fingertips data
#'
#' Outputs a data frame of data from
#' \href{https://fingertips.phe.org.uk/}{Fingertips}
#' @return A data frame of data extracted from the Fingertips API
#' @inheritParams indicators
#' @param IndicatorID Numeric vector, id of the indicator of interest
#' @param ProfileID Numeric vector, id of profiles of interest. Indicator
#'   polarity can vary between profiles therefore if using one of the comparison
#'   fields it is recommended to complete this field as well as IndicatorID. If
#'   IndicatorID is populated, ProfileID can be ignored or must be the same
#'   length as IndicatorID (but can contain NAs).
#' @param AreaCode Character vector, ONS area code of area of interest
#' @param ParentAreaTypeID Numeric vector, the comparator area type for the data
#'   extracted; if NULL the function will use the first record for the specified
#'   `AreaTypeID` from the area_types() function
#' @param AreaTypeID Numeric vector, the Fingertips ID for the area type;
#'   default is 102
#' @param categorytype TRUE or FALSE, determines whether the final table
#'   includes categorytype data where it exists. Default to FALSE
#' @param inequalities deprecated: TRUE or FALSE, same as categorytype
#' @param rank TRUE or FALSE, the rank of the area compared to other areas for
#'   that combination of indicator, sex, age, categorytype and category along
#'   with the indicator's polarity. 1 is lowest NAs will be bottom and ties will
#'   return the average position. The total count of areas with a non-NA value
#'   are returned also in AreaValuesCount
#' @param stringsAsFactors logical: should character vectors be converted to
#'   factors? The 'factory-fresh' default is TRUE, but this can be changed by
#'   setting options(stringsAsFactors = FALSE).
#' @examples
#' \dontrun{
#' # Returns data for the two selected domains at county and unitary authority geography
#' doms <- c(1000049,1938132983)
#' fingdata <- fingertips_data(DomainID = doms)#'
#'
#' # Returns data at local authority district geography for the indicator with the id 22401
#' fingdata <- fingertips_data(22401, AreaTypeID = 101)
#'
#' # Returns same indicator with different comparisons due to indicator polarity
#' # differences between profiles
#' # It is recommended to check the website to ensure consistency between your
#' # data extract here and the polarity required
#' fingdata <- fingertips_data(rep(90282,2), ProfileID = c(19,93), AreaCode = "E06000008")
#' fingdata <- fingdata[order(fingdata$TimeperiodSortable, fingdata$Sex),]}
#' @importFrom jsonlite fromJSON
#' @family data extract functions
#' @export

fingertips_data <- function(IndicatorID = NULL,
                            AreaCode = NULL,
                            DomainID = NULL,
                            ProfileID = NULL,
                            AreaTypeID = 102,
                            ParentAreaTypeID = NULL,
                            categorytype = FALSE,
                            inequalities,
                            rank = FALSE,
                            stringsAsFactors = default.stringsAsFactors()) {

        if (!missing(inequalities)) {
                warning("argument inequalities is deprecated; please use categorytype instead.",
                        call. = FALSE)
                categorytype <- inequalities
        }
        path <- "https://fingertips.phe.org.uk/api/"
        set_config(config(ssl_verifypeer = 0L))

        # ensure there are the correct inputs
        if (!is.null(IndicatorID)) {
                IndicatorIDs <- IndicatorID
                if (!is.null(DomainID)) {
                        warning("If IndicatorID is populated DomainID is ignored")
                }
                if (!is.null(ProfileID) & length(ProfileID) != length(IndicatorID)) {
                        stop("If ProfileID and IndicatorID are populated, they must be the same length")
                } else {
                        ProfileIDs <- ProfileID
                }
        } else {
                if (!is.null(DomainID)) {
                        DomainIDs <- DomainID
                        if (!is.null(ProfileID)) {
                                warning("DomainID is complete so ProfileID is ignored")
                        }
                } else {
                        if (!is.null(ProfileID)) {
                                ProfileIDs <- ProfileID
                        } else {
                                stop("One of IndicatorID, DomainID or ProfileID must have an input")
                        }
                }
        }

        if (!(categorytype == FALSE|categorytype == TRUE)){
                stop("categorytype input must be TRUE or FALSE")
        }

        # check on area details before calling data
        if (is.null(AreaTypeID)) {
                stop("AreaTypeID must have a value. Use function area_types() to see what values can be used.")
        } else {
                areaTypes <- area_types()
                if (sum(!(AreaTypeID %in% c(15, areaTypes$AreaTypeID))==TRUE)>0) {
                        stop("Invalid AreaTypeID. Use function area_types() to see what values can be used.")
                } else {
                        if (!is.null(AreaCode)) {
                                areacodes <- data.frame()
                                for (i in AreaTypeID) {
                                        areacodes <- rbind(paste0(path,
                                                                  "areas/by_area_type?area_type_id=",
                                                                  i) %>% GET %>% content("text") %>% fromJSON(),
                                                           areacodes)
                                }

                                if (sum(!(AreaCode %in% c("E92000001", areacodes$Code))==TRUE) > 0) {
                                        stop("Area code not contained AreaTypeID.")
                                }
                        }
                        ChildAreaTypeIDs <- AreaTypeID
                }
                if (is.null(ParentAreaTypeID)) {
                        areaTypes <- area_types(AreaTypeID = AreaTypeID) %>%
                                group_by(AreaTypeID) %>%
                                filter(row_number() == 1)
                        ParentAreaTypeIDs <- areaTypes$ParentAreaTypeID
                } else {
                        areaTypes <- areaTypes[areaTypes$AreaTypeID %in% ChildAreaTypeIDs,]
                        if (sum(!(ParentAreaTypeID %in% areaTypes$ParentAreaTypeID)==TRUE) > 0) {
                                warning("AreaTypeID not a child of ParentAreaTypeID. There may be duplicate values in data. Use function area_types() to see mappings of area type to parent area type.")
                        }
                        ParentAreaTypeIDs <- ParentAreaTypeID
                }
        }
        # this pulls the data from the API
        if (!is.null(IndicatorID)) {
                if (is.null(ProfileID)) {
                        fingertips_data <- retrieve_indicator(IndicatorIDs = IndicatorIDs,
                                                              ChildAreaTypeIDs = ChildAreaTypeIDs,
                                                              ParentAreaTypeIDs = ParentAreaTypeIDs)
                } else {
                        fingertips_data <- retrieve_indicator(IndicatorIDs = IndicatorIDs,
                                                              ProfileIDs = ProfileIDs,
                                                              ChildAreaTypeIDs = ChildAreaTypeIDs,
                                                              ParentAreaTypeIDs = ParentAreaTypeIDs)
                }
        } else {
                if (!is.null(DomainID)) {
                        fingertips_data <- retrieve_domain(ChildAreaTypeIDs = ChildAreaTypeIDs,
                                                           ParentAreaTypeIDs = ParentAreaTypeIDs,
                                                           DomainIDs = DomainIDs)
                } else {
                        if (!is.null(ProfileID)) {
                                fingertips_data <- retrieve_profile(ChildAreaTypeIDs = ChildAreaTypeIDs,
                                                                    ParentAreaTypeIDs = ParentAreaTypeIDs,
                                                                    ProfileIDs = ProfileIDs)
                        } else {
                                stop("One of IndicatorID, DomainID or ProfileID must have an input")
                        }
                }
        }
        names(fingertips_data) <- gsub("\\s","",names(fingertips_data))
        fingertips_data <- data.frame(fingertips_data)

        if (rank == TRUE) {
                inds <- unique(fingertips_data$IndicatorID)
                polarities <- indicator_metadata(inds) %>%
                        select(IndicatorID, Polarity)
                fingertips_data <- left_join(fingertips_data, polarities, by = c("IndicatorID" = "IndicatorID")) %>%
                        group_by(IndicatorID, Timeperiod, Sex, Age, CategoryType, Category, AreaType) %>%
                        mutate(Rank = rank(Value, na.last = "keep"),
                               AreaValuesCount = sum(!is.na(Value))) %>%
                        ungroup()

        }
        if (!is.null(AreaCode)) {
                fingertips_data <- fingertips_data[fingertips_data$AreaCode %in% AreaCode,] %>%
                        droplevels()
        }

        if (nrow(fingertips_data) > 0){
                fingertips_data[fingertips_data==""] <- NA
                if (categorytype == FALSE) {
                        fingertips_data <- filter(fingertips_data, is.na(CategoryType))
                }
        }
        if (stringsAsFactors == TRUE) {
                fingertips_data[sapply(fingertips_data, is.character)] <-
                        lapply(fingertips_data[sapply(fingertips_data, is.character)],
                               factor)
        }
        return(fingertips_data)
}
