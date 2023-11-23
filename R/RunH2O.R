#!/usr/bin/env Rscript

suppressMessages(require(argparser))
suppressWarnings(require(h2o))
suppressWarnings(require(jsonlite))

parser <- arg_parser("H2O Model")
parser <- add_argument(parser, '--model',        help='local file location of H2O model')
parser <- add_argument(parser, '--soildata',     help='local file location of calibrated soil data')
parser <- add_argument(parser, '--ratedata',     help='local file location of rate output data')
parser <- add_argument(parser, '--coefficient',  help='model prediction QC coefficient to use', default='3')
parser <- add_argument(parser, '--auxdata',      help='local JSON file with AUX data')
parser <- add_argument(parser, '--inputcsv',     help='local CSV file with model input data')
args <- parse_args(parser)

args$coefficient <- as.numeric(args$coefficient)

cat('\n\n***** command args:\n ',paste0(args,'\n'),'\n',file=stderr())

## Read the regional data from its JSON file
regionalvalues <- data.frame(id=1)
if(!is.na(args$auxdata) && file.exists(args$auxdata)) {
  auxdata <- fromJSON(args$auxdata,simplifyDataFrame=T,flatten=T)
  cat('Regional data:','\n',paste0(names(auxdata),','),'\n',file=stderr())
  cat(paste0(auxdata,'\n'),'\n',file=stderr())

  if('bioclimate' %in% names(auxdata) && !is.null(auxdata$bioclimate)) {
    cat('...processing bioclimate','\n',file=stderr())
    if('bio8'  %in% names(auxdata$bioclimate)) { regionalvalues$Bio8  <- as.numeric(auxdata$bioclimate$bio8)  }
    if('bio10' %in% names(auxdata$bioclimate)) { regionalvalues$Bio10 <- as.numeric(auxdata$bioclimate$bio10) }
    if('bio12' %in% names(auxdata$bioclimate)) { regionalvalues$Bio12 <- as.numeric(auxdata$bioclimate$bio12) }
    if('bio16' %in% names(auxdata$bioclimate)) { regionalvalues$Bio16 <- as.numeric(auxdata$bioclimate$bio16) }
    if('bio18' %in% names(auxdata$bioclimate)) { regionalvalues$Bio18 <- as.numeric(auxdata$bioclimate$bio18) }
  }

  # If we have a better estimate for Bio12, use it
  if('wc2_10m' %in% names(auxdata) && !is.null(auxdata$wc2_10m)) {
    cat('...processing wc2_10m','\n',file=stderr())
    if('GRAY_INDEX' %in% names(auxdata$wc2_10m)) { regionalvalues$Bio12 <- as.numeric(auxdata$wc2_10m$GRAY_INDEX) }
  }

  if('hwsd_data' %in% names(auxdata) && !is.null(auxdata$hwsd_data)) {
    cat('...processing hwsd_data','\n',file=stderr())
    if('records' %in% names(auxdata$hwsd_data) && !is.null(auxdata$hwsd_data$records) && (length(auxdata$hwsd_data$records) > 0)) {
      hwsd.df <- auxdata$hwsd_data$records[[1]]
      head(hwsd.df)
      if('T_CLAY' %in% names(hwsd.df)) { regionalvalues$T_CLAY <- as.numeric(hwsd.df[1,'T_CLAY']) }
      if('S_CLAY' %in% names(hwsd.df)) { regionalvalues$S_CLAY <- as.numeric(hwsd.df[1,'S_CLAY']) }
      if('T_SAND' %in% names(hwsd.df)) { regionalvalues$T_SAND <- as.numeric(hwsd.df[1,'T_SAND']) }
      if('S_SAND' %in% names(hwsd.df)) { regionalvalues$S_SAND <- as.numeric(hwsd.df[1,'S_SAND']) }
      if('T_ECE'  %in% names(hwsd.df)) { regionalvalues$T_ECE  <- as.numeric(hwsd.df[1,'T_ECE'])  }
      if('S_ECE'  %in% names(hwsd.df)) { regionalvalues$S_ECE  <- as.numeric(hwsd.df[1,'S_ECE'])  }

      if('AWC_CLASS' %in% names(hwsd.df)) {
        awcc <- as.numeric(hwsd.df[1,'AWC_CLASS'])

        awcc_mm <- switch(awcc,150,125,100,75,50,15)
        if(is.null(awcc_mm)) { awcc_mm <- 0 }

        regionalvalues$AWC_mm     <- awcc_mm
        regionalvalues$AWC_class  <- awcc
      }
    }
  }
}

## Read the calibrated soil data
soil.df <- read.csv(args$soildata,header=T,stringsAsFactors=F)
if(nrow(soil.df) <= 2) {
  cat(paste0('*** no soil data to process - empty result ***'),'\n')
  write.csv(data.frame(), file=args$ratedata, row.names=F)
  quit(save='no',status=-2)
}

## Augment the soil data with regional data if it is available
if(ncol(regionalvalues) > 1) {
  cat('Augmenting soil data with regional data:','\n',file=stderr())
  cat(paste(names(regionalvalues),','),'\n',file=stderr())
  cat(paste(regionalvalues[1,],','),'\n',file=stderr())
  soil.df <- cbind(soil.df,regionalvalues[1,2:ncol(regionalvalues)])
}
cat('\n\n***** columns:\n ',paste0(names(soil.df),'\n'),'\n',file=stderr())

