args <- commandArgs(trailingOnly = TRUE)

csv_path <- if (length(args) >= 1) args[[1]] else "benchmark/publication_runs.csv"
out_dir <- if (length(args) >= 2) args[[2]] else "benchmark/plots"
validation_path <- if (length(args) >= 3) args[[3]] else "benchmark/publication_validation.txt"
all_v_all_path <- if (length(args) >= 4) args[[4]] else "benchmark/all_v_all_summary.csv"
cache_metrics_path <- if (length(args) >= 5) args[[5]] else "benchmark/cache_profile_latest/metrics.tsv"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

numericize_cols <- function(frame, columns) {
  for (col in columns) {
    if (col %in% names(frame)) {
      frame[[col]] <- suppressWarnings(as.numeric(frame[[col]]))
    }
  }
  frame
}

fmt_num <- function(x, digits = 2) {
  format(round(x, digits), nsmall = digits, trim = TRUE)
}

fmt_pct <- function(x, digits = 1) {
  sprintf(paste0("%.", digits, "f%%"), x)
}

variant_levels <- c("old_release", "new_release", "standard", "batch_5", "batch_1")
variant_plot_labels <- c(
  old_release = "Old release\nno sketch",
  new_release = "Current release\nno sketch",
  standard = "Sketch query\nfull sketch",
  batch_5 = "Sketch query\nbatch=5",
  batch_1 = "Sketch query\nbatch=1"
)
variant_table_labels <- c(
  old_release = "Old release no sketch",
  new_release = "Current release no sketch",
  standard = "Sketch query full sketch",
  batch_5 = "Sketch query batch=5",
  batch_1 = "Sketch query batch=1"
)
variant_short_labels <- c(
  old_release = "Old no-sketch",
  new_release = "Current no-sketch",
  standard = "Full sketch",
  batch_5 = "Batch=5",
  batch_1 = "Batch=1"
)
variant_colors <- c(
  old_release = "#6B7280",
  new_release = "#1D4ED8",
  standard = "#059669",
  batch_5 = "#D97706",
  batch_1 = "#DC2626"
)
cache_colors <- c(
  old_half_nosketch = variant_colors[["old_release"]],
  new_half_nosketch = variant_colors[["new_release"]],
  new_half_sketch_query = variant_colors[["standard"]],
  new_half_sketch_build_perf = "#7C3AED"
)
cache_labels <- c(
  old_half_nosketch = "Old no-sketch",
  new_half_nosketch = "Current no-sketch",
  new_half_sketch_query = "Sketch query",
  new_half_sketch_build_perf = "Sketch build"
)
phase_colors <- c(
  db = "#D55E00",
  query = "#56B4E9",
  post = "#CC79A7",
  other = "#A7B3C0"
)

bg <- "#F4F7FB"
panel_bg <- "#FFFFFF"
panel_border <- "#D8E1EA"
grid_col <- "#E7EEF5"
text_primary <- "#1F2D3D"
text_muted <- "#607286"
good_col <- "#18864B"
bad_col <- "#C84C4C"
neutral_col <- "#4B5D6B"
warn_col <- "#C78A07"

df <- read.csv(csv_path, stringsAsFactors = FALSE, na.strings = c("NA", ""))
df <- numericize_cols(
  df,
  c(
    "replicate", "threads", "output_rows", "internal_db_phase_sec",
    "internal_query_map_sec", "internal_post_map_sec", "wall_sec",
    "user_cpu_sec", "system_cpu_sec", "cpu_percent", "max_rss_kb",
    "fs_inputs_blocks", "fs_outputs_blocks", "major_page_faults",
    "minor_page_faults", "voluntary_ctx_switches", "involuntary_ctx_switches"
  )
)
df$max_rss_gb <- df$max_rss_kb / (1024 * 1024)
df$total_cpu_sec <- df$user_cpu_sec + df$system_cpu_sec

