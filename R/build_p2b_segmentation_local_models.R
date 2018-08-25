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

retail_test <- h2o.importFile(path = file.path(script_path, "..", "data/retail_test.csv"),
                              destination_frame = "retail_test",
                              header = TRUE,
                              sep = ";",
                              parse = TRUE)

loginfo("--> Datasets imported into H2O cluster")

loginfo("--> Datasets imported into H2O cluster")

predictors <- setdiff(colnames(retail_train),
                      c("id",
                        "purchased"))
purchased_var <- "purchased"

segmentation_vars <- colnames(retail_train)[grep(pattern = "^frq_.*_",
                                                 x = colnames(retail_train))] 

segmentation_models <- segmentationmodels::build_segmentation_models(training_frame = h2o.rbind(retail_train,
                                                                            retail_test),
                                                 segmentation_vars = segmentation_vars,
                                                 cluster_cnts = 2:5,
                                                 rounds = 20)
loginfo("--> Built segmentation models")

segmentation_preds <- segmentationmodels::predict_segmentation_models(segmentation_models = segmentation_models,
                                                  train_df = retail_train,
                                                  test_df = retail_test)

loginfo("--> Predicted segmentation models")

segs_models <- lapply(X = segmentation_preds,
                      FUN = function(segmentation_pred) {
                        retail_train$segment_assignment <- segmentation_pred$segment_train$predict
                        
                        seg_local_models <- list()
                        
                        for (seg_id in 0:(segmentation_pred$k - 1)) {
                          local_seg_model <- h2o.glm(model_id = sprintf("glm_model_k_%s_seg_id_%s",
                                                                        segmentation_pred$k,
                                                                        seg_id),
                                                     training_frame = retail_train[retail_train$segment_assignment == seg_id, ],
                                                     x = predictors,
                                                     y = purchased_var,
                                                     family  = "binomial")
                          
                          seg_local_models[[ seg_id + 1]] <- list(
                            seg_id = seg_id,
                            local_seg_model = local_seg_model)
                        }
                        
                        return(list(seg_local_models = seg_local_models,
                                    segmentation_pred = segmentation_pred))
                      })

loginfo("--> Built local models for segments")

segs_preds <- lapply(X = segs_models,
                     FUN = function(seg_local_models) {
                       retail_test$segment_assignment <- seg_local_models$segmentation_pred$segment_test$predict
                       
                       list(
                         preds = Reduce(
                           f = function(left, seg_model) {
                             local_pred <- h2o.cbind(h2o.predict(object = seg_model$local_seg_model,
                                                                 newdata = retail_test[retail_test$segment_assignment  == seg_model$seg_id, ]),
                                                     retail_test[retail_test$segment_assignment  == seg_model$seg_id,  ])
                             if (is.null(left)) {
                               return(local_pred)
                             } else {
                               return(h2o.rbind(left, local_pred))
                             }
                           },
                           x = seg_local_models$seg_local_models,
                           init = NULL),
                         k = seg_local_models$segmentation_pred$k)})

best_model <- Reduce(x = lapply(X = segs_preds,
                                FUN = function(seg_pred) {
                                  model_roc <- pROC::roc(as.data.table(seg_pred$preds[, "purchased"])$purchased,
                                                         as.data.table(seg_pred$preds[, "TRUE"])$TRUE.)
                                  model_auc <- pROC::auc(model_roc)
                                  
                                  loginfo("k = %s with AUC = %s",
                                          seg_pred$k,
                                          model_auc)
                                  
                                  list(
                                    auc = model_auc,
                                    roc = model_roc,
                                    k = seg_pred$k)}),
                     init = NULL,
                     f = function(left, local_res) {
                       if (is.null(left)) {
                         return(local_res)
                       }
                       
                       if (local_res$auc > left$auc) {
                         return(local_res)
                       } else {
                         return(left)
                       }
                     })

loginfo("--> Best model [k = %s] with test AUC=%s", 
        best_model$k,
        best_model$auc)

saveRDS(best_model, file = file.path(script_path, "../export/best_segs_local_models.RDS"))
