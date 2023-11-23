#!/usr/bin/env Rscript

suppressMessages(require(argparser))
suppressMessages(require(data.table))
suppressMessages(require(rgdal))
suppressMessages(require(sp))
suppressMessages(require(maptools))
suppressMessages(require(rgeos))
suppressMessages(require(RANN))
suppressMessages(require(plyr)) # Used by make_grid
suppressMessages(require(jsonlite))

### Arguments ###
parser <- arg_parser("VSR Model")
parser <- add_argument(parser, '--config',         help='local file location of configuration file')
parser <- add_argument(parser, '--table',           help='local file location of lookup table')
parser <- add_argument(parser, '--wkt',             help='field boundary WKT')
parser <- add_argument(parser, '--region',          help='field location region code', default='USA')
parser <- add_argument(parser, '--labels',          help='local file location of labeled point data')
parser <- add_argument(parser, '--yieldpotential',  help='local file location of yield potential data')
parser <- add_argument(parser, '--product',         help='product Id used for table lookup')
parser <- add_argument(parser, '--lowerrate',       help='td-argentina model lower rate')
parser <- add_argument(parser, '--static',          help='informed static rate to use if needed')
parser <- add_argument(parser, '--upperrate',       help='td-argentina model upper rate')
parser <- add_argument(parser, '--rowwidth',        help='width of planting rows')
parser <- add_argument(parser, '--output',          help='local output filename')
parser <- add_argument(parser, '--metaout',         help='local metadata output filename')
parser <- add_argument(parser, '--ratesout',        help='local rate data output filename')
parser <- add_argument(parser, '--gridout',         help='local grid data output filename')
parser <- add_argument(parser, '--boundstype',      help='type of bounds limiting to perform (area,linear)')
parser <- add_argument(parser, '--highupperbound',  help='alternate upper bound to limit rates to')
parser <- add_argument(parser, '--grid',            help='grid size in meters', default=10)
parser <- add_argument(parser, '--plantype',        help='crop plan type', default='commercial')
parser <- add_argument(parser, '--planA',           help='labels are planA labels', flag=TRUE)
parser <- add_argument(parser, '--globalscoring',   help='use global scoring models if possible', flag=TRUE)
parser <- add_argument(parser, '--nobagadjustment', help='disable or enable bag adjustment', flag=TRUE)
parser <- add_argument(parser, '--irrigated',       help='field is irrigated', flag=TRUE)
args <- parse_args(parser)

args$rowwidth       <- as.numeric(args$rowwidth)
args$static         <- as.numeric(args$static)
args$lowerrate      <- as.numeric(args$lowerrate)
args$upperrate      <- as.numeric(args$upperrate)
args$grid           <- as.numeric(args$grid)

meta <- list()
meta$ECHitRate <- unbox(0.0)

### Constants ###

# This is the coordinate system for all input and output.
CommonCRS <- CRS("+proj=longlat +datum=WGS84")

# Conversion constants
squareMeters2Acres          <- 0.000247105
perSquareMeters2PerHectares <- 10000
inches2Centimeters          <- 2.54

### Selectors ###

perform_smoothing <- F

## @TODO: Pull the config data from a file here

### Configuration ###
if(!is.na(args$config)) {
  config <- fromJSON(args$config,flatten=T)

} else {
  cat(paste0("ERROR: configuration file must be specified.\n"),file=stderr())
  quit(save="no", status=1)
}

# Configure execution values

benchmark.adjustment <- 1.0
rowspacing.bonus     <- 0
joinRadius           <- args$grid
rounding             <- 1000

