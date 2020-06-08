# -*- coding: utf-8 -*-
from psycopg2 import DatabaseError

from base.threedi_base.command_utils import ThreediBaseCommand
from base.threedi_base.constants import CULVERT_OUTPUT_TABLE_NAME

class Command(ThreediBaseCommand):
    help = "Fix short segments by effectively removing them."

    def add_arguments(self, parser):
        super(Command, self).add_arguments(parser)

        parser.add_argument(
            '--channel-table',
            action='store',
            dest='channel_table',
            default='tmp_sel_branches_without_structures',
            help="Input table name of the channels",
        )
        parser.add_argument(
            '--culvert-table',
            action='store',
            dest='culvert_table',
            default=CULVERT_OUTPUT_TABLE_NAME,
            help="Input table name of the culvert, without the tmp_sel_",
        )
        parser.add_argument(
            '--geom-column',
            action='store',
            dest='geom_column',
            default='geom',
            help="Name of the geometry column of the channel input table",
        )
        parser.add_argument(
            '--culvert-geom-column',
            action='store',
            dest='culvert_geom_column',
            default='geom',
            help="Name of culvert geometry column created by the previous "
                 "command.",
        )
        parser.add_argument(
            '--min-distance',
            action='store',
            dest='min_distance',
            type=float,
            default=5,
            help="Minimum distance. Shorter segments will be removed."
        )

    def handle(self, *args, **options):
        self.set_start_time()
        status = 'error'
        msg = ''
        self.setup_db(*args, **options)
        try:
            self.db.fix_short_segments_culvert(
                channel_table=options['channel_table'],
                culvert_table=options['culvert_table'],
                geom_column=options['geom_column'],
                culvert_geom_column=options['culvert_geom_column'],
                min_distance=options['min_distance'],
            )
            status = 'success'
            msg = 'Successfully executed command in {}.'.format(
                self.get_exec_time(), self.db.schema)

        except DatabaseError as u_err:
            msg = u_err
        finally:
            self.deliver_message(msg, status)
