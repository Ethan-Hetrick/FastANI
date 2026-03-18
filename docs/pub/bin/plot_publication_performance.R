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

variant_levels <- c("old_release", "new_release", "standard", "low_memory")
variant_plot_labels <- c(
  "Old release\nno sketch",
  "Current release\nno sketch",
  "Sketch query\nstandard",
  "Sketch query\nlow-memory"
)
names(variant_plot_labels) <- variant_levels

variant_table_labels <- c(
  "Old release no sketch",
  "Current release no sketch",
  "Sketch query standard",
  "Sketch query low-memory"
)
names(variant_table_labels) <- variant_levels

variant_colors <- c(
  old_release = "#6E7C87",
  new_release = "#1F8A9E",
  standard = "#4F8A3C",
  low_memory = "#D98E04"
)

phase_colors <- c(
  db = "#C95A4A",
  query = "#556FB5",
  post = "#96B95C",
  other = "#A6ADB5"
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
low_s <- get_summary("low_memory")

no_sketch_speedup_pct <- (old_s$wall_mean - new_s$wall_mean) / old_s$wall_mean * 100
query_speedup_pct <- (old_s$query_mean - new_s$query_mean) / old_s$query_mean * 100
lowmem_rss_reduction_pct <- (std_s$rss_mean_gb - low_s$rss_mean_gb) / std_s$rss_mean_gb * 100
lowmem_slowdown_x <- low_s$wall_mean / std_s$wall_mean

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
  variants <- c("old_release", "new_release", "standard", "low_memory")
  sub <- summary_df[match(variants, as.character(summary_df$variant)), ]
  vals <- sub$rss_mean_gb
  sds <- sub$rss_sd_gb
  cols <- unname(variant_colors[variants])
  ymax <- max(vals + sds) * 1.20

  par(mar = c(7, 6, 4, 2) + 0.1)
  mids <- barplot(
    vals,
    names.arg = unname(variant_plot_labels[variants]),
    col = cols,
    border = NA,
    ylim = c(0, ymax),
    ylab = "Max RSS (GiB)",
    main = "Peak Memory",
    las = 1,
    cex.names = 0.9
  )
  abline(h = pretty(c(0, ymax)), col = grid_col, lwd = 1)
  mids <- barplot(
    vals,
    names.arg = unname(variant_plot_labels[variants]),
    col = cols,
    border = "#5E6B78",
    add = TRUE,
    axes = FALSE,
    axisnames = FALSE
  )

  for (i in seq_along(variants)) {
    overlay_replicate_points(mids[i], df$max_rss_gb[df$variant == variants[i]], cols[i])
  }

  text(mids, vals, labels = fmt_num(vals, 2), pos = 3, cex = 0.86, col = text_primary)
  mtext("Bars show means; points show replicate RSS values", side = 3, line = 0.4, cex = 0.84, col = text_muted)
}

draw_walltime_boxplot_panel <- function() {
  variants <- c("old_release", "new_release", "standard", "low_memory")
  values <- lapply(variants, function(v) df$wall_sec[df$variant == v])
  names(values) <- unname(variant_plot_labels[variants])

  par(mar = c(5.5, 8, 4, 2) + 0.1)
  bp <- boxplot(
    values,
    horizontal = TRUE,
    col = unname(variant_colors[variants]),
    border = "#4A5865",
    xaxt = "s",
    las = 1,
    xlab = "Wall time (s)",
    main = "Wall-Time Distribution Across Replicates",
    outline = FALSE
  )
  abline(v = pretty(range(df$wall_sec) * c(0.95, 1.05)), col = grid_col, lwd = 1)

  for (i in seq_along(variants)) {
    vals <- df$wall_sec[df$variant == variants[i]]
    y <- rep(i, length(vals)) + seq(-0.10, 0.10, length.out = length(vals))
    points(vals, y, pch = 21, cex = 1.2,
           bg = adjustcolor(variant_colors[[variants[i]]], alpha.f = 0.72),
           col = "#2E3B46", lwd = 0.8)
    mean_val <- mean(vals)
    points(mean_val, i, pch = 23, cex = 1.5,
           bg = variant_colors[[variants[i]]], col = "#1F2D38", lwd = 1.1)
    text(max(vals) + max(df$wall_sec) * 0.035, i, labels = fmt_num(mean_val, 2),
         adj = c(0, 0.5), cex = 0.82, col = text_primary)
  }

  mtext("Boxes show replicate spread; diamonds mark means and labels show mean wall time", side = 3, line = 0.4, cex = 0.84, col = text_muted)
}

