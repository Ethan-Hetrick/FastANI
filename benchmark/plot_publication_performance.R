args <- commandArgs(trailingOnly = TRUE)

csv_path <- if (length(args) >= 1) args[[1]] else "benchmark/publication_runs.csv"
out_dir <- if (length(args) >= 2) args[[2]] else "benchmark/plots"
validation_path <- if (length(args) >= 3) args[[3]] else "benchmark/publication_validation.txt"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

df <- read.csv(csv_path, stringsAsFactors = FALSE, na.strings = c("NA", ""))

numeric_cols <- c(
  "replicate", "threads", "output_rows", "internal_db_phase_sec",
  "internal_query_map_sec", "internal_post_map_sec", "wall_sec",
  "user_cpu_sec", "system_cpu_sec", "cpu_percent", "max_rss_kb",
  "fs_inputs_blocks", "fs_outputs_blocks", "major_page_faults",
  "minor_page_faults", "voluntary_ctx_switches", "involuntary_ctx_switches"
)

for (col in numeric_cols) {
  df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
}

df$max_rss_gb <- df$max_rss_kb / (1024 * 1024)
df$total_cpu_sec <- df$user_cpu_sec + df$system_cpu_sec

variant_levels <- c("old_release", "new_release", "standard", "batch_5", "batch_1")
variant_plot_labels <- c(
  "Old release\nno sketch",
  "Current release\nno sketch",
  "Sketch query\nall shards",
  "Sketch query\nbatch=5",
  "Sketch query\nbatch=1"
)
names(variant_plot_labels) <- variant_levels

variant_table_labels <- c(
  "Old release no sketch",
  "Current release no sketch",
  "Sketch query all shards",
  "Sketch query batch=5",
  "Sketch query batch=1"
)
names(variant_table_labels) <- variant_levels

variant_colors <- c(
  old_release = "#7F7F7F",
  new_release = "#0072B2",
  standard = "#009E73",
  batch_5 = "#E69F00",
  batch_1 = "#D55E00"
)

phase_colors <- c(
  db = "#D55E00",
  query = "#56B4E9",
  post = "#CC79A7",
  other = "#B3B3B3"
)

bg <- "#F4F7FB"
panel_bg <- "#FFFFFF"
panel_border <- "#D8E1EA"
grid_col <- "#E7EEF5"
text_primary <- "#1F2D3D"
text_muted <- "#607286"

fmt_num <- function(x, digits = 2) {
  format(round(x, digits), nsmall = digits, trim = TRUE)
}

