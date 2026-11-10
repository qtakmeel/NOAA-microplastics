# NOAA NCEI Global Marine Microplastics - nation's GDP vs microplastics testing
# Companion script: measures "testing" as records per country in the NCEI
# harmonized database, downloads GDP and population from the World Bank API,
# and correlates wealth with sampling effort. Saves chart + table.
# Packages: base R + ggplot2 (+ maps already installed for earlier scripts)

mp <- read.csv("microplastics_ncei_2026.csv", stringsAsFactors = FALSE)

# --- 1. Records per country (the dataset's own country field) -----------------
mp$country <- trimws(mp$country)
mp$country[mp$country == ""] <- NA
recs <- na.omit(sort(table(mp$country), decreasing = TRUE))

# Harmonize dataset country names to World Bank spellings
wbmap <- c(
  "USA" = "United States", "United States" = "United States",
  "UK" = "United Kingdom", "United Kingdom" = "United Kingdom",
  "Russia" = "Russian Federation", "Vietnam" = "Viet Nam",
  "Iran" = "Iran, Islamic Rep.", "Egypt" = "Egypt, Arab Rep.",
  "South Korea" = "Korea, Rep.", "Korea" = "Korea, Rep.",
  "Venezuela" = "Venezuela, RB", "Turkey" = "Turkiye",
  "Czech Republic" = "Czechia", "Hong Kong" = "Hong Kong SAR, China",
  "Syria" = "Syrian Arab Republic", "Laos" = "Lao PDR",
  "North Korea" = "Korea, Dem. People's Rep.", "Slovakia" = "Slovak Republic",
  "Kyrgyzstan" = "Kyrgyz Republic", "Yemen" = "Yemen, Rep.",
  "Gambia" = "Gambia, The", "Cape Verde" = "Cabo Verde",
  "Bahamas" = "Bahamas, The", "Columbia" = "Colombia",
  "Guatamala" = "Guatemala", "Saudia Arabia" = "Saudi Arabia",
  "Trinidad" = "Trinidad and Tobago", "Cayman Island" = "Cayman Islands",
  "St Kitts and Nevis" = "St. Kitts and Nevis",
  "US Virgin Islands" = "Virgin Islands (U.S.)",
  "USA Virgin Islands" = "Virgin Islands (U.S.)",
  "Virgin Islands (British)" = "British Virgin Islands", "Reunion" = "Reunion"
)
names(recs) <- ifelse(names(recs) %in% names(wbmap), wbmap[names(recs)], names(recs))
recs <- tapply(recs, names(recs), sum)          # merge e.g. USA + United States
recs <- sort(recs, decreasing = TRUE)

cat("=== RECORDS PER COUNTRY (dataset country field) ===\n")
cat("countries:", length(recs), "  records with a country:", sum(recs), "\n")
print(head(recs, 15))

# --- 2. Download World Bank GDP, GDP per capita and population ----------------
fetch_wb <- function(ind) {
  url <- sprintf("https://api.worldbank.org/v2/en/indicator/%s?downloadformat=csv", ind)
  tmp <- file.path(tempdir(), paste0(ind, ".zip"))
  download.file(url, tmp, mode = "wb", quiet = TRUE)
  files <- unzip(tmp, exdir = tempdir())
  base <- basename(files)
  datafile <- files[grepl("^API_.*\\.csv$", base) & !grepl("Metadata", base)][1]
  raw <- read.csv(datafile, skip = 4, stringsAsFactors = FALSE)
  yr_cols <- grep("^X[0-9]{4}$", names(raw))
  long <- do.call(rbind, lapply(seq_along(yr_cols), function(j)
    data.frame(Country.Name = raw$Country.Name,
               year = as.integer(sub("^X", "", names(raw)[yr_cols[j]])),
               value = suppressWarnings(as.numeric(raw[[yr_cols[j]]])))))
  long <- long[!is.na(long$value) & long$value != "", ]
  latest <- tapply(seq_len(nrow(long)), long$Country.Name, function(i) i[which.max(long$year[i])])
  out <- long[unlist(latest), c("Country.Name", "year", "value")]
  names(out)[3] <- ind
  out
}

gdp   <- fetch_wb("NY.GDP.MKTP.CD")   # GDP, current US$
gdppc <- fetch_wb("NY.GDP.PCAP.CD")   # GDP per capita, current US$
pop   <- fetch_wb("SP.POP.TOTL")      # population