all_v_all_df <- NULL
if (file.exists(all_v_all_path)) {
  all_v_all_df <- read.csv(all_v_all_path, stringsAsFactors = FALSE, na.strings = c("NA", ""))
  all_v_all_df <- numericize_cols(
    all_v_all_df,
    c("output_rows", "db_sec", "query_sec", "post_sec", "wall_sec", "user_cpu_sec", "system_cpu_sec", "cpu_percent", "max_rss_kb", "fs_in", "fs_out")
  )
  all_v_all_df$other_sec <- pmax(0, all_v_all_df$wall_sec - all_v_all_df$db_sec - all_v_all_df$query_sec - all_v_all_df$post_sec)
  all_v_all_df$max_rss_gb <- all_v_all_df$max_rss_kb / (1024 * 1024)
}

cache_df <- NULL
if (file.exists(cache_metrics_path)) {
  cache_df <- read.delim(cache_metrics_path, stringsAsFactors = FALSE, na.strings = c("NA", ""))
  cache_df <- numericize_cols(
    cache_df,
    c(
      "output_rows", "ref_phase_sec", "map_phase_sec", "post_phase_sec",
      "collect_minimizers_sec", "build_lookup_index_sec", "ipc",
      "cache_miss_rate", "branch_miss_rate", "llc_load_miss_rate",
      "llc_store_miss_rate", "l2_all_demand_miss_rate", "l2_demand_data_read_miss_rate"
    )
  )
}

summarise_group <- function(frame) {
  threads_mean <- mean(as.numeric(frame$threads))
  wall_mean <- mean(frame$wall_sec)
  total_cpu_mean <- mean(frame$total_cpu_sec)
  data.frame(
    scenario = frame$scenario[1],
    variant = frame$variant[1],
    label = variant_table_labels[[frame$variant[1]]],
    n = nrow(frame),
    output_rows = frame$output_rows[1],
    wall_mean = wall_mean,
    wall_sd = sd(frame$wall_sec),
    db_mean = mean(frame$internal_db_phase_sec),
    db_sd = sd(frame$internal_db_phase_sec),
    query_mean = mean(frame$internal_query_map_sec),
    query_sd = sd(frame$internal_query_map_sec),
    post_mean = mean(frame$internal_post_map_sec),
    post_sd = sd(frame$internal_post_map_sec),
    other_mean = mean(pmax(0, frame$wall_sec - frame$internal_db_phase_sec - frame$internal_query_map_sec - frame$internal_post_map_sec)),
    other_sd = sd(pmax(0, frame$wall_sec - frame$internal_db_phase_sec - frame$internal_query_map_sec - frame$internal_post_map_sec)),
    rss_mean_gb = mean(frame$max_rss_gb),
    rss_sd_gb = sd(frame$max_rss_gb),
    cpu_mean = mean(frame$cpu_percent),
    cpu_sd = sd(frame$cpu_percent),
    fs_in_mean = mean(frame$fs_inputs_blocks),
    fs_out_mean = mean(frame$fs_outputs_blocks),
    total_cpu_mean = total_cpu_mean,
    total_cpu_sd = sd(frame$total_cpu_sec),
    threads_mean = threads_mean,
    effective_cores_mean = total_cpu_mean / wall_mean,
    thread_util_mean = total_cpu_mean / wall_mean / threads_mean * 100
  )
}

summary_df <- do.call(
  rbind,
  lapply(split(df, interaction(df$scenario, df$variant, drop = TRUE)), summarise_group)
)
rownames(summary_df) <- NULL
summary_df$variant <- factor(summary_df$variant, levels = variant_levels)
summary_df <- summary_df[order(summary_df$variant), ]

get_summary <- function(variant_name) {
  summary_df[summary_df$variant == variant_name, ][1, ]
}

old_s <- get_summary("old_release")
new_s <- get_summary("new_release")
std_s <- get_summary("standard")
batch5_s <- get_summary("batch_5")
batch1_s <- get_summary("batch_1")

no_sketch_speedup_pct <- (old_s$wall_mean - new_s$wall_mean) / old_s$wall_mean * 100
query_speedup_pct <- (old_s$query_mean - new_s$query_mean) / old_s$query_mean * 100
ref_build_speedup_pct <- (old_s$db_mean - new_s$db_mean) / old_s$db_mean * 100
sketch_setup_speedup_x <- old_s$db_mean / std_s$db_mean
sketch_end_to_end_speedup_x <- old_s$wall_mean / std_s$wall_mean
batch5_rss_reduction_pct <- (old_s$rss_mean_gb - batch5_s$rss_mean_gb) / old_s$rss_mean_gb * 100
batch5_runtime_speedup_pct <- (old_s$wall_mean - batch5_s$wall_mean) / old_s$wall_mean * 100
batch1_rss_reduction_pct <- (old_s$rss_mean_gb - batch1_s$rss_mean_gb) / old_s$rss_mean_gb * 100
batch1_runtime_speedup_pct <- (old_s$wall_mean - batch1_s$wall_mean) / old_s$wall_mean * 100