## Rename the columns to match those expected by the model
names(soil.df)[names(soil.df) == 'ec30']               <- 'ECs'
names(soil.df)[names(soil.df) == 'ec90']               <- 'ECd'
names(soil.df)[names(soil.df) == 'ecs']                <- 'EC30'
names(soil.df)[names(soil.df) == 'ecd']                <- 'EC90'

names(soil.df)[names(soil.df) == 'elevation']          <- 'Elev'
names(soil.df)[names(soil.df) == 'upslope']            <- 'Upslope_area'
names(soil.df)[names(soil.df) == 'slope']              <- 'Slope'
names(soil.df)[names(soil.df) == 'aspect']             <- 'Aspect'
names(soil.df)[names(soil.df) == 'roughness']          <- 'Roughness'
names(soil.df)[names(soil.df) == 'cti']                <- 'CTI'
names(soil.df)[names(soil.df) == 'om']                 <- 'OM'
names(soil.df)[names(soil.df) == 'cec']                <- 'CEC'
names(soil.df)[names(soil.df) == 'relative_elevation'] <- 'DEM'

cat('\n\n',paste0('***** soil data rows: ',dim(soil.df)[1]),'\n',file=stderr())
cat('\n\n***** columns:\n ',paste0(names(soil.df),'\n'),'\n',file=stderr())

############################################
#   Regional environmental layers
############################################
if ( 'Elev' %in% names(soil.df)){
  soil.df$DEMmax <- max(soil.df$DEM)
  soil.df$DEMcv <- sd(soil.df$DEM) / mean(soil.df$DEM) * 100
}

if ( 'ECs' %in% names(soil.df)){
    soil.df["EC30"] <- scale(soil.df[, "ECs"])[, 1]
    soil.df$EC30cv <- sd(soil.df$ECs) / mean(soil.df$ECs) * 100
    soil.df$ECsq90 <- quantile(soil.df$ECs, probs = .9, names = F)
    soil.df$ECsq10 <- quantile(soil.df$ECs, probs = .1, names = F)
}

if ( 'ECd' %in% names(soil.df)) {
    soil.df["EC90"] <- scale(soil.df[, "ECd"])[, 1]
    soil.df$EC90cv <- sd(soil.df$ECd) / mean(soil.df$ECd) * 100
    soil.df$ECdq90 <- quantile(soil.df$ECd, probs = .9, names = F)
    soil.df$ECdq10 <- quantile(soil.df$ECd, probs = .1, names = F)
}

if ( 'OM' %in% names(soil.df)) {
    soil.df$OMcv <- sd(soil.df$OM) / mean(soil.df$OM) * 100
    soil.df$OMq90 <- quantile(soil.df$OM, probs = .9, names = F)
    soil.df$OMq10 <- quantile(soil.df$OM, probs = .1, names = F)
}

cat('\n\n',paste0('***** soil data rows: ',dim(soil.df)[1]),'\n',file=stderr())
cat('\n\n***** columns:\n ',paste0(names(soil.df),'\n'),'\n',file=stderr())

if(!is.na(args$inputcsv)) {
  ## Input data to the H2O model
  write.csv(soil.df, file=args$inputcsv, row.names=F)
  cat(paste0('input CSV written\n'),file=stderr())
}

# soil.spdf <- soil.df
# coordinates(soil.spdf) <- ~lon + lat
# soil.spdf  <- SpatialPointsDataFrame(soil.spdf,soil.df)
# soil.spdf@proj4string  <- CRS("+proj=longlat +datum=WGS84")
# writeOGR(soil.spdf, 'inputshapes', 'h2oinput', driver='ESRI Shapefile', overwrite_layer=TRUE)
# cat(paste0('input shapefile written\n'),file=stderr())

## Fire up H2O, Version 3.10.4.4 for Mod_5.0
n.cl <- parallel::detectCores()
h2o.init(nthreads=n.cl - 1, max_mem_size="4G")

cat('\n\n***** local files:\n ',paste0(list.files('/vsr/tmp'),'\n'),'\n',file=stderr())
cat('\n\n',paste0('***** model location: ',args$model),'\n',file=stderr())
cat('\n\n',paste0('***** model size: ',file.size(args$model)),'\n',file=stderr())

## Load the model
model <- h2o.loadModel(args$model)

cat('\n\n',paste0('***** model loaded'),'\n',file=stderr())

## Format the soil data set
model.df <- as.h2o(x = soil.df, destination_frame = "model.df")

cat('\n\n',paste0('***** data formatted'),'\n',file=stderr())

## Run model predictions on the soil data set
model.df$QC5 <- args$coefficient
result.df <- data.frame(cells = seq(1:nrow(soil.df)), lon=soil.df$lon, lat=soil.df$lat)
result.df$YieldPotential <- as.data.frame(h2o.predict(model, model.df))$predict

cat('\n\n',paste0('***** model scored'),'\n',file=stderr())
head(result.df)

## Rate data at each location in the field that had calibrated data available
write.csv(result.df, file=args$ratedata, row.names=F)

h2o.shutdown(F)
