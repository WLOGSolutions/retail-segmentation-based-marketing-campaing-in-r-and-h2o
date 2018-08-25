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

best_nosegs_model <- readRDS(file.path(script_path, "../export/best_nosegs_model.RDS"))
best_segsvar_model <- readRDS(file.path(script_path, "../export/best_segsvar_model.RDS"))
best_segs_local_models <- readRDS(file.path(script_path, "../export/best_segs_local_models.RDS"))


pROC::roc.test(roc1 = best_nosegs_model$roc, 
               roc2 = best_segsvar_model$roc,
               alternative = "less")

pROC::roc.test(roc1 = best_nosegs_model$roc, 
               roc2 = best_segs_local_models$roc,
               alternative = "less")

pROC::roc.test(roc1 = best_segsvar_model$roc, 
               roc2 = best_segs_local_models$roc,
               alternative = "less")