validation_lines <- if (file.exists(validation_path)) readLines(validation_path, warn = FALSE) else character()
validation_all_match <- length(validation_lines) > 0 && all(grepl("MATCH$", validation_lines))

all_v_all_old <- NULL
all_v_all_build <- NULL
all_v_all_query <- NULL
all_v_all_total_speedup_x <- NA_real_
if (!is.null(all_v_all_df) && nrow(all_v_all_df) >= 3) {
  all_v_all_old <- all_v_all_df[1, ]
  all_v_all_build <- all_v_all_df[2, ]
  all_v_all_query <- all_v_all_df[3, ]
  all_v_all_total_speedup_x <- all_v_all_old$wall_sec / (all_v_all_build$wall_sec + all_v_all_query$wall_sec)
}

cache_lookup <- function(workload, column) {
  if (is.null(cache_df) || !(column %in% names(cache_df))) {
    return(NA_real_)
  }
  vals <- cache_df[cache_df$workload == workload, column]
  if (!length(vals)) {
    return(NA_real_)
  }
  vals[[1]]
}

compare_metric <- function(current, baseline, lower_is_better = TRUE, verb_better = "faster", verb_worse = "slower") {
  if (is.na(current) || is.na(baseline) || current <= 0 || baseline <= 0) {
    return(list(value = "N/A", accent = neutral_col, improved = NA))
  }
  improved <- if (lower_is_better) current < baseline else current > baseline
  ratio <- if (lower_is_better) {
    if (improved) baseline / current else current / baseline
  } else {
    if (improved) current / baseline else baseline / current
  }
  value <- sprintf("%.2fx %s", ratio, if (improved) verb_better else verb_worse)
  list(
    value = value,
    accent = if (improved) good_col else bad_col,
    improved = improved
  )
}

panel_box <- function() {
  plot.new()
  plot.window(xlim = c(0, 1), ylim = c(0, 1))
  rect(0, 0, 1, 1, col = panel_bg, border = panel_border, lwd = 2)
}

draw_card <- function(title, value, subtitle, accent) {
  par(mar = c(0.35, 0.35, 0.35, 0.35) + 0.1)
  panel_box()
  rect(0, 0.915, 1, 1, col = adjustcolor(accent, alpha.f = 0.14), border = NA)
  title_line <- gsub("\n+", "; ", title)
  subtitle_line <- gsub("\n+", "; ", subtitle)
  text(0.05, 0.83, title_line, adj = c(0, 1), cex = 0.98, font = 2, col = text_primary)
  text(0.05, 0.47, value, adj = c(0, 0.5), cex = 1.72, font = 2, col = accent)
  text(0.05, 0.18, subtitle_line, adj = c(0, 1), cex = 0.86, col = text_muted)
}

overlay_replicate_points <- function(x, values, color) {
  if (!length(values)) {
    return()
  }
  offsets <- seq(-0.12, 0.12, length.out = length(values))
  points(rep(x, length(values)) + offsets, values, pch = 21, cex = 1.0,
         bg = adjustcolor(color, alpha.f = 0.72), col = "#31424F", lwd = 0.8)
}

