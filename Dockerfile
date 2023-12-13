FROM public.ecr.aws/lts/ubuntu:20.04

RUN export LANGUAGE="en_US.UTF-8" && \
    ln -s /usr/share/zoneinfo/UTC /etc/localtime && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get update && \
    apt-get install -y nodejs npm && \
    apt-get install -y software-properties-common


RUN npm init -y && \
    npm install express 

RUN apt-get -qq update -y \
 && apt-get -qq upgrade -y \
 && apt-get -qq --fix-missing install -y \
            curl \
            ess \
            gdal-bin \
            git \
            jq \
            libgdal-dev \
            libproj-dev \
            libgeos-dev \
            libudunits2-dev \
            libv8-dev \
            libcairo2-dev \
            libnetcdf-dev \
            libspatialindex-dev \
            littler \
            python3 \
            python3-pip \
            python3-gdal \
            python3-boto3 \
            python3-pandas \
            r-base-core \
            r-base-dev \
 && pip3 install --upgrade pip \
 && apt-get autoclean && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


#RUN R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/gtable/gtable_0.3.0.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/rlang/rlang_0.4.12.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/glue/glue_1.6.0.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/cli/cli_3.1.0.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/lifecycle/lifecycle_1.0.1.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/fansi/fansi_1.0.0.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/utf8/utf8_1.2.2.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/ellipsis_0.3.2.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/vctrs/vctrs_0.3.8.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/crayon/crayon_1.4.2.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/pillar/pillar_1.6.4.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/farver/farver_2.1.0.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/labeling/labeling_0.4.2.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/colorspace/colorspace_2.0-2.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/munsell_0.5.0.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/R6_2.5.1.tar.gz")' && \
#    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/RColorBrewer/RColorBrewer_1.1-2.tar.gz")'

RUN R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/gtable/gtable_0.3.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/rlang/rlang_0.4.12.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/glue/glue_1.6.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/cli/cli_3.1.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/lifecycle/lifecycle_1.0.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/fansi/fansi_1.0.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/utf8/utf8_1.2.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/ellipsis_0.3.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/vctrs/vctrs_0.3.8.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/crayon/crayon_1.4.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/pillar/pillar_1.6.4.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/farver/farver_2.1.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/labeling/labeling_0.4.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/colorspace/colorspace_2.0-2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/munsell_0.5.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/R6_2.5.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/RColorBrewer/RColorBrewer_1.1-2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/viridisLite/viridisLite_0.4.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/scales/scales_1.1.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/magrittr/magrittr_2.0.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/pkgconfig_2.0.3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/tibble/tibble_3.1.6.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/isoband/isoband_0.2.5.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/scales/scales_1.1.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/withr/withr_2.4.3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/digest/digest_0.6.29.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/ggplot2/ggplot2_3.3.5.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/png/png_0.1-7.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/jpeg/jpeg_0.1-9.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/latticeExtra/latticeExtra_0.6-29.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/acepack/acepack_1.4.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/gridExtra_2.3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/stringi/stringi_1.7.6.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/stringr/stringr_1.4.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/base64enc_0.1-3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/fastmap/fastmap_1.1.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/ellipsis_0.3.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/htmltools/htmltools_0.5.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/jsonlite/jsonlite_1.7.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/yaml/yaml_2.2.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/htmlwidgets/htmlwidgets_1.5.4.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/evaluate/evaluate_0.14.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/xfun/xfun_0.29.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/highr/highr_0.9.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/knitr/knitr_1.37.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/backports_1.4.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/checkmate/checkmate_2.0.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/rstudioapi/rstudioapi_0.13.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/htmlTable/htmlTable_2.4.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/viridis/viridis_0.6.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/Formula/Formula_1.2-4.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/data.table/data.table_1.14.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/survival/survival_3.2-13.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/Hmisc/Hmisc_4.6-0.tar.gz")'