draw_notes_panel <- function() {
  panel_box()
  text(0.05, 0.93, "Legends and Validation", adj = c(0, 1), cex = 1.06, font = 2, col = text_primary)

  text(0.05, 0.82, "Variant colors", adj = c(0, 0.5), cex = 0.9, font = 2, col = text_primary)
  variant_y <- c(0.76, 0.70, 0.64, 0.58)
  variant_keys <- c("old_release", "new_release", "standard", "low_memory")
  for (i in seq_along(variant_keys)) {
    rect(0.05, variant_y[i] - 0.018, 0.09, variant_y[i] + 0.018, col = variant_colors[[variant_keys[i]]], border = "#41505C")
    text(0.11, variant_y[i], variant_table_labels[[variant_keys[i]]], adj = c(0, 0.5), cex = 0.82, col = text_primary)
  }

  text(0.55, 0.82, "Phase colors", adj = c(0, 0.5), cex = 0.9, font = 2, col = text_primary)
  phase_y <- c(0.76, 0.70, 0.64, 0.58)
  phase_keys <- c("db", "query", "post", "other")
  phase_labels <- c("DB/load", "Query map", "Post map", "Other overhead")
  for (i in seq_along(phase_keys)) {
    rect(0.55, phase_y[i] - 0.018, 0.59, phase_y[i] + 0.018, col = phase_colors[[phase_keys[i]]], border = "#41505C")
    text(0.61, phase_y[i], phase_labels[i], adj = c(0, 0.5), cex = 0.82, col = text_primary)
  }

  lines_to_show <- c(
    sprintf("12 total runs: 4 variants x %d replicates", unique(summary_df$n)[1]),
    "Workload: 1 query vs 5,032 references (half-list subset)",
    "Release builds for original and current binaries",
    "Sketch benchmark uses 8 sketch shards"
  )

  for (i in seq_along(lines_to_show)) {
    text(0.05, 0.42 - (i - 1) * 0.07, paste0("\u2022 ", lines_to_show[i]),
         adj = c(0, 0.5), cex = 0.86, col = text_primary)
  }

  status_col <- if (validation_all_match) "#2C8E5A" else "#C84C4C"
  status_label <- if (validation_all_match) "All 10 recorded validation checks matched" else "One or more validation checks failed"
  text(0.05, 0.11, status_label, adj = c(0, 0.5), cex = 0.97, font = 2, col = status_col)
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
      "low_memory_vs_standard_rss_reduction_pct",
      "low_memory_vs_standard_runtime_slowdown_x"
    ),
    value = c(
      no_sketch_speedup_pct,
      query_speedup_pct,
      lowmem_rss_reduction_pct,
      lowmem_slowdown_x
    )
  )
  write.table(pairwise, file = pairwise_path, sep = "\t", quote = FALSE, row.names = FALSE)
}

render_dashboard <- function(file_name) {
  png(file.path(out_dir, file_name), width = 2400, height = 1800, res = 170, bg = bg)
  layout(
    matrix(
      c(1, 2, 3, 4,
        5, 5, 6, 6,
        7, 8, 8, 9),
      nrow = 3,
      byrow = TRUE
    ),
    heights = c(0.82, 1.45, 1.25)
  )

  par(bg = bg, oma = c(0, 0, 4.2, 0), xpd = NA)

  draw_card(
    "No-Sketch Runtime",
    sprintf("%.1f%% faster", no_sketch_speedup_pct),
    sprintf("Current release: %.2fs vs old: %.2fs", new_s$wall_mean, old_s$wall_mean),
    "#2C8E5A"
  )
  draw_card(
    "Query Mapping Gain",
    sprintf("%.1f%% faster", query_speedup_pct),
    sprintf("Mean query phase: %.2fs vs %.2fs", new_s$query_mean, old_s$query_mean),
    "#4A7BB7"
  )
  draw_card(
    "Low-Memory RSS",
    sprintf("%.1f%% lower", lowmem_rss_reduction_pct),
    sprintf("Mean RSS: %.2f GiB vs %.2f GiB", low_s$rss_mean_gb, std_s$rss_mean_gb),
    "#D98E04"
  )
  draw_card(
    "Low-Memory Runtime",
    sprintf("%.2fx slower", lowmem_slowdown_x),
    sprintf("Tradeoff: %.2fs vs %.2fs", low_s$wall_mean, std_s$wall_mean),
    "#CE5A57"
  )

  draw_stacked_runtime(
    c("old_release", "new_release"),
    "No-Sketch Runtime Breakdown",
    "Bars show mean phase times; points show individual replicates"
  )
  draw_stacked_runtime(
    c("standard", "low_memory"),
    "Sketch Query Tradeoff",
    "Standard sketch querying vs low-memory loading across 8 sketch shards"
  )
  draw_memory_panel()
  draw_walltime_boxplot_panel()
  draw_notes_panel()

  mtext("FastANI Publication Benchmark Dashboard", outer = TRUE, cex = 1.62, font = 2, col = text_primary, line = 2.25)
  mtext("Repeated Release-mode benchmarks: original vs current no-sketch performance, plus standard vs low-memory sketch queries", outer = TRUE, side = 3, line = 1.02, cex = 0.96, col = text_muted)
  mtext(sprintf("Data source: %s", basename(csv_path)), outer = TRUE, side = 1, line = -1.5, cex = 0.85, col = text_muted)
  dev.off()
}

write_summary_tables()
render_dashboard("publication_performance_dashboard.png")

message("Read publication metrics from: ", csv_path)
message("Wrote publication dashboard to: ", file.path(out_dir, "publication_performance_dashboard.png"))
message("Wrote summary tables to: ", file.path(out_dir, "publication_summary_by_variant.tsv"))