draw_stacked_runtime <- function(variants, title, subtitle) {
  sub <- summary_df[summary_df$variant %in% variants, ]
  sub <- sub[match(variants, as.character(sub$variant)), ]
  runtime_mat <- rbind(sub$db_mean, sub$query_mean, sub$post_mean, sub$other_mean)
  phase_labels <- c("DB/load", "Query", "Post", "Overhead")
  rownames(runtime_mat) <- phase_labels
  colnames(runtime_mat) <- unname(variant_plot_labels[variants])
  totals <- colSums(runtime_mat)
  ymax <- max(totals) * 1.28

  par(mar = c(6.8, 6, 4, 2) + 0.1)
  mids <- barplot(
    runtime_mat,
    beside = FALSE,
    col = phase_colors,
    border = NA,
    ylim = c(0, ymax),
    ylab = "Seconds",
    main = title,
    las = 1,
    cex.names = 1.00
  )
  abline(h = pretty(c(0, ymax)), col = grid_col, lwd = 1)
  mids <- barplot(
    runtime_mat,
    beside = FALSE,
    col = phase_colors,
    border = "#5E6B78",
    add = TRUE,
    axes = FALSE,
    axisnames = FALSE
  )

  for (i in seq_along(variants)) {
    vals <- df$wall_sec[df$variant == variants[i]]
    overlay_replicate_points(mids[i], vals, variant_colors[[variants[i]]])
  }

  text(mids, totals, labels = fmt_num(totals, 2), pos = 3, cex = 0.98, col = text_primary)
  legend(
    "topright",
    legend = phase_labels,
    fill = phase_colors,
    bty = "n",
    cex = 0.88,
    ncol = 2,
    x.intersp = 0.65,
    y.intersp = 1.0,
    inset = c(0.02, 0.01)
  )
  mtext(subtitle, side = 3, line = 0.4, cex = 0.98, col = text_muted)
  mtext(
    sprintf("Half-list workload: 1 query, 5,032 references, %d reported comparisons", std_s$output_rows),
    side = 1,
    line = 4.8,
    cex = 0.88,
    col = text_muted
  )
}

draw_memory_panel <- function() {
  variants <- c("old_release", "new_release", "standard", "batch_5", "batch_1")
  sub <- summary_df[match(variants, as.character(summary_df$variant)), ]
  vals <- sub$rss_mean_gb
  cols <- unname(variant_colors[variants])
  xmax <- max(vals) * 1.25
  labels <- c("Old no-sketch", "Current no-sketch", "Full sketch", "Batch=5", "Batch=1")

  par(mar = c(4.8, 10, 4, 2) + 0.1)
  mids <- barplot(
    vals,
    names.arg = labels,
    col = cols,
    border = NA,
    xlim = c(0, xmax),
    xlab = "Peak RSS (GiB)",
    main = "Peak Memory",
    las = 1,
    cex.names = 0.90,
    horiz = TRUE
  )
  abline(v = pretty(c(0, xmax)), col = grid_col, lwd = 1)
  mids <- barplot(
    vals,
    names.arg = labels,
    col = cols,
    border = "#5E6B78",
    add = TRUE,
    axes = FALSE,
    axisnames = FALSE,
    horiz = TRUE
  )

  for (i in seq_along(variants)) {
    xvals <- df$max_rss_gb[df$variant == variants[i]]
    yvals <- rep(mids[i], length(xvals)) + seq(-0.10, 0.10, length.out = length(xvals))
    points(xvals, yvals, pch = 21, cex = 1.0,
           bg = adjustcolor(cols[i], alpha.f = 0.75), col = "#32404B", lwd = 0.8)
  }

  text(vals, mids, labels = fmt_num(vals, 2), pos = 4, cex = 0.92, col = text_primary)
  mtext("Bars show means; points show replicate RSS values", side = 3, line = 0.4, cex = 0.92, col = text_muted)
}

