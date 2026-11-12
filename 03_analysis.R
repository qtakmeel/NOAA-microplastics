# Analysis + plots: decay from coast, gyres, seasonality
suppressMessages(library(ggplot2))
if (!requireNamespace("gridExtra", quietly = TRUE)) install.packages("gridExtra", repos = "https://cloud.r-project.org")
suppressMessages(library(gridExtra))

dir <- "C:/Users/qanit/Documents/R Programming/microplastics"
w <- readRDS(file.path(dir, "ocean_water.rds"))
theme_set(theme_minimal(base_size = 13))
blue <- "#2C6E8F"; orange <- "#D1495B"; grey <- "#8A8A8A"

## ================= Q1: concentration vs distance from coast =================
w$conc <- w$measurement + 0.01   # offset so zeros survive logs

bins <- c(0, 10, 25, 50, 100, 200, 400, 800, 1600, Inf)
w$dist_bin <- cut(w$dist_coast_km, bins,
                  labels = c("0-10", "10-25", "25-50", "50-100",
                             "100-200", "200-400", "400-800", "800-1600", ">1600"))
agg <- data.frame(
  dist_bin = levels(w$dist_bin),
  median = as.numeric(tapply(w$measurement, w$dist_bin, median)),
  n = as.numeric(tapply(w$measurement, w$dist_bin, length))
)

cat("\n===== Q1: binned medians by distance from coast =====\n")
print(agg)

# near-shore decay fit (first 100 km only, where the curve is monotone)
fit_ns <- lm(log10(conc) ~ log10(dist_coast_km + 1), data = w[w$dist_coast_km <= 100, ])
cat("\nnear-shore (<=100 km) log-log fit: slope =", round(coef(fit_ns)[2], 3),
    " R2 =", round(summary(fit_ns)$r.squared, 3), "\n")

oceans_keep <- c("Atlantic Ocean", "Pacific Ocean", "Indian Ocean", "Arctic Ocean")
agg_o <- do.call(rbind, lapply(oceans_keep, function(o) {
  s <- w[w$ocean == o, ]
  data.frame(ocean = o,
             dist_bin = levels(w$dist_bin),
             median = as.numeric(tapply(s$measurement, s$dist_bin, median)),
             n = as.numeric(tapply(s$measurement, s$dist_bin, length)))
}))
agg_o <- agg_o[!is.na(agg_o$median), ]
cat("\nper-ocean binned medians:\n")
print(agg_o)

agg$dist_mid <- c(5, 17.5, 37.5, 75, 150, 300, 600, 1200, 3000)
agg_o <- agg_o[agg_o$n >= 20, ]   # drop unstable tiny bins (incl. the n=1 Indian point)
agg_o$dist_mid <- agg$dist_mid[match(agg_o$dist_bin, agg$dist_bin)]

p1 <- ggplot(agg, aes(dist_mid, median)) +
  geom_point(aes(size = n), color = "grey25", alpha = 0.9) +
  geom_line(data = agg_o, aes(dist_mid, median, color = ocean, group = ocean),
            linewidth = 0.9, alpha = 0.9) +
  annotate("text", x = 12, y = 0.085, label = "near-shore decay", size = 3.6, fontface = "italic") +
  annotate("text", x = 1200, y = 0.055, label = "gyre accumulation", size = 3.6, fontface = "italic") +
  scale_x_log10(breaks = c(1, 10, 100, 1000), labels = c("1", "10", "100", "1000")) +
  scale_y_log10(limits = c(0.003, 2.5),
                labels = function(x) format(x, scientific = FALSE)) +
  scale_color_manual(values = c(`Atlantic Ocean` = "#1B6CA8", `Pacific Ocean` = "#D1495B",
                                `Indian Ocean` = "#3F8F4F", `Arctic Ocean` = "#E8A33D")) +
  scale_size_continuous(range = c(2, 7), guide = "none") +
  labs(title = "Concentration falls near shore, then climbs again offshore",
       subtitle = "Ocean-water samples (pieces/m3). Points: all samples (sized by n). Lines: per-ocean medians",
       x = "Distance from nearest coastline (km, log scale)",
       y = "Median concentration (pieces/m3, log scale)", color = NULL) +
  theme(panel.grid.minor = element_blank())
