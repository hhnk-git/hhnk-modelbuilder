# (c) Nelen & Schuurmans.  GPL licensed, see LICENSE.rst.
# -*- coding: utf-8 -*-


class UpdateError(Exception):
    """
    Exception to be raised when updating a table failed
    """

    pass


class InsertError(Exception):
    """
    Exception to be raised when inserting into a table failed
    """

    pass