draw_relative_change_panel <- function() {
  labels <- c(
    "Current no-sketch wall",
    "Current no-sketch DB build",
    "Current no-sketch query",
    "Full-sketch wall",
    "Full-sketch RSS",
    "Batch=5 wall",
    "Batch=5 RSS",
    "Batch=1 wall",
    "Batch=1 RSS"
  )

  values <- c(
    new_s$wall_mean / old_s$wall_mean,
    new_s$db_mean / old_s$db_mean,
    new_s$query_mean / old_s$query_mean,
    std_s$wall_mean / old_s$wall_mean,
    std_s$rss_mean_gb / old_s$rss_mean_gb,
    batch5_s$wall_mean / old_s$wall_mean,
    batch5_s$rss_mean_gb / old_s$rss_mean_gb,
    batch1_s$wall_mean / old_s$wall_mean,
    batch1_s$rss_mean_gb / old_s$rss_mean_gb
  )

  cols <- c(
    variant_colors[["new_release"]],
    variant_colors[["new_release"]],
    variant_colors[["new_release"]],
    variant_colors[["standard"]],
    variant_colors[["standard"]],
    variant_colors[["batch_5"]],
    variant_colors[["batch_5"]],
    variant_colors[["batch_1"]],
    variant_colors[["batch_1"]]
  )

  y <- rev(seq_along(labels))
  xmax <- max(values) * 1.15

  par(mar = c(5.2, 13, 4, 2) + 0.1)
  plot(
    NA,
    xlim = c(0, xmax),
    ylim = c(0.5, length(labels) + 0.5),
    yaxt = "n",
    ylab = "",
    xlab = "Relative ratio (1.0 = no change; lower is better here)",
    main = "Relative Change Summary",
    las = 1
  )
  abline(v = pretty(c(0, xmax)), col = grid_col, lwd = 1)
  abline(v = 1, col = "#3F4F5D", lwd = 1.5, lty = 2)
  axis(2, at = y, labels = labels, las = 1, cex.axis = 0.90)

  segments(0, y, values, y, col = "#C8D3DE", lwd = 3)
  points(values, y, pch = 21, bg = cols, col = "#24313C", cex = 1.55, lwd = 0.9)
  text(values + xmax * 0.025, y, labels = sprintf("%.2fx", values), adj = c(0, 0.5), cex = 0.90, col = text_primary)
  mtext("Reference line at 1.0; values left of the line indicate reductions", side = 3, line = 0.4, cex = 0.92, col = text_muted)
}

draw_cache_panel <- function() {
  if (is.null(cache_df) || nrow(cache_df) == 0) {
    panel_box()
    text(0.05, 0.90, "Cache Efficiency Snapshot", adj = c(0, 1), cex = 1.02, font = 2, col = text_primary)
    text(0.05, 0.52, "No cache/perf metrics file found.", adj = c(0, 0.5), cex = 0.92, col = text_muted)
    return()
  }

  cache_order <- c("old_half_nosketch", "new_half_nosketch", "new_half_sketch_query", "new_half_sketch_build_perf")
  sub <- cache_df[match(cache_order, cache_df$workload), ]
  sub <- sub[!is.na(sub$workload), ]
  if (!nrow(sub)) {
    panel_box()
    text(0.05, 0.90, "Cache Efficiency Snapshot", adj = c(0, 1), cex = 1.02, font = 2, col = text_primary)
    text(0.05, 0.52, "Cache metrics file is present but empty for expected workloads.", adj = c(0, 0.5), cex = 0.88, col = text_muted)
    return()
  }

  metrics <- list(
    list(column = "ipc", label = "IPC", formatter = function(x) sprintf("%.2f", x), better = "Higher is better"),
    list(column = "branch_miss_rate", label = "Branch miss", formatter = function(x) fmt_pct(x, 1), better = "Lower is better"),
    list(column = "l2_all_demand_miss_rate", label = "L2 demand miss", formatter = function(x) fmt_pct(x, 1), better = "Lower is better"),
    list(column = "llc_load_miss_rate", label = "LLC load miss", formatter = function(x) fmt_pct(x, 1), better = "Lower is better")
  )

  par(mar = c(4.8, 2.5, 4.0, 1.5) + 0.1)
  plot(NA, xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, xlab = "", ylab = "", main = "Cache Efficiency Snapshot")
  rect(0, 0, 1, 1, col = panel_bg, border = panel_border, lwd = 2)

  cols_x <- c(0.36, 0.56, 0.75, 0.92)
  row_y <- c(0.72, 0.53, 0.34, 0.15)

  text(0.05, 0.86, "Metric", adj = c(0, 0.5), cex = 1.00, font = 2, col = text_primary)
  for (j in seq_len(nrow(sub))) {
    x <- cols_x[j]
    rect(x - 0.075, 0.79, x + 0.075, 0.89,
         col = adjustcolor(cache_colors[[sub$workload[j]]], alpha.f = 0.16),
         border = panel_border, lwd = 1)
    text(x, 0.84, cache_labels[[sub$workload[j]]], cex = 0.86, font = 2, col = text_primary)
  }

  for (i in seq_along(metrics)) {
    metric <- metrics[[i]]
    y <- row_y[i]
    rect(0.03, y - 0.075, 0.97, y + 0.075, col = if (i %% 2) "#FBFCFE" else "#F6F9FC", border = NA)
    text(0.05, y + 0.02, metric$label, adj = c(0, 0.5), cex = 1.00, font = 2, col = text_primary)
    text(0.05, y - 0.03, metric$better, adj = c(0, 0.5), cex = 0.82, col = text_muted)
    for (j in seq_len(nrow(sub))) {
      x <- cols_x[j]
      val <- sub[[metric$column]][j]
      lab <- if (is.na(val)) "NA" else metric$formatter(val)
      text(x, y, lab, cex = 1.02, col = text_primary)
    }
  }

  mtext("Single-run perf stat snapshots on the t=1 half-list workload", side = 1, line = 2.9, cex = 0.90, col = text_muted)
}

