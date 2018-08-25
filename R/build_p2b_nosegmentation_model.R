# Detect proper script_path (you cannot use args yet as they are build with tools in set_env.r)
script_path <- (function() {
  args <- commandArgs(trailingOnly = FALSE)
  script_path <- dirname(sub("--file=", "", args[grep("--file=", args)]))
  if (!length(script_path)) {
    return("R")
  }
  if (grepl("darwin", R.version$os)) {
    base <- gsub("~\\+~", " ", base) # on MacOS ~+~ in path denotes whitespace
  }
  return(normalizePath(script_path))
})()

# Setting .libPaths() to point to libs folder
source(file.path(script_path, "set_env.R"), chdir = T)

config <- load_config()
args <- args_parser()

library(data.table)
library(h2o)
library(logging)

h2o_local <- h2o.init(nthreads = 4, 
                      max_mem_size = "6g")
h2o.removeAll()

loginfo("--> H2O started")

set.seed(1234)

retail_train <- h2o.importFile(path = file.path(script_path, "../data/retail_train.csv"),
                               destination_frame = "retail_train",
                               header = TRUE,
                               sep = ";",
                               parse = TRUE)

retail_test <- h2o.importFile(path = file.path(script_path, "../data/retail_test.csv"),
                              destination_frame = "retail_test",
                              header = TRUE,
                              sep = ";",
                              parse = TRUE)

loginfo("--> Datasets imported into H2O cluster")

predictors <- setdiff(colnames(retail_train),
                      c("id",
                        "purchased"))
purchased_var <- "purchased"

best_model <- segmentationmodels::find_best_classifier_model(
  model_quality_measure = "AUC",
  algorithm = "glm",
  grid_id = "glm_grid",
  training_frame = retail_train,
  validation_frame = retail_test,
  x = predictors,
  y = purchased_var,
  family  = "binomial")

h2o.saveModel(best_model$model, path = "export", force = TRUE)

loginfo("--> Best model exported into export folder")

loginfo("--> Best model with test AUC=%s", h2o.auc(best_model$model, valid = TRUE))

saveRDS(object = list(roc =  pROC::roc(data.table::as.data.table(retail_test)[,  purchased],
                                       data.table::as.data.table(h2o.predict(object = best_model$model, newdata = retail_test))[,  TRUE.])),
        file = file.path(script_path, "../export/best_nosegs_model.RDS"))