if(!is.na(args$region)) {
  if(args$region == "USA") {
    minFieldArea                <- config$usa$minarea # Acres
    maxFieldArea                <- config$usa$maxarea # Acres
    perform_smoothing           <- config$usa$perform_smoothing
    smoothingThreshold          <- config$usa$smoothing.threshold
    interval.upper.limit        <- config$usa$binningInterval
    interval.range.precision    <- config$usa$rangePrecision
    germinationAdjustment       <- config$usa$germination
    squareMeters2AreaConversion <- config$usa$squareMeters2AreaConversion
    hitrate.min                 <- config$usa$hitrate.min

    # Restrict operation to only configured row widths
    if( as.character(args$rowwidth) %in% names(config$usa$rowwidth) ) {
      # USA rates are increased for smaller row spacing.
      cat(paste0('ADJUSTMENT CHECK: ','adjustment' %in% names(config$usa$rowwidth[[as.character(args$rowwidth)]])),'\n',file=stderr())
      if( 'adjustment' %in% names(config$usa$rowwidth[[as.character(args$rowwidth)]]) ) {
        rowspacing.bonus  <- as.numeric( config$usa$rowwidth[[as.character(args$rowwidth)]]$adjustment[[args$plantype]] )
        args$static       <- args$static + rowspacing.bonus
        cat(paste0('rowspacing bonus: ',rowspacing.bonus),'\n',file=stderr())
      }

      # Population bounds are unique by row width, irrigation, and crop plan types
      pops <- config$usa$rowwidth[[as.character(args$rowwidth)]][[ifelse(args$irrigated,'wet','dry')]][[args$plantype]]
      minPop <- pops$minpop
      maxPop <- pops$maxpop

    } else {
        errorMessage <- paste0("ERROR: Invalid row spacing for planA data.\n")
        cat(errorMessage)
        quit(save="no", status=1)
    }

  } else if(args$region == "EME") {
    minFieldArea                <- config$eme$minarea # Acres
    maxFieldArea                <- config$eme$maxarea # Acres
    minPop                      <- config$eme$minpop

    if(is.na(args$highupperbound)) {
      maxPop                    <- config$eme$maxpop
    } else {
      maxPop                    <- config$eme$highmaxpop
    }

    perform_smoothing           <- config$eme$perform_smoothing
    smoothingThreshold          <- config$eme$smoothing.threshold
    interval.upper.limit        <- config$eme$binningInterval
    interval.range.precision    <- config$eme$rangePrecision
    germinationAdjustment       <- config$eme$germination
    squareMeters2AreaConversion <- config$eme$squareMeters2AreaConversion
    hitrate.min                 <- config$eme$hitrate.min
    benchmark.adjustment        <- config$eme$benchmark.width / (inches2Centimeters * args$rowwidth)

  } else if(args$region == "MEX") {
    minFieldArea                <- config$mex$minarea # Acres
    maxFieldArea                <- config$mex$maxarea # Acres
    minPop                      <- config$mex$minpop
    maxPop                      <- config$mex$maxpop
    perform_smoothing           <- config$mex$perform_smoothing
    smoothingThreshold          <- config$mex$smoothing.threshold
    interval.upper.limit        <- config$mex$binningInterval
    interval.range.precision    <- config$mex$rangePrecision
    germinationAdjustment       <- config$mex$germination
    squareMeters2AreaConversion <- config$mex$squareMeters2AreaConversion
    hitrate.min                 <- config$mex$hitrate.min

  } else if(args$region == "BRA") {
    minFieldArea                <- config$bra$minarea # Acres
    maxFieldArea                <- config$bra$maxarea # Acres
    minPop                      <- config$bra$minpop
    maxPop                      <- config$bra$maxpop
    perform_smoothing           <- config$bra$perform_smoothing
    smoothingThreshold          <- config$bra$smoothing.threshold
    interval.upper.limit        <- config$bra$binningInterval
    interval.range.precision    <- config$bra$rangePrecision
    germinationAdjustment       <- config$bra$germination
    squareMeters2AreaConversion <- config$bra$squareMeters2AreaConversion
    hitrate.min                 <- config$bra$hitrate.min

  } else if(args$region == "ARG") {
    minFieldArea                <- config$arg$minarea # Acres
    maxFieldArea                <- config$arg$maxarea # Acres
    minPop                      <- config$arg$minpop
    maxPop                      <- config$arg$maxpop
    perform_smoothing           <- config$arg$perform_smoothing
    smoothingThreshold          <- config$arg$smoothing.threshold
    interval.upper.limit        <- config$arg$binningInterval
    interval.range.precision    <- config$arg$rangePrecision
    germinationAdjustment       <- config$arg$germination
    squareMeters2AreaConversion <- config$arg$squareMeters2AreaConversion
    hitrate.min                 <- config$arg$hitrate.min

  } else if(args$region == "ZAF") {
    minFieldArea                <- config$zaf$minarea # Acres
    maxFieldArea                <- config$zaf$maxarea # Acres
    minPop                      <- config$zaf$minpop
    maxPop                      <- config$zaf$maxpop
    perform_smoothing           <- config$zaf$perform_smoothing
    smoothingThreshold          <- config$zaf$smoothing.threshold
    interval.upper.limit        <- config$zaf$binningInterval
    interval.range.precision    <- config$zaf$rangePrecision
    germinationAdjustment       <- config$zaf$germination
    squareMeters2AreaConversion <- config$zaf$squareMeters2AreaConversion
    hitrate.min                 <- config$zaf$hitrate.min

  }
}