draw_cpu_panel <- function() {
  variants <- c("old_release", "new_release", "standard", "batch_5", "batch_1")
  sub <- summary_df[match(variants, as.character(summary_df$variant)), ]
  vals <- sub$total_cpu_mean
  cols <- unname(variant_colors[variants])
  xmax <- max(vals) * 1.42
  labels <- c("Old no-sketch", "Current no-sketch", "Full sketch", "Batch=5", "Batch=1")

  par(mar = c(4.8, 10, 4, 2) + 0.1)
  mids <- barplot(
    vals,
    names.arg = labels,
    col = cols,
    border = NA,
    xlim = c(0, xmax),
    xlab = "Total CPU time (user + sys seconds)",
    main = "CPU Consumption",
    las = 1,
    cex.names = 0.90,
    horiz = TRUE
  )
  abline(v = pretty(c(0, xmax)), col = grid_col, lwd = 1)
  mids <- barplot(
    vals,
    names.arg = labels,
    col = cols,
    border = "#5E6B78",
    add = TRUE,
    axes = FALSE,
    axisnames = FALSE,
    horiz = TRUE
  )

  text(vals + xmax * 0.02, mids, labels = sprintf("%s s", fmt_num(vals, 1)), adj = c(0, 0.5), cex = 0.92, col = text_primary)
  cpu_labels <- ifelse(
    sub$threads_mean > 1,
    sprintf("%s cores avg (%s%% eff.)",
            fmt_num(sub$effective_cores_mean, 1),
            fmt_num(sub$thread_util_mean, 0)),
    sprintf("%s%% of 1 core", fmt_num(sub$thread_util_mean, 0))
  )
  text(rep(xmax * 0.99, length(mids)), mids, labels = cpu_labels, adj = c(1, 0.5), cex = 0.88, col = text_muted)
  mtext("Means across replicates; right labels show effective cores and thread efficiency", side = 3, line = 0.4, cex = 0.92, col = text_muted)
}

draw_notes_panel <- function() {
  par(mar = c(0.5, 0.5, 0.5, 0.5) + 0.1)
  panel_box()
  text(0.05, 0.93, "Method Notes", adj = c(0, 1), cex = 1.12, font = 2, col = text_primary)

  lines_to_show <- c(
    sprintf("%d half-list runs total: 5 modes x %d replicates", nrow(df), unique(summary_df$n)[1]),
    "Release builds; sketch modes use an 8-chunk prebuilt reference sketch",
    "Cache panel uses single perf-stat snapshots; replicate markers show run-to-run spread"
  )

  y <- 0.80
  for (line in lines_to_show) {
    wrapped <- strwrap(line, width = 46)
    for (j in seq_along(wrapped)) {
      prefix <- if (j == 1) "\u2022 " else "  "
      text(0.08, y, paste0(prefix, wrapped[[j]]), adj = c(0, 0.5), cex = 0.92, col = text_primary)
      y <- y - 0.09
    }
    y <- y - 0.04
  }

  segments(0.07, 0.24, 0.93, 0.24, col = panel_border, lwd = 1)
  status_col <- if (validation_all_match) good_col else if (length(validation_lines)) bad_col else neutral_col
  status_label <- if (validation_all_match) {
    "Validation summary: all recorded checks passed"
  } else if (length(validation_lines)) {
    "Validation summary: recorded mismatches or failures are present"
  } else {
    "Validation summary: no validation text file was provided"
  }
  text(0.08, 0.12, status_label, adj = c(0, 0.5), cex = 0.96, font = 2, col = status_col)
}

