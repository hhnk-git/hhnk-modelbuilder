# -*- coding: utf-8 -*-
from psycopg2 import DatabaseError

from base.threedi_base.command_utils import ThreediBaseCommand
from base.threedi_base.constants import CULVERT_BUFFER_SIZE, CULVERT_SNAPPED_TABLE_NAME
from base.threedi_base.culverts import CulvertChannelLines
from base.threedi_base.exceptions import InsertError


class Command(ThreediBaseCommand):
    help = "Clip channels with culverts."

    def add_arguments(self, parser):
        super(Command, self).add_arguments(parser)

        parser.add_argument(
            '--channel-input-table',
            action='store',
            dest='channel_input_table',
            default='channel_simplified',
            help="Channel input table name",
        )
        parser.add_argument(
            '--culvert-input-table',
            action='store',
            dest='culvert_input_table',
            default='culvert',
            help="Culvert input table name",
        )
        parser.add_argument(
            '--channel-output-table',
            action='store',
            dest='channel_output_table',
            default='channel_clipped',
            help="Channel output table name",
        )
        parser.add_argument(
            '--culvert-output-table',
            action='store',
            dest='culvert_output_table',
            default=CULVERT_SNAPPED_TABLE_NAME,
            help="Culvert output table name",
        )
        parser.add_argument(
            '--search-radius',
            action='store',
            dest='buffer_size',
            default=CULVERT_BUFFER_SIZE,
            type=float,
            help="Radius from culvert used to search for channels",
        )
        parser.add_argument(
            '--remove-intermediate-tables',
            dest='rm_tmp_tables',
            action='store_true',
            help="Remove all intermediate tables (default)"
        )
        parser.add_argument(
            '--save-intermediate-tables',
            dest='rm_tmp_tables',
            action='store_false',
            help="Save all intermediate tables"
        )
        parser.set_defaults(rm_tmp_tables=True)

    def handle(self, *args, **options):
        self.set_start_time()
        self.setup_db(*args, **options)
        self.run_command(**options)

    def run_command(self, **options):
        status = 'error'
        msg = ''
        print(options)
        ccl = CulvertChannelLines(
            self.db, buffer_size=options['buffer_size'],
            culvert_input_table=options['culvert_input_table'],
            channel_input_table=options['channel_input_table'],
            culvert_output_table_name=options['culvert_output_table'],
            channel_output_table_name=options['channel_output_table']
        )
        
        # ccl.analyze_dataset() 
        # ccl.create_tmp_culverts()
        # ccl.clip_channels_by_culverts()
        # ccl.move_multi_geoms_to_misfits()
        # ccl.add_missing_culverts_to_misfits()

        try:
            ccl.analyze_dataset()
            ccl.create_tmp_culverts()
            ccl.clip_channels_by_culverts()
            ccl.move_multi_geoms_to_misfits()
            ccl.add_missing_culverts_to_misfits()

        except DatabaseError as u_err:
            msg = u_err
        except InsertError as i_err:
            msg = i_err
        else:
            status = 'success'
            msg = """
            Successfully clipped geometries of channels from table
            '{schema}.{channel_input_table}' with culverts from table
            '{schema}.{culvert_input_table}'. \n
            Channel results are stored here:
            {schema}.{channel_output_table}. \n
            Culvert results here:
            {schema}.{culvert_output_table}. \n
            There are {error_cnt} culverts that could not been snapped.
            They have been stored at {schema}.{misfits_table}
            \n\n
            Finished in {exec_time}""".format(
                channel_input_table=options['channel_input_table'],
                culvert_input_table=options['culvert_input_table'],
                culvert_output_table=options['culvert_output_table'],
                channel_output_table=options['channel_output_table'],
                schema=self.db.schema,
                exec_time=self.get_exec_time(),
                error_cnt=ccl.get_count_misfits(),
                misfits_table=ccl.misfits_table_name
            )
        finally:
            if options['rm_tmp_tables']:
                ccl.remove_tmp_tables()
            self.deliver_message(msg, status)
