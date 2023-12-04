FROM public.ecr.aws/lts/ubuntu:20.04

WORKDIR /app
COPY . .

ENV DEBIAN_FRONTEND=noninteractive

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
    R -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/RColorBrewer/RColorBrewer_1.1-2.tar.gz")'

ARG stage=dev
ENV STAGE=${stage}

#CMD /bin/bash

CMD ["node", "index.js"]
EXPOSE 3000