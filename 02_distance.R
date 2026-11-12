# NOAA NCEI Global Marine Microplastics - main analysis
# Q1: concentration vs distance from coast (decay curve, by ocean)
# Q2: overlap with five subtropical gyres (higher or just sampled more?)
# Q3: seasonality of sampling effort and measured concentration

suppressMessages(library(maps))
suppressMessages(library(ggplot2))

dir <- "C:/Users/qanit/Documents/R Programming/microplastics"
d <- read.csv(file.path(dir, "microplastics_ncei_2026.csv"), stringsAsFactors = FALSE)
d$date <- as.Date(d$date)

## ---- subset: ocean water only (pieces/m3, comparable units) ----
w <- d[d$medium == "Ocean water", ]
cat("ocean-water rows:", nrow(w), "\n")
cat("\nocean x method (ocean-water subset):\n")
print(table(w$ocean, w$sampling_method))
cat("\nmedian lon/lat per ocean label:\n")
print(aggregate(cbind(longitude, latitude) ~ ocean, w, median))
cat("\nzero measurements:", sum(w$measurement == 0), "of", nrow(w), "\n")

## ---- distance from nearest coastline (haversine, chunked) ----
coast <- map("world", plot = FALSE)
cl <- cbind(coast$x, coast$y)  # polygon vertices, NAs separate polygons
cl <- cl[!is.na(cl[, 1]), ]
cl <- unique(round(cl, 4))   # dedupe vertices
cat("coastline vertices:", nrow(cl), "\n")

hav <- function(lat1, lon1, lat2, lon2) {
  rad <- pi / 180
  p1 <- lat1 * rad; p2 <- lat2 * rad
  dp <- (lat2 - lat1) * rad; dl <- (lon2 - lon1) * rad
  a <- sin(dp / 2)^2 + cos(p1) * cos(p2) * sin(dl / 2)^2
  r <- 6371 * 2 * asin(pmin(1, sqrt(a)))
  matrix(r, nrow = length(lat1))  # rebuild dims (pmin drops them)
}

dist_coast <- rep(Inf, nrow(w))
lat <- w$latitude; lon <- w$longitude
pchunk <- 1000; cchunk <- 4000
for (i in seq(1, nrow(w), by = pchunk)) {
  idx <- i:min(i + pchunk - 1, nrow(w))
  for (j in seq(1, nrow(cl), by = cchunk)) {
    jdx <- j:min(j + cchunk - 1, nrow(cl))
    dm <- hav(lat[idx], lon[idx],
              matrix(rep(cl[jdx, 2], each = length(idx)), ncol = length(jdx)),
              matrix(rep(cl[jdx, 1], each = length(idx)), ncol = length(jdx)))
    dist_coast[idx] <- pmin(dist_coast[idx], apply(dm, 1, min))
  }
}
w$dist_coast_km <- dist_coast
cat("distance summary (km):\n")
print(summary(w$dist_coast_km))
saveRDS(w, file.path(dir, "ocean_water.rds"))
cat("saved ocean_water.rds\n")
