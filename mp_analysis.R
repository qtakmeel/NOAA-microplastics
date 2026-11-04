# NOAA NCEI Global Marine Microplastics - exploratory analysis in R
# Data: NCEI Accession 0306475 harmonized database snapshot (29,076 rows, Oct 2026)
# Units differ by medium: analysis restricted to comparable subsets per question.

mp <- read.csv("microplastics_ncei_2026.csv", stringsAsFactors = FALSE)
mp$date <- as.Date(mp$date)
mp$decade <- cut(mp$year, breaks = c(1971, 1979, 1989, 1999, 2009, 2019, 2026),
                 labels = c("1970s", "1980s", "1990s", "2000s", "2010s", "2020s"))

cat("=== 1. DATASET OVERVIEW ===\n")
cat("Rows:", nrow(mp), "  Columns:", ncol(mp), "\n")
cat("Date range:", format(min(mp$date)), "to", format(max(mp$date)), "\n\n")

# --- Q: How has sampling effort evolved? (records = observations, not pollution) ---
cat("=== 2. RECORDS PER DECADE (sampling effort) ===\n")
print(table(mp$decade))

cat("\n=== 3. HEMISPHERIC SPLIT (data-justice angle) ===\n")
mp$hemi <- with(mp, ifelse(latitude > 0, "Northern", ifelse(latitude < 0, "Southern", "Equator")))
print(prop.table(table(mp$hemi)) * 100)
cat("\nBy decade, % Northern:\n")
print(round(prop.table(table(mp$decade, mp$hemi), margin = 1) * 100, 1))

cat("\n=== 4. RECORDS BY OCEAN ===\n")
print(table(mp$ocean, useNA = "ifany"))

cat("\n=== 5. RECORDS BY MEDIUM ===\n")
print(table(mp$medium))

# --- Comparable subset: ocean water, pieces/m3 ---
ow <- subset(mp, medium == "Ocean water" & unit == "pieces/m3")
cat("\nOcean-water pieces/m3 records:", nrow(ow), "\n")

cat("\n=== 6. TREND: median & mean concentration by decade (ocean water, pieces/m3) ===\n")
agg <- aggregate(ow$measurement, by = list(decade = ow$decade), FUN = function(x)
  c(median = median(x, na.rm = TRUE), mean = mean(x, na.rm = TRUE),
    n = length(x), p90 = quantile(x, 0.9, na.rm = TRUE)))
print(agg)

cat("\n=== 7. TREND by method group ===\n")
net.methods <- c("Neuston net", "Manta net", "AVANI net", "Bongo net", "Plankton net")
ow$method_grp <- with(ow, ifelse(sampling_method %in% net.methods, "Towed net",
                          ifelse(grepl("pump|intake", sampling_method, ignore.case = TRUE), "Pump/intake",
                          "Bottle/grab")))
agg2 <- aggregate(ow$measurement, by = list(decade = ow$decade, grp = ow$method_grp), FUN = function(x)
  c(median = median(x, na.rm = TRUE), n = length(x)))
print(agg2, right = FALSE)

cat("\n=== 8. CONCENTRATION BY OCEAN (ocean water, pieces/m3) ===\n")
agg3 <- aggregate(ow$measurement, by = list(ocean = ow$ocean), FUN = function(x)
  c(median = median(x, na.rm = TRUE), mean = mean(x, na.rm = TRUE), n = length(x)))
agg3 <- agg3[order(-agg3$x[, "median"]), ]
print(agg3)

cat("\n=== 9. HOTSPOTS: top regions by median concentration (n >= 100) ===\n")
ow_reg <- subset(ow, region != "")
reg <- aggregate(ow_reg$measurement, by = list(region = ow_reg$region), FUN = function(x)
  c(median = median(x, na.rm = TRUE), n = length(x)))
reg <- reg[reg$x[, "n"] >= 100, ]
reg <- reg[order(-reg$x[, "median"]), ]
print(head(reg, 12), right = FALSE)

cat("\n=== 10. NURDLE PATROL EFFECT on record mix (2015-2026, records/year by medium) ===\n")
recent <- subset(mp, year >= 2015)
print(table(recent$year, recent$medium))

cat("\n=== 11. CONCENTRATION CLASS DISTRIBUTION (all records) ===\n")
print(table(mp$concentration_class))

# --- Save tidy outputs ---
write.csv(agg, "decade_trend_oceanwater.csv", row.names = FALSE)
write.csv(agg3, "concentration_by_ocean.csv", row.names = FALSE)
write.csv(reg, "region_hotspots.csv", row.names = FALSE)
cat("\nSaved summary tables.\n")