### Functions ###

## Function to compute the mode
Mode <- function(x) {
    ux <- unique(x)
    ux[which.max(tabulate(match(x, ux)))]
}

# Determine a rate interval to bin data with.
#   Upper and lower are the rate limits, and the limit parameter
#   is the largest acceptable interval size.  Intervals are required
#   to be equal in size (rate endpoints per interval).
rateinterval <- function(lower,upper,limit) {
  return ((upper - lower) / ceiling( (upper - lower) / limit ))
}

# Project a spatial object onto UTM in either N or S hemisphere
wgs2utm <- function (sp.layer)
{
  if (!inherits(sp.layer, c("Spatial", "Raster"))) {
    stop(deparse(substitute(sp.layer)), " isn't a Spatial* or Raster* object")
  }
  proj <- "+proj=longlat +datum=WGS84"
  if (is.na(proj4string(sp.layer))) {
    sp.layer@proj4string <- CRS(proj)
  }
  long <- bbox(sp.layer)[1]
  lat <- bbox(sp.layer)[2]
  zone <- floor((long + 180)/6%%60) + 1
  northing <- ifelse(lat < 0, " +south=T", "")
  zone <- paste0(zone, northing)
  UTM <- paste("+proj=utm +zone=", zone, " +ellps=WGS84", sep = "")
  sp.layer.utm <- spTransform(sp.layer, CRS(UTM))
  return(sp.layer.utm)
}

# Create a buffered grid on a spacing in a spatial objects current projection
make_grid <- function(p, size, shift.x, shift.y)
{
  bounds <- p@bbox

  maxX <- bounds[1,2] + size
  maxX <- plyr::round_any(maxX, 10, ceiling)

  maxY <- bounds[2,2] + size
  maxY <- plyr::round_any(maxY, 10, ceiling)

  minX <- bounds[1,1] - size
  minX <- plyr::round_any(minX, 10, floor)

  minY <- bounds[2,1] - size
  minY <- plyr::round_any(minY, 10, floor)

  grd  <- expand.grid( X = seq(from = minX - shift.x, to = maxX + shift.x, by = size),
                       Y = seq(from = minY - shift.y, to = maxY + shift.y, by = size))

  coordinates(grd) <- c("X", "Y")
  grd@proj4string  <- p@proj4string
  grd  <- SpatialPixels(grd)
  buff <- size/2
  grd  <- grd[ gBuffer(p, width=buff), ]

  return(grd)
}

## Convert a grid to a set of polygons
points_to_polygons <- function(points)
{
  poly.spdf <- SpatialPixelsDataFrame(points, data = points@data)
  poly.spdf <- as(poly.spdf, "SpatialPolygonsDataFrame")
  return(poly.spdf)
}

