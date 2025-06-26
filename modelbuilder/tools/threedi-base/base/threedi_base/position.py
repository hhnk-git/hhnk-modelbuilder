# -*- coding: utf-8 -*-
from collections import defaultdict

from base.threedi_base.apps import ThreediBaseConfig as conf
from base.threedi_base.constants import END_POSITION, START_POSITION
from base.threedi_base.logger import Logger

logger = Logger.get(__name__, conf.LOG_LEVEL)


def fully_covered(positions):
    """
    channel completely contained in culvert,
    channel geometry must be removed
    """
    if not len(positions) == 2:
        return False
    start = positions[0]
    end = positions[1]
    if start == START_POSITION and end == END_POSITION:
        return True


def must_be_skipped(positions):
    """
    entries of length 2 with an indentical
    start- and endpoint must be skipped
    """

    if not len(positions) == 2:
        return False
    start = positions[0]
    end = positions[1]
    if start == end:
        return True


def remove_start_end_points(positions):
    """remove all items from list that are either 0.0 or 1.0"""
    positions = list(filter((0.0).__ne__, positions))
    positions = list(filter((1.0).__ne__, positions))
    return positions


def add_start_end_position(positions):
    # remove any duplicates
    positions = list(set(positions))
    # order might got lost due to set operation
    positions.sort()
    if all(
        [
            0.0 in positions,
            1.0 in positions,
            (len(positions) % 2 == 0),
            len(positions) > 2,
        ]
    ):
        return remove_start_end_points(positions)

    # runs from start to x, all good
    if 0.0 in positions and (len(positions) % 2 == 0):
        return positions
    # runs from x to end, all good
    if 1.0 in positions and (len(positions) % 2 == 0):
        return positions

    stripped_positions = remove_start_end_points(positions)
    stripped_positions.insert(0, 0.0)
    stripped_positions.append(1.0)
    return stripped_positions


def get_positions(entry):
    """
    get the correct start and end position
    """
    start_position = entry["pal_s"]
    end_position = entry["pal_e"]
    if start_position > end_position:
        _start_position = start_position
        start_position = end_position
        end_position = _start_position
    return start_position, end_position


def flip_start_end_position(positions):
    if positions[0] == START_POSITION:
        positions[0] = END_POSITION
    if positions[-1] == END_POSITION:
        positions[-1] = START_POSITION
    positions.sort()
    return positions


def get_ordered_positions(items):
    """
    :param items: collection of culvert entries
    :return: ASC sorted fractions of culvert/channel intersections
    """
    positions = []
    for entry in items:
        start_position, end_position = get_positions(entry)
        if start_position == end_position:
            continue
        positions.extend([start_position, end_position])
    positions.sort()
    return positions


def remove_duplicate_positions(positions):
    """remove duplicate positions"""
    def_dict = defaultdict(list)
    for i, item in enumerate(positions):
        def_dict[item].append(i)
    duplicates = {k: v for k, v in def_dict.items() if len(v) > 1}
    for k, v in duplicates.items():
        positions = list(filter((k).__ne__, positions))

    return positions


def correct_positions_by_distance(entry):
    """
    if the distance of the start- and endpoints to the
    channel in question is bigger than 2 * the buffer size
    for the start- and endpoints, the point along line attribute
    will be reset
    """

    if all([entry["pal_s"] == START_POSITION, entry["pal_e"] == START_POSITION]):
        return entry
    if all([entry["pal_s"] == END_POSITION, entry["pal_e"] == END_POSITION]):
        return entry

    reset_value = 0.0
    s_diff = e_diff = None
    if entry["dist_start"] > entry["l_len"] / 2:
        if entry["pal_e"] >= 0.5:
            reset_value = 1.0
        entry["pal_s"] = reset_value
        s_diff = abs(entry["pal_s"] - entry["pal_s_org"])

    if entry["dist_end"] > entry["l_len"] / 2:
        if entry["pal_s"] == END_POSITION:
            reset_value = 1.0
        entry["pal_e"] = reset_value
        e_diff = abs(entry["pal_e"] - entry["pal_e_org"])

    # make sure the pal* attributes of a culvert that touches a channel
    # perpendicularly will get reset
    if s_diff or e_diff:
        diff_l = [s_diff, e_diff]
        diff = max(x for x in diff_l if x is not None)
        # we assume a difference of 10% is not likely
        if all(
            [diff > 0.1, diff != 0.0, diff != 1.0, entry["pal_e"] != entry["pal_s"]]
        ):
            entry["pal_s"] = entry["pal_e"] = 0.0

    return entry


