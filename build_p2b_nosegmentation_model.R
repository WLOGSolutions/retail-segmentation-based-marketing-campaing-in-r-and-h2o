.libPaths("libs")

library(data.table)
library(h2o)
library(bit64)
library(pROC)
library(logging)

source("find_best_model.R")

logging::basicConfig()


h2o_local <- h2o.init(nthreads = 4, 
                      max_mem_size = "6g")
h2o.removeAll()

loginfo("--> H2O started")

set.seed(1234)

retail_train <- h2o.importFile(path = "data/retail_train.csv",
                               destination_frame = "retail_train",
                               header = TRUE,
                               sep = ";",
                               parse = TRUE)

retail_test <- h2o.importFile(path = "data/retail_test.csv",
                              destination_frame = "retail_test",
                              header = TRUE,
                              sep = ";",
                              parse = TRUE)

loginfo("--> Datasets imported into H2O cluster")

predictors <- setdiff(colnames(retail_train),
                      c("id",
                        "purchased"))
purchased_var <- "purchased"

best_model <- find_best_classifier_model(
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

saveRDS(object = list(roc =  pROC::roc(as.data.table(retail_test)[,  purchased],
                                       as.data.table(h2o.predict(object = best_model$model, newdata = retail_test))[,  TRUE.])),
        file = "export/best_nosegs_model.RDS")
