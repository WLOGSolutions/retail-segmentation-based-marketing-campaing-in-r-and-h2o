.libPaths("libs")

library(data.table)
library(h2o)
library(bit64)
library(pROC)
library(logging)

source("find_best_model.R")
source("build_segmentation_models.R")
source("predict_segmentation_models.R")

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

segmentation_vars <- colnames(retail_train)[grep(pattern = "^frq_.*_",
                                                 x = colnames(retail_train))] 

segmentation_models <- build_segmentation_models(training_frame = h2o.rbind(retail_train,
                                                                            retail_test),
                                                 segmentation_vars = segmentation_vars,
                                                 cluster_cnts = 2:5,
                                                 rounds = 20)

loginfo("--> Built segmentation models")

segmentation_preds <- predict_segmentation_models(segmentation_models = segmentation_models,
                                                  train_df = retail_train,
                                                  test_df = retail_test)

loginfo("--> Predicted segmentation models")

seg_var_models <- lapply(X = segmentation_preds,
                         FUN = function(segmentation_pred) {
                           retail_train$segment_assignment <- segmentation_pred$segment_train$predict
                           retail_test$segment_assignment <- segmentation_pred$segment_test$predict
                           
                           best_seg_model <- find_best_classifier_model(
                             model_quality_measure = "AUC",
                             algorithm = "glm",
                             grid_id = sprintf("glm_grid_k_%s",
                                               segmentation_pred$k),
                             training_frame = retail_train,
                             validation_frame = retail_test,
                             x = c(predictors,
                                   "segment_assignment"),
                             y = purchased_var,
                             family  = "binomial")
                           return(list(best_model = best_seg_model,
                                       segmentation_pred = segmentation_pred))
                         })

loginfo("--> Built models with added segmentation assignment")

best_global_model <- Reduce(x = seg_var_models,
                            init = list(AUC = 0,
                                        best_model = NULL,
                                        segmentation_pred = NULL),
                            f = function(left, right) {
                              right_auc <- h2o.auc(object = right$best_model$model, valid = TRUE)
                              if (right_auc > left$AUC) {
                                return(list(
                                  AUC = right_auc,
                                  best_model = right$best_model,
                                  segmentation_pred = right$segmentation_pred))
                              } else return(left)
                            })

loginfo("--> Best model [k = %s] with test AUC=%s", 
        best_global_model$segmentation_pred$k,
        best_global_model$AUC, xval = TRUE)

retail_test$segment_assignment <- best_global_model$segmentation_pred$segment_test$predict
saveRDS(list(roc = pROC::roc(as.data.table(retail_test)[, purchased],
                             as.data.table(h2o.predict(best_global_model$best_model$model, newdata = retail_test))[, TRUE.])),
        file = "export/best_segsvar_model.RDS")
