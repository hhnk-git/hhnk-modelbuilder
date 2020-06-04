from osgeo import gdal
import logging
import argparse


def get_parser():
    """ Return argument parser. """

    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    parser.add_argument("raster", help="path to raster file")
    return parser


def calculate_max_pixelsize(**kwargs):
    raster_file = kwargs.get("raster")

    # find raster dimensions
    gdalsrc = gdal.Open(raster_file)
    upx, xres, xskew, upy, yskew, yres = gdalsrc.GetGeoTransform()
    cols = gdalsrc.RasterXSize
    rows = gdalsrc.RasterYSize

    # get X and Y size in meters
    xsize = cols * xres
    ysize = rows * yres * -1.0

    # get area in square meters
    area = xsize * ysize

    pixelsize = 0

    # compute maximum pixelsize based on 4 rasters and 1 billion pixels
    if 4 * area * 4 < 1e9:
        pixelsize = 0.5
    elif 1 * area * 4 < 1000 * 1000 * 1000:
        pixelsize = 1.0
    elif 1 / 4 * area * 4 < 1000 * 1000 * 1000:
        pixelsize = 2.0
    elif 1 / 16 * area * 4 < 1000 * 1000 * 1000:
        pixelsize = 4.0
    elif 1 / 64 * area * 4 < 1000 * 1000 * 1000:
        pixelsize = 8.0
    # return pixelsize

    print(pixelsize)


def main():
    return calculate_max_pixelsize(**vars(get_parser().parse_args()))


if __name__ == "__main__":
    logging.basicConfig(format="%(levelname)s:%(message)s", level=logging.DEBUG)
    main()