## Convert yield potential to seeding rates
score_td_args <- function(data.df, lowrate, highrate, staticrate) {
  ## Model range
  data.max <- max(data.df$YieldPotential, na.rm=T)
  data.min <- min(data.df$YieldPotential, na.rm=T)

  cat('\n\n',paste0('data.max: ',data.max),'\n',file=stderr())
  cat(paste0('data.min: ',data.min),'\n',file=stderr())

  #### From original code:
  ## Restrict the internal rate to within the range
  ## middlerate <- staticrate
  ## if(middlerate > highrate){middlerate <- highrate}
  ## if(middlerate < lowrate) {middlerate <- lowrate}

  #### From Pato July, 2018:
  middlerate <- mean( c( highrate, lowrate) )
  cat(paste0('upper  rate: ',highrate),'\n',file=stderr())
  cat(paste0('middle rate: ',middlerate),'\n',file=stderr())
  cat(paste0('lower  rate: ',lowrate),'\n',file=stderr())

  ## Target range
  target.max <- 1 + ((highrate - middlerate) / highrate)
  target.min <- 1 - ((middlerate - lowrate)  / lowrate)

  cat(paste0('target.max: ',target.max),'\n',file=stderr())
  cat(paste0('target.min: ',target.min),'\n',file=stderr())

  ## Scale the predictions to the same range as the upper and lower rates.
  if(data.max == data.min) {
    # move the minimum if the inputs have no range
    data.df$YieldPotential <- 1.0

  } else {
    # scale from input range to target range
    scale <- (target.max  - target.min) / (data.max - data.min)
    data.df$YieldPotential <- scale * (data.df$YieldPotential - data.min) + target.min
  }

  head(data.df)

  ## Compute the female rate.
  ## TODO: check if we want to use the static rate here or the mean of upper and lower
  data.df$rate <- data.df$YieldPotential * staticrate
  return( data.df[,c('lon','lat','rate')] )
}

#############################################################
#Subsetting files for specified field and product information
############################################################
lookup_label_rates <- function(product,irrigated,table,grid){
  # Simplify the grid factors
  grid<-droplevels(grid)

  if(irrigated) {
    irr <- 'IRR'
  } else {
    irr <- 'DRY'
  }

  # Subset the table to the product of interest and its irrigated condition
  product.data<-table[table$Base == product & table$Irrigation == irr,]
  product.data<-droplevels(product.data)

  # Diagnostic outputs if other diagnostics were requested
  if(!is.na(args$ratesout)) {
    cat('grid dim: ',dim(grid),'\n',file=stderr())
    cat('product dim: ',dim(product.data),'\n',file=stderr())
    write.csv(product.data,'/vsr/tmp/product-info.csv',row.names=F)
  }

  #############################################################
  # Assigning rate for environmental classes at each point
  ############################################################
  rates <- by(product.data,product.data$Base,function(current) {
    # Join where location label and table Class match
    merge(grid,current,by.x='label',by.y='Class',all.x=TRUE)
  })
  rates.df <- do.call(rbind,rates)

  return(rates.df)
}

#######################################
##
##

### Read the field ###
Boundary84 <- readWKT(args$wkt, p4s=CommonCRS)

# Convert the boundary to UTM
BoundaryUTM <- wgs2utm(Boundary84)
LocalCRS    <- BoundaryUTM@proj4string
cat('Projecting to UTM using CRS: ',LocalCRS@projargs,'\n',file=stderr())

## Convert the boundary to EPSG:3857
Boundary3857 <- spTransform(Boundary84, CRS("+init=epsg:3857"))
bb <- bbox(Boundary3857)
meta$BoundingBox <- c(bbox(Boundary3857)[1,1], bbox(Boundary3857)[2,1], bbox(Boundary3857)[1,2], bbox(Boundary3857)[2,2])
Center <- gCentroid(Boundary84)
meta$Centroid <- unbox(paste0("(", Center@coords[1], ",", Center@coords[2], ")"))

Area <- gArea(BoundaryUTM) * squareMeters2Acres
cat(paste0("INFO: Field boundary is ", round(Area, 2), " acres\n"),file=stderr())

# TODO:  Why?
if (Area > maxFieldArea) {
    errorMessage <- paste0("ERROR: Field boundary is too large to process.\n")
    cat(errorMessage,file=stderr())
    quit(save="no", status=1)
}
# TODO:  Why?
if (Area < minFieldArea) {
    errorMessage <- paste0("ERROR: Field boundary is too small to process.\n")
    cat(errorMessage,file=stderr())
    quit(save="no", status=1)
}

# Create prescription grid from boundary.
Grid <- data.frame( make_grid(BoundaryUTM, args$grid, 0, 0) )

SpatialOutput <- SpatialPointsDataFrame(Grid[,c('X','Y')],Grid)
SpatialOutput@proj4string <- LocalCRS