def correct_positions_by_threshold(entry, min_threshold=0.01, max_threshold=0.99):
    """
    the position of the culvert start- and endpoints along the
    channel line will either be snapped to the start- or
    endpoint of the channel when they are beyond the
    given threshold

    :param entry: database entry from the culvert_valid table
    :param: min_threshold: point locations smaller than this
        threshold will be set to 0.0
    :param: max_threshold: point locations bigger than this
        threshold will be set to 1.0

    :returns updated entry
    """
    cnt_corrected_start = 0
    cnt_corrected_end = 0
    pal_s_org = entry["pal_s_org"]
    if all([pal_s_org < min_threshold, pal_s_org != START_POSITION]):
        corrected_pal_s = START_POSITION
        cnt_corrected_start += 1
    elif all([pal_s_org > max_threshold, pal_s_org != END_POSITION]):
        corrected_pal_s = END_POSITION
        cnt_corrected_end += 1
    else:
        corrected_pal_s = pal_s_org

    pal_e_org = entry["pal_e_org"]
    if all([pal_e_org > max_threshold, pal_e_org != END_POSITION]):
        corrected_pal_e = END_POSITION
        cnt_corrected_end += 1
    elif all([pal_e_org < min_threshold, pal_e_org != START_POSITION]):
        corrected_pal_e = START_POSITION
        cnt_corrected_start += 1
    else:
        corrected_pal_e = pal_e_org

    # if both pal_s and pal_e are close to either the start or endpoint
    # keep them as they are. Those are culverts on a very long
    # channel line
    if any([cnt_corrected_end == 2, cnt_corrected_start == 2]):
        relative_len_positions = abs(pal_e_org - pal_s_org) * 100
        relative_len_lines = (entry["l_len"] * 100) / entry["ch_len"]
        if are_almost_equal(relative_len_positions, relative_len_lines):
            corrected_pal_e = pal_e_org
            corrected_pal_s = pal_s_org
    entry["pal_s"] = corrected_pal_s
    entry["pal_e"] = corrected_pal_e

    return entry


def are_almost_equal(a, b, allowed_error=0.0001):
    """
    compare equality of two floats
    """
    return abs(a - b) <= allowed_error


def correct_crossings(culvert_id, entries):
    """
    will correct point along line entries for culverts that span across
    two or more channel lines by taking into account the direction of
    the culvert line.

    :param culvert_id: id int
    :param entries: list of culvert_valid table entries
    """

    ps = []
    ps_org = []
    pe = []
    pe_org = []
    # group entries for point along line attributes (start(s) and end(e))
    for entry in entries:
        ps.append(entry["pal_s"])
        pe.append(entry["pal_e"])
        ps_org.append(entry["pal_s_org"])
        pe_org.append(entry["pal_e_org"])

    s_index = e_index = None
    s_value = [x for x in ps if all((x > START_POSITION, x < END_POSITION))]
    # get index of start point
    if s_value:
        # one culvert, therefore only a single start position!
        s_index = ps.index(s_value[0])
    e_value = [x for x in pe if all((x > START_POSITION, x < END_POSITION))]
    # get index of end point
    if e_value:
        # one culvert, therefore only a single end position!
        e_index = pe.index(e_value[0])

    # both indices are present so the start and end point is on two different
    # channels. If the pal_e and pal_s attributes have been changed to due
    # to former corrections, reset them. Like this the drawing direction
    # of the culvert will be taken into account
    if s_index is not None and e_index is not None:
        # get corresponding p-start and p-end values
        pal_e = pe[s_index]
        pal_e_org = pe_org[s_index]
        if pal_e != pal_e_org:
            entries[s_index]["pal_e"] = pal_e_org
            logger.info(
                "[*] Culvert {}: Attribute pal_e has been reset from {} to {}".format(
                    culvert_id, pal_e, pal_e_org
                )
            )
        pal_s = ps[e_index]
        pal_s_org = ps_org[e_index]
        if pal_s != pal_s_org:
            entries[e_index]["pal_s"] = pal_s_org
            logger.info(
                "[*] Culvert {}: Attribute pal_s has been reset from {} to {}".format(
                    culvert_id, pal_s, pal_s_org
                )
            )

    return [
        (entry["channel_id"], entry["culvert_id"], entry["pal_e"], entry["pal_s"])
        for entry in entries
    ]
