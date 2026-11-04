# NOAA NCEI Global Marine Microplastics: Exploratory Analysis in R

An exploratory analysis of the [NOAA NCEI Global Marine Microplastics Harmonized Database](https://www.ncei.noaa.gov/products/microplastics) (NCEI Accession 0306475), covering 29,076 marine microplastic observations from April 1972 to April 2026.

## Data

- **Source:** NOAA NCEI Global Marine Microplastics Harmonized Database, verified against NCEI Accession 0306475
- **Snapshot:** `microplastics_ncei_2026.csv` (29,076 rows, 14 columns), database accessed October 2026
- **Fields:** date, latitude/longitude, ocean, region, country, medium (ocean water, beach, ocean sediment, nurdle surveys), sampling method, measurement, unit, concentration class, source reference

## Files

| File | Description |
|---|---|
| `mp_analysis.R` | Full exploratory analysis script (base R only, no packages needed) |
| `microplastics_ncei_2026.csv` | The dataset snapshot used in the analysis |
| `decade_trend_oceanwater.csv` | Median/mean concentration by decade (ocean water, pieces/m³) |
| `concentration_by_ocean.csv` | Concentration summary by ocean |
| `region_hotspots.csv` | Top regions by median concentration (n ≥ 100) |
| `chart1`–`chart4` (`.png`) | Charts: sampling effort, concentration trend, records by ocean, record mix 2015–2026 |

## How to run

Open the folder in RStudio, set the working directory to it (Session → Set Working Directory), and run `mp_analysis.R` top to bottom. The script uses base R only and rewrites the three summary CSVs in the same folder.

## Key findings

- **Sampling effort grew enormously:** from 45 records in the 1970s to over 10,000 per decade in the 2010s and 2020s.
- **Within the most method-comparable subset** (towed-net ocean-water samples), median concentration was flat from the 1970s through the 2000s (~0.002–0.004 pieces/m³) and rose to ~0.11 in the 2010s and ~0.18 in the 2020s. Part of this rise likely reflects improved detection as well as more plastic.
- **A data-justice gap:** 94% of records sit in the Northern Hemisphere; the Southern Hemisphere's share peaked at 13% in the 2010s and fell back below 2% in the 2020s. The Indian Ocean has 777 records and the entire Southern Ocean has 27.
- **Records are not the same as pollution:** after 2018 the database is dominated by a citizen-science nurdle survey program, so record counts after that year measure survey activity, not ocean conditions.
- This is **presence-only data**: an unrecorded sample does not mean a clean sea.

## Caveats

Concentrations are not directly comparable across sampling methods or units (`pieces/m³`, `pieces/10 mins`, `pieces kg⁻¹ d.w.`); trend analysis is restricted to towed-net ocean-water records. The rise in apparent concentration over time conflates real pollution trends with improvements in detection, mesh sizes, and research effort.