ggsave(file.path(dir, "fig1_decay.png"), p1, width = 9, height = 5.6, dpi = 220)

## ================= Q2: subtropical gyres =================
gyres <- data.frame(
  name = c("North Pacific", "South Pacific", "North Atlantic", "South Atlantic", "Indian"),
  lat = c(30, -30, 30, -30, -30),
  lon = c(-140, -130, -40, -15, 80)
)
hav_pt <- function(lat1, lon1, lat2, lon2) {
  rad <- pi / 180
  a <- sin((lat2 - lat1) * rad / 2)^2 + cos(lat1 * rad) * cos(lat2 * rad) * sin((lon2 - lon1) * rad / 2)^2
  6371 * 2 * asin(pmin(1, sqrt(a)))
}
gyre_dist <- sapply(seq_len(nrow(gyres)), function(i) hav_pt(w$latitude, w$longitude, gyres$lat[i], gyres$lon[i]))
w$gyre <- apply(gyre_dist, 1, function(r) if (min(r) < 2500) gyres$name[which.min(r)] else "Outside")

cat("\n===== Q2: gyre comparison (radius 2500 km) =====\n")
gy <- data.frame(
  gyre = c(gyres$name, "Outside"),
  n = c(sapply(gyres$name, function(g) sum(w$gyre == g)), sum(w$gyre == "Outside")),
  median = c(sapply(gyres$name, function(g) median(w$measurement[w$gyre == g])),
             median(w$measurement[w$gyre == "Outside"]))
)
gy$pct_samples <- 100 * gy$n / sum(gy$n)
print(gy[order(gy$gyre), ])

for (g in gyres$name) {
  a <- w$measurement[w$gyre == g]; b <- w$measurement[w$gyre == "Outside"]
  p <- wilcox.test(a, b)$p.value
  cat(sprintf("%s: median in = %.3f, out = %.3f, ratio = %.1fx, Mann-Whitney p = %.2e, n_in = %d\n",
              g, median(a), median(b), median(a) / max(median(b), 1e-9), p, length(a)))
}

gy$label <- ifelse(gy$gyre == "Outside", "Outside gyres", gy$gyre)
out_med <- gy$median[gy$gyre == "Outside"]

p2a <- ggplot(gy, aes(median, reorder(label, median))) +
  geom_point(aes(color = gyre == "Outside"), size = 4.5) +
  geom_vline(xintercept = out_med, linetype = "dashed", color = grey) +
  geom_text(aes(label = sprintf("%.3f", median)), hjust = -0.7, size = 3.3) +
  scale_color_manual(values = c(`TRUE` = grey, `FALSE` = blue), guide = "none") +
  scale_x_log10(labels = function(x) format(x, scientific = FALSE),
                expand = expansion(mult = c(0.08, 0.18))) +
  labs(title = "Do the gyres really measure higher?",
       subtitle = "Median pieces/m3, 2500-km disks; dashed = outside median",
       x = "Median concentration (pieces/m3, log scale)", y = NULL) +
  theme(panel.grid.minor = element_blank())

eff <- data.frame(gyre = c(gyres$name, "Outside"),
                  pct = c(100 * sapply(gyres$name, function(g) mean(w$gyre == g)),
                          100 * mean(w$gyre == "Outside")))
eff$area <- c(rep(100 * pi * 2500^2 / 361e6, 5), 100 - 5 * pi * 2500^2 / 361e6)
eff$label <- ifelse(eff$gyre == "Outside", "Outside gyres", eff$gyre)
eff_long <- rbind(
  data.frame(label = eff$label, value = eff$pct, what = "share of samples"),
  data.frame(label = eff$label, value = eff$area, what = "share of ocean area")
)