# Start with entire field at ISR rate
SpatialOutput@data[['female']] <- args$static
meta$StaticRate   <- unbox(TRUE)
meta$RateType     <- unbox('Static')
meta$rateSource   <- unbox('informed')

cat('grid dim: ',dim(SpatialOutput@data),'\n',file=stderr())

if(!is.na(args$gridout)) {
  write.csv(SpatialOutput@data,args$gridout,row.names=F)
  cat(paste0('grid data written\n'),file=stderr())
}

# Dataframe for the variable rates
rates.df <- data.frame()

# Track amount of data for each source
td.hitrate <- 0.0
ec.hitrate <- 0.0

# Load locations with TD model rates where available
if( !is.na(args$yieldpotential) ) {
  yieldpotential.df <- data.frame()
  if( file.exists(args$yieldpotential) ) {
    yieldpotential.df <- read.csv(args$yieldpotential,header=T,stringsAsFactors=F)
  }

  if((nrow(yieldpotential.df) > 2) && !is.na(args$lowerrate) && !is.na(args$upperrate)) {
    ## Obtain the variable rates from the model yield potential values
    rates.df <- score_td_args(yieldpotential.df,
                              args$lowerrate,
                              args$upperrate,
                              args$static)
    td.hitrate <- nrow(rates.df) / nrow(SpatialOutput)
    cat(paste0('TD Hitrate: ',td.hitrate),'\n',file=stderr())

    # Create projected longitude and latitude for joining with the grid
    rates.spdf <- SpatialPointsDataFrame(rates.df[,c('lon','lat')],rates.df)
    rates.spdf@proj4string <- CommonCRS
    rates.spdf <- spTransform(rates.spdf, LocalCRS)
    rates.df <- as.data.frame(rates.spdf)
    names(rates.df)[names(rates.df) == 'lon.1'] <- 'X'
    names(rates.df)[names(rates.df) == 'lat.1'] <- 'Y'
    rates.df$X <- round(rates.df$X)
    rates.df$Y <- round(rates.df$Y)

    meta$rateSource   <- unbox('td-model')

    # Distance to neighbors from TD model to grid is less that grid size
    # N.B. distance at exactly the grid size starts to include the wrong neighbors
    joinRadius <- args$grid

    cat(paste0('yield rates\n'),names(rates.df),'\n',file=stderr())
    cat(paste0(summary(rates.df$rate)),'\n',file=stderr())
    cat(paste0(rates.df[1:10,],'\n'),file=stderr())
  }
}

# Load locations with table rates where available
if(!is.na(args$labels) && (args$planA || args$globalscoring)) {
  ### Read the (EC,product,population) table
  ec.Lookup <- fread(args$table, header = T, sep = ',')

  ### Read the (Lat,Long,EC) table for grower fields
  ec.GrowerClasses <- fread(args$labels, header = T, sep = ',')

  ### Check if product exists.
  product.list <- unique(ec.Lookup$Base)
  product.list <- product.list[!is.na(product.list)]

  if (args$product %in% product.list) {
    # Lookup the rates for the class labels
    EC <- lookup_label_rates(args$product, args$irrigated, ec.Lookup, ec.GrowerClasses)
    cat(paste0('size of EC table: ',dim(EC),'\n'),file=stderr())
    cat(paste0('EC table columns: ',colnames(EC),'\n'),file=stderr())

    # Project positions into UTM
    coordinates(EC) <- ~longitude + latitude
    EC@proj4string  <- CommonCRS
    EC              <- spTransform(EC, LocalCRS)
    EC.df           <- as.data.frame(EC)
    ## @TODO: Ensure this is joined with any existing rates here (spatial join to nearest?)
    ## N.B. Currently this simply overwrites any TD model values

    # Make the column names consistent with other region processing
    names(EC.df)[names(EC.df) == 'PlantPop']  <- 'rate'
    names(EC.df)[names(EC.df) == 'longitude'] <- 'X'
    names(EC.df)[names(EC.df) == 'latitude']  <- 'Y'

    # Drop incomplete rows (NA rates)
    EC.df <- EC.df[ !is.na(EC.df$rate),]

    ec.hitrate <- nrow(EC.df) / nrow(SpatialOutput)
    cat(paste0('EC Hitrate: ',ec.hitrate),'\n',file=stderr())

    if( ec.hitrate > (0.5 * td.hitrate) ) {
      rates.df <- EC.df

      cat(paste0(summary(rates.df$rate)),'\n',file=stderr())
      meta$rateSource   <- unbox('label-lookup')

      joinRadius <- config$common$nn.distance
    }
  }
}

