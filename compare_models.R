.libPaths("libs")

library(data.table)
library(h2o)
library(bit64)
library(pROC)
library(logging)


best_nosegs_model <- readRDS("export/best_nosegs_model.RDS")
best_segsvar_model <- readRDS("export/best_segsvar_model.RDS")
best_segs_local_models <- readRDS("export/best_segs_local_models.RDS")


pROC::roc.test(roc1 = best_nosegs_model$roc, 
               roc2 = best_segsvar_model$roc,
               alternative = "less")

pROC::roc.test(roc1 = best_nosegs_model$roc, 
               roc2 = best_segs_local_models$roc,
               alternative = "less")

pROC::roc.test(roc1 = best_segsvar_model$roc, 
               roc2 = best_segs_local_models$roc,
               alternative = "less")
