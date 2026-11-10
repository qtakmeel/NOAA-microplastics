# NOAA NCEI Global Marine Microplastics - latitude banding & sampling density
# Companion to mp_analysis.R: bins records into 10-degree latitude bands and
# maps sampling density to show the equatorial and polar gaps visually.
# Packages: ggplot2, scales (base install), maps (installed for coastlines)

mp <- read.csv("microplastics_ncei_2026.csv", stringsAsFactors = FALSE)
mp$date <- as.Date(mp$date)

# --- 1. Bin into 10-degree latitude bands -------------------------------------
brks <- seq(-90, 90, by = 10)
band_labels <- paste0(head(brks, -1), " to ", tail(brks, -1))
mp$band <- cut(mp$latitude, breaks = brks, include.lowest = TRUE, labels = band_labels)

band_counts <- as.data.frame(table(band = mp$band))
names(band_counts)[2] <- "records"
band_counts$mid <- seq(-85, 85, by = 10)   # band midpoints for plotting

cat("=== RECORDS PER 10-DEGREE LATITUDE BAND ===\n")
print(band_counts[, c("band", "records")], right = FALSE)

cat("\nLatitude range in data:", min(mp$latitude), "to", max(mp$latitude), "\n")

# The gaps: bands with (almost) no records
gaps <- band_counts[band_counts$records < 50, ]
cat("\nBands with fewer than 50 records (the gaps):\n")
if (nrow(gaps) == 0) cat("  none\n") else print(gaps[, c("band", "records")], row.names = FALSE)

# Northern-hemisphere concentration by band, the data-justice angle
north_share <- sum(band_counts$records[band_counts$mid > 0]) / nrow(mp) * 100
cat(sprintf("\nShare of all records in the Northern Hemisphere: %.1f%%\n", north_share))
temp3560 <- sum(band_counts$records[band_counts$mid >= 25 & band_counts$mid <= 55])
cat(sprintf("Share in the 25-55N sampling belt (US/EU coasts, gyres): %.1f%%\n", temp3560 / nrow(mp) * 100))

# --- 2. Median concentration per band (ocean water, pieces/m3, n >= 20) -------
ow <- subset(mp, medium == "Ocean water" & unit == "pieces/m3")
conc <- aggregate(ow$measurement, by = list(band = ow$band), FUN = median)
names(conc)[2] <- "median_conc"
conc$n <- as.integer(table(ow$band)[conc$band])
conc <- conc[conc$n >= 20, ]
conc$mid <- match(conc$band, band_labels) * 10 - 85

cat("\n=== MEDIAN CONCENTRATION BY BAND (ocean water, pieces/m3, n>=20) ===\n")
print(conc[, c("band", "n", "median_conc")], row.names = FALSE, right = FALSE)

# --- 3. Chart: sampling density by latitude band ------------------------------
max_rec <- max(band_counts$records)
p1 <- ggplot2::ggplot(band_counts, ggplot2::aes(x = records, y = mid)) +
  ggplot2::geom_col(ggplot2::aes(fill = records), width = 10, orientation = "y") +
  ggplot2::scale_fill_viridis_c(option = "mako", direction = -1, guide = "none") +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "grey30") +
  ggplot2::annotate("text", x = max_rec * 0.72, y = 0, label = "equator",
                    hjust = -0.05, vjust = -1, size = 3, color = "grey30") +
  ggplot2::scale_y_continuous(breaks = seq(-80, 80, 20), limits = c(-90, 90)) +
  ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0, 0.06))) +
  ggplot2::labs(
    title = "Where the world has looked for microplastics",
    subtitle = "Records per 10-degree latitude band, NCEI harmonized database (n = 29,076)",
    x = "Records", y = "Latitude band midpoint (degrees)"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

# Overlay median concentration where measurable (scaled onto the same x-axis)
if (nrow(conc) > 0) {
  conc$scaled <- conc$median_conc / max(conc$median_conc) * max_rec
  p1 <- p1 +
    ggplot2::geom_point(data = conc, ggplot2::aes(x = scaled, y = mid),
                        shape = 21, fill = "white", color = "black", size = 2.2) +
    ggplot2::scale_x_continuous(
      expand = ggplot2::expansion(mult = c(0, 0.06)),
      sec.axis = ggplot2::sec_axis(
        ~ . / max_rec * max(conc$median_conc),
        name = "Median concentration, ocean water (pieces/m3)")
    ) +
    ggplot2::labs(caption = "White dots: median concentration (pieces/m3) in bands with n >= 20 ocean-water records")
}

ggplot2::ggsave("chart5_latitude_bands.png", p1, width = 8, height = 8, dpi = 200)

# --- 4. Chart: world map of sampling locations --------------------------------
p2 <- ggplot2::ggplot() +
  ggplot2::borders("world", colour = "grey75", fill = "grey93") +
  ggplot2::geom_point(data = mp, ggplot2::aes(x = longitude, y = latitude),
                      shape = 16, size = 0.55, alpha = 0.18, color = "#08519c") +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "grey30") +
  ggplot2::geom_hline(yintercept = c(-60, 60), linetype = "dotted", color = "grey55") +
  ggplot2::coord_cartesian(xlim = c(-180, 180), ylim = c(-85, 85)) +
  ggplot2::scale_y_continuous(breaks = seq(-80, 80, 20)) +
  ggplot2::labs(
    title = "Sampling density collapses at the equator and the poles",
    subtitle = "Every record in the NCEI harmonized microplastics database, 1971-2026",
    caption = "Blue dots: individual sampling records (29,076). Dashed line: equator. Dotted lines: 60N / 60S.",
    x = NULL, y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(panel.grid = ggplot2::element_blank())

ggplot2::ggsave("chart6_latitude_map.png", p2, width = 12, height = 6.5, dpi = 200)

# --- 5. Save the summary table -------------------------------------------------
write.csv(band_counts[, c("band", "mid", "records")], "latitude_bands.csv", row.names = FALSE)
cat("\nSaved: chart5_latitude_bands.png, chart6_latitude_map.png, latitude_bands.csv\n")