# Spatial join of the rates to the grid
if( nrow(rates.df) > 0 ) {
  cat('*** joining variable rates to prescription grid ***','\n',file=stderr())

  if(!is.na(args$ratesout)) {
    write.csv(rates.df,args$ratesout,row.names=F)
    cat(paste0('rate data written\n'),file=stderr())
  }

  # Find the nearest point in the prescription grid for each rate
  # N.B. specifying k and radius seems to not honor the radius,
  #      handle it after generating the result
  neighbors <- nn2(rates.df[,c('X','Y')],SpatialOutput@coords,k=1)

  cat('\nRate locations:\n',file=stderr())
  cat(paste0(rates.df[1:10,c('X','Y')],'\n'),file=stderr())
  cat('\nGrid locations:\n',file=stderr())
  cat(paste0(SpatialOutput@coords[1:10,],'\n'),file=stderr())

  cat('\nNeighbors:\n',file=stderr())
  cat(neighbors$nn.idx[1:10,],file=stderr())

  # Extract the rates for the nearest prescription grid points and adjust
  closest        <- neighbors$nn.dists < joinRadius
  rates          <- rep(args$static, nrow(SpatialOutput))
  rates[closest] <- rates.df$rate[ neighbors$nn.idx[closest] ]
  rates          <- rates + rowspacing.bonus

  cat('top rate: ',max(rates),', bottom rate: ',min(rates),'\n',file=stderr())
  cat('variable rates: ',sum(closest),'\n',file=stderr())
  cat('static rates:',sum(rates == args$static),'\n',file=stderr())
  cat('\nrates:\n',file=stderr())
  cat(paste0(rates[1:10],'\n'),file=stderr())


  ## Compute the fraction of the prescription of the most popular rate.
  rate.mode <- Mode(rates)
  meta$ModeFraction <- unbox( sum(rates == rate.mode) / nrow(SpatialOutput) )

  # Compute and store the portion of the field not covered by the variable rates
  hitRate <- sum(closest) / nrow(SpatialOutput)
  meta$HitRate <- unbox(hitRate)

  cat('number of neighbors: ',nrow(neighbors$nn.idx),'\n',file=stderr())
  cat('number of rates: ',length(rates),'\n',file=stderr())
  cat('number of grid points: ',nrow(SpatialOutput),'\n',file=stderr())
  cat('hit rate: ',hitRate,'\n',file=stderr())
  cat('mode rate: ',rate.mode,'\n',file=stderr())
  cat('mode fraction: ',meta$ModeFraction,'\n',file=stderr())
  cat(paste0(summary(rates)),'\n',file=stderr())

  if (hitRate > hitrate.min) {
      ## Use variable rate.
      SpatialOutput@data[['female']] <- rates

      meta$StaticRate <- unbox(FALSE)
      meta$RateType   <- unbox('Variable')
  }

}

meta$ECHitRate <- unbox(ec.hitrate)
meta$TDHitRate <- unbox(td.hitrate)

# Adjust seeding rates to account for germination
SpatialOutput@data[['female']] = SpatialOutput@data[['female']] * germinationAdjustment

