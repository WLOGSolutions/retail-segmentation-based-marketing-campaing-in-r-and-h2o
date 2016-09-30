build_segmentation_models <- function(training_frame, segmentation_vars, cluster_cnts, rounds = 20) {
  segmentation_models <- list()
  
  for (cluster_cnt in cluster_cnts) {
    best_model <- NULL
    for (round in 1:rounds) {
      segmentation_model <- h2o.kmeans(training_frame = training_frame,
                                       x = segmentation_vars,
                                       k = cluster_cnt,
                                       model_id = sprintf("segmentation_model_%s", cluster_cnt),
                                       init = "PlusPlus",
                                       standardize = TRUE)
      model_withinss <- h2o.tot_withinss(segmentation_model)
      model_betweenss <- h2o.betweenss(segmentation_model)
      
      if (is.null(best_model)) {
        best_model <- list(
          segmentation_model = segmentation_model,
          tot_withinss = model_withinss,
          betweenss = model_betweenss)
      } else if (best_model$tot_withinss/best_model$betweenss > 
                 model_withinss/model_betweenss) {
        best_model <- list(
          segmentation_model = segmentation_model,
          tot_withinss = model_withinss,
          betweenss = model_betweenss)
      }
    }
    segmentation_models[[cluster_cnt]] <- best_model$segmentation_model
  }
  
  Filter(f = function(m) {!is.null(m)}, segmentation_models)
}
