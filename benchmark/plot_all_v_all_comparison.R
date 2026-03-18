args <- commandArgs(trailingOnly = TRUE)
csv_path <- if (length(args) >= 1) args[[1]] else 'benchmark/all_v_all_summary.csv'
out_path <- if (length(args) >= 2) args[[2]] else 'benchmark/plots/all_v_all_comparison.png'

df <- read.csv(csv_path, stringsAsFactors = FALSE)
num_cols <- c('output_rows','db_sec','query_sec','post_sec','wall_sec','user_cpu_sec','system_cpu_sec','cpu_percent','max_rss_kb','fs_in','fs_out')
for (col in num_cols) df[[col]] <- as.numeric(df[[col]])
df$other_sec <- pmax(0, df$wall_sec - df$db_sec - df$query_sec - df$post_sec)
df$max_rss_gb <- df$max_rss_kb / (1024*1024)
df$db_min <- df$db_sec / 60
df$query_min <- df$query_sec / 60
df$post_min <- df$post_sec / 60
df$other_min <- df$other_sec / 60
df$wall_min <- df$wall_sec / 60

a <- df$label
runtime_mat <- rbind(df$db_min, df$query_min, df$post_min, df$other_min)
rownames(runtime_mat) <- c('DB/load','Query map','Post map','Other overhead')
colnames(runtime_mat) <- a
cols <- c('#D55E00','#56B4E9','#CC79A7','#B3B3B3')
bar_cols <- c('#7F7F7F','#009E73','#E69F00')

png(out_path, width=2200, height=1400, res=170)
layout(matrix(c(1,1,2,3), nrow=2, byrow=TRUE), heights=c(1.4,1))
par(oma=c(0,0,3,0), bg='white')

par(mar=c(7,6,4,2)+0.1)
ymax <- max(colSums(runtime_mat)) * 1.20
mids <- barplot(runtime_mat, beside=FALSE, col=cols, border=NA, ylim=c(0,ymax), las=1, ylab='Minutes', main='All-v-all runtime breakdown (full genome list vs full genome list)', cex.names=0.95)
abline(h=pretty(c(0,ymax)), col='#E6EDF5')
mids <- barplot(runtime_mat, beside=FALSE, col=cols, border='#5E6B78', add=TRUE, axes=FALSE, axisnames=FALSE)
text(mids, colSums(runtime_mat), labels=sprintf('%.1f min', colSums(runtime_mat)), pos=3, cex=0.92)
legend('topright', legend=rownames(runtime_mat), fill=cols, bty='n', cex=0.9)
mtext(sprintf('Warm-cache run; rows %.2fM old vs %.2fM new sketch query', df$output_rows[1] / 1e6, df$output_rows[3] / 1e6), side=3, line=0.5, cex=0.9, col='#607286')

par(mar=c(6,6,4,2)+0.1)
mem_vals <- df$max_rss_gb
m1 <- barplot(mem_vals, col=bar_cols, border=NA, las=1, ylab='Peak RSS (GiB)', main='Peak memory', cex.names=0.95)
abline(h=pretty(c(0,max(mem_vals)*1.2)), col='#E6EDF5')
barplot(mem_vals, col=bar_cols, border='#5E6B78', add=TRUE, axes=FALSE, axisnames=FALSE)
text(m1, mem_vals, labels=sprintf('%.2f', mem_vals), pos=3, cex=0.9)

par(mar=c(8,6,4,2)+0.1)
cpu_vals <- df$cpu_percent
m2 <- barplot(cpu_vals, col=bar_cols, border=NA, las=1, ylab='CPU utilization (%)', main='CPU utilization', cex.names=0.95)
abline(h=pretty(c(0,max(cpu_vals)*1.15)), col='#E6EDF5')
barplot(cpu_vals, col=bar_cols, border='#5E6B78', add=TRUE, axes=FALSE, axisnames=FALSE)
text(m2, cpu_vals, labels=sprintf('%.0f%%', cpu_vals), pos=3, cex=0.9)
mtext('Measured with /usr/bin/time -v on Intel Xeon E5-2660 v3 host (20 physical cores)', side=1, line=6, cex=0.86, col='#607286')

mtext('FastANI all-v-all benchmark comparison', outer=TRUE, cex=1.5, font=2, line=1)
dev.off()
