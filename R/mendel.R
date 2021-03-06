library(ggplot2)
library(gridExtra)
library(plyr)

calc_mendel <- function(x) {
  return( with(x, length(which(N>0))/length(N)) )
}

parse_imen <- function(x) {
  read.table(x, header=T)
}

"%&%" <- function(a,b) paste(a, b, sep="")


args <- commandArgs(trailing=TRUE)

atlas.base <- args[1]
gatk.base <- args[2]
freebayes.base <- args[3]
mpileup.base <- args[4]
cges.base <- args[5]
pdf.file <- args[6]

## look at mendelian inconsistencies per trio
atlas.fmen <- read.table(atlas.base %&% ".fmendel", header=T)
gatk.fmen <- read.table(gatk.base %&% ".fmendel", header=T)
freebayes.fmen <- read.table(freebayes.base %&% ".fmendel", header=T)
mpileup.fmen <- read.table(mpileup.base %&% ".fmendel", header=T)
consensus.fmen <- read.table(cges.base %&% ".fmendel", header=T)


## look at mendelian inconsistencies per locus
atlas.lmen <- read.table(atlas.base %&% ".lmendel", header=T)
gatk.lmen <- read.table(gatk.base %&% ".lmendel", header=T)
freebayes.lmen <- read.table(freebayes.base %&% ".lmendel", header=T)
mpileup.lmen <- read.table(mpileup.base %&% ".lmendel", header=T)
consensus.lmen <- read.table(cges.base %&% ".lmendel", header=T)

## count the total number of variants in the set 
freebayes.mvar <- length(freebayes.lmen$N)
consensus.mvar <- length(consensus.lmen$N)
atlas.mvar <- length(atlas.lmen$N)
mpileup.mvar <- length(mpileup.lmen$N)
gatk.mvar <- length(gatk.lmen$N)



trio_mvar <- list(atlas.mvar*sum(as.numeric(atlas.fmen$CHLD)),
             gatk.mvar*sum(as.numeric(gatk.fmen$CHLD)),
             freebayes.mvar*sum(as.numeric(freebayes.fmen$CHLD)),
             mpileup.mvar*sum(as.numeric(mpileup.fmen$CHLD)),
             consensus.mvar*sum(as.numeric(consensus.fmen$CHLD)))

locus_mvar <- list(atlas.mvar, gatk.mvar, freebayes.mvar, mpileup.mvar, consensus.mvar)

## format numerical data
atlas.lmen$N <- as.numeric(atlas.lmen$N)
gatk.lmen$N <- as.numeric(gatk.lmen$N)
freebayes.lmen$N <- as.numeric(freebayes.lmen$N)
mpileup.lmen$N <- as.numeric(mpileup.lmen$N)
consensus.lmen$N <- as.numeric(consensus.lmen$N)

atlas.fmen$N <- as.numeric(atlas.fmen$N)
gatk.fmen$N <- as.numeric(gatk.fmen$N)
freebayes.fmen$N <- as.numeric(freebayes.fmen$N)
mpileup.fmen$N <- as.numeric(mpileup.fmen$N)
consensus.fmen$N <- as.numeric(consensus.fmen$N)


## throw data into one large dataframe
callers <- list( 'Atlas', 'GATK', 'Freebayes', 'Mpileup', 'CGES')
fmendel.dat <- list(atlas.fmen$N,
                    gatk.fmen$N,
                    freebayes.fmen$N,
                    mpileup.fmen$N,
                    consensus.fmen$N)
lmendel.dat <- list(which(atlas.lmen$N>0),
                    which(gatk.lmen$N > 0),
                    which(freebayes.lmen$N > 0),
                    which(mpileup.lmen$N > 0),
                    which(consensus.lmen$N > 0))
mendel <- data.frame( trio_error_rate = (unlist(lapply(fmendel.dat, sum)) / unlist(trio_mvar)) * 100,
                      locus_error_rate = (unlist(lapply(lmendel.dat, length)) / unlist(locus_mvar)) * 100,
                      Callers = unlist(callers)) 

mendel$locus_order_callers <- reorder(mendel$Callers, mendel$locus_error_rate)
mendel$trio_order_callers <- reorder(mendel$Callers, mendel$trio_error_rate)

## tMer data manipulation
dat <- list(atlas.fmen, gatk.fmen, freebayes.fmen, mpileup.fmen, consensus.fmen)
## uniquify errors column names
dat <- Map( function(dataf, newname) rename(dataf, c("N"=newname)), dat, callers )
## Merge them into a single data frame properly ordered by sample
dat <- Reduce( function(...) merge(..., by.x=c('FID','PAT', 'MAT', 'CHLD'), by.y=c('FID', 'PAT', 'MAT', 'CHLD'), suffixes), dat )
plt.dat <- stack( dat, select = unlist(callers) )
plt.dat$ind <- factor(plt.dat$ind, levels = callers)
tmer_plt <- ggplot(plt.dat, aes(x=values, fill=ind)) + facet_grid( ind ~ . ,scale= "free") +
        geom_histogram(binwidth=100) +
        xlab('# of Mendelian errors') + ylab('# of trios') +
        theme_bw()

## plot dat graph
locus_plt <- ggplot( mendel, aes(x=locus_order_callers, y=locus_error_rate, fill=Callers) ) + 
          geom_bar(stat="identity", show_guide = FALSE) +
          theme_bw() +
          xlab("Caller") +
          ylab("% of Sites with >1 Mendelian Errors") 

trio_plt <- ggplot( mendel, aes(x=locus_order_callers, y=trio_error_rate, fill=Callers) ) + 
          geom_bar(stat="identity", show_guide = FALSE) +
          theme_bw() +
          xlab("Caller") +
          ylab("% of Proband Genotypes with Mendelian errors") 

print("Mendel")
print(mendel)

raw_ranges <- lapply(dat[c('Atlas', 'GATK', 'Freebayes', 'Mpileup', 'CGES')], range)
ranges <- lapply(raw_ranges, function(x) 100*(x/(139897)))
print(ranges)

pdf(pdf.file)
show(locus_plt)
show(trio_plt)
show(tmer_plt)
dev.off()