if( perform_smoothing ) {
  ## Smooth
  cat('*** smoothing a variable rate script ***','\n',file=stderr())

  ## Nearest neighbor radius.  15 meters gets 8 neighbors in 10mx10m grid.
  nn_radius <- config$common$nn.distance

  ##  find the adjacent neighbors of the current point
  areaNeighbors <- nn2(SpatialOutput@coords, SpatialOutput@coords,
                       searchtype = "radius", radius = nn_radius)

  iteration      <- 0
  iteration.max  <- config$common$smoothing.iterations
  smoothing.done <- F
  if(nrow(areaNeighbors$nn.idx) != nrow(SpatialOutput)) {
    smoothing.done <- T
  }

  cat('\n\n***** neighbors: ',nrow(areaNeighbors$nn.idx),' *****\n',file=stderr())
  cat('\n\n***** coordinates: ',dim(SpatialOutput@coords),' *****\n',file=stderr())

  ##  vector to hold temporary values
  rates.current <- SpatialOutput@data[['female']]
  rates.next    <- rates.current
  while(!smoothing.done & iteration < iteration.max) {
      smoothing.done <- T
      for(i in 1:nrow(SpatialOutput)){
          neighbors.current <- areaNeighbors$nn.idx[i,]
          neighbors.current <- neighbors.current[ neighbors.current != 0 ]
          neighbors.values  <- rates.current[ neighbors.current ]
          change.max <- max( abs( rates.current[i] - neighbors.values ) )
          if( change.max > smoothingThreshold ) {
              ##  assign average of neighbors to current cell
              rates.next[i]  <- mean(neighbors.values)
              smoothing.done <- F
          }
      }
      ##  update density vecto for prescription grid
      rates.current <- rates.next
      iteration     <- iteration + 1
  }
  SpatialOutput@data[['female']] <- rates.current

} else {
  cat(paste0('not performing smoothing computations\n'),file=stderr())
}

cat(paste0('success!!!\n'),file=stderr())

# Note any remaining NA values
narows <- sum(is.na(SpatialOutput@data[['female']]))
cat(paste0('rows with undefined female rates: ',narows,'\n'),file=stderr())

# If the benchmark is a linear rate instead of a per area rate, adjust the rates
# to account for the current fields row width with respect to the benchmark
cat(paste0('benchmark.adjustment: ',benchmark.adjustment),'\n',file=stderr())
if(benchmark.adjustment != 1.0) {
  SpatialOutput@data[['female']] <- SpatialOutput@data[['female']] * benchmark.adjustment
}

# Translate all bounds values to a per area basis
if( args$boundstype == 'linear') {
  # minPop,maxPop are in seeds / 10m
  width.cm <- args$rowwidth * inches2Centimeters

  minPop.seeds.per.m2 <- 10 * minPop / width.cm
  minPop.area <- minPop.seeds.per.m2 * perSquareMeters2PerHectares

  maxPop.seeds.per.m2 <- 10 * maxPop / width.cm
  maxPop.area <- maxPop.seeds.per.m2 * perSquareMeters2PerHectares

} else {
  if( args$boundstype != 'area') {
    cat(paste0('unrecognized bounds type: ',args$boundstype,', assuming area\n'),file=stderr())
  }
  minPop.area <- minPop
  maxPop.area <- maxPop

}

## Handle extremes.
cat(paste0('clamping rates to [',minPop.area,',',maxPop.area,']\n'),file=stderr())
lowrows  <- sum(SpatialOutput@data[['female']] < minPop.area)
lowrows  <- ifelse(is.na(lowrows),0,lowrows)
highrows <- sum(SpatialOutput@data[['female']] > maxPop.area)
highrows <- ifelse(is.na(highrows),0,highrows)
cat(paste0('number of rates clamped [',lowrows,',',highrows,']\n'),file=stderr())

if( lowrows > 0) {
  SpatialOutput@data[['female']][SpatialOutput@data[['female']] < minPop.area] <- minPop.area
}
if( highrows > 0) {
  SpatialOutput@data[['female']][SpatialOutput@data[['female']] > maxPop.area] <- maxPop.area
}
cat(paste0('rates clamped to [',minPop.area,'(',lowrows,'),',maxPop.area,'(',highrows,')]\n'),file=stderr())

# Brazil wants total seeds for this model to match total seeds for ISR
if((args$region == "BRA" && meta$rateSource == 'td-model') && !args$nobagadjustment) {
  adjustment = mean(SpatialOutput@data[['female']]) - args$static
  SpatialOutput@data[['female']] = SpatialOutput@data[['female']] - adjustment
}

# Bin the data to intervals determined by configuration.  This is truncating to
# the next lowest interval value.

# bin intervals within the data range
break.range   <- range(SpatialOutput@data[['female']])
if(Reduce("&&",is.na(range(break.range)))) {
  errorMessage <- paste0("ERROR: Rates include NA.\n")
  cat(errorMessage,file=stderr())
  quit(save="no", status=1)
}
cat(paste0('break.range: ',break.range),'\n')