summarise_group <- function(frame) {
  data.frame(
    scenario = frame$scenario[1],
    variant = frame$variant[1],
    label = variant_table_labels[[frame$variant[1]]],
    n = nrow(frame),
    output_rows = frame$output_rows[1],
    wall_mean = mean(frame$wall_sec),
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
    total_cpu_mean = mean(frame$total_cpu_sec),
    total_cpu_sd = sd(frame$total_cpu_sec)
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

panel_box <- function() {
  plot.new()
  plot.window(xlim = c(0, 1), ylim = c(0, 1))
  rect(0, 0, 1, 1, col = panel_bg, border = panel_border, lwd = 2)
}

draw_card <- function(title, value, subtitle, accent) {
  panel_box()
  rect(0, 0.915, 1, 1, col = adjustcolor(accent, alpha.f = 0.14), border = NA)
  text(0.05, 0.82, title, adj = c(0, 1), cex = 0.98, font = 2, col = text_primary)
  text(0.05, 0.53, value, adj = c(0, 0.5), cex = 1.95, font = 2, col = accent)
  text(0.05, 0.18, subtitle, adj = c(0, 0), cex = 0.88, col = text_muted)
}

overlay_replicate_points <- function(x, values, color) {
  if (!length(values)) {
    return()
  }
  offsets <- seq(-0.12, 0.12, length.out = length(values))
  points(rep(x, length(values)) + offsets, values, pch = 21, cex = 1.1,
         bg = adjustcolor(color, alpha.f = 0.7), col = "#31424F", lwd = 0.8)
}

draw_stacked_runtime <- function(variants, title, subtitle) {
  sub <- summary_df[summary_df$variant %in% variants, ]
  sub <- sub[match(variants, as.character(sub$variant)), ]
  runtime_mat <- rbind(sub$db_mean, sub$query_mean, sub$post_mean, sub$other_mean)
  rownames(runtime_mat) <- c("DB/load", "Query map", "Post map", "Other overhead")
  colnames(runtime_mat) <- unname(variant_plot_labels[variants])
  totals <- colSums(runtime_mat)
  ymax <- max(totals) * 1.28

  par(mar = c(6.5, 6, 4, 2) + 0.1)
  mids <- barplot(
    runtime_mat,
    beside = FALSE,
    col = phase_colors,
    border = NA,
    ylim = c(0, ymax),
    ylab = "Seconds",
    main = title,
    las = 1,
    cex.names = 0.95
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

  text(mids, totals, labels = fmt_num(totals, 2), pos = 3, cex = 0.92, col = text_primary)
  legend("topright", legend = rownames(runtime_mat), fill = phase_colors, bty = "n", cex = 0.84)
  mtext(subtitle, side = 3, line = 0.4, cex = 0.88, col = text_muted)
}

draw_metric_bars <- function(variants, values, title, ylab, subtitle, point_col_fun) {
  labels <- unname(variant_plot_labels[variants])
  cols <- unname(variant_colors[variants])
  ymax <- max(values) * 1.22

  par(mar = c(7, 6, 4, 2) + 0.1)
  mids <- barplot(
    values,
    names.arg = labels,
    col = cols,
    border = NA,
    ylim = c(0, ymax),
    ylab = ylab,
    main = title,
    las = 1,
    cex.names = 0.9
  )
  abline(h = pretty(c(0, ymax)), col = grid_col, lwd = 1)
  mids <- barplot(
    values,
    names.arg = labels,
    col = cols,
    border = "#5E6B78",
    add = TRUE,
    axes = FALSE,
    axisnames = FALSE
  )

  for (i in seq_along(variants)) {
    sub_vals <- point_col_fun(variants[i])
    overlay_replicate_points(mids[i], sub_vals, cols[i])
  }

  text(mids, values, labels = fmt_num(values, 2), pos = 3, cex = 0.88, col = text_primary)
  if (nzchar(subtitle)) {
    mtext(subtitle, side = 3, line = 0.4, cex = 0.84, col = text_muted)
  }
}

draw_memory_panel <- function() {
  variants <- c("old_release", "new_release", "standard", "batch_5", "batch_1")
  sub <- summary_df[match(variants, as.character(summary_df$variant)), ]
  vals <- sub$rss_mean_gb
  cols <- unname(variant_colors[variants])
  xmax <- max(vals) * 1.25
  labels <- c("Old no-sketch", "Current no-sketch", "All shards", "Batch=5", "Batch=1")

  par(mar = c(4.5, 10, 4, 2) + 0.1)
  mids <- barplot(
    vals,
    names.arg = labels,
    col = cols,
    border = NA,
    xlim = c(0, xmax),
    xlab = "Max RSS (GiB)",
    main = "Peak Memory",
    las = 1,
    cex.names = 0.8,
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

  text(vals, mids, labels = fmt_num(vals, 2), pos = 4, cex = 0.84, col = text_primary)
  mtext("Bars show means; points show replicate RSS values", side = 3, line = 0.4, cex = 0.84, col = text_muted)
}

draw_relative_change_panel <- function() {
  labels <- c(
    "No-sketch total runtime",
    "No-sketch query mapping",
    "No-sketch DB build",
    "All-shards sketch DB/load",
    "All-shards sketch runtime",
    "Batch=5 runtime",
    "Batch=5 RSS",
    "Batch=1 runtime",
    "Batch=1 RSS"
  )

  values <- c(
    new_s$wall_mean / old_s$wall_mean,
    new_s$query_mean / old_s$query_mean,
    new_s$db_mean / old_s$db_mean,
    std_s$db_mean / old_s$db_mean,
    std_s$wall_mean / old_s$wall_mean,
    batch5_s$wall_mean / old_s$wall_mean,
    batch5_s$rss_mean_gb / old_s$rss_mean_gb,
    batch1_s$wall_mean / old_s$wall_mean,
    batch1_s$rss_mean_gb / old_s$rss_mean_gb
  )

  cols <- c(
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

  par(mar = c(5.5, 12, 4, 2) + 0.1)
  plot(
    NA,
    xlim = c(0, xmax),
    ylim = c(0.5, length(labels) + 0.5),
    yaxt = "n",
    ylab = "",
    xlab = "Relative ratio (1.0 = no change)",
    main = "Relative Change Summary",
    las = 1
  )
  abline(v = pretty(c(0, xmax)), col = grid_col, lwd = 1)
  abline(v = 1, col = "#3F4F5D", lwd = 1.5, lty = 2)
  axis(2, at = y, labels = labels, las = 1, cex.axis = 0.82)

  segments(0, y, values, y, col = "#C8D3DE", lwd = 3)
  points(values, y, pch = 21, bg = cols, col = "#24313C", cex = 1.6, lwd = 0.9)

  direction <- ifelse(values < 1, "lower", "higher")
  pretty_vals <- ifelse(values < 1, sprintf("%.2fx", values), sprintf("%.2fx", values))
  for (i in seq_along(values)) {
    text(values[i] + xmax * 0.025, y[i], pretty_vals[i], adj = c(0, 0.5), cex = 0.82, col = text_primary)
  }

  mtext("Reference line at 1.0; values left of the line are reductions", side = 3, line = 0.4, cex = 0.84, col = text_muted)
}

draw_notes_panel <- function() {
  panel_box()
  text(0.05, 0.93, "Legends and Validation", adj = c(0, 1), cex = 1.06, font = 2, col = text_primary)

  short_variant_labels <- c(
    old_release = "Old no-sketch",
    new_release = "Current no-sketch",
    standard = "All shards",
    batch_5 = "Batch=5",
    batch_1 = "Batch=1"
  )

  text(0.07, 0.82, "Variant colors", adj = c(0, 0.5), cex = 0.92, font = 2, col = text_primary)
  variant_y <- c(0.75, 0.67, 0.59, 0.51, 0.43)
  variant_keys <- c("old_release", "new_release", "standard", "batch_5", "batch_1")
  for (i in seq_along(variant_keys)) {
    rect(0.07, variant_y[i] - 0.022, 0.125, variant_y[i] + 0.022, col = variant_colors[[variant_keys[i]]], border = "#41505C")
    text(0.15, variant_y[i], short_variant_labels[[variant_keys[i]]], adj = c(0, 0.5), cex = 0.85, col = text_primary)
  }

  text(0.58, 0.82, "Phase colors", adj = c(0, 0.5), cex = 0.92, font = 2, col = text_primary)
  phase_y <- c(0.75, 0.67, 0.59, 0.51)
  phase_keys <- c("db", "query", "post", "other")
  phase_labels <- c("DB/load", "Query", "Post", "Other")
  for (i in seq_along(phase_keys)) {
    rect(0.58, phase_y[i] - 0.022, 0.635, phase_y[i] + 0.022, col = phase_colors[[phase_keys[i]]], border = "#41505C")
    text(0.66, phase_y[i], phase_labels[i], adj = c(0, 0.5), cex = 0.85, col = text_primary)
  }

  segments(0.07, 0.34, 0.93, 0.34, col = panel_border, lwd = 1)

  lines_to_show <- c(
    sprintf("15 runs total: 5 variants x %d replicates", unique(summary_df$n)[1]),
    "Workload: 1 query vs 5,032 references",
    "Release builds; sketch test uses 8 shards"
  )

  for (i in seq_along(lines_to_show)) {
    text(0.07, 0.28 - (i - 1) * 0.08, paste0("\u2022 ", lines_to_show[i]),
         adj = c(0, 0.5), cex = 0.88, col = text_primary)
  }

  status_col <- if (validation_all_match) "#2C8E5A" else "#C84C4C"
  status_label <- if (validation_all_match) "All recorded validation checks matched" else "One or more validation checks failed"
  text(0.07, 0.05, status_label, adj = c(0, 0.5), cex = 0.92, font = 2, col = status_col)
}

write_summary_tables <- function() {
  summary_path <- file.path(out_dir, "publication_summary_by_variant.tsv")
  write.table(
    summary_df[, c(
      "scenario", "variant", "label", "n", "output_rows",
      "wall_mean", "wall_sd", "db_mean", "db_sd",
      "query_mean", "query_sd", "post_mean", "post_sd", "other_mean", "other_sd",
      "rss_mean_gb", "rss_sd_gb", "cpu_mean", "cpu_sd",
      "fs_in_mean", "fs_out_mean"
    )],
    file = summary_path,
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )

  pairwise_path <- file.path(out_dir, "publication_key_comparisons.tsv")
  pairwise <- data.frame(
    comparison = c(
      "current_vs_old_nosketch_speedup_pct",
      "current_vs_old_query_speedup_pct",
      "current_vs_old_reference_build_speedup_pct",
      "all_shards_vs_old_db_setup_speedup_x",
      "all_shards_vs_old_end_to_end_speedup_x",
      "batch_5_vs_old_runtime_speedup_pct",
      "batch_5_vs_old_rss_reduction_pct",
      "batch_1_vs_old_runtime_speedup_pct",
      "batch_1_vs_old_rss_reduction_pct"
    ),
    value = c(
      no_sketch_speedup_pct,
      query_speedup_pct,
      ref_build_speedup_pct,
      sketch_setup_speedup_x,
      sketch_end_to_end_speedup_x,
      batch5_runtime_speedup_pct,
      batch5_rss_reduction_pct,
      batch1_runtime_speedup_pct,
      batch1_rss_reduction_pct
    )
  )
  write.table(pairwise, file = pairwise_path, sep = "\t", quote = FALSE, row.names = FALSE)
}

render_dashboard <- function(file_name) {
  png(file.path(out_dir, file_name), width = 2400, height = 1800, res = 170, bg = bg)
  layout(
    matrix(
      c(1, 2, 3, 4, 5, 6,
        7, 7, 7, 7, 7, 7,
        8, 8, 9, 9, 10, 10),
      nrow = 3,
      byrow = TRUE
    ),
    widths = c(1.0, 1.0, 1.0, 1.0, 1.0, 1.25),
    heights = c(0.82, 1.45, 1.25)
  )

  par(bg = bg, oma = c(0, 0, 4.2, 0), xpd = FALSE)

  draw_card(
    "No-Sketch Runtime",
    sprintf("%.1f%% faster", no_sketch_speedup_pct),
    sprintf("%.2fs vs %.2fs", new_s$wall_mean, old_s$wall_mean),
    "#009E73"
  )
  draw_card(
    "Query Mapping Gain",
    sprintf("%.1f%% faster", query_speedup_pct),
    sprintf("%.2fs vs %.2fs", new_s$query_mean, old_s$query_mean),
    "#0072B2"
  )
  draw_card(
    "Reference Build",
    sprintf("%.1f%% faster", ref_build_speedup_pct),
    sprintf("%.2fs vs %.2fs", new_s$db_mean, old_s$db_mean),
    "#7F7F7F"
  )
  draw_card(
    "Sketch DB Setup",
    sprintf("%.1fx faster", sketch_setup_speedup_x),
    sprintf("%.2fs vs %.2fs", std_s$db_mean, old_s$db_mean),
    "#56B4E9"
  )
  draw_card(
    "Batch=5 Runtime",
    sprintf("%.1f%% faster", batch5_runtime_speedup_pct),
    sprintf("%.2fs vs %.2fs", batch5_s$wall_mean, old_s$wall_mean),
    variant_colors[["batch_5"]]
  )
  draw_card(
    "Batch=1 Peak RSS",
    sprintf("%.1f%% lower", batch1_rss_reduction_pct),
    sprintf("%.2f GiB vs %.2f GiB", batch1_s$rss_mean_gb, old_s$rss_mean_gb),
    variant_colors[["batch_1"]]
  )

  draw_stacked_runtime(
    c("old_release", "new_release", "standard", "batch_5", "batch_1"),
    "Runtime Breakdown Across Execution Modes",
    "Shared y-axis for direct comparison across no-sketch and sketch batch-size runs"
  )
  draw_memory_panel()
  draw_relative_change_panel()
  draw_notes_panel()

  mtext("FastANI Publication Benchmark Dashboard", outer = TRUE, cex = 1.62, font = 2, col = text_primary, line = 2.25)
  mtext("Repeated Release-mode benchmarks: original vs current no-sketch performance, plus all-shards, batch=5, and batch=1 sketch queries", outer = TRUE, side = 3, line = 1.02, cex = 0.96, col = text_muted)
  mtext(sprintf("Data source: %s", basename(csv_path)), outer = TRUE, side = 1, line = -1.5, cex = 0.85, col = text_muted)
  dev.off()
}

write_summary_tables()
render_dashboard("publication_performance_dashboard.png")

message("Read publication metrics from: ", csv_path)
message("Wrote publication dashboard to: ", file.path(out_dir, "publication_performance_dashboard.png"))
message("Wrote summary tables to: ", file.path(out_dir, "publication_summary_by_variant.tsv"))
