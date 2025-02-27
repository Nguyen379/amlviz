library(shiny)
library(shinyjs)
library(shinythemes)
library(plotly)
library(ggplot2)
library(ggbeeswarm)
library(DBI)
library(RMySQL)
source("functions.R")


# database
# loaded once per server rather than every client
database <- dbConnect(MySQL(),
                      user = Sys.getenv("DB_USER"),
                      password = Sys.getenv("DB_PASSWORD"),
                      dbname = Sys.getenv("DB_NAME"),
                      host = Sys.getenv("DB_HOST"),
                      port = as.integer(Sys.getenv("DB_PORT")))
print("Connected to database")

query <- "SELECT * FROM datasets;"
dataset <- dbGetQuery(database,query)

# Generate all available plots and gene dropdowns
available_plots <- new.env(hash=TRUE)
geneList <- new.env(hash=TRUE)

for(i in dataset$Study_ID) {
  # Generate gene dropdown if cache doesn't exist
  if(!file.exists(paste0("gene_list/", i, ".txt"))) {
    query <- geneQuery(factors = c("Gene"), table = i, unique = TRUE, sort = TRUE)
    write.table(dbGetQuery(database,query), paste0("gene_list/", i, ".txt"),sep="\t",row.names=FALSE,col.names=FALSE)
  }
  geneList[[i]] <- read.delim(paste0("gene_list/", i, ".txt"), header = FALSE, sep = "\t", dec = ".")
  available_plots[[i]] <- c("Multiplot")
}

# Add other factors to available plots
dbFields <- dbListFields(database, "clinical")
dbFields <- dbFields[!(dbFields %in% c("UPN","Age","Sex"))] # Removes UPN and other columns that can't be plotted
for(i in dbFields) {
  query <- paste0("SELECT DISTINCT P.Study_ID FROM clinical U INNER JOIN mappings P on P.UPN = U.UPN WHERE U.", i, " IS NOT NULL")
  datasetPlots <- dbGetQuery(database, query)
  for(j in datasetPlots$Study_ID) {
    available_plots[[j]] <- append(available_plots[[j]], i)
  }
}

# Add Mutations option if dataset is in mutation table
# TODO: Make dynamic again
for(i in dataset$Study_ID) {
  available_plots[[i]] <- append(available_plots[[i]], "Mutations")
}