wb <- merge(gdp, gdppc, by = "Country.Name", suffixes = c("", ".pcap"))
wb <- merge(wb, pop, by = "Country.Name", suffixes = c("", ".pop"))
cat("\nWorld Bank countries with recent GDP:", nrow(wb), "\n")

# --- 3. Join testing effort to wealth -----------------------------------------
joined <- data.frame(country = names(recs), records = as.numeric(recs), stringsAsFactors = FALSE)
joined <- merge(joined, wb, by.x = "country", by.y = "Country.Name", all.x = TRUE)
joined$records_per_million <- joined$records / (joined$SP.POP.TOTL / 1e6)

unmatched <- joined[is.na(joined$NY.GDP.MKTP.CD), "country"]
cat("\nDataset countries not matched to World Bank (dropped from correlations):\n")
cat(paste(unmatched, collapse = ", "), "\n")

d <- na.omit(joined[, c("country", "records", "NY.GDP.MKTP.CD", "NY.GDP.PCAP.CD",
                        "SP.POP.TOTL", "records_per_million")])
cat("countries in correlation:", nrow(d), "\n")

# --- 4. Correlations ------------------------------------------------------------
cat("\n=== SPEARMAN CORRELATIONS ===\n")
c1 <- cor.test(log10(d$records), log10(d$NY.GDP.MKTP.CD), method = "spearman")
cat(sprintf("records vs total GDP:      rho = %.3f, p = %.2e\n", c1$estimate, c1$p.value))
c2 <- cor.test(log10(d$records), log10(d$NY.GDP.PCAP.CD), method = "spearman")
cat(sprintf("records vs GDP per capita: rho = %.3f, p = %.2e\n", c2$estimate, c2$p.value))
c3 <- cor.test(log10(d$records_per_million), log10(d$NY.GDP.PCAP.CD), method = "spearman")
cat(sprintf("records/million vs GDP per capita: rho = %.3f, p = %.2e\n", c3$estimate, c3$p.value))
d_noUS <- d[d$country != "United States", ]
c4 <- cor.test(log10(d_noUS$records), log10(d_noUS$NY.GDP.MKTP.CD), method = "spearman")
cat(sprintf("records vs total GDP, US excluded: rho = %.3f, p = %.2e\n", c4$estimate, c4$p.value))

# --- 5. Chart: wealth vs testing, log-log scatter -------------------------------
lab <- d[d$records >= 20 | d$NY.GDP.MKTP.CD > 1e12, ]
p <- ggplot2::ggplot(d, ggplot2::aes(x = NY.GDP.MKTP.CD, y = records)) +
  ggplot2::geom_point(size = 2.2, alpha = 0.75, color = "#08519c") +
  ggplot2::geom_text(data = lab, ggplot2::aes(label = country,
                     hjust = ifelse(country == "United States", 1.08, -0.08)),
                     size = 2.6, check_overlap = TRUE) +
  ggplot2::scale_x_log10(labels = function(v) paste0(v / 1e12, "T")) +
  ggplot2::scale_y_log10() +
  ggplot2::annotation_logticks(sides = "bl") +
  ggplot2::labs(
    title = "A nation's wealth predicts who measures the plastic",
    subtitle = "Microplastics records by country in the NCEI database vs GDP (World Bank, latest year)",
    x = "GDP, current US$ (log scale)",
    y = "Microplastics records in NCEI database (log scale)",
    caption = sprintf("Spearman rho = %.2f (n = %d countries; US excluded: rho = %.2f). Country field covers %.0f%% of records.",
                      c1$estimate, nrow(d), c4$estimate, 100 * sum(recs) / nrow(mp))
  ) +
  ggplot2::theme_minimal(base_size = 12)

ggplot2::ggsave("chart7_gdp_vs_records.png", p, width = 9, height = 6.5, dpi = 200)

# --- 6. Save the joined table ---------------------------------------------------
out <- joined[order(-joined$records), c("country", "records", "NY.GDP.MKTP.CD",
                                        "NY.GDP.PCAP.CD", "SP.POP.TOTL", "records_per_million")]
names(out) <- c("country", "records", "gdp_usd", "gdp_per_capita_usd", "population", "records_per_million")
write.csv(out, "gdp_testing.csv", row.names = FALSE, na = "")
cat("\nSaved: chart7_gdp_vs_records.png, gdp_testing.csv\n")
