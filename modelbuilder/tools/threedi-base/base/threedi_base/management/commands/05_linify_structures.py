# -*- coding: utf-8 -*-
from psycopg2 import DatabaseError

from base.threedi_base import sql
from base.threedi_base.command_utils import ThreediBaseCommand
from base.threedi_base.constants import (
    CULVERT_OUTPUT_TABLE_NAME,
    CULVERT_SNAPPED_TABLE_NAME,
)


class Command(ThreediBaseCommand):
    """
    Example for running this command:
    $ python manage.py linify_structures --structure-tables=pumpstation,weirs,bridge --channel-table=clipped_channel  # NOQA

    N.B. this command needs to be called in one sweep for all structure tables,
    in order to create and connect the connection nodes correctly.

    """

    help = "Convert structure point geometries to line geometries."

    def add_arguments(self, parser):
        super(Command, self).add_arguments(parser)
        parser.add_argument(
            "--structure-tables",
            action="store",
            dest="structure_tables",
            default="bridge,pumpstation,weirs",
            help="One or more comma-separated structure tables",
        )
        parser.add_argument(
            "--channel-table",
            action="store",
            default="channel_cut_circular",
            dest="channel_table",
            help="Channel table",
        )

    def handle(self, *args, **options):
        self.set_start_time()
        self.setup_db(*args, **options)
        status = "error"
        msg = ""
        nodes_exist = self.db.table_exists("v2_connection_nodes")
        if not nodes_exist:
            self.db.free_form(
                sql.create_connection_nodes_statement.format(
                    schema=self.db.schema,
                ),
                fetch=False,
            )
        tmp_connection_node_table = "tmp_connection_nodes_structures"
        structure_tables_raw = options["structure_tables"]
        structure_tables = structure_tables_raw.split(",")
        channel_table = options["channel_table"]
        try:
            self.db.linify_structures(structure_tables, channel_table)
            self.db.create_tmp_sel_culvert_table(
                connection_nodes_tables=tmp_connection_node_table,
                culvert_input_table=CULVERT_SNAPPED_TABLE_NAME,
                culvert_output_table=CULVERT_OUTPUT_TABLE_NAME,
            )
            self.db.add_missing_connection_nodes_for_culverts(
                connection_node_table=tmp_connection_node_table,
                culvert_table=CULVERT_OUTPUT_TABLE_NAME,
            )
            status = "success"
            msg = "Successfully executed command in {}".format(self.get_exec_time())
        except DatabaseError as u_err:
            msg = u_err
        finally:
            self.deliver_message(msg, status)
