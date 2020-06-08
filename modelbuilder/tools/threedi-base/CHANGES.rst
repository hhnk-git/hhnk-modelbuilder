Changelog of threedi-base
=========================


0.5 (unreleased)
----------------

- Deployed release 0.4 to the production deltares server (deltares-3di-task-01)
  on 2017-05-01.

- Deployed release 0.4 to production on 2017-04-14.


0.4 (2017-04-14)
----------------

- Make sure the pal* attributes of a culvert that touches a channel
  perpendicularly will get reset.

- Because the channel_code is already filled and not emtied if structures
  are too far away from an available channel, they may be connected to a
  random channel too far away. Added some lines that empty the channel_code attribute.
  Added a create table statement that stored stuctures that cannot be
  connected to a channel. Added a delete from statement that removes the
  misfits from the linify data.

- Deployed release 0.3 to production on 2017-02-13.


0.3 (2017-02-13)
----------------

- As part of the deployment all __pycache__ folders and .pyc/.pyo files will
  be deleted. Solves issue #18.

- Deployed release 0.2 to deltares production server on 2017-02-08.

- Add missing connection nodes for culverts that are adjacent or isolated (issue #23).

- Move multiline culverts to culvert_misfit table.

- Do not discard culverts at beginning or end of very long channels.

- Improve clip_culvert tool: will not extend the culvert on to the next
  channel when close to start or endpoint.

- Merge command ``02_*`` and ``03_*``. New name for the tool is
  02_fix_channels (issue #17).

- Move the ``snap_to_grid function`` to the inner geometry.

- Remove lines shorter than the snap distance from command ``02_*`` (issue #16)

- Added input option snap_distance to the ``02_snap_start_end`` command (issue #15).

- Added ``snap_to_grid`` to the ``02_snap_start_end`` command (issue #14).


0.2 (2017-01-19)
----------------

- Bug fix: Remove duplicate positions.

- Bug fix: Remove start- and endpoints for channels with culverts at the
  beginning and end of the channel.

- Rearranged the order of the tools (swapped 03_* and 04_*).

- Deployed release 0.1 to staging and production on 2017-01-17.


0.1 (2017-01-17)
----------------

- Added user feedback to all commands.

- Add management commands that snaps culverts to channels and then clips
  channels by those culverts.

- Add management command ``linify_structures`` for converting structure point
  geometries to line geometries.

- Add management command for fixing short segments.

- Add management commands for line simplification and cutting up circular
  lines.

- Add ansible deploy scripts for staging and production.

- Add management command to snap channel start and end points.

- Add files for local development with ``docker-compose``.

- Database credentials can be specified in an ini file. Added a
  default ini-file.

- Added ``snap_to_grid`` command.