RUN R -e 'install.packages("https://cran.r-project.org/src/contrib/carData_3.0-5.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/Rcpp/Rcpp_1.0.7.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/minqa/minqa_1.2.4.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/nloptr/nloptr_1.2.2.3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_1.4-0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/RcppEigen/RcppEigen_0.3.3.9.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/lme4/lme4_1.1-27.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/numDeriv_2016.8-1.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/DBI/DBI_1.1.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/mitools_2.4.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/survey/survey_4.1-1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/estimability/estimability_1.3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/insight/insight_0.15.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/effects/effects_4.2-1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/bitops_1.0-7.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/caTools_1.18.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/gtools/gtools_3.9.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/gdata/gdata_2.18.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/gplots/gplots_3.1.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/abind_1.4-5.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/coda_0.19-4.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/arm/arm_1.12-2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/generics/generics_0.1.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/purrr/purrr_0.3.4.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/tidyselect/tidyselect_1.1.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/dplyr/dplyr_1.0.7.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/interactionTest_1.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/interplot_0.2.3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/SparseM_1.81.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/MatrixModels/MatrixModels_0.5-0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/matrixStats/matrixStats_0.61.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/proxy/proxy_0.4-26.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/e1071/e1071_1.7-9.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/iterators/iterators_1.0.13.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/foreach/foreach_1.5.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/data.table/data.table_1.14.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/ModelMetrics_1.2.2.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/plyr/plyr_1.8.6.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/pROC/pROC_1.18.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/gower/gower_0.2.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/globals/globals_0.14.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/listenv/listenv_0.8.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/parallelly/parallelly_1.30.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/future/future_1.23.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/future.apply/future.apply_1.8.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/progressr/progressr_0.10.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/SQUAREM_2021.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/lava/lava_1.6.10.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/prodlim/prodlim_2019.11.13.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/ipred/ipred_0.9-12.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/cpp11/cpp11_0.4.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/lubridate/lubridate_1.8.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/tidyr/tidyr_1.1.4.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/timeDate/timeDate_3043.102.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/recipes/recipes_0.1.17.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/reshape2_1.4.4.tar.gz")' && \ 
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/caret/caret_6.0-90.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/RcppArmadillo/RcppArmadillo_0.10.7.5.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/conquer/conquer_1.2.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/quantreg/quantreg_5.86.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/cubature/cubature_2.0.4.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/quadprog_1.5-8.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/np/np_0.60-11.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/broom/broom_0.7.11.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/pbkrtest/pbkrtest_0.5.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/forcats/forcats_0.3.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/hms/hms_1.1.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/clipr/clipr_0.4.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/crayon/crayon_1.4.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/bit_4.0.5.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/bit64/bit64_0.9-7.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/cpp11/cpp11_0.4.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/tzdb/tzdb_0.2.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/assertthat/assertthat_0.2.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/prettyunits/prettyunits_1.0.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/progress_1.2.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/vroom/vroom_1.5.7.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/readr/readr_2.1.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/haven/haven_2.4.3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/curl/curl_4.3.3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/rematch/rematch_1.0.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/cellranger_1.1.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/readxl/readxl_1.3.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/zip/zip_2.2.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/openxlsx/openxlsx_4.1.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/rio/rio_0.5.10.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/sp/sp_1.4-6.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/maptools/maptools_1.1-2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/car/car_3.0-12.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/phia_0.2-1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/reshape2_1.4.4.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/rprojroot/rprojroot_2.0.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/desc/desc_1.4.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/pkgload/pkgload_1.2.4.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/cpp11/cpp11_0.4.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/brew/brew_1.0-6.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/commonmark/commonmark_1.7.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/xml2/xml2_1.3.3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/cli/cli_3.1.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/roxygen2/roxygen2_7.1.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/e1071/e1071_1.7-9.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/wk/wk_0.6.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/s2/s2_1.0.7.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/classInt/classInt_0.4-3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/DBI/DBI_1.1.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/units/units_0.8-0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/sf_1.0-14.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/mvtnorm/mvtnorm_1.1-3.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/lmec/lmec_1.0.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/rjson/rjson_0.2.20.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/rgdal/rgdal_1.5-28.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/RANN_2.6.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/argparser_0.7.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/rgeos/rgeos_0.5-9.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/vec2dtransf/vec2dtransf_1.1.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/littler/littler_0.3.15.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/MASS/MASS_7.3-54.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/class/class_7.3-19.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/cluster/cluster_2.1.2.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/codetools/codetools_0.2-18.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/mgcv/mgcv_1.8-38.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/nlme/nlme_3.1-152.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/nnet/nnet_7.3-16.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/rpart/rpart_4.1-15.tar.gz")' && \
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/spatial/spatial_7.3-11.tar.gz")'

COPY requirements.txt /requirements.txt
RUN pip3 install -r requirements.txt \
 && rm -f requirements.txt

RUN mkdir -p /vsr/tmp
COPY pipeline-config.json season-config.json ec-config.json scoring-config.json /vsr/tmp/
COPY R ApiIntegration.py run-engine.py /vsr/pipeline/

ARG stage=dev
ENV STAGE=${stage}

CMD /bin/bash
