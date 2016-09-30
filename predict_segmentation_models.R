predict_segmentation_models <- function(segmentation_models, train_df, test_df) {
    lapply(X = segmentation_models,
           FUN = function(segmentation_model) {
               list(
                   k = segmentation_model@parameters$k,
                   segment_train = h2o.assign(h2o.predict(segmentation_model, newdata = train_df),
                                              key = sprintf("retail_train_segment_assignment_k_%s",
                                                            segmentation_model@parameters$k)),
                   segment_test = h2o.assign(h2o.predict(segmentation_model, newdata = test_df),
                                             key = sprintf("retail_test_segment_assignment_k_%s",
                                                           segmentation_model@parameters$k))
               )
           })  
}
