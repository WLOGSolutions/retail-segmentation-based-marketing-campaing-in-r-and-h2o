# Showcase: on segmentation importance for marketing campaign in retail using [GNU R](https://www.r-project.org/) and [H2O](http://www.h2o.ai/).

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Showcase: on segmentation importance for marketing campaign in retail using [GNU R](https://www.r-project.org/) and [H2O](http://www.h2o.ai/).](#showcase-on-segmentation-importance-for-marketing-campaign-in-retail-using-gnu-rhttpswwwr-projectorg-and-h2ohttpwwwh2oai)
    - [Business story behind the showcase](#business-story-behind-the-showcase)
    - [Approach](#approach)
        - [What is segmentation in predictive modeling?](#what-is-segmentation-in-predictive-modeling)
        - [How one can use segmentation to improve predictive models?](#how-one-can-use-segmentation-to-improve-predictive-models)
        - [Generating optimal segmentation (with given number of segments) with [H2O](http://h2o.ai)](#generating-optimal-segmentation-with-given-number-of-segments-with-h2ohttph2oai)
        - [Selecting number of segments](#selecting-number-of-segments)
        - [Obtained results](#obtained-results)
    - [Prerequisities](#prerequisities)
        - [Remark for Windows users](#remark-for-windows-users)
    - [Usage instruction](#usage-instruction)
        - [Cloning project](#cloning-project)
        - [Prepare R Suite's project and install packages](#prepare-r-suites-project-and-install-packages)
        - [Run the scripts](#run-the-scripts)
			- [Running from R session](#running-from-r-session)
            - [Running from R cmd](#running-from-r-cmd)

<!-- markdown-toc end -->


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


## Prerequisities

To run the showcase you have to install:

* [R](https://www.r-project.org/) in version 3.5.1
* [R Suite](https://github.com/WLOGSolutions/RSuite/blob/master/docs/basic_workflow.md) in version [0.32-245](http://rsuite.io/RSuite_Download.php)

For machine learning I have used:

* [H2O](https://www.h2o.ai/) in version [3.20.0.2](http://h2o-release.s3.amazonaws.com/h2o/rel-wright/6/index.html)

**Remark**: [R Suite](http://rsuite.io) will take care of installing proper versions of the packages. See [Prerequ

### Remark for Windows users

Instalation of the packages requires [Rtools](https://cran.r-project.org/bin/windows/Rtools/) compatible with your R version.

## Usage instruction

### Cloning project

First you have to clone the project using `git`:
``` bash
git clone https://github.com/WLOGSolutions/retail-segmentation-based-marketing-campaing-in-r-and-h2o
```

This will create a directory `retail-segmentation-based-marketing-campaing-in-r-and-h2o`. Issue command

``` bash
cd retail-segmentation-based-marketing-campaing-in-r-and-h2o
```

### Prepare R Suite's project and install packages

Now you should prepare the project:

* Install dependencies for the project
* Build custom package(s) `segmentationmodels` with internal functions implemented

To install dependencies for the R Suite project you have to issue the following command in cmdline

```bash
rsuite proj depsinst
```

Now you can build custom package `segmentationmodels` with the following command:

```bash
rsuite proj build
```

More about R Suite you can read [here](http://rsuite.io/RSuite_Tutorial.php). Please be aware that there is an addin to [R Studio](https://rstudio.com) that gives you access to R Suite functionality from this great IDE.

### Run the scripts

You are ready to run the scripts. Be sure that your working directory is the main project directory.

##### Running from R session

You can run the scripts from an active R session with commands as below: 

* `source("R/build_p2b_nosegmentation_model.R")` - builds model without segmentation (**no segmentation**)
* `source("R/build_p2b_segmentation_model.R")` - builds model (**segmentation var**) with extra predictor being a segment assignment
* `source("R/build_p2b_segmentation_local_models.R")` - builds local models for each segment (**local models**).
* `source("R/compare_models.R")` - compare statistical difference between  models

##### Running from R cmd

I personally prefer using cmd line for running my R code. To run the scripts from within cmd you use the following scripts:

* `Rscript R/build_p2b_nosegmentation_model.R` - builds model without segmentation (**no segmentation**)
* `Rscript R/build_p2b_segmentation_model.R` - builds model (**segmentation var**) with extra predictor being a segment assignment
* `Rscript R/build_p2b_segmentation_local_models.R` - builds local models for each segment (**local models**).
* `Rscript R/compare_models.R` - compare statistical difference between  models