write_summary_tables <- function() {
  summary_path <- file.path(out_dir, "publication_summary_by_variant.tsv")
  write.table(
    summary_df[, c(
      "scenario", "variant", "label", "n", "output_rows",
      "wall_mean", "wall_sd", "db_mean", "db_sd",
      "query_mean", "query_sd", "post_mean", "post_sd", "other_mean", "other_sd",
      "rss_mean_gb", "rss_sd_gb", "cpu_mean", "cpu_sd",
      "fs_in_mean", "fs_out_mean", "total_cpu_mean", "total_cpu_sd"
    )],
    file = summary_path,
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )

  pairwise_path <- file.path(out_dir, "publication_key_comparisons.tsv")
  pairwise <- data.frame(
    comparison = c(
      "current_vs_old_nosketch_runtime_ratio",
      "current_vs_old_nosketch_rss_ratio",
      "current_vs_old_nosketch_query_ratio",
      "current_vs_old_nosketch_db_build_ratio",
      "full_sketch_vs_old_runtime_ratio",
      "full_sketch_vs_old_rss_ratio",
      "batch_5_vs_old_runtime_ratio",
      "batch_5_vs_old_rss_ratio",
      "batch_1_vs_old_runtime_ratio",
      "batch_1_vs_old_rss_ratio"
    ),
    value = c(
      new_s$wall_mean / old_s$wall_mean,
      new_s$rss_mean_gb / old_s$rss_mean_gb,
      new_s$query_mean / old_s$query_mean,
      new_s$db_mean / old_s$db_mean,
      std_s$wall_mean / old_s$wall_mean,
      std_s$rss_mean_gb / old_s$rss_mean_gb,
      batch5_s$wall_mean / old_s$wall_mean,
      batch5_s$rss_mean_gb / old_s$rss_mean_gb,
      batch1_s$wall_mean / old_s$wall_mean,
      batch1_s$rss_mean_gb / old_s$rss_mean_gb
    )
  )

  current_ipc <- cache_lookup("new_half_nosketch", "ipc")
  old_ipc <- cache_lookup("old_half_nosketch", "ipc")
  current_llc <- cache_lookup("new_half_nosketch", "llc_load_miss_rate")
  old_llc <- cache_lookup("old_half_nosketch", "llc_load_miss_rate")
  current_l2 <- cache_lookup("new_half_nosketch", "l2_all_demand_miss_rate")
  old_l2 <- cache_lookup("old_half_nosketch", "l2_all_demand_miss_rate")

  pairwise <- rbind(
    pairwise,
    data.frame(
      comparison = c(
        "current_vs_old_nosketch_ipc_ratio",
        "current_vs_old_nosketch_llc_load_miss_ratio",
        "current_vs_old_nosketch_l2_miss_ratio"
      ),
      value = c(current_ipc / old_ipc, current_llc / old_llc, current_l2 / old_l2)
    )
  )

  write.table(pairwise, file = pairwise_path, sep = "\t", quote = FALSE, row.names = FALSE)

  if (!is.null(cache_df) && nrow(cache_df)) {
    cache_path <- file.path(out_dir, "publication_cache_metrics.tsv")
    cache_out <- cache_df
    cache_out$label <- unname(cache_labels[cache_out$workload])
    write.table(cache_out, file = cache_path, sep = "\t", quote = FALSE, row.names = FALSE)
  }
}