break.lowest  <- floor(  interval.range.precision * (break.range[1] %/% interval.range.precision))
cat(paste0('break.lowest: ',break.lowest),'\n')

break.highest <- ceiling(interval.range.precision * (break.range[2] %/% interval.range.precision))
cat(paste0('break.highest: ',break.highest),'\n')

bin.interval  <- rateinterval(break.lowest,break.highest,interval.upper.limit)
cat(paste0('bin.interval: ',bin.interval),'\n')

if(!is.na(bin.interval) && (break.highest > break.lowest)) {
  bins.breaks   <- as.integer(seq(break.lowest,break.highest,bin.interval))
  cat('binned to ',paste0(bins.breaks,', '),'\n',file=stderr())

  bins <- findInterval( SpatialOutput@data[['female']], bins.breaks )
  SpatialOutput@data[['female']] <- bins.breaks[bins]

  capture.output(table(SpatialOutput@data[['female']]),file=stderr())
  cat(paste0('Number of rates: ',sum(table(SpatialOutput@data[['female']]))),'\n')

  ## Compute and bin average rate
  meta$AverageFemaleRate <- unbox(as.integer(
      bins.breaks[
          findInterval( mean(SpatialOutput@data[['female']]), bins.breaks )
      ]
  ))

} else {
  singleRate <- floor(  interval.range.precision
                        * (mean(SpatialOutput@data[['female']])
                           %/% interval.range.precision))
  SpatialOutput@data[['female']] <- singleRate
  cat(paste0('Adjusted single rate: ',singleRate),'\n')

  meta$AverageFemaleRate <- unbox(as.integer( singleRate ))
}
cat(paste0('average rate of ',meta$AverageFemaleRate,'\n'),file=stderr())

## Each grid cell is args$grid * args$grid.
cellArea <- args$grid * args$grid

## Convert to regional area UOM.
cellArea  <- cellArea * squareMeters2AreaConversion

# Kluge to counteract an original kluge - @TODO: de-klugificate this
cellAcres <- args$grid * args$grid * squareMeters2Acres

## Compute the total number of seeds.
totalSeeds <- sum(cellArea * SpatialOutput@data[['female']])
cat(paste0('total seeds ',totalSeeds,'\n'),file=stderr())

meta$TotalBagsFemale <- unbox(as.integer(ceiling(totalSeeds / config$common$seedsperbag)))
cat(paste0('total bags ',meta$TotalBagsFemale,'\n'),file=stderr())

## Compute the total area.
meta$TotalAcresFemale <- unbox(nrow(SpatialOutput@data) * cellAcres)
cat(paste0('total acres ',meta$TotalAcresFemale,'\n'),file=stderr())

d <- data.frame(acres = SpatialOutput$'female')
meta$RateTable <- aggregate(x=d, by=list(rate=d$acres), FUN=function(x) { length(x) * cellAcres})

SpatialOutput <- points_to_polygons(SpatialOutput)

## Create a data frame containing unique planting densities with
## appropriately named rows.
t <- data.frame(female = as.numeric(unique(SpatialOutput@data$female)))
cat('*** Source rates: ',paste0(' ',t$female),'\n',file=stderr())

row.names(t) <- as.character(as.integer(t$female))
cat('*** Data rates: ',paste0(' ',row.names(t)),'\n',file=stderr())

## Dissolve the polygons.
polys <- gUnaryUnion(SpatialOutput, id = as.character(as.integer(as.numeric(SpatialOutput@data$female))))
cat('*** Poly rates: ',paste0(' ',row.names(polys)),'\n',file=stderr())

## Reconstitute as a dataframe.
SpatialOutput <- SpatialPolygonsDataFrame(polys, t)
cat(paste0('output frame formatted\n'),file=stderr())

SpatialOutput <- spTransform(SpatialOutput, CommonCRS)
writeOGR(SpatialOutput, args$output, 'prescription', 'GML', dataset_options="FORMAT=GML3",overwrite_layer=TRUE)
cat(paste0('shapefile written\n'),file=stderr())

write(toJSON(meta), args$metaout)
cat(paste0('metadata written\n'),file=stderr())
