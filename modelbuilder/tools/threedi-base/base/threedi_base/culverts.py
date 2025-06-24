from collections import defaultdict

from base.threedi_base import position
from base.threedi_base.apps import ThreediBaseConfig as conf
from base.threedi_base.constants import CULVERT_SNAPPED_TABLE_NAME
from base.threedi_base.exceptions import InsertError
from base.threedi_base.logger import Logger

logger = Logger.get(__name__, conf.LOG_LEVEL)


def get_chunk(l, n=2):
    n = max(1, n)
    return (l[i:i+n] for i in range(0, len(l), n))


class CulvertChannelLines:

    def __init__(self, db, buffer_size, culvert_input_table,
                 channel_input_table,
                 culvert_output_table_name,
                 channel_output_table_name):
        """
        :param db: ThreediDatabase instance
        :param buffer_size: size to buffer the start and
            endpoint of the culvert with
        :param culvert_input_table: name of the culvert table
        :param channel_input_table: name of the channel table
        :param culvert_output_table_name: name of the culvert output table
        :param channel_output_table_name: name of the channel output table
        """
        self.db = db
        self.buffer_size = buffer_size
        self.channel_input_table_name = channel_input_table
        self.culvert_input_table_name = culvert_input_table
        self.corrected_valids_table_name = 'culvert_valid_corrected'
        self.buffer_table_name = 'culvert_buff_pnts'
        self.valids_table_name = 'culvert_valid'
        self.misfits_table_name = 'culvert_misfits'
        self.culvert_snapped_table_name = CULVERT_SNAPPED_TABLE_NAME
        self.connection_nodes_tables = 'tmp_connection_nodes_structures'
        self.channel_output_table_name = channel_output_table_name
        self.culvert_channel_mapping = defaultdict(list)
        self.channel_culvert_mapping = defaultdict(list)
        self.channels_fully_replaced = set()

    def analyze_dataset(self):
        """
        separate the good from the bad, Create intermediate tables
        ``self.buffer_table_name`` and ``self.valids_table_name``
        """
        self._create_culvert_buffers()
        self._identify_misfits()
        self._identify_valids()
        self._create_channel_culvert_mappings()

    def remove_tmp_tables(self):
        """remove intermediate tables"""
        for table_name in (self.buffer_table_name,
                           self.valids_table_name):
            self.db.drop_item(name_item=table_name, type_item='TABLE')

    def _create_culvert_buffers(self):
        """
        creates a buffer around the start- and endpoints of the
        culvert line geometry.

        Buffer geometry of the startpoint
        will by accessible as column name ``start_b``

        Buffer geometry of the endpoint
        will by accessible as column name ``end_b``
        """

        statement = """
        DROP TABLE IF EXISTS {schema}.{table_name};
        CREATE TABLE {schema}.{table_name} AS
        SELECT
          *,
          ST_Buffer(
            ST_Startpoint(a.geom),
            {buffer_size}
          ) AS start_b,
          ST_Buffer(
            ST_Endpoint(a.geom),
            {buffer_size}
          ) AS end_b
        FROM
          {schema}.{input_table_name} AS a
        ;
        """.format(schema=self.db.schema,
                   input_table_name=self.culvert_input_table_name,
                   table_name=self.buffer_table_name,
                   buffer_size=self.buffer_size)
        self.db.free_form(statement, fetch=False)
        self.db.create_index(
            self.buffer_table_name, 'idx_startb', 'start_b', gist=True)
        self.db.create_index(
            self.buffer_table_name, 'idx_endb', 'end_b', gist=True)

    def _identify_misfits(self):
        """
        identify the culverts the are (partly) too
        far away from the channels
        """
        self.db.drop_item(self.misfits_table_name, 'TABLE')
        misfits_statement = """
        -- get misfits
        DROP SEQUENCE IF EXISTS misfits_id_seq;
        CREATE SEQUENCE misfits_id_seq;

        CREATE TABLE {schema}.{misfits_table} AS
        SELECT
          nextval('misfits_id_seq') AS id,
          b.id as channel_id,
          a.id as culvert_id,
          a.geom as geom
        FROM
          {schema}.{buffer_table} AS a
        LEFT JOIN
          {schema}.{channel_input_table} AS b
        ON
          ST_Intersects(b.geom, a.start_b)
        OR
          ST_Intersects(b.geom, a.end_b)
        WHERE
          b.id IS NULL
        ORDER by a.id
        ;""".format(schema=self.db.schema, buffer_table=self.buffer_table_name,
                    misfits_table=self.misfits_table_name,
                    channel_input_table=self.channel_input_table_name)
        self.db.free_form(misfits_statement, fetch=False)

    def get_count_misfits(self):
        """count the culverts that lay too far from a channel"""
        return self.db.get_count(table_name=self.misfits_table_name)

    def _identify_valids(self):
        """
        create a table of the culverts that can be
        linked to a channel
        """
        valids_statement = """
        DROP TABLE IF EXISTS {schema}.{valids_table_name};
        CREATE TABLE {schema}.{valids_table_name} AS
        SELECT
          b.id as channel_id,
          a.id as culvert_id,
          a.geom as geom,
          b.geom as geom_ch,
          -- generalize start and endpoints
          ST_LineLocatePoint(b.geom, ST_Startpoint(a.geom)) as pal_s_org,
          ST_LineLocatePoint(b.geom, ST_Endpoint(a.geom)) as pal_e_org,
          ST_Distance(b.geom, ST_Startpoint(a.geom)) as dist_start,
          ST_Distance(b.geom, ST_Endpoint(a.geom)) as dist_end,
          ST_Length(a.geom) AS l_len,
          ST_Length(b.geom) AS ch_len
        FROM
          {schema}.{buffer_table} AS a
        LEFT JOIN
          {schema}.{channel_input_table_name} AS b
        ON
          ST_Intersects(b.geom, a.start_b)
        OR
          ST_Intersects(b.geom, a.end_b)
        WHERE
          b.id IS NOT NULL
        ORDER by a.id
        ;
        """.format(schema=self.db.schema,
                   valids_table_name=self.valids_table_name,
                   buffer_table=self.buffer_table_name,
                   channel_input_table_name=self.channel_input_table_name)
        self.db.free_form(valids_statement, fetch=False)

    def get_corrected_valids(self):
        """
        select all entries from the database table ``culvert_valid_corrected``
        :returns a dictionary with all entries from
           database table ``culvert_valid_corrected``
        """

        entries = self.db.free_form(
            """
            SELECT
              a.*,
              b.pal_e AS pal_e,
              b.pal_s AS pal_s,
              ST_AsText(a.geom) AS geom,
              ST_AsText(a.geom_ch) AS geom_ch
            FROM
              {schema}.{valids_table_name} AS a
            LEFT JOIN
              {schema}.{corrected_valids_table_name} AS b
            ON
              a.culvert_id=b.culvert_id
            AND
              a.channel_id=b.channel_id
            ;""".format(
                schema=self.db.schema,
                valids_table_name=self.valids_table_name,
                corrected_valids_table_name=self.corrected_valids_table_name),
            fetch=True, fetch_as='dict')
        return entries

    def get_valids(self):
        """
        select all entries from the database table ``culvert_valid``
        :returns a dictionary with all entries from
           database table ``culvert_valid``
        """

        entries = self.db.free_form(
            """
            SELECT
              *,
              ST_AsText(geom) AS geom,
              ST_AsText(geom_ch) AS geom_ch
            FROM
              {schema}.{valids_table_name}
            ;""".format(schema=self.db.schema,
                        valids_table_name=self.valids_table_name),
            fetch=True, fetch_as='dict')
        return entries

    def _create_channel_culvert_mappings(self):
        """
        fills the ``culvert_channel_mapping`` and ``channel_culvert_mapping``
        dictionaries.
        Example item ``self.culvert_channel_mapping``::
            (<culvert_id>,
             [{'channel_id': 218278,
               'culvert_id': 18775,
               'geom': 'LINESTRING(130267.399095133 503416.05146975, ...)',
               'geom_ch': 'LINESTRING(130442.905 503308.345,130427.1, ...)',
               # position along line of end point culvert (generalized)
               'pal_e': 0.646281930928462,
               # position along line of end point culvert (original)
               'pal_e_org': 0.646281930928462,
               # position along line of start point culvert (generalized)
               'pal_s': 0.614951093082171,
               # position along line of start point culvert (original)
               'pal_s_org': 0.614951093082171
               }])
        """
        valids = self.get_valids()
        corrected_entries = self._correct_entries(valids)
        self.create_corrected_valids_table(
            corrected_entries
        )
        corrected_valids = self.get_corrected_valids()
        for c_entry in corrected_valids:
            self.culvert_channel_mapping[
                c_entry['culvert_id']].append(c_entry)
            self.channel_culvert_mapping[
                c_entry['channel_id']].append(c_entry)

    def _correct_entries(self, valids):
        """
        corrects the entries from the culvert_valid table by
          * a threshold. That is, the position of the culvert
            start- and endpoints along the channel line will
            either be snapped to the start- or endpoint of the
            channel when they are beyond the given threshold
          * the measured distance of the start- and endpoint to
            the given channel. That is, if the distance of the
            start- and endpoints to the channel in question is
            bigger than 2 * the buffer size for the start- and
            endpoints, the point along line attribute will be reset

        :param valids: list of entries from the ``culvert_valid`` table

        :returns a list of corrected entries
        """
        _corrected = defaultdict(list)
        for entry in valids:
            entry_cpos = position.correct_positions_by_threshold(entry)
            entry_cd = position.correct_positions_by_distance(entry_cpos)
            _corrected[entry['culvert_id']].append(entry_cd)

        corrected_entries = []
        for culvert_id, entries in _corrected.items():
            if len(entries) > 1:
                corrected_crossings = position.correct_crossings(
                    culvert_id, entries
                )
                corrected_entries.extend(corrected_crossings)
            else:
                entry = entries[0]
                corrected_entries.append(
                    (entry['channel_id'], entry['culvert_id'],
                     entry['pal_e'], entry['pal_s'])
                )
        return corrected_entries

    def create_corrected_valids_table(self, corrected_entries):
        field_names = 'channel_id, culvert_id, pal_e, pal_s'
        self.db.create_table(
            self.corrected_valids_table_name, field_names.split(','),
            ['bigint', 'bigint', 'double precision', 'double precision']
        )
        
        self.db.commit_values(
            self.corrected_valids_table_name, field_names, corrected_entries
        )
        self.db.create_index(
            table_name=self.valids_table_name,
            index_name='idx_valids_culvert_id', column='culvert_id'
        )
        self.db.create_index(
            table_name=self.corrected_valids_table_name,
            index_name='idx_corrected_valids_culvert_id', column='culvert_id'
        )

    def create_tmp_culverts(self):
        # create new culverts

        self.db.create_table(
            self.culvert_snapped_table_name,
            ["culvert_id", "geom"],
            ["bigint", "geometry"]
        )
        for culvert_id, channel_map in \
                self.culvert_channel_mapping.items():
            self.merge_culvert_subparts(culvert_id, channel_map)

    def clip_channels_by_culverts(self):
        # clip channels by culverts
        self.db.create_table(
            table_name=self.channel_output_table_name,
            field_names=["channel_id", "part_id", "geom"],
            field_types=["bigint", "smallint", "geometry"]
        )

        channels_to_be_removed = []
        for channel_id, items in self.channel_culvert_mapping.items():
            ordered_positions = position.get_ordered_positions(items)
            # culvert completely on channel line. Mark channel
            # for deletion
            if position.fully_covered(ordered_positions):
                channels_to_be_removed.append(channel_id)
                continue
            # check for false positives
            if position.must_be_skipped(ordered_positions):
                continue

            cleaned_ordered_positions = position.remove_duplicate_positions(
                ordered_positions
            )
            positions = position.add_start_end_position(
                cleaned_ordered_positions
            )
            flipped_positions = position.flip_start_end_position(positions)
            self.create_channel_sub_lines(channel_id, flipped_positions)

        self.add_channels_without_culvert()

    def create_channel_sub_lines(self, channel_id, positions):
        """
        fills the channel_output_table with columns
          channel_id,
          part_id,
          geometry (line)

        :param channel_id: id of the channel object
        :param positions: all the positions that make up the
            channel line geometry
        """
        cnt = 0
        try:
            for a, b in get_chunk(positions):
                statement_line_substring = """
                ST_LineSubstring(
                  a.geom_ch, {}, {}
                )
                """.format(a, b)

                insert_statement = """
                INSERT INTO
                  {schema}.{output_table_name}(channel_id, part_id, geom)
                SELECT DISTINCT ON(a.channel_id)
                  a.channel_id,
                  {cnt},
                  {st_line_substring}
                FROM
                  {schema}.{valids_table_name} AS a
                WHERE
                  a.channel_id={channel_id}
                ;
                """.format(
                    schema=self.db.schema,
                    valids_table_name=self.valids_table_name,
                    output_table_name=self.channel_output_table_name,
                    channel_id=channel_id, cnt=cnt,
                    st_line_substring=statement_line_substring
                )
                self.db.free_form(insert_statement, fetch=False)
                cnt += 1
        except ValueError:
            msg = 'Failed to create line for channel {}. ' \
                  'Has the following positions {}'.\
                format(channel_id, positions)
            logger.exception(msg)
            raise InsertError(msg)

    def add_channels_without_culvert(self):
        statement = """
        INSERT INTO {schema}.{channel_output_table}(channel_id, part_id, geom)
        SELECT
          a.id AS channel_id
          , 0 AS part_id  -- has only a single part
          , a.geom AS geom
        FROM
          {schema}.{original_channels} AS a
        LEFT JOIN
           {schema}.{valids_table_name} AS b
        ON
          a.id=b.channel_id
        WHERE
          b.channel_id IS NULL
        ;
        """.format(
            schema=self.db.schema,
            original_channels=self.channel_input_table_name,
            channel_output_table=self.channel_output_table_name,
            valids_table_name=self.valids_table_name,
        )
        self.db.free_form(sql_statement=statement, fetch=False)

    def filter_channels(self, entries):
        """
        filter channels that do not share any space with culvert
        or are fully covered by culverts. Filters the current
        selection against a set of channels that are already filled or
        replaced by culvert geometries to avoid duplicates.
        """
        current_selection = set()
        fully_covered_by = set()
        for entry in entries:
            positions = [entry['pal_e'], entry['pal_s']]
            positions.sort()
            if position.must_be_skipped(positions):
                continue
            if position.fully_covered(positions):
                fully_covered_by.add(entry['channel_id'])
            current_selection.add(entry['channel_id'])
        filtered_channel_ids = current_selection.difference(
            self.channels_fully_replaced
        )
        self.channels_fully_replaced.update(fully_covered_by)
        return filtered_channel_ids

    def merge_culvert_subparts(self, culvert_id, entries):
        """
        performs a ST_LineMerge on all culvert sub-linestrings that have
        the same channel_id
        """

        channel_ids = self.filter_channels(entries)
        if not channel_ids:
            return
        if all([channel_id in self.channels_fully_replaced
                for channel_id in channel_ids]):
            for channel_id in channel_ids:
                self.insert_into_culvert_output_table(
                    [channel_id], culvert_id
                )
        else:
            self.insert_into_culvert_output_table(channel_ids, culvert_id)

    def insert_into_culvert_output_table(self, channel_ids, culvert_id):
        """

        """
        ids_str = ','.join([str(x) for x in channel_ids])

        insert_statement = """
        INSERT INTO
          {schema}.{culvert_output_table_name} (culvert_id, geom)
        SELECT
          DISTINCT ON(culvert_id) subq.culvert_id AS culvert_id,
          ST_LineMerge(
            ST_Collect(
              subq.culvert_n
            )
          ) AS geom
        FROM (
          SELECT
            DISTINCT ON(a.channel_id)
            a.*,
            CASE WHEN (
              a.pal_s > a.pal_e)
            THEN
              ST_LineSubstring(b.geom_ch, a.pal_e, a.pal_s)
            ELSE
              ST_LineSubstring(b.geom_ch, a.pal_s, a.pal_e)
            END AS culvert_n
          FROM
            {schema}.{corrected_valids_table_name} AS a
          LEFT JOIN
            {schema}.{valids_table_name} AS b
          ON
            a.culvert_id=b.culvert_id
          AND
            a.channel_id=b.channel_id
          WHERE
            a.channel_id IN ({channel_ids})
          AND
           a.culvert_id={culvert_id}

        ) AS subq
        GROUP BY
          subq.culvert_id
        ;
        """.format(
            channel_ids=ids_str,
            culvert_output_table_name=self.culvert_snapped_table_name,
            schema=self.db.schema,
            valids_table_name=self.valids_table_name,
            corrected_valids_table_name=self.corrected_valids_table_name,
            culvert_id=culvert_id,
        )
        self.db.free_form(insert_statement, fetch=False)

    @staticmethod
    def get_channel_ids(items, as_string=False):
        """
        :param items: list of dicts. dict must contain key channel_id
        :param as_string: if True the ids as will be returned as strings,
            if False (default) as integers
        :returns a list of channel_ids
        """
        return [str(item['channel_id'])
                if as_string
                else item['channel_id']
                for item in items]

    def get_start_or_end_point(self, geom_as_text, position):
        if position == 'start':
            st = 'ST_Startpoint'
        elif position == 'end':
            st = 'ST_Endpoint'

        statement = """
        SELECT
          ST_AsText(
            {st}(
              ST_GeomFromText(
                '{geom}'
              )
            )
          )
        ;
        """.format(st=st, geom=geom_as_text)
        return self.db.free_form(statement, fetch=True)[0][0]

    def move_multi_geoms_to_misfits(self):
        """
        """

        insert_to_misfits_statement = """
        INSERT INTO
          {schema}.{misfits_table} (id, culvert_id, geom)
        SELECT
          nextval('misfits_id_seq') AS id,
          a.id AS culvert_id,
          a.geom as geom
        FROM
          {schema}.{culverts_snapped_table} AS a
        WHERE
          ST_NumGeometries(geom) > 1
        ;""".format(
            schema=self.db.schema, misfits_table=self.misfits_table_name,
            culverts_snapped_table=self.culvert_snapped_table_name
        )
        self.db.free_form(insert_to_misfits_statement, fetch=False)

        del_from_snapped_table_statement = """
        DELETE FROM
          {schema}.{culverts_snapped_table}
        WHERE
          ST_NumGeometries(geom) > 1
        ;
        """.format(
            schema=self.db.schema,
            culverts_snapped_table=self.culvert_snapped_table_name
        )
        self.db.free_form(del_from_snapped_table_statement, fetch=False)

    def add_missing_culverts_to_misfits(self):

        add_missing_statemet = """
        INSERT INTO
          {schema}.{misfits_table} (id, culvert_id, geom)
        SELECT
          nextval('misfits_id_seq') AS id,
          a.id AS culvert_id,
          a.geom AS geom
        FROM
          {schema}.{culvert_input_table_name} AS a
        LEFT JOIN
           {schema}.{misfits_table} AS b
        ON
          a.id=b.culvert_id
        LEFT JOIN
          {schema}.{culverts_snapped_table} AS c
        ON
          a.id=c.culvert_id
        WHERE
           c.culvert_id IS NULL
        AND
          b.culvert_id IS NULL
        ;
        """.format(
            schema=self.db.schema,
            culverts_snapped_table=self.culvert_snapped_table_name,
            culvert_input_table_name=self.culvert_input_table_name,
            misfits_table=self.misfits_table_name
        )
        self.db.free_form(add_missing_statemet, fetch=False)