render_dashboard <- function(file_name) {
  png(file.path(out_dir, file_name), width = 2120, height = 2120, res = 180, bg = bg)
  layout(
    matrix(
      c(
        1, 1, 2, 2, 3, 3,
        4, 4, 5, 5, 6, 6,
        7, 7, 7, 8, 8, 8,
        9, 9, 9, 10, 10, 10,
        11, 11, 11, 12, 12, 12
      ),
      nrow = 5,
      byrow = TRUE
    ),
    widths = c(1.0, 1.0, 1.0, 1.0, 1.01, 1.01),
    heights = c(0.72, 0.72, 1.28, 1.16, 1.02)
  )

  par(bg = bg, oma = c(0, 0, 2.8, 0), xpd = FALSE)

  no_sketch_cmp <- compare_metric(new_s$wall_mean, old_s$wall_mean, lower_is_better = TRUE, verb_better = "faster", verb_worse = "slower")
  no_sketch_build_cmp <- compare_metric(new_s$db_mean, old_s$db_mean, lower_is_better = TRUE, verb_better = "faster", verb_worse = "slower")
  no_sketch_query_cmp <- compare_metric(new_s$query_mean, old_s$query_mean, lower_is_better = TRUE, verb_better = "faster", verb_worse = "slower")
  full_sketch_cmp <- compare_metric(std_s$wall_mean, old_s$wall_mean, lower_is_better = TRUE, verb_better = "faster", verb_worse = "slower")
  batch5_rss_cmp <- compare_metric(batch5_s$rss_mean_gb, old_s$rss_mean_gb, lower_is_better = TRUE, verb_better = "lower", verb_worse = "higher")
  batch1_rss_cmp <- compare_metric(batch1_s$rss_mean_gb, old_s$rss_mean_gb, lower_is_better = TRUE, verb_better = "lower", verb_worse = "higher")
  batch1_wall_cmp <- compare_metric(batch1_s$wall_mean, old_s$wall_mean, lower_is_better = TRUE, verb_better = "faster", verb_worse = "slower")

  draw_card(
    "No-Sketch Runtime",
    no_sketch_cmp$value,
    sprintf("%.2fs vs %.2fs", new_s$wall_mean, old_s$wall_mean),
    no_sketch_cmp$accent
  )
  draw_card(
    "No-Sketch Build",
    no_sketch_build_cmp$value,
    sprintf("%.2fs vs %.2fs", new_s$db_mean, old_s$db_mean),
    warn_col
  )
  draw_card(
    "Full-Sketch Runtime",
    full_sketch_cmp$value,
    sprintf("%.2fs vs %.2fs", std_s$wall_mean, old_s$wall_mean),
    full_sketch_cmp$accent
  )
  draw_card(
    "No-Sketch Query",
    no_sketch_query_cmp$value,
    sprintf("%.2fs vs %.2fs", new_s$query_mean, old_s$query_mean),
    no_sketch_query_cmp$accent
  )
  draw_card(
    "Batch=5 Peak RSS",
    batch5_rss_cmp$value,
    sprintf("%.2f GiB vs %.2f GiB", batch5_s$rss_mean_gb, old_s$rss_mean_gb),
    batch5_rss_cmp$accent
  )
  draw_card(
    "Batch=1 Peak RSS",
    batch1_rss_cmp$value,
    sprintf("%.2f GiB vs %.2f GiB", batch1_s$rss_mean_gb, old_s$rss_mean_gb),
    batch1_rss_cmp$accent
  )

  draw_stacked_runtime(
    c("old_release", "new_release", "standard", "batch_5", "batch_1"),
    "Runtime Breakdown Across Execution Modes",
    "Updated branch snapshot with current sketch-query variants and replicate markers"
  )
  draw_memory_panel()
  draw_relative_change_panel()
  draw_cache_panel()
  draw_cpu_panel()
  draw_notes_panel()

  mtext("FastANI Performance Dashboard", outer = TRUE, cex = 1.48, font = 2, col = text_primary, line = 1.42)
  mtext("Refreshed half-list repeated benchmarks with resource and perf-stat cache snapshots", outer = TRUE, side = 3, line = 0.48, cex = 0.90, col = text_muted)
  mtext(
    sprintf(
      "Data sources: %s | %s",
      basename(csv_path),
      basename(cache_metrics_path)
    ),
    outer = TRUE,
    side = 1,
    line = -0.7,
    cex = 0.82,
    col = text_muted
  )
  dev.off()
}

write_summary_tables()
render_dashboard("publication_performance_dashboard.png")

message("Read publication metrics from: ", csv_path)
message("Read cache metrics from: ", cache_metrics_path)
message("Wrote publication dashboard to: ", file.path(out_dir, "publication_performance_dashboard.png"))
message("Wrote summary tables to: ", file.path(out_dir, "publication_summary_by_variant.tsv"))
