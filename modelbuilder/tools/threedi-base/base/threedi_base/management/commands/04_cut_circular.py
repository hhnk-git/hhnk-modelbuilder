# -*- coding: utf-8 -*-
from psycopg2 import DatabaseError

from base.threedi_base.command_utils import ThreediBaseCommand


class Command(ThreediBaseCommand):
    help = "Cut circular lines."

    def add_arguments(self, parser):
        super(Command, self).add_arguments(parser)

        parser.add_argument(
            "--input-table",
            action="store",
            dest="input_table",
            default="channel_clipped",
            help="Input table name",
        )
        parser.add_argument(
            "--output-table",
            action="store",
            dest="output_table",
            default="channel_cut_circular",
            help="Output table name",
        )

    def handle(self, *args, **options):
        self.set_start_time()
        status = "error"
        msg = ""
        self.setup_db(*args, **options)
        try:
            self.db.cut_circular(
                input_table=options["input_table"], output_table=options["output_table"]
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
