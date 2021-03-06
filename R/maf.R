library(ggplot2)
library(grid)

"%&%" <- function(a,b) paste(a, b, sep="")

parse_file <- function(x) {
  read.table(x, header=T)
}

args <- commandArgs(trailing=TRUE)

atlas.base <- args[1]
gatk.base <- args[2]
freebayes.base <- args[3]
mpileup.base <- args[4]
cges.base <- args[5]
pdf.file <- args[6]

callers <- list( 'Atlas', 'GATK', 'Freebayes', 'Mpileup', 'CGES')
files <- list(atlas.base %&% '.frq',
              gatk.base %&% '.frq',
              freebayes.base %&% '.frq',
              mpileup.base %&% '.frq',
              cges.base %&% '.frq')

## read in tables
dat <- lapply(files, parse_file)

## drop unnecessary columns
dat <- Map( function(dataf) dataf[ ,"MAF" ], dat )

## and ye shall be named
names(dat) <- callers

plt.dat <- stack(dat, callers)

plt <- ggplot(plt.dat, aes(x=values, fill=ind)) + facet_grid( ind ~ . ,scale= "free") +
      geom_histogram(show_guide = FALSE) +
      xlab('MAF') +
      ylab('Counts')

plt2 <- ggplot(plt.dat, aes(values, colour=ind)) + stat_ecdf() +
      labs(x='MAF', y='Proportion of Variants with MAF <= x') +
      theme_bw()

plt2_zoom <- ggplot(plt.dat, aes(values, colour=ind)) + stat_ecdf(geom="step") +
      scale_x_continuous(limits=c(0.0, 0.1)) +
      labs(x='MAF', y='Proportion of Variants with MAF <= x') +
      theme_bw() + theme(legend.position="none")

#A viewport taking up a fraction of the plot area
vp <- viewport(width = 0.4, height = 0.4, x = 0.5, y = 0.3)

pdf(pdf.file)
show(plt)
show(plt2)
print(plt2)
print(plt2_zoom, vp = vp)
dev.off()

