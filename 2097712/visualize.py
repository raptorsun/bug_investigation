#!/usr/bin/env python3

"""Visualize Prometheus query outputs in JSON format.
"""

from array import array
import string
import sys
import argparse

import json
from matplotlib import pyplot as plt
import matplotlib.ticker as ticker
import numpy as np


class TimeSeries(object):
    metric: dict
    values: array

    def __init__(self, _metric, _values):
        self.metric = _metric
        self.values = _values


def extract_timeseries(file):
    rootjson = json.load(file)
    tss = []
    for result in rootjson['data']['result']:
        metric = result['metric']
        values = result['values']
        timeseries = TimeSeries(metric, values)
        tss.append(timeseries)
    return tss


def draw_charts(timeserieses, ylabel):
    fig, ax = plt.subplots()
    # flatten arrays
    for ts in timeserieses:
        label = str(ts.metric)
        x = [elem[0] for elem in ts.values]
        base_x = min(x)
        x = [elem - base_x for elem in x]
        y = [elem[1] for elem in ts.values]
        ax.plot(x, y, label=label)
    ax.legend()
    ax.get_xaxis().set_major_locator(ticker.MaxNLocator(8))
    ax.get_yaxis().set_major_locator(ticker.MaxNLocator(8))
    plt.ylabel(ylabel)
    plt.title(ylabel)
    plt.show()


def main(arguments):

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('datafile', help="Prometheus Query JSON response files",
                        type=argparse.FileType('r'),  nargs='+',)
    args = parser.parse_args(arguments)

    for f in args.datafile:
        tss = extract_timeseries(f)
        draw_charts(tss, f.name)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
