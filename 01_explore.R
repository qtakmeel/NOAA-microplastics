# Exploration of NOAA NCEI Global Marine Microplastics dataset
d <- read.csv("C:/Users/qanit/Documents/R Programming/microplastics/microplastics_ncei_2026.csv",
              stringsAsFactors = FALSE)
cat("rows:", nrow(d), "\n")
cat("units:", paste(unique(d$unit), collapse = " | "), "\n")
cat("measurement NA:", sum(is.na(d$measurement)), "\n")
cat("classes:", paste(names(table(d$concentration_class)),
                      table(d$concentration_class), sep = "=", collapse = " "), "\n")
cat("mediums:", paste(names(table(d$medium)), table(d$medium),
                      sep = "=", collapse = " | "), "\n")
cat("oceans:\n")
print(table(d$ocean))
cat("methods:\n")
print(sort(table(d$sampling_method), decreasing = TRUE)[1:10])
cat("years:", min(d$year), "-", max(d$year), "\n")
cat("date empty:", sum(is.na(d$date) | d$date == ""), "\n")
cat("lat range:", range(d$latitude), " lon range:", range(d$longitude), "\n")
cat("measurement summary:\n")
print(summary(d$measurement))
