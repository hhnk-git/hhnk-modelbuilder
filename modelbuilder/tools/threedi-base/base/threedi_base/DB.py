# (c) Nelen & Schuurmans.  GPL licensed, see LICENSE.rst.
# -*- coding: utf-8 -*-

import psycopg2
from django.template import Context, Template
from psycopg2.extras import RealDictCursor

from base.threedi_base import sql
from base.threedi_base.apps import ThreediBaseConfig as conf
from base.threedi_base.exceptions import UpdateError
from base.threedi_base.logger import Logger

logger = Logger.get(__name__, conf.LOG_LEVEL)


DEFAULT_FETCH = conf.DEFAULT_FETCH


class ThreediDatabase(object):
    """
    Connects to a database using python's psycopg2 module.
    """

    def __init__(self, **kwargs):
        """
        Establishes the db connection.
        """
        self.schema = kwargs.pop('schema')
        try:
            self.db = psycopg2.connect(**kwargs)
        except psycopg2.Error as e:
            logger.exception(e)
            raise

    def create_table(self, table_name, field_names, field_types):
        """
        :param table_name: string that will be used as a name in the database.
        :param field_names: list of field names to add to the tables
        :param field_types: list of field types

        example::
            create_table(
                "my_table", ["foo", "bar", "my_double"],
                ["serial", "smallint", "double precision"]
            )
        """

        if not table_name:
            raise ValueError('[E] table_name {} is not definied'.format(
                table_name)
            )
        table_name = table_name

        row_def_raw = []
        for e, ee in zip(field_names, field_types):
            s = '%s %s' % (e, ee)
            row_def_raw.append(s)

        row_def = ','.join(row_def_raw)
        create_str = """
            CREATE TABLE
              {schema}.{table_name}
            (id serial PRIMARY KEY,{row_definition})
            ;
            """.format(
            schema=self.schema, table_name=table_name, row_definition=row_def
        )

        try:
            cur = self.db.cursor()
            del_str = "DROP TABLE IF EXISTS %s.%s;" % (self.schema, table_name)
            cur.execute(del_str)
            cur.execute(create_str)
            self.db.commit()
            logger.info(
                '[+] Successfully created table {}.{}  ...'.format(
                    self.schema, table_name)
            )
            return

        except psycopg2.DatabaseError as e:
            self._raise(e)

    def commit_values(self, table_name, field_names, data):
        """
        :param table_name: destination table
        :param field_names: field names that correspond with the
            data array
        :param data: array of tuples with data to insert
        """

        try:
            cur = self.db.cursor()
            records_list_template = ','.join(['%s'] * len(data))
            insert_query = """
            INSERT INTO
              {schema}.{table_name}({field_names})
            VALUES
              {template}""".format(
                schema=self.schema, table_name=table_name,
                field_names=field_names, template=records_list_template
            )
            print(insert_query, data)
            cur.execute(insert_query, data)
            self.db.commit()

        except psycopg2.DatabaseError as e:
            self._raise(e)

    def create_index(self, table_name, index_name, column, gist=False):

        self.drop_item(index_name, 'INDEX')
        if gist is True:
            create_index_str = """
                CREATE INDEX
                  {0:s}
                ON
                  {3:s}.{1:s}
                USING
                  GIST({2:s})
                ;
                """.format(index_name, table_name, column, self.schema)
        else:
            create_index_str = """
                 CREATE INDEX
                   {0:s}
                 ON
                   {3:s}.{1:s} ({2:s})
                  ;
                  """.format(index_name, table_name, column, self.schema)

        try:
            cur = self.db.cursor()
            cur.execute(create_index_str)
            self.db.commit()
            logger.info(
                '[+] Index {0:s} created successfully...'.format(index_name)
            )
            return

        except psycopg2.DatabaseError as e:
            self._raise(e)

    def simple_select(self, table_name, fields=None, filter_by=None,
                      filter_value=None, operator='=', schmema=None,
                      fetch_as=DEFAULT_FETCH):
        """
        select entries from a database table

        :param table_name: name of the table
        """
        try:
            cur = self._get_cursor(fetch_as)
            if not fields:
                fields = '*'

            sel_str = \
                """SELECT
                     {fields:s}
                   FROM
                     {schema:s}.{table_name:s}
                   WHERE
                     {filter:s} {operator:s} '{filter_value:s}';
                """.format(
                    fields=fields, table_name=table_name,
                    filter=filter_by, operator=operator,
                    filter_value=filter_value, schema=self.schema
                )
            logger.debug(sel_str)
            cur.execute(sel_str)
            return cur.fetchall()

        except psycopg2.DatabaseError as e:
            self._raise(e)

    def count_identical_geos(self, table_name1, table_name2,
                             geom_column='geom', fetch_as=DEFAULT_FETCH):
        '''
        Uses the postGis function ST_Equals to
        checks how many identical geometries are in
        table_name1 & table_name2
        '''

        try:
            cur = self._get_cursor(fetch_as)
            sel_str = """
                SELECT
                  COUNT(*)
                FROM
                  {table_name1} AS c,
                  {table_name2} AS d
                WHERE
                  ST_Equals(d.{geom_column}, c.{geom_column})
                ;""".format(
                table_name1=table_name1, table_name2=table_name2,
                geom_column=geom_column
                )
            logger.debug(sel_str)
            cur.execute(sel_str)
            return cur.fetchone()[0]

        except psycopg2.DatabaseError as e:
            self._raise(e)

    def get_geos_dwithin(self, table_name1, table_name2, distance_m,
                         filter_by=None, filter_value=None,
                         selector='=', fetch_as=DEFAULT_FETCH):
        """
        :param table_name1:
        Uses the postGis 'ST_DWithin' function to select geometries from
        table_name2 that are in the vicinity of geometries in
        table_name1.

        IMPORTANT: both tables need to have a geography column!
        """
        try:
            cur = self._get_cursor(fetch_as)
            sel_str = "SELECT * FROM {0:s} AS c " \
                      "JOIN {1:s} AS d on ST_DWithin(d.geog, c.geog, {2:d}) " \
                      "WHERE c.{3:s} {4:s} {5:s};".format(table_name1,
                                                          table_name2,
                                                          distance_m,
                                                          filter_by,
                                                          selector,
                                                          filter_value)

            logger.debug(sel_str)
            cur.execute(sel_str)
            return cur.fetchall()

        except psycopg2.DatabaseError as e:
            self._raise(e)

    def get_count(self, table_name):
        """

        :param table:
        :return:
        """
        try:
            cur = self._get_cursor()
            sel_str = "SELECT COUNT(*) from {schema}.{table_name:s}".format(
                table_name=table_name, schema=self.schema)
            logger.debug(sel_str)
            cur.execute(sel_str)
            return cur.fetchone()[0]

        except psycopg2.DatabaseError as e:
            self._raise(e)

    def snap_to_grid(
            self, table_name, geom_column, precision=0.001):
        """
        snap all geometries to a regular grid with the given precision

        :param table_name: the table to update
        :param geom_column: the name of the column that holds the geometries
        :param precision: precision to use. Default is 0.001 (1mmm)
        """
        update_str = """
        UPDATE
          {schema}.{table_name}
        SET
          {geom_column} = ST_SnapToGrid(
            {geom_column}, 0, 0, {precision}, {precision})
          ;
        """.format(table_name=table_name, geom_column=geom_column,
                   precision=precision, schema=self.schema)
        try:
            self.free_form(update_str, fetch=False)
        except psycopg2.DatabaseError as e:
            raise UpdateError(
                'Updating column {} of table {} failed with error:'
                '\n {}'.format(geom_column, table_name, e)
            )

    def snap_start_end(
            self, input_table, output_table, snap_distance,
            schema=None, geom_column='geom'):
        """Snap channel lines that are 0.2m apart from each other together
        and put them in a new table.

        Args:
            schema: schema name
            geom_column: name of geometry column
            input_table: the line table to be snapped
            output_table: table with snapped lines created by this method

        Temporary tables (may be deleted afterwards):
            tmp_snappoints
            tmp_snappoints_union
        """
        schema = schema or self.schema
        sql_str = sql.snap_start_end.format(
            schema=schema, geom_column=geom_column,
            input_table=input_table, output_table=output_table,
            snap_distance=snap_distance)
        self.free_form(sql_str, fetch=False)

    def simplify_lines(self, input_table, output_table, minimum_line_len,
                       geom_column='geom'):
        """Simplify lines using ST_SnapToGrid."""
        sql_str = sql.simplify_lines.format(
            geom_column=geom_column,
            schema=self.schema,
            input_table=input_table,
            output_table=output_table
        )
        self.free_form(sql_str, fetch=False)
        sql_str = sql.remove_short_lines.format(
            schema=self.schema,
            table_name=output_table, geom_column=geom_column,
            minimum_line_len=minimum_line_len)
        self.free_form(sql_str, fetch=False)

    def cut_circular(
            self, geom_column='geom',
            input_table='tmp_watergangen_eenvoudig2a',
            output_table='tmp_watergangen_eenvoudig3'):
        """Cut up circular lines, i.e., lines that have the same start and end
        point.

        Args:
            geom_column: name of geom column
            input_table: table with lines to cut
            output_table: table produced by this method
        """
        sql_str = sql.cut_circular.format(
            schema=self.schema,
            geom_column=geom_column,
            input_table=input_table,
            output_table=output_table
        )
        self.free_form(sql_str, fetch=False)

    def merge_lines(self, input_table, output_table, geom_column='geom'):
        """
        Args:
            geom_column: name of geom column
            input_table: table with lines to cut
            output_table: table produced by this method

        """
        merge_lines_statement = """
        DROP TABLE IF EXISTS {schema}.{output_table};
        CREATE TABLE {schema}.{output_table} AS
        SELECT
          ST_SnapToGrid(
            ST_LineMerge(
              ST_Union(
                {geom_column}
              )
            ), 0,0,0.05,0.05
          ) as geom
        FROM
          {schema}.{input_table}
        ;
        """.format(
            schema=self.schema,
            geom_column=geom_column,
            input_table=input_table,
            output_table=output_table
        )
        self.free_form(merge_lines_statement, fetch=False)

    def union_geoms(self, input_table, output_table, geom_column='geom'):
        """
        union geometries of ``input_table`` into ``output_table``
        """
        union_geoms_statement = """
        DROP TABLE IF EXISTS {schema}.{output_table};
        CREATE TABLE {schema}.{output_table} AS
        SELECT
          ST_SnapToGrid(
            ST_Union(
              {geom_column}
            ), 0, 0, 0.05, 0.05
          )  as geom
        FROM
          {schema}.{input_table}
        ;
        """.format(
            schema=self.schema,
            input_table=input_table,
            output_table=output_table,
            geom_column=geom_column
        )
        self.free_form(union_geoms_statement, fetch=False)

    def buffer_geoms(self, input_table, output_table, buffer_size=0.05,
                     endcap='flat', geom_column='geom'):
        """
        buffer geometries of ``input_table`` by ``buffer_size``. Saves
        results into  ``output_table``.
        """
        buffer_geoms_statement = """
        DROP TABLE IF EXISTS {schema}.{output_table};
        CREATE TABLE {schema}.{output_table} AS
        SELECT
           ST_SnapToGrid(
                ST_Buffer(
                  {geom_column}, {buffer_size}, 'endcap={endcap}'
             ), 0, 0, 0.05, 0.05
           ) AS geom
        FROM {schema}.{input_table}
        ;
        """.format(schema=self.schema,
                   geom_column=geom_column,
                   output_table=output_table,
                   input_table=input_table,
                   buffer_size=buffer_size,
                   endcap=endcap)
        self.free_form(buffer_geoms_statement, fetch=False)

    def clip_geoms(self, base_input_table, clip_by_table, output_table,
                   geom_column='geom'):
        """
        clip geometries of ``base_input_table`` with geometries of
        ``clip_by_table`` to ``output_table`` using postgis' ST_Difference
        function.
        """

        clip_geoms_statement = """
        DROP TABLE IF EXISTS {schema}.{output_table};
        CREATE TABLE {schema}.{output_table} AS
        SELECT
           ST_SnapToGrid(
             ST_Difference(
               a.{geom_column}, b.{geom_column}
             ), 0, 0, 0.05, 0.05
           ) AS geom
        FROM
          {schema}.{base_input_table} AS a,
          {schema}.{clip_by_table} AS b
        ;""".format(
            schema=self.schema,
            base_input_table=base_input_table,
            clip_by_table=clip_by_table,
            output_table=output_table,
            geom_column=geom_column
        )
        self.free_form(clip_geoms_statement, fetch=False)

    def linify_structures(
            self, structure_tables, channel_table):
        """
        Convert structure point geometries of to line geometries. The output
        table containing the line geometries is called:
         "`structure_table`_linified".

        :param structure_tables - list of one or more structure tables (e.g.
            pumpstation, weirs, bridge)
        :param channel_table - the table containing the channels

        """
        template = Template(sql.linify_structures_template)
        context = Context({
            'schema': self.schema,
            'structure_tables': structure_tables,
            'channel_table': channel_table
        })
        sql_str = template.render(context)
        self.free_form(sql_str, fetch=False)

    def add_missing_connection_nodes_for_culverts(
            self, connection_node_table, culvert_table,
            geom_column_cn='the_geom', geom_column_culvert='geom'):
        sql_query = sql.add_missing_connection_nodes_for_culverts.format(
            schema=self.schema,
            connection_node_table=connection_node_table,
            culvert_table=culvert_table, geom_column_cn=geom_column_cn,
            geom_column_culvert=geom_column_culvert
        )
        self.free_form(sql_query, fetch=False)

    def fix_short_segments_channel(
            self,
            geom_column='geom',
            channel_table='tmp_sel_branches_without_structures',
            min_distance=5,
            remove_table='remove_channel'):
        """Fix up for short (< min_distance) lines by effectively removing
        them.

        Args:
            input table: name of the table that will be fixed
            geom_column: geom column of the input table
            culvert_geom_column: geom column of tmp_sel_culvert
        """
        for sql_str in [
            sql.fix_short_segments_create_remove_table.format(
                schema=self.schema,
                remove_table=remove_table,
            ),
            sql.fix_short_segments_channel.format(
                schema=self.schema,
                geom_column=geom_column,
                channel_table=channel_table,
                min_distance=min_distance,
                remove_table=remove_table,
            ),
            sql.fix_short_segments_cleanup_reaches.format(
                schema=self.schema,
                channel_table=channel_table,
                remove_table=remove_table,
            ),
        ]:
            self.free_form(sql_str, fetch=False)

    def fix_short_segments_culvert(
            self,
            channel_table='tmp_sel_branches_without_structures',
            culvert_table='culverts',
            geom_column='geom',
            culvert_geom_column='geom',
            min_distance=5,
            remove_table='remove_culvert'):
        """Fix up for short (< min_distance) lines by effectively removing
        them.

        Args:
            channel_table: name of the channel table
            culvert_table: name of the culvert table, without the tmp_sel_
            geom_column: geom column of the input table
            culvert_geom_column: geom column of tmp_sel_culvert
        """
        if culvert_table.startswith('tmp_sel_'):
            culvert_table = culvert_table.split('tmp_sel_')[1]
        for sql_str in [
            sql.fix_short_segments_create_remove_table.format(
                schema=self.schema,
                remove_table=remove_table,
            ),
            sql.fix_short_segments_culvert.format(
                schema=self.schema,
                geom_column=geom_column,
                culvert_geom_column=culvert_geom_column,
                channel_table=channel_table,
                culvert_table=culvert_table,
                min_distance=min_distance,
                remove_table=remove_table,
            ),
            sql.fix_short_segments_cleanup_reaches.format(
                schema=self.schema,
                channel_table=channel_table,
                remove_table=remove_table,
            ),
        ]:
            self.free_form(sql_str, fetch=False)

    def fix_short_segments_structures(
            self,
            geom_column='geom',
            structures=None,
            channel_table='tmp_sel_branches_without_structures',
            min_distance=5,
            remove_table='remove_structures'):
        """Fix up for short (< min_distance) lines by effectively removing
        them.

        Args:
            input table: name of the table that will be fixed
            geom_column: geom column of the input table
            structures: a list of structure names, without the tmp_sel_
        """
        if not structures:
            return

        create_rm_table = sql.fix_short_segments_create_remove_table.format(
            schema=self.schema,
            remove_table=remove_table,
        )
        structure_sqls = [
            sql.fix_short_segments_structure.format(
                schema=self.schema,
                geom_column=geom_column,
                channel_table=channel_table,
                min_distance=min_distance,
                remove_table=remove_table,
                structure_name=s
            ) for s in structures if s
        ]
        cleanup = sql.fix_short_segments_cleanup_reaches.format(
            schema=self.schema,
            channel_table=channel_table,
            remove_table=remove_table,
        )

        for sql_str in ([create_rm_table] + structure_sqls + [cleanup]):
            self.free_form(sql_str, fetch=False)

    def assign_cross_section(
            self,
            geom_column='geom',
            input_table='tmp_sel_branches_without_structures',
            cross_section_table='cross_section',
            output_table='tmp_v2_cross_section_location'
            ):
        """Assign cross sections to channels.

        Args:
            geom_column: geom column name of input_table
            cross_section_table: table name of the cross sections
            drop_and_create_sequence: if True, drop and create a new sequnce
                'v2_cross_section_definition_id_seq'

        Temporary tables created:
            tmp_sel_branches_without_structures_buf
            tmp_extra_crs
            tmp_channel_without_profile
        """
        sql_str = sql.assign_cross_section.format(
            schema=self.schema,
            geom_column=geom_column,
            input_table=input_table,
            output_table=output_table,
            cross_section_table=cross_section_table,
        )
        self.free_form(sql_str, fetch=False)

    def free_form(self, sql_statement, fetch=True, fetch_as=DEFAULT_FETCH):
        """
        :param sql_statement: custom sql statement

        makes use of the existing database connection to run a custom query
        """

        try:
            cur = self._get_cursor(fetch_as)
            cur.execute(sql_statement)
            self.db.commit()
            logger.debug(
                "[+] Successfully executed statement {}".format(
                    sql_statement)
            )
            if fetch is True:
                return cur.fetchall()

        except psycopg2.DatabaseError as e:
            self._raise(e)

    def create_sequence(self, sequence_name='serial', schema=None):
        """create a sequnce"""
        schema = schema or self.schema
        drop_sequence = """DROP SEQUENCE {sequence_name};""".format(
            schema=schema, sequence_name=sequence_name)
        self.free_form(drop_sequence, fetch=False)
        create_sequence_statement = """
        CREATE SEQUENCE {sequence_name}
        ;""".format(
            sequence_name=sequence_name, schema=schema
        )
        self.free_form(sql_statement=create_sequence_statement, fetch=False)

    def drop_item(self, name_item, type_item):
        """

        :param name_item: name of a table, view, ...
        :param type_item: type of the item, e.g. TABLE, VIEW,...
        :return:
        """
        try:
            sql_drop = """
            DROP
              {type}
            IF EXISTS
              {schema}.{name}
            ;
            """.format(type=type_item.upper(), name=name_item,
                       schema=self.schema)
            logger.debug(sql_drop)
            cur = self.db.cursor()
            cur.execute(sql_drop)
            self.db.commit()
            logger.info(
                '[+] Successfully dropped {0:s} {2:s}.{1:s} ...'.format(
                    type_item, name_item, self.schema)
            )
        except psycopg2.DatabaseError as e:
            self._raise(e)

    def close_cursor(self):
        cur = self.db.cursor()
        cur.close()

    def _get_cursor(self, user_choise=""):
        if user_choise == 'dict':
            return self.db.cursor(cursor_factory=RealDictCursor)
        else:
            return self.db.cursor()

    def _raise(self, _exception):
        if self.db:
            self.db.rollback()
        logger.error('Error %s' % _exception)
        raise

    def create_tmp_sel_culvert_table(
            self, connection_nodes_tables, culvert_input_table,
            culvert_output_table):
        """
        create the result table
        """
        self.create_index(
            connection_nodes_tables, 'idx_connection_nodes', 'the_geom',
            gist=True
        )
        self.create_index(
            culvert_input_table, 'idx_snapped_culvert', 'geom',
            gist=True
        )
        statement = """
        DROP SEQUENCE IF EXISTS culvert_id_seq;
        CREATE SEQUENCE culvert_id_seq;

        DROP TABLE IF EXISTS {schema}.{culvert_output_table};
        CREATE TABLE {schema}.{culvert_output_table} AS
        WITH culvert_simple AS (
            SELECT
              nextval('culvert_id_seq') AS id,
              culvert_id,
              (ST_Dump(ST_LineMerge(ST_SnapToGrid(geom,0.05)))).geom
               AS geom
            FROM
              {schema}.{culvert_input_table}
            GROUP BY
              culvert_id,
              geom
            )
        SELECT
          a.*,
          b.id as connection_node_start_id,
          c.id as connection_node_end_id
        FROM
          culvert_simple AS a
        LEFT JOIN
          {schema}.{connection_nodes_tables} as b
        ON
          ST_DWithin(ST_Startpoint(a.geom), b.the_geom, 0.2)
        LEFT JOIN
          {schema}.{connection_nodes_tables} AS c
        ON
          ST_DWithin(ST_Endpoint(a.geom), c.the_geom, 0.2)
        ;
        """.format(schema=self.schema,
                   culvert_output_table=culvert_output_table,
                   culvert_input_table=culvert_input_table,
                   connection_nodes_tables=connection_nodes_tables)
        self.free_form(sql_statement=statement, fetch=False)

    def table_exists(self, table_name, schema=None):
        schema = schema or self.schema

        statement = """
        SELECT EXISTS (
        SELECT 1
        FROM   information_schema.tables
        WHERE  table_schema = '{schema}'
        AND    table_name = '{table_name}'
        );
        """.format(schema=schema, table_name=table_name)
        return self.free_form(statement, fetch=True)[0][0]
