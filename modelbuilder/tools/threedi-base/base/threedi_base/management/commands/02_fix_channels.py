# -*- coding: utf-8 -*-
from psycopg2 import DatabaseError

from base.threedi_base.command_utils import ThreediBaseCommand
from base.threedi_base.constants import SNAP_START_END_DISTANCE


class Command(ThreediBaseCommand):
    help = "Snap end points of lines that are close to each other."

    def add_arguments(self, parser):
        super(Command, self).add_arguments(parser)

        parser.add_argument(
            "--input-table",
            action="store",
            dest="input_table",
            default="channel",
            help="Input table name",
        )
        parser.add_argument(
            "--output-table",
            action="store",
            dest="output_table",
            default="channel_simplified",
            help="Output table name",
        )
        parser.add_argument(
            "--snap-distance",
            action="store",
            dest="snap_distance",
            default=SNAP_START_END_DISTANCE,
            type=float,
            help="Snap distance in meters. This distance will also "
            "function as a minimum line length threshold. That is, "
            "all channels that are shorter will be remove. "
            "Default {}.".format(SNAP_START_END_DISTANCE),
        )

    def handle(self, *args, **options):
        snapped_table_name = "channel_snapped"
        status = "error"
        msg = ""
        self.set_start_time()
        self.setup_db(*args, **options)
        try:
            self.db.snap_start_end(
                input_table=options["input_table"],
                output_table=snapped_table_name,
                snap_distance=options["snap_distance"],
            )
            self.db.simplify_lines(
                input_table=snapped_table_name,
                output_table=options["output_table"],
                minimum_line_len=SNAP_START_END_DISTANCE,
            )
            status = "success"
            msg = (
                "Successfully executed command in {}. \n"
                "Output has been stored to {}.{}".format(
                    self.get_exec_time(), self.db.schema, options["output_table"]
                )
            )
        except DatabaseError as u_err:
            msg = u_err
        finally:
            self.deliver_message(msg, status)
