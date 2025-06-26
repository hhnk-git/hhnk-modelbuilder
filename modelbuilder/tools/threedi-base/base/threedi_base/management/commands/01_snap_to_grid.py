# (c) Nelen & Schuurmans.  GPL licensed, see LICENSE.rst.
# -*- coding: utf-8 -*-
"""
Geometries come from different organisations, different databases etc.
That is, sources differ and so is their precision. This scripts ensures
that all data lies on a regular grid. All successive steps rely on this
operation.
"""

from base.threedi_base.apps import ThreediBaseConfig as conf
from base.threedi_base.command_utils import ThreediBaseCommand
from base.threedi_base.exceptions import UpdateError
from base.threedi_base.logger import Logger

logger = Logger.get(__name__, conf.LOG_LEVEL)


tables_geom_map = {
    "bridge": ["geom"],
    "channel": ["geom", "bufgeom", "pointgeom"],
    "channelsurface": ["geom"],
    "crosssection": ["geom"],
    "culvert": ["geom"],
    "fixeddrainagelevelarea": ["geom"],
    "manhole": ["geom"],
    "orifice": ["geom"],
    "polder": ["geom"],
    "pumpstation": ["geom"],
    "sluice": ["geom"],
    "weirs": ["geom"],
}


class Command(ThreediBaseCommand):
    """
    To make use of reading in the given ini-file and establishing a
    database connection the ThreediBaseCommand.setup_db() method is
    called first.
    """

    help = "Snap all geometries to a regular grid"

    def handle(self, *args, **options):
        """
        main method that sets up the ThreediDatabase instance
        and runs the command
        """
        self.setup_db(*args, **options)
        self._snap_geoms()

    def _snap_geoms(self):
        """
        call the ThreediDatabase-method
        """
        try:
            for table_name, geom_columns in tables_geom_map.items():
                if not self.db.table_exists(table_name=table_name):
                    logger.warning(
                        "[!] Table {} does not exist at schema {}. Skipping...".format(
                            table_name, self.db.schema
                        )
                    )
                    continue
                for column in geom_columns:
                    self.db.snap_to_grid(
                        table_name=table_name, geom_column=column, precision=0.05
                    )
        except UpdateError as u_err:
            self.stdout.write(self.style.ERROR(u_err))
        else:
            self.stdout.write(
                self.style.SUCCESS(
                    "Successfully snapped geometries for the tables {}".format(
                        ", ".join(tables_geom_map.keys())
                    )
                )
            )