p2b <- ggplot(eff_long, aes(value, reorder(label, value), color = what, shape = what)) +
  geom_point(size = 4) +
  geom_vline(xintercept = 5.4, linetype = "dashed", color = grey) +
  annotate("text", x = 5.4, y = 1.5, label = "5.4% = fair share", size = 3, color = grey, hjust = -0.05) +
  scale_color_manual(values = c("share of samples" = blue, "share of ocean area" = orange), name = NULL) +
  scale_shape_manual(values = c("share of samples" = 16, "share of ocean area" = 18), name = NULL) +
  scale_x_log10(labels = function(x) format(x, scientific = FALSE)) +
  labs(title = "...or do they just get sampled more?",
       subtitle = "Share of water samples vs share of ocean area",
       x = "Percent (log scale)", y = NULL) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom")

ggsave(file.path(dir, "fig2_gyres.png"), arrangeGrob(p2a, p2b, nrow = 1),
       width = 12, height = 5.6, dpi = 220)

## ================= Q3: seasonality =================
w$month <- as.integer(format(w$date, "%m"))
w$hemisphere <- ifelse(w$latitude >= 0, "North", "South")
# meteorological seasons, hemisphere-adjusted: DJF winter in the north
north_seas <- c("winter", "winter", "spring", "spring", "spring", "summer",
                "summer", "summer", "fall", "fall", "fall", "winter")
south_seas <- c("summer", "summer", "fall", "fall", "fall", "winter",
                "winter", "winter", "spring", "spring", "spring", "summer")
w$season <- ifelse(w$hemisphere == "North", north_seas[w$month], south_seas[w$month])

cat("\n===== Q3: seasonality =====\n")
cat("samples by month:\n")
print(table(w$month))
cat("\nsamples by season (hemisphere-adjusted):\n")
print(table(w$season))
cat("\nmedian concentration by season:\n")
print(aggregate(measurement ~ season, w, median))
kw <- kruskal.test(measurement ~ season, data = w)
cat("Kruskal-Wallis p =", format.pval(kw$p.value), "\n")

mp <- data.frame(month = 1:12,
                 n = as.integer(table(factor(w$month, levels = 1:12))))
mp$month_name <- month.name

p3a <- ggplot(mp, aes(reorder(month_name, -n), n)) +
  geom_col(fill = blue, width = 0.75) +
  labs(title = "When does sampling happen?",
       subtitle = "Ocean-water samples by calendar month (both hemispheres pooled)",
       x = NULL, y = "Number of samples") +
  theme(axis.text.x = element_text(angle = 40, hjust = 1, size = 10))

seas <- data.frame(
  season = c("winter", "spring", "summer", "fall"),
  median = sapply(c("winter", "spring", "summer", "fall"),
                  function(s) median(w$measurement[w$season == s])),
  n = sapply(c("winter", "spring", "summer", "fall"),
             function(s) sum(w$season == s))
)
seas$season <- factor(seas$season, levels = c("winter", "spring", "summer", "fall"))

p3b <- ggplot(seas, aes(season, median, fill = season)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.3f", median)), vjust = -0.4, size = 3.6) +
  scale_fill_manual(values = c(winter = "#5B8FB9", spring = "#7FB069",
                               summer = "#E8A33D", fall = "#C1663B")) +
  expand_limits(y = max(seas$median) * 1.12) +
  labs(title = "Does measured concentration vary by season?",
       subtitle = "Median pieces/m3, hemisphere-adjusted seasons",
       x = NULL, y = "Median concentration (pieces/m3)")

ggsave(file.path(dir, "fig3_season.png"), arrangeGrob(p3a, p3b, nrow = 1),
       width = 11, height = 5.2, dpi = 220)

cat("\nAll figures saved.\n")
