# Showcase: on segmentation importance for marketing campaign in retail using [GNU R](https://www.r-project.org/) and [H2O](http://www.h2o.ai/).

## Business story behind the showcase

A retail chain "At the corner" sales different types of products. They would like to introduce a new product. They decided to go with an e-mail marketing campaign. To optimize campaign costs and customers' comfort they decided to carefully select customers that would be contacted in the campaign.

As an analytical driven company "At the corner" conducted a pilot campaign to gather data (stored in **data/retail_train.csv** file). The data was gathered for 10 000 customers with an information (column **purchased**) whether a customer opened an email and clicked in a promoting banner.

## Approach
The showcase presents two main things:

* importance of segmentation for modeling customers' propensity to buy
* how to use segmentation within predictive model

### What is segmentation in predictive modeling?

Technically segmentation is an unsupervised approach for discovering groups of similar objects according to some distance/similarity
measure. Problem with segmentation is that final segments (aka clusters) highly depend on both variables and **the distance**. Moreover it is almost impossible to formalize requirements for **being good segmentation**. 

The objective in selecting variables and distance measure that they capture possible meaningful differences in behavior of segmented entities.

### How one can use segmentation to improve predictive models?

As we wrote above any segmentation algorithm (e.g. [k-means](https://en.wikipedia.org/wiki/K-means_clustering)) discovers a new *latent* variable representing segment membership. This transformation is too difficult for a classification algorithm to generate it. Therefore one needs to use a two stage approach:

1. Generate segments
2. Build predictive model(s)

Technically segmentation membership can be used in a predictive model in two ways. First approach is to use segment membership as an extra predictor. Second approach is to build a local predictive model for data from each segment.

### Generating optimal segmentation (with given number of segments) with [H2O](http://h2o.ai)

[H2O's implementation of k-means algorithm](https://github.com/h2oai/h2o-3/blob/master/h2o-docs/src/product/tutorials/kmeans/kmeans.md) (as in many other solutions) is randomized - different runs gives different results. Typical practice is to repeat the algorithm few times (we used 20 iterations) and select
segments that are optimal. With given number of segments optimal segmentation is the one with minimal avg. within sum of squares metric.

### Selecting number of segments

According to our experience a very informative method for selecting number of segments is to use [*silhouette*](https://en.wikipedia.org/wiki/Silhouette_(clustering)) measure. Unfortunately this measure is not available in [H2O](http://h2o.ai). And even if it were available it is also very computing intensive. We decided to 
select number of segments using predictive powerof the final models.

### Obtained results

We have built three models (all were logistic regression models):

* **no segmentation** - the model was built without segmentation phase (see script `build_p2b_nosegmentation_model.R`)
* **segment var** - the model was built using with added extra predictor `segment_assignment` (see script `build_p2b_segmentation_model.R`)
* **segment local models** - for each segment we built a local model and combined their output for final prediction (see script `build_p2b_segmentation_local_models.R`)

All models were built using training data stored in `data\retail_train.csv` and tested on a test data set (stored in `data\retail_test.csv`). The results were as follows:

* **no segmentation**: AUC = 0.6461
* **segmentation var**: AUC = 0.6470
* **local models**: AUC = 0.6515

This means that local models for each segment gave the best result. 

Let's check if [DeLong's test](https://www.jstor.org/stable/2531595) confirm that improvements in AUCs are significant. Checking output from `compare_models.R` we can see that p-value is around 0.00071 when comparing *no segmentation* and *local models* which indicates that segmentation is important. It is worth to mention that comparing *segmentation var* with *local models* results in p-value 0.05681, which also indicates significant  improvement. We have also tested other predictive algorithms (like *GBM* or *RF*) but could not get AUC bigger than local *GLMs* for segments.

## Prerequisites

I have used R version 3.2.3 with the following R packages:

* [data.table](https://cran.r-project.org/web/packages/data.table/index.html), version 1.9.6
* [h2o](http://www.h2o.ai/download/h2o/r), version 3.10.0.6
* [bit64](https://cran.r-project.org/web/packages/bit64/index.html), version 0.9-5
* [pROC](https://cran.r-project.org/web/packages/pROC/index.html), version 1.8

### Remark for Windows users

Instalation of the packages requires [Rtools](https://cran.r-project.org/bin/windows/Rtools/) compatible with your R version.

## Usage instruction

1. Install packages by running `source("install_packages.R")`
2. Run following scripts:

- `source("build_p2b_nosegmentation_model.R")` - builds model without segmentation (**no segmentation**)
- `source("build_p2b_segmentation_model.R")` - builds model (**segmentation var**) with extra predictor being a segment assignment
- `source("build_p2b_segmentation_local_models.R")` - builds local models for each segment (**local models**).
- `source("compare_models.R")` - compare statistical difference between  models
